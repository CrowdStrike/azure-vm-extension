# helper.ps1

$VERSION = "0.0.0"

# Get the log folder path from HandlerEnvironment.json
function Get-LogsFolder {
    $handlerEnv = Get-Content -Raw -Path "HandlerEnvironment.json" | ConvertFrom-Json
    $script:LOGS_FOLDER = $handlerEnv[0].handlerEnvironment.logFolder
}

# Logging function
function Log {
    param(
        [string]$level,
        [string]$message
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("o")

    if (-not $script:LOGS_FOLDER) {
        Get-LogsFolder
    }

    $logMessage = "[$timestamp] $level $message"
    Write-Host $logMessage
    Add-Content -Path "$LOGS_FOLDER\cshandler.log" -Value $logMessage
}

# Detect system architecture
function Detect-Architecture {
    $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

    if ($arch -eq "ARM64") {
        $script:ARCH_SUFFIX = "arm64"
    }
    elseif ($arch -eq "AMD64") {
        $script:ARCH_SUFFIX = "x86_64"
    }
    else {
        Log "ERROR" "Unsupported architecture: $arch"
        exit 1
    }

    $script:INSTALLER = "falcon-installer-$ARCH_SUFFIX.exe"
    Log "INFO" "Detected architecture: $arch, using installer: $INSTALLER"
}

# Check if sensor is already installed
function Is-SensorInstalled {
    return Test-Path -Path "C:\Program Files\CrowdStrike\CSFalconService.exe"
}

# Get the configuration file path from HandlerEnvironment.json
function Get-ConfigFile {
    $handlerEnv = Get-Content -Raw -Path "HandlerEnvironment.json" | ConvertFrom-Json
    $cfgPath = $handlerEnv[0].handlerEnvironment.configFolder
    $configFilesPath = Join-Path -Path $cfgPath -ChildPath "*.settings"

    $configFiles = Get-ChildItem -Path $configFilesPath -ErrorAction SilentlyContinue | Sort-Object -Property Name
    if ($configFiles.Count -gt 0) {
        $script:CONFIG_FILE = $configFiles[-1].FullName
    }
    else {
        $script:CONFIG_FILE = $null
    }
}

# Get the status folder path from HandlerEnvironment.json
function Get-StatusFolder {
    $handlerEnv = Get-Content -Raw -Path "HandlerEnvironment.json" | ConvertFrom-Json
    $script:STATUS_FOLDER = $handlerEnv[0].handlerEnvironment.statusFolder
}

# Parse proxy configuration from config file
function Get-ProxyConfig {
    $script:PROXY_HOST = ""
    $script:PROXY_PORT = ""
    $script:HTTPS_PROXY = ""

    if ($CONFIG_FILE -and (Test-Path -Path $CONFIG_FILE)) {
        try {
            $configContent = Get-Content -Raw -Path $CONFIG_FILE | ConvertFrom-Json

            # Extract proxy_host and proxy_port from settings
            if ($configContent.runtimeSettings -and $configContent.runtimeSettings[0].handlerSettings) {
                $settings = $configContent.runtimeSettings[0].handlerSettings

                if ($settings.publicSettings.proxy_host) {
                    $script:PROXY_HOST = $settings.publicSettings.proxy_host
                }
                if ($settings.publicSettings.proxy_port) {
                    $script:PROXY_PORT = $settings.publicSettings.proxy_port
                }
            }

            # Construct HTTPS_PROXY - proxy_host is required, proxy_port is optional
            if ($PROXY_HOST) {
                if ($PROXY_PORT) {
                    $script:HTTPS_PROXY = "$PROXY_HOST`:$PROXY_PORT"
                }
                else {
                    $script:HTTPS_PROXY = $PROXY_HOST
                }
                Log "INFO" "Proxy configuration found: $HTTPS_PROXY"
            }
        }
        catch {
            Log "WARN" "Failed to parse proxy configuration: $_"
        }
    }
}

# Set the status of the VM Extension
function Set-Status {
    param(
        [string]$Operation,
        [string]$Activity,
        [string]$Status,
        [string]$Message,
        [string]$SubStatus,
        [string]$SubStatusStatus,
        [string]$SubStatusMessage
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("o")
    $statusNum = "0"
    $code = 0

    # Get the status folder path
    Get-StatusFolder

    $statusFile = Join-Path -Path $STATUS_FOLDER -ChildPath "$statusNum.status"
    if ($SubStatusStatus -eq "error") {
        $code = 1
    }

    # Create a PowerShell object and convert to JSON
    $statusObject = @(
        @{
            "version" = "1.0"
            "timestampUTC" = $timestamp
            "status" = @{
                "name" = $Operation
                "operation" = $Activity
                "status" = $Status
                "code" = $code
                "formattedMessage" = @{
                    "lang" = "en-US"
                    "message" = $Message
                }
                "substatus" = @(
                @{
                    "name" = $SubStatus
                    "status" = $SubStatusStatus
                    "code" = $code
                    "formattedMessage" = @{
                        "lang" = "en-US"
                        "message" = $SubStatusMessage
                    }
                }
                )
            }
        }
    )

    # Ensure the status folder exists
    if (-not (Test-Path -Path $STATUS_FOLDER)) {
        New-Item -Path $STATUS_FOLDER -ItemType Directory -Force | Out-Null
    }

    # Convert to JSON and write to file without BOM
    try {
        $jsonContent = ConvertTo-Json -InputObject $statusObject -Depth 10

        # Write the file using .NET methods to ensure no BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($statusFile, $jsonContent, $utf8NoBom)
    }
    catch {
        Write-Host "Error writing status file: $_"
    }
}

# Function to create a directory if it doesn't exist
function Create-Folder {
    param(
        [string]$folderPath
    )

    if (-not (Test-Path -Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
    }
}

function Invoke-FalconInstaller {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Install", "Update", "Uninstall")]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    # Get Config file - this sets $CONFIG_FILE
    Get-ConfigFile

    # Get proxy configuration
    Get-ProxyConfig

    # Ensure we have logs folder
    if (-not $LOGS_FOLDER) {
        Get-LogsFolder
    }

    # Detect architecture and set installer
    Detect-Architecture

    # Determine operation-specific settings
    $operationTag = switch ($Operation) {
        "Uninstall" { "UNINSTALL" }
        default { "INSTALL" }
    }

    $activityDescription = "Installing the Falcon Sensor"
    if ($Operation -eq "Uninstall") {
        $activityDescription = "Uninstalling the Falcon Sensor"
    }

    # Determine where to store logs based on operation
    $logsDestination = if ($Operation -eq "Uninstall") { $LOGS_FOLDER } else { $ScriptPath }
    $tempDir = Join-Path -Path $logsDestination -ChildPath "falcon"

    # Get installer path
    $installerPath = Join-Path -Path $ScriptPath -ChildPath $INSTALLER

    # Create base installer arguments
    $installerArgs = @(
        "--verbose",
        "--enable-file-logging",
        "--user-agent=`"azure-vm-extension/$VERSION`"",
        "--tmpdir", "`"$tempDir`"",
        "--config", "`"$CONFIG_FILE`""
    )

    # Add uninstall flag if operation is uninstall
    if ($Operation -eq "Uninstall") {
        $installerArgs = @("--uninstall") + $installerArgs
    }

    Log "INFO" "[$operationTag] running the Falcon installer..."
    try {
        # Create temp directory if it doesn't exist
        Create-Folder $tempDir

        Log "INFO" "[$operationTag] Using installer at: $installerPath with arguments: $($installerArgs -join ' ')"

        # Set proxy environment variable if configured
        $originalProxy = $env:HTTPS_PROXY
        if ($HTTPS_PROXY) {
            Log "INFO" "[$operationTag] Using proxy configuration: $HTTPS_PROXY"
            $env:HTTPS_PROXY = $HTTPS_PROXY
        }

        try {
            $logFilePath = Join-Path -Path $tempDir -ChildPath "falcon-installer.log"
            $process = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait -PassThru -NoNewWindow -RedirectStandardError $logFilePath
            $installerExitCode = $process.ExitCode
        }
        finally {
            # Restore original proxy environment variable
            if ($originalProxy) {
                $env:HTTPS_PROXY = $originalProxy
            }
            elseif ($HTTPS_PROXY) {
                Remove-Item -Path "env:HTTPS_PROXY" -ErrorAction SilentlyContinue
            }
        }

        if ($installerExitCode -eq 0) {
            $successMessage = "The Falcon Sensor $($Operation.ToLower()) process completed"
            Log "INFO" "[$operationTag] $successMessage"
            Set-Status -Operation $Operation -Activity $activityDescription -Status "success" -Message $successMessage -SubStatus "Falcon Sensor" -SubStatusStatus "success" -SubStatusMessage $successMessage
            return 0
        }
        else {
            throw "$($Operation)er exited with code $installerExitCode"
        }
    }
    catch {
        $errorMessage = "The Falcon Sensor $($Operation.ToLower()) failed to complete. Please see '$logFilePath' for more info."
        Log "ERROR" "[$operationTag] $errorMessage"
        Set-Status -Operation $Operation -Activity $activityDescription -Status "failed" -Message "The Falcon Sensor $($Operation.ToLower()) failed to complete." -SubStatus "Falcon Sensor" -SubStatusStatus "error" -SubStatusMessage $errorMessage
        return 1
    }
}

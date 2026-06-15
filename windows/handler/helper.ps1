# helper.ps1

$VERSION = "0.0.0"
$MAX_LOG_SIZE = 5MB

# Check if running in an Azure Arc environment
function Test-ArcEnvironment {
    $arcPath = Join-Path $env:ProgramFiles "AzureConnectedMachineAgent\himds.exe"
    return Test-Path -Path $arcPath
}

# Get the log folder path from HandlerEnvironment.json
function Get-LogsFolder {
    $handlerEnv = Get-Content -Raw -Path (Join-Path $PSScriptRoot "HandlerEnvironment.json") | ConvertFrom-Json
    $script:LOGS_FOLDER = $handlerEnv[0].handlerEnvironment.logFolder
}

function Rotate-Log {
    $logFile = Join-Path $LOGS_FOLDER "cshandler.log"
    if (Test-Path $logFile) {
        $size = (Get-Item $logFile).Length
        if ($size -ge $MAX_LOG_SIZE) {
            Move-Item -Path $logFile -Destination "$logFile.1" -Force
        }
    }
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

    Rotate-Log

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
    $handlerEnv = Get-Content -Raw -Path (Join-Path $PSScriptRoot "HandlerEnvironment.json") | ConvertFrom-Json
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
    $handlerEnv = Get-Content -Raw -Path (Join-Path $PSScriptRoot "HandlerEnvironment.json") | ConvertFrom-Json
    $script:STATUS_FOLDER = $handlerEnv[0].handlerEnvironment.statusFolder
}

# Extract host and port from a proxy URL, stripping scheme and credentials
# e.g. http://user:password@proxy:8080 -> proxy:8080
function Parse-ProxyUrl {
    param([string]$Url)

    $stripped = $Url
    $stripped = $stripped -replace '^https?://', ''
    $stripped = $stripped -replace '^[^@]+@', ''
    $stripped = $stripped -replace '/.*$', ''

    return $stripped
}

# Resolve proxy configuration from the Arc agent
function Get-ArcProxyConfig {
    if ($env:ProxySettings) {
        $script:HTTPS_PROXY = Parse-ProxyUrl $env:ProxySettings
        Log "INFO" "Using Arc proxy from ProxySettings environment variable: $HTTPS_PROXY"
        return
    }

    $arcConfig = Join-Path $env:ProgramData "AzureConnectedMachineAgent\Config\localconfig.json"
    if (Test-Path -Path $arcConfig) {
        try {
            $config = Get-Content -Raw -Path $arcConfig | ConvertFrom-Json
            if ($config.'proxy.url') {
                $script:HTTPS_PROXY = Parse-ProxyUrl $config.'proxy.url'
                Log "INFO" "Using Arc proxy from localconfig.json: $HTTPS_PROXY"
                return
            }
        } catch {
            Log "WARN" "Failed to parse Arc proxy config: $_"
        }
    }
}

# Parse proxy configuration from config file
function Get-ProxyConfig {
    $script:PROXY_HOST = ""
    $script:PROXY_PORT = ""
    $script:HTTPS_PROXY = ""

    # On Arc, inherit the agent's proxy settings first
    if (Test-ArcEnvironment) {
        Get-ArcProxyConfig
        if ($HTTPS_PROXY) {
            return
        }
    }

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

    # Get sequence number from environment variable, fallback to 0 if not available
    $statusNum = if ($env:ConfigSequenceNumber) { $env:ConfigSequenceNumber } else { "0" }
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

    # Azure Arc only supports system-assigned managed identities. If a user-assigned
    # managed identity client ID is configured, warn and clear it so the installer
    # falls back to system-assigned identity via HIMDS challenge/response.
    if ((Test-ArcEnvironment) -and $CONFIG_FILE -and (Test-Path -Path $CONFIG_FILE)) {
        try {
            $cfgJson = Get-Content -Raw -Path $CONFIG_FILE | ConvertFrom-Json
            if ($cfgJson.runtimeSettings -and $cfgJson.runtimeSettings[0].handlerSettings) {
                $pubSettings = $cfgJson.runtimeSettings[0].handlerSettings.publicSettings
                $miClientId = $pubSettings.azure_managed_identity_client_id
                if ($miClientId) {
                    Log "WARN" "[$operationTag] Azure Arc does not support user-assigned managed identities."
                }
            }
        } catch {
            Log "WARN" "[$operationTag] Failed to parse config for managed identity check: $_"
        }
    }

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

    # On Arc, append --disable-provisioning-wait if the setting doesn't exist in the config.
    # If the customer explicitly set it (true or false), respect their choice.
    if ((Test-ArcEnvironment) -and $Operation -ne "Uninstall") {
        $provWaitExists = $false
        if ($CONFIG_FILE -and (Test-Path -Path $CONFIG_FILE)) {
            try {
                $cfgContent = Get-Content -Raw -Path $CONFIG_FILE | ConvertFrom-Json
                if ($cfgContent.runtimeSettings -and $cfgContent.runtimeSettings[0].handlerSettings) {
                    $pubSettings = $cfgContent.runtimeSettings[0].handlerSettings.publicSettings
                    if ($null -ne $pubSettings.PSObject.Properties.Item("disable_provisioning_wait")) {
                        $provWaitExists = $true
                    }
                }
            } catch {
                Log "WARN" "[$operationTag] Failed to parse config for provisioning wait check: $_"
            }
        }

        if (-not $provWaitExists) {
            Log "INFO" "[$operationTag] Arc environment detected, appending --disable-provisioning-wait"
            $installerArgs += "--disable-provisioning-wait"
        }
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

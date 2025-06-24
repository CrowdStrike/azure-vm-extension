# enable.ps1

# Stop on errors
$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\helper.ps1"

# Check if sensor is already installed
if (Is-SensorInstalled) {
    Log "INFO" "[INSTALL] Falcon Sensor is already installed. Skipping installation."
    Set-Status -Operation "Install" -Activity "Installing the Falcon Sensor" -Status "success" -Message "The Falcon Sensor is already installed" -SubStatus "Falcon Sensor" -SubStatusStatus "success" -SubStatusMessage "The Falcon Sensor is already installed"
    exit 0
}

Log "INFO" "[INSTALL] Starting Falcon Sensor installation"

$result = Invoke-FalconInstaller -Operation "Install" -ScriptPath $scriptPath
exit $result

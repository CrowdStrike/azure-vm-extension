# uninstall.ps1

# Stop on errors
$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\helper.ps1"

# Check if sensor is already installed
if (-not (Is-SensorInstalled)) {
    Log "INFO" "[UNINSTALL] Falcon Sensor is already been uninstalled. Skipping uninstall process."
    Set-Status -Operation "Uninstall" -Activity "Uninstalling the Falcon Sensor" -Status "success" -Message "The Falcon Sensor is not installed" -SubStatus "Falcon Sensor" -SubStatusStatus "success" -SubStatusMessage "The Falcon Sensor is not installed"
    exit 0
}

# Run the installer with appropriate parameters
Log "INFO" "[UNINSTALL] running the Falcon installer to remove the Falcon sensor..."
$result = Invoke-FalconInstaller -Operation "Uninstall" -ScriptPath $scriptPath
exit $result
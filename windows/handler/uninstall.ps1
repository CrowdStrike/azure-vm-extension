# uninstall.ps1

# Stop on errors
$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\helper.ps1"

Get-LogsFolder

if (Is-SensorInstalled) {
    Log "ERROR" "[UNINSTALL] Falcon Sensor is still installed after uninstall process was completed in the disable step. Please check the logs for more details. Please see '$LOGS_FOLDER\falcon\falcon-installer.log' for more info."
    exit 1
}

exit 0
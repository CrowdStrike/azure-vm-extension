# uninstall.ps1

# Stop on errors
$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\helper.ps1"

Log "INFO" "[UNINSTALL] Falcon Sensor uninstall should have already happened during disable"

exit 0

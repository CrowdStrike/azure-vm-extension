# install.ps1

# Stop on errors
$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\helper.ps1"

Log "INFO" "[INSTALL] Falcon Sensor installation will happen on enable"
exit 0

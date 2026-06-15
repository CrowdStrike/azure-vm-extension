# reset.ps1

# Stop on errors
$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\helper.ps1"

Log "INFO" "[RESET] Resetting extension handler state"

Get-StatusFolder

if (Test-Path -Path $STATUS_FOLDER) {
    Remove-Item -Path "$STATUS_FOLDER\*.status" -Force -ErrorAction SilentlyContinue
    Log "INFO" "[RESET] Cleared status files from $STATUS_FOLDER"
}

Log "INFO" "[RESET] Extension handler state has been reset"

exit 0

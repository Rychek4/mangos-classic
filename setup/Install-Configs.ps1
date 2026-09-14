<#
.SYNOPSIS
    Turns the installed .conf.dist templates into live .conf files and switches
    the narrator bridge on.

.DESCRIPTION
    `cmake --install` leaves templates named *.conf.dist. The server reads the
    names without .dist, so until they are copied it starts with defaults and
    no bridge.

        powershell -ExecutionPolicy Bypass -File C:\wow\mangos-classic\setup\Install-Configs.ps1

    Existing .conf files are left alone unless you pass -Overwrite: your edits
    are worth more than these defaults. The bridge line is set either way,
    because that is the one setting this project cannot run without.
#>
[CmdletBinding()]
param(
    [string] $ServerPath = "C:\wow\server",
    [int]    $BridgePort = 8890,
    [switch] $Overwrite,
    # setup.bat hands the same command line to every script in turn, so each
    # one has to shrug at options meant for one of the others rather than
    # refuse to run.
    [Parameter(ValueFromRemainingArguments = $true)] $ForOtherScripts
)

. (Join-Path $PSScriptRoot "_Common.ps1")

Write-Host ""
Write-Host "  Azeroth server: configuration" -ForegroundColor White
Write-Host "  server   $ServerPath"

if (-not (Test-Path (Join-Path $ServerPath "mangosd.exe"))) {
    Fail "No mangosd.exe in $ServerPath. Build and install the server first (BUILDING_PLAYERBOTS.md)."
}

# 1 -------------------------------------------------------------------------
Write-Step "Copying the templates"

$templates = Get-ChildItem -Path $ServerPath -Filter "*.conf.dist" -File | Sort-Object Name
if (-not $templates) { Fail "No .conf.dist files in $ServerPath. The install did not finish." }

foreach ($template in $templates) {
    $live = Join-Path $ServerPath ($template.Name -replace "\.dist$", "")
    if ((Test-Path $live) -and -not $Overwrite) {
        Write-Note "kept    $(Split-Path $live -Leaf) (already there; -Overwrite replaces it)"
        continue
    }
    Copy-Item $template.FullName $live -Force
    Write-Good "wrote   $(Split-Path $live -Leaf)"
}

# 2 -------------------------------------------------------------------------
Write-Step "Switching the bridge on"

<#
    On Windows the module opens aiplayerbot.conf as a bare relative filename,
    resolved against the working directory. If it is not beside mangosd.exe the
    server still starts and only mentions in passing that playerbots is off,
    which is a slow way to find out.
#>
$botConf = Join-Path $ServerPath "aiplayerbot.conf"
if (-not (Test-Path $botConf)) {
    Fail "aiplayerbot.conf is missing. The playerbots module was not installed with the server."
}

$lines = Get-Content $botConf
$sawPort = $false
$updated = foreach ($line in $lines) {
    if ($line -match "^\s*#?\s*AiPlayerbot\.Bridge\.Port\s*=") {
        $sawPort = $true
        "AiPlayerbot.Bridge.Port = $BridgePort"
    } else {
        $line
    }
}
if (-not $sawPort) {
    $updated = $updated + "" + "# added by setup\Install-Configs.ps1" + "AiPlayerbot.Bridge.Port = $BridgePort"
    Write-Warn "no Bridge.Port line in the template; appended one"
    Write-Note "An older playerbots build may be installed. Rebuild if the bridge never listens."
}
Set-Content -Path $botConf -Value $updated
Write-Good "AiPlayerbot.Bridge.Port = $BridgePort"

$enabled = Select-String -Path $botConf -Pattern "^\s*AiPlayerbot\.Enabled\s*=\s*(\d)" | Select-Object -First 1
if ($enabled -and $enabled.Matches[0].Groups[1].Value -eq "0") {
    Write-Warn "AiPlayerbot.Enabled is 0. Set it to 1 or there will be no bots at all."
} else {
    Write-Good "AiPlayerbot.Enabled is on"
}

Write-Host ""
Write-Host "  Configuration is ready." -ForegroundColor Green
Write-Host "  Next: extract the client data, then setup\Test-Setup.ps1." -ForegroundColor Gray
Write-Host ""

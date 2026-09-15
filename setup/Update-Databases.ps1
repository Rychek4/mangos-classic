<#
.SYNOPSIS
    Brings the four databases up to the revision the core checkout expects.

.DESCRIPTION
    Run this after pulling a newer core and rebuilding:

        powershell -ExecutionPolicy Bypass -File C:\wow\mangos-classic\setup\Update-Databases.ps1

    Each database's version table names the last update applied to it; each
    file in sql\updates\<database>\ is one update. Whatever comes after the
    database's current one is applied, in order. Nothing is touched on a
    database that is already current, and a database that is AHEAD of the core
    is reported as such rather than guessed at.

    Install-Databases.ps1 does this too, as one of its steps. This is the same
    thing on its own, for the case where only the core moved.
#>
[CmdletBinding()]
param(
    [string] $CorePath   = "C:\wow\mangos-classic",
    [string] $MySqlPath  = "",
    [string] $DbUser     = "mangos",
    [string] $DbPassword = "mangos",
    [Parameter(ValueFromRemainingArguments = $true)] $ForOtherScripts
)

. (Join-Path $PSScriptRoot "_Common.ps1")

Write-Host ""
Write-Host "  Azeroth server: database updates" -ForegroundColor White
Write-Host "  core     $CorePath"

$mysql = Find-MySql -Hint $MySqlPath
if (-not $mysql) { Fail "Cannot find mysql.exe. Pass -MySqlPath." }
if (-not (Test-Path (Join-Path $CorePath "sql\updates\mangos"))) {
    Fail "No sql\updates\mangos under $CorePath; that is not the core checkout."
}
if (-not (Test-Port 3306)) { Fail "Nothing is listening on 127.0.0.1:3306. Start MySQL first." }

Write-Step "Bringing each database up to the core's revision"
if (-not (Initialize-MySqlOptions -MySql $mysql -User $DbUser -Password $DbPassword)) {
    Fail "'$DbUser' cannot connect to MySQL."
}

$stale = 0
foreach ($db in $script:CoreDatabases) {
    if (-not (Update-CoreDatabase -MySql $mysql -CorePath $CorePath -User $DbUser -Password $DbPassword @db)) { $stale++ }
}

Write-Host ""
if ($stale -gt 0) {
    Write-Host "  $stale database(s) are not in step with this core. See above." -ForegroundColor Red
    Write-Host ""
    exit 1
}
Write-Host "  All four databases match the core. Start the server." -ForegroundColor Green
Write-Host ""

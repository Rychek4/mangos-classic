<#
.SYNOPSIS
    Checks everything the server needs before you try to start it.

.DESCRIPTION
    Reads only. Nothing here changes a file, a database or the world.

        powershell -ExecutionPolicy Bypass -File C:\wow\mangos-classic\setup\Test-Setup.ps1

    Run it whenever something does not work. It is faster than reading a log,
    and it checks the things that fail quietly: a config file in the wrong
    folder, extracted map data in the wrong folder, a database that exists but
    is empty. Exits non-zero if anything is wrong.
#>
[CmdletBinding()]
param(
    [string] $ServerPath = "C:\wow\server",
    [string] $MySqlPath  = "",
    [string] $DbUser     = "mangos",
    [string] $DbPassword = "mangos",
    [int]    $BridgePort = 8890,
    # setup.bat hands the same command line to every script in turn, so each
    # one has to shrug at options meant for one of the others rather than
    # refuse to run.
    [Parameter(ValueFromRemainingArguments = $true)] $ForOtherScripts
)

. (Join-Path $PSScriptRoot "_Common.ps1")

$problems = 0
function Bad([string] $Message) { Write-Bad $Message; $script:problems++ }

Write-Host ""
Write-Host "  Azeroth server: preflight" -ForegroundColor White
Write-Host "  server   $ServerPath"

# 1 -------------------------------------------------------------------------
Write-Step "The binaries"

foreach ($exe in @("mangosd.exe", "realmd.exe")) {
    $path = Join-Path $ServerPath $exe
    if (Test-Path $path) { Write-Good $exe } else { Bad "$exe is missing from $ServerPath" }
}

# A binary that will not run at all - wrong architecture, a missing runtime
# DLL - is a real thing to find here, and it must be reported rather than
# thrown, or the checks below never run.
if (Test-Path (Join-Path $ServerPath "mangosd.exe")) {
    try {
        $version = & (Join-Path $ServerPath "mangosd.exe") --version 2>&1 | Select-Object -First 3
        if ($LASTEXITCODE -ne 0 -and -not $version) { throw "mangosd.exe --version returned $LASTEXITCODE" }
        foreach ($line in $version) { Write-Note $line }
    } catch {
        Bad "mangosd.exe will not run: $($_.Exception.Message)"
        Write-Note "Usually a missing Visual C++ runtime. Install the x64 redistributable."
    }
}

# 2 -------------------------------------------------------------------------
Write-Step "Extracted client data"

<#
    The shipped DataDir is "." so these four have to sit beside mangosd.exe,
    not in the client folder they came out of. Without dbc and maps the server
    refuses to start; without mmaps the bots cannot path, which looks like a
    bug in the bots rather than a missing folder.
#>
$data = @{ "dbc"   = "spell and item definitions; the server will not start without it"
           "maps"  = "terrain; the server will not start without it"
           "vmaps" = "line of sight; without it everything can see through walls"
           "mmaps" = "pathfinding; without it bots stand still or walk into things" }

foreach ($folder in @("dbc", "maps", "vmaps", "mmaps")) {
    $path = Join-Path $ServerPath $folder
    if (-not (Test-Path $path)) {
        Bad "$folder is missing - $($data[$folder])"
        continue
    }
    $count = @(Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue).Count
    if ($count -eq 0) { Bad "$folder exists but is empty - $($data[$folder])" }
    else { Write-Good ("{0,-6} {1} files" -f $folder, $count) }
}

# 3 -------------------------------------------------------------------------
Write-Step "Configuration"

foreach ($conf in @("mangosd.conf", "realmd.conf", "aiplayerbot.conf")) {
    $path = Join-Path $ServerPath $conf
    if (Test-Path $path) { Write-Good $conf }
    else { Bad "$conf is not beside mangosd.exe. Run setup\Install-Configs.ps1." }
}

$botConf = Join-Path $ServerPath "aiplayerbot.conf"
if (Test-Path $botConf) {
    $bridge = Select-String -Path $botConf -Pattern "^\s*AiPlayerbot\.Bridge\.Port\s*=\s*(\d+)" | Select-Object -First 1
    if (-not $bridge) {
        Bad "AiPlayerbot.Bridge.Port is commented out. The narrator will have nothing to connect to."
    } else {
        $port = [int] $bridge.Matches[0].Groups[1].Value
        if ($port -eq 0) { Bad "AiPlayerbot.Bridge.Port is 0, which means off." }
        else { Write-Good "bridge port $port" }
    }
}

# 4 -------------------------------------------------------------------------
Write-Step "Databases"

$mysql = Find-MySql -Hint $MySqlPath
if (-not $mysql) {
    Bad "mysql.exe not found, so the databases cannot be checked."
} else {
    $checks = @(
        @{ Db = "classicmangos";     Table = "creature_template";           Least = 1000 },
        @{ Db = "classicmangos";     Table = "ai_playerbot_texts";          Least = 1 },
        @{ Db = "classicmangos";     Table = "ai_playerbot_named_location"; Least = 1 },
        @{ Db = "classiccharacters"; Table = "ai_playerbot_names";          Least = 1 },
        @{ Db = "classiccharacters"; Table = "ai_playerbot_random_bots";    Least = 0 },
        @{ Db = "classicrealmd";     Table = "account";                     Least = 0 },
        @{ Db = "classicrealmd";     Table = "realmlist";                   Least = 1 }
    )
    foreach ($check in $checks) {
        $count = Get-RowCount -MySql $mysql -Database $check.Db -Table $check.Table -User $DbUser -Password $DbPassword
        $label = "{0}.{1}" -f $check.Db, $check.Table
        if ($count -lt 0)              { Bad ("{0,-46} missing or unreachable" -f $label) }
        elseif ($count -lt $check.Least) { Bad ("{0,-46} {1} rows, expected more" -f $label, $count) }
        else                             { Write-Good ("{0,-46} {1} rows" -f $label, $count) }
    }

    <#
        realmd.sql ships four accounts - ADMINISTRATOR, GAMEMASTER, MODERATOR,
        PLAYER - whose passwords are the usernames. So "there are accounts" is
        never news; "there are only those four" is.
    #>
    $accounts = Get-RowCount -MySql $mysql -Database "classicrealmd" -Table "account" -User $DbUser -Password $DbPassword
    if ($accounts -le 4) {
        Write-Warn "Only the four demo accounts that ship with the schema."
        Write-Note "Make your own: start mangosd and type  account create <name> <password>"
        Write-Note "Their passwords are their usernames, so delete them if this machine"
        Write-Note "is ever reachable from outside your network."
    } else {
        Write-Good "$accounts accounts (four of them the shipped demo ones)"
    }
    $bots = Get-RowCount -MySql $mysql -Database "classiccharacters" -Table "ai_playerbot_random_bots" `
                         -User $DbUser -Password $DbPassword
    if ($bots -eq 0) {
        Write-Warn "The random bot pool is empty. The server fills it a few minutes after first start."
        Write-Note "Until it does, the narrator has nobody to cast and every scene is skipped."
    }
}

# 5 -------------------------------------------------------------------------
Write-Step "What is already listening"

# Test-NetConnection spends seconds on a closed port. A plain TCP connect with
# a short timeout answers the same question in milliseconds.
function Test-Port([int] $Port, [int] $TimeoutMs = 300) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $handle = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (-not $handle.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($handle)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

$ports = [ordered] @{
    3306        = "MySQL"
    3724        = "realmd, the login server"
    8085        = "mangosd, the world server"
    $BridgePort = "the narrator bridge"
    8080        = "the language model (llama.cpp)"
}
# GetEnumerator, not $ports[$key]: an ordered dictionary reads an integer
# index as a position, so $ports[3306] asks for the 3306th entry.
foreach ($entry in $ports.GetEnumerator()) {
    if (Test-Port ([int] $entry.Key)) { Write-Good ("{0,-6} {1}" -f $entry.Key, $entry.Value) }
    else                              { Write-Note ("{0,-6} {1} - not running" -f $entry.Key, $entry.Value) }
}

Write-Host ""
if ($problems -gt 0) {
    Write-Host "  $problems problem(s). Fix those before starting the server." -ForegroundColor Red
    Write-Host ""
    exit 1
}
Write-Host "  Preflight clean. Run setup\start-server.bat." -ForegroundColor Green
Write-Host ""

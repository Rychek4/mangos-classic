<#
.SYNOPSIS
    Builds every database the server needs, from nothing to ready to start.

.DESCRIPTION
    Four databases, the server's own MySQL user, the base schemas, the full
    classic world database, and the playerbots tables. Roughly fifteen minutes,
    almost all of it the world database loading.

    Run it from anywhere:

        powershell -ExecutionPolicy Bypass -File C:\wow\mangos-classic\setup\Install-Databases.ps1

    It asks for your MySQL root password once, to create the databases and the
    `mangos` user. Everything after that runs as `mangos`, so the root password
    is never put on a command line where other programs could read it.

    Safe to run again. It skips what already exists unless you pass -Force,
    which drops the four databases first.

.PARAMETER ClientlessCheck
    Skip the check for extracted client data. The databases do not need it;
    the server does. On by default so you are told early.
#>
[CmdletBinding()]
param(
    [string] $CorePath       = "C:\wow\mangos-classic",
    [string] $PlayerbotsPath = "C:\wow\playerbots",
    [string] $ClassicDbPath  = "C:\wow\classic-db",
    [string] $MySqlPath      = "",
    [string] $DbUser         = "mangos",
    [string] $DbPassword     = "mangos",
    [switch] $Force,
    [switch] $SkipWorldDb
)

. (Join-Path $PSScriptRoot "_Common.ps1")

Write-Host ""
Write-Host "  Azeroth server: databases" -ForegroundColor White
Write-Host "  core       $CorePath"
Write-Host "  playerbots $PlayerbotsPath"
Write-Host "  world db   $ClassicDbPath"

# 1 -------------------------------------------------------------------------
Write-Step "Looking for the tools"

$mysql = Find-MySql -Hint $MySqlPath
if (-not $mysql) {
    Write-Bad "Cannot find mysql.exe."
    Write-Note "Install MySQL Community Server, then run this again. If it is already"
    Write-Note "installed, find mysql.exe under C:\Program Files\MySQL and add its"
    Write-Note "bin folder to PATH."
    exit 1
}
Write-Good "mysql    $mysql"

$bash = $null
if (-not $SkipWorldDb) {
    $bash = Find-GitBash
    if (-not $bash) {
        Write-Bad "Cannot find Git Bash (bash.exe)."
        Write-Note "The world database installs itself with a shell script, and Git Bash is"
        Write-Note "how that runs on Windows. Install Git for Windows and run this again."
        exit 1
    }
    Write-Good "bash     $bash"
}

if (-not (Test-Path (Join-Path $CorePath "sql\create\db_create_mysql.sql"))) {
    Fail "That does not look like the core checkout: $CorePath (no sql\create\db_create_mysql.sql)"
}
if (-not (Test-Path (Join-Path $PlayerbotsPath "sql\characters\ai_playerbot_random_bots.sql"))) {
    Fail "That does not look like the playerbots checkout: $PlayerbotsPath"
}
Write-Good "both checkouts look right"

# 2 -------------------------------------------------------------------------
Write-Step "Is MySQL actually running?"

<#
    Asked before anything else, and before the password prompt in particular.
    Typing a root password and then being told the connection was refused is
    the wrong answer to the wrong question: the password was never tried.
#>
if (-not (Test-Port 3306)) {
    Write-Bad "Nothing is listening on 127.0.0.1:3306, so MySQL is not running."
    Write-Note "Find the service and start it:"
    Write-Note ""
    Write-Note "    Get-Service MySQL*"
    Write-Note "    Start-Service <the name it printed>"
    Write-Note "    Set-Service <the name it printed> -StartupType Automatic"
    Write-Note ""
    Write-Note "If Get-Service finds nothing, the server files are installed but the"
    Write-Note "service was never created. Re-run MySQL Installer and choose Reconfigure"
    Write-Note "on the server, which initialises the data directory and registers it."
    exit 1
}
Write-Good "something is listening on 127.0.0.1:3306"

# 4 -------------------------------------------------------------------------
Write-Step "Creating the four databases and the server's MySQL user"

$wanted   = @("classicmangos", "classiccharacters", "classicrealmd", "classiclogs")
$existing = @(Invoke-Sql -MySql $mysql -User $DbUser -Password $DbPassword `
                         -Query "SHOW DATABASES LIKE 'classic%'")
$missing  = @($wanted | Where-Object { $existing -notcontains $_ })
$haveAll  = ($missing.Count -eq 0)

if ($haveAll -and -not $Force) {
    Write-Good "all four already exist, and $DbUser can reach them"
    Write-Note "Pass -Force to drop and rebuild them from scratch."
} else {
    if ($Force) {
        Write-Warn "-Force: the four classic* databases are about to be dropped."
        $answer = Read-Host "     Type DROP to confirm"
        if ($answer -ne "DROP") { Fail "Not confirmed. Nothing was changed." }
    }

    Write-Note "MySQL root password, please. It is used for this step only."
    $secure = Read-Host "     root password" -AsSecureString
    $rootPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    if (-not $rootPass) {
        Fail "No password was entered. This step needs a console it can prompt on; run it from a PowerShell window rather than a pipeline or a scheduled task."
    }

    # The shipped script uses plain CREATE DATABASE, which fails the second
    # time. Same statements, made repeatable, so re-running is not a dead end.
    $createSql = Get-Content (Join-Path $CorePath "sql\create\db_create_mysql.sql") -Raw
    $createSql = $createSql -replace "CREATE DATABASE ``", "CREATE DATABASE IF NOT EXISTS ``"
    if ($Force) {
        $drops = @("classicmangos", "classiccharacters", "classicrealmd", "classiclogs") |
                 ForEach-Object { "DROP DATABASE IF EXISTS ``$_``;" }
        $createSql = ($drops -join "`n") + "`n" + $createSql
    }
    $createSql = $createSql -replace "'mangos'@'localhost' IDENTIFIED BY 'mangos'",
                                     "'$DbUser'@'localhost' IDENTIFIED BY '$DbPassword'"
    $createSql = $createSql -replace "TO 'mangos'@'localhost'", "TO '$DbUser'@'localhost'"

    # WriteAllText with an explicit no-BOM encoding. Set-Content on Windows
    # PowerShell writes a BOM, and mysql reads it as part of the first statement.
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) "azeroth_db_create.sql"
    [System.IO.File]::WriteAllText($temp, $createSql, (New-Object System.Text.UTF8Encoding($false)))
    $result = Invoke-SqlAsRoot -MySql $mysql -RootPassword $rootPass -File $temp
    Remove-Item $temp -ErrorAction SilentlyContinue
    $rootPass = $null

    if (-not $result.Ok) {
        # mysql's own error numbers say which of these it was, so say which.
        if ($result.Output -match "1045|Access denied") {
            Write-Bad "MySQL rejected that root password."
            Write-Note "If you have forgotten it, MySQL Installer can reset it: Reconfigure"
            Write-Note "the server and set a new root password."
        } elseif ($result.Output -match "2003|Can't connect") {
            Write-Bad "MySQL stopped answering between the check above and this step."
            Write-Note "Check the service: Get-Service MySQL*"
        } else {
            Write-Bad "MySQL refused the statements that create the databases."
        }
        Write-Host $result.Output
        exit 1
    }
    Write-Good "classicmangos, classiccharacters, classicrealmd, classiclogs"
    Write-Good "user '$DbUser' can reach all four from localhost"
}

# 4 -------------------------------------------------------------------------
Write-Step "Loading the base schemas (realmd, characters, logs)"

if (-not (Initialize-MySqlOptions -MySql $mysql -User $DbUser -Password $DbPassword)) {
    Fail "'$DbUser' cannot connect to MySQL. Step 2 did not do what it said it did."
}

# Not sql\base\mangos.sql: the world database arrives as a complete dump in
# step 5 and brings its own structure with it.
$bases = @{ "classicrealmd"     = "sql\base\realmd.sql"
            "classiccharacters" = "sql\base\characters.sql"
            "classiclogs"       = "sql\base\logs.sql" }

foreach ($db in $bases.Keys) {
    $file = Join-Path $CorePath $bases[$db]
    if (-not (Invoke-SqlFile -MySql $mysql -Database $db -File $file -User $DbUser -Password $DbPassword)) {
        Fail "Failed loading $($bases[$db]) into $db"
    }
    Write-Good "$db  <-  $($bases[$db])"
}

$realms = Invoke-Sql -MySql $mysql -Database "classicrealmd" -User $DbUser -Password $DbPassword `
                     -Query "SELECT CONCAT(name, ' at ', address, ':', port) FROM realmlist"
if ($realms) { Write-Good "realm: $($realms | Select-Object -First 1)" }

# 5 -------------------------------------------------------------------------
Write-Step "Fetching the world database"

if ($SkipWorldDb) {
    Write-Warn "skipped (-SkipWorldDb)"
} else {
    if (-not (Test-Path (Join-Path $ClassicDbPath "InstallFullDB.sh"))) {
        Write-Note "Cloning cmangos/classic-db into $ClassicDbPath. About 400 MB."
        & git clone --depth 1 https://github.com/cmangos/classic-db.git $ClassicDbPath
        if ($LASTEXITCODE -ne 0) { Fail "git clone failed. Check the network and try again." }
    }
    Write-Good "world database repository present"

    # Writing this file is the step people get wrong by hand, so it is written
    # rather than explained. Every default in it already matches what step 2
    # created; only the paths and the two switches actually need setting.
    $config = @"
## Written by setup\Install-Databases.ps1. Edit freely; it is not overwritten
## unless you run that script again.
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_USERNAME="$DbUser"
MYSQL_PASSWORD="$DbPassword"
MYSQL_USERIP="localhost"
WORLD_DB_NAME="classicmangos"
REALM_DB_NAME="classicrealmd"
CHAR_DB_NAME="classiccharacters"
LOGS_DB_NAME="classiclogs"
MYSQL_PATH="$((ConvertTo-MsysPath $mysql))"
## Left empty this becomes `"" --version` on line 905 of the installer, which
## prints "command not found" and carries on. Harmless, but it is noise, and
## the backup commands need a real path anyway.
MYSQL_DUMP_PATH="$((ConvertTo-MsysPath (Join-Path (Split-Path $mysql) "mysqldump.exe")))"
CORE_PATH="$((ConvertTo-MsysPath $CorePath))"
LOCALES="YES"
FORCE_WAIT="NO"
DEV_UPDATES="NO"
AHBOT="NO"
## Left NO on purpose. The installer looks for the module's SQL inside the core
## at src/modules/PlayerBots/sql, and ours is a separate checkout, so it would
## quietly find nothing and say nothing. Step 6 below applies those files.
PLAYERBOTS_DB="NO"
"@
    # A shell script sources this, so: unix line endings and no BOM.
    $configPath = Join-Path $ClassicDbPath "InstallFullDB.config"
    [System.IO.File]::WriteAllText($configPath, ($config -replace "`r`n", "`n"),
                                   (New-Object System.Text.UTF8Encoding($false)))
    Write-Good "wrote $configPath"

    Write-Step "Loading the world database (this is the long one, 5-15 minutes)"
    Write-Note "Rows scroll past. That is the script working, not failing."
    $msysDb = ConvertTo-MsysPath $ClassicDbPath
    & $bash -lc "cd '$msysDb' && ./InstallFullDB.sh -World"
    if ($LASTEXITCODE -ne 0) {
        Write-Bad "The world database installer stopped with an error."
        Write-Note "Its output is above. The usual cause is MYSQL_PATH or CORE_PATH in"
        Write-Note "$configPath pointing somewhere that does not exist."
        exit 1
    }
    Write-Good "world database loaded"
}

# 6 -------------------------------------------------------------------------
Write-Step "Applying the playerbots tables"

<#
    Two of these are not self-contained. ai_playerbot_indexes.sql adds indexes
    to the loot tables and ai_playerbot_rpg_races.sql edits gossip_menu_option,
    so both need the world database to be there already. And the index file has
    no IF NOT EXISTS, so applying it twice is an error rather than a no-op.
    Both are handled by looking before leaping, not by ignoring failures.
#>
$haveWorld = Test-SqlTable -MySql $mysql -Database "classicmangos" -Table "creature_template" `
                           -User $DbUser -Password $DbPassword
if (-not $haveWorld) {
    if (-not $SkipWorldDb) {
        Fail "classicmangos has no creature_template, so the world database did not load."
    }
    Write-Warn "No world database (-SkipWorldDb), so the two files that need it are skipped."
}
$haveIndexes = Test-SqlIndex -MySql $mysql -Database "classicmangos" `
                             -Index "idx_creature_loot_template_item" -User $DbUser -Password $DbPassword

$groups = @(
    @{ Db = "classicmangos";     Glob = "sql\world\*.sql" },
    @{ Db = "classicmangos";     Glob = "sql\world\classic\*.sql" },
    @{ Db = "classiccharacters"; Glob = "sql\characters\*.sql" }
)
$applied = 0
foreach ($group in $groups) {
    $files = Get-ChildItem -Path (Join-Path $PlayerbotsPath $group.Glob) -File -ErrorAction SilentlyContinue |
             Sort-Object Name
    if (-not $files) { Fail "No SQL files matched $($group.Glob) under $PlayerbotsPath" }
    foreach ($file in $files) {
        $needsWorld = $file.Name -in @("ai_playerbot_indexes.sql", "ai_playerbot_rpg_races.sql")
        if ($needsWorld -and -not $haveWorld) {
            Write-Note "skip    $($file.Name) (needs the world database)"
            continue
        }
        if ($file.Name -eq "ai_playerbot_indexes.sql" -and $haveIndexes) {
            Write-Good "$($group.Db)  --  $($file.Name) already applied"
            continue
        }
        if (-not (Invoke-SqlFile -MySql $mysql -Database $group.Db -File $file.FullName `
                                 -User $DbUser -Password $DbPassword)) {
            Fail "Failed applying $($file.Name) to $($group.Db). The error is in the lines above."
        }
        Write-Good "$($group.Db)  <-  $($file.Name)"
        $applied++
    }
}
Write-Good "$applied playerbots SQL files applied"

# 7 -------------------------------------------------------------------------
Write-Step "Checking the result"

$checks = @(
    @{ Db = "classicmangos";     Table = "creature_template";        Least = $(if ($SkipWorldDb) { -1 } else { 1000 }); Why = "the world database" },
    @{ Db = "classicmangos";     Table = "ai_playerbot_texts";       Least = 1;    Why = "what bots can say" },
    @{ Db = "classicmangos";     Table = "ai_playerbot_named_location"; Least = 1; Why = "'go to Goldshire'" },
    @{ Db = "classiccharacters"; Table = "characters";               Least = 0;    Why = "your characters" },
    @{ Db = "classiccharacters"; Table = "ai_playerbot_names";       Least = 1;    Why = "names for random bots" },
    @{ Db = "classiccharacters"; Table = "ai_playerbot_random_bots"; Least = 0;    Why = "the pool the narrator casts from" },
    @{ Db = "classicrealmd";     Table = "realmlist";                Least = 1;    Why = "where the client is sent" }
)
$bad = 0
foreach ($check in $checks) {
    $count = Get-RowCount -MySql $mysql -Database $check.Db -Table $check.Table -User $DbUser -Password $DbPassword
    $label = "{0}.{1}" -f $check.Db, $check.Table
    if ($check.Least -lt 0) {
        Write-Note ("{0,-46} not checked  ({1})" -f $label, $check.Why)
    } elseif ($count -lt 0) {
        Write-Bad ("{0,-46} missing  ({1})" -f $label, $check.Why)
        $bad++
    } elseif ($count -lt $check.Least) {
        Write-Warn ("{0,-46} {1} rows, expected more  ({2})" -f $label, $count, $check.Why)
        $bad++
    } else {
        Write-Good ("{0,-46} {1} rows  ({2})" -f $label, $count, $check.Why)
    }
}

Write-Host ""
if ($bad -gt 0) {
    Write-Bad "$bad table(s) are not right. Nothing after this will work properly."
    Write-Note "Run this script again with -Force to rebuild from scratch."
    exit 1
}

if ($SkipWorldDb) {
    Write-Warn "The world database was skipped, so the server cannot start yet."
    Write-Note "Run this again without -SkipWorldDb when you are ready for it."
}
Write-Host "  Databases are ready." -ForegroundColor Green
Write-Host "  ai_playerbot_random_bots is empty for now; the server fills it on first start." -ForegroundColor Gray
Write-Host "  Next: setup\Install-Configs.ps1, then extract the client data." -ForegroundColor Gray
Write-Host ""

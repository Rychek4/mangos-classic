<#
    Shared helpers for the setup scripts in this folder. Dot-sourced, not run
    on its own:

        . (Join-Path $PSScriptRoot "_Common.ps1")

    Nothing here touches the database or the world. It finds tools, converts
    paths and prints in a consistent shape, so the scripts that do the work
    stay short enough to read.
#>

$script:StepNumber = 0

function Write-Step([string] $Message) {
    $script:StepNumber++
    Write-Host ""
    Write-Host ("  {0}. {1}" -f $script:StepNumber, $Message) -ForegroundColor Cyan
}

function Write-Good([string] $Message) { Write-Host "     ok    $Message" -ForegroundColor Green }
function Write-Note([string] $Message) { Write-Host "           $Message" -ForegroundColor Gray }
function Write-Warn([string] $Message) { Write-Host "     note  $Message" -ForegroundColor Yellow }
function Write-Bad ([string] $Message) { Write-Host "     STOP  $Message" -ForegroundColor Red }

function Fail([string] $Message) {
    Write-Bad $Message
    exit 1
}

<#
    mysql.exe is usually not on PATH after a default MySQL install, which is
    the first thing that stops people. Look where the installer puts it before
    giving up.
#>
function Find-MySql {
    param([string] $Hint = "")

    if ($Hint) {
        if (Test-Path $Hint) { return (Resolve-Path $Hint).Path }
        Write-Warn "-MySqlPath '$Hint' does not exist; looking in the usual places instead."
    }
    foreach ($name in @("mysql.exe", "mysql")) {
        $onPath = Get-Command $name -ErrorAction SilentlyContinue
        if ($onPath) { return $onPath.Source }
    }

    $roots = @("C:\Program Files\MySQL", "C:\Program Files (x86)\MySQL", "C:\tools\mysql")
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $found = Get-ChildItem -Path $root -Filter mysql.exe -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

<#
    Git Bash, not WSL. C:\Windows\System32\bash.exe is the WSL launcher and
    cannot see the Windows filesystem the way these scripts expect, so it is
    ruled out by name rather than trusted because it answered first.
#>
function Find-GitBash {
    foreach ($guess in @("C:\Program Files\Git\bin\bash.exe", "C:\Program Files (x86)\Git\bin\bash.exe")) {
        if (Test-Path $guess) { return $guess }
    }
    $onPath = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($onPath -and $onPath.Source -notlike "*\System32\*") { return $onPath.Source }
    return $null
}

# C:\wow\classic-db  ->  /c/wow/classic-db, which is what Git Bash understands.
function ConvertTo-MsysPath([string] $Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    return "/" + $full.Substring(0, 1).ToLower() + $full.Substring(2).Replace("\", "/")
}

# MySQL's own `source` command wants forward slashes on Windows.
function ConvertTo-SqlPath([string] $Path) {
    return ([System.IO.Path]::GetFullPath($Path)).Replace("\", "/")
}

$script:MySqlExtra = @()

<#
    `source file.sql` reports success even when statements inside the file
    failed, which turns a broken install into a silent one. --abort-source-on-error
    makes mysql stop and exit non-zero on the first error instead. Older clients
    do not have the flag, so probe once and say so rather than assume.

    (`mysql < file.sql` is not an option here: PowerShell reserves `<` and the
    line fails before mysql starts. That is why every step uses `source`.)
#>
function Initialize-MySqlOptions {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [string] $User = "mangos",
        [string] $Password = "mangos"
    )
    & $MySql "--user=$User" "--password=$Password" "--abort-source-on-error" -e "SELECT 1" *> $null
    if ($LASTEXITCODE -eq 0) {
        $script:MySqlExtra = @("--abort-source-on-error")
        return $true
    }
    & $MySql "--user=$User" "--password=$Password" -e "SELECT 1" *> $null
    if ($LASTEXITCODE -eq 0) {
        $script:MySqlExtra = @()
        Write-Warn "This mysql client is too old for --abort-source-on-error."
        Write-Note "A statement that fails inside a .sql file will not stop the script."
        Write-Note "Watch for lines beginning ERROR."
        return $true
    }
    return $false
}

function Invoke-SqlFile {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [Parameter(Mandatory)] [string] $Database,
        [Parameter(Mandatory)] [string] $File,
        [string] $User = "mangos",
        [string] $Password = "mangos"
    )
    $sqlPath = ConvertTo-SqlPath $File
    & $MySql "--user=$User" "--password=$Password" "--default-character-set=utf8mb4" `
             @script:MySqlExtra $Database -e "source $sqlPath"
    return ($LASTEXITCODE -eq 0)
}

# Does this table exist? Used to tell "the step before this one did not run"
# apart from "that step ran and went wrong".
function Test-SqlTable {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [Parameter(Mandatory)] [string] $Database,
        [Parameter(Mandatory)] [string] $Table,
        [string] $User = "mangos",
        [string] $Password = "mangos"
    )
    $answer = Invoke-Sql -MySql $MySql -User $User -Password $Password -Query @"
SELECT COUNT(*) FROM information_schema.tables
 WHERE table_schema = '$Database' AND table_name = '$Table'
"@
    return ($answer -and ([int]($answer | Select-Object -First 1)) -gt 0)
}

function Test-SqlIndex {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [Parameter(Mandatory)] [string] $Database,
        [Parameter(Mandatory)] [string] $Index,
        [string] $User = "mangos",
        [string] $Password = "mangos"
    )
    $answer = Invoke-Sql -MySql $MySql -User $User -Password $Password -Query @"
SELECT COUNT(*) FROM information_schema.statistics
 WHERE table_schema = '$Database' AND index_name = '$Index'
"@
    return ($answer -and ([int]($answer | Select-Object -First 1)) -gt 0)
}

<#
    Is anything listening? A plain TCP connect with a short timeout, because
    Test-NetConnection spends seconds on a closed port and we ask this before
    doing anything slow.
#>
function Test-Port([int] $Port, [string] $ComputerName = "127.0.0.1", [int] $TimeoutMs = 400) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $handle = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $handle.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($handle)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

<#
    Run mysql as root without putting the password in the process command line,
    where any other program on the machine can read it out of the argument list.
    An option file passed as --defaults-extra-file is MySQL's own answer to
    this; it must be the first option, and it is deleted straight after.
#>
function Invoke-SqlAsRoot {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [Parameter(Mandatory)] [string] $RootPassword,
        [Parameter(Mandatory)] [string] $File
    )
    # Option files take backslash escapes inside quoted values, so a password
    # with a backslash or a quote in it has to be written as one.
    $escaped = $RootPassword -replace '\\', '\\' -replace '"', '\"'
    # GetTempPath rather than $env:TEMP, which is not set everywhere, and a
    # random name so two runs cannot fight over one credentials file.
    $optFile = Join-Path ([System.IO.Path]::GetTempPath()) ("azeroth_" + [System.IO.Path]::GetRandomFileName() + ".cnf")
    [System.IO.File]::WriteAllText($optFile, "[client]`nuser=root`npassword=`"$escaped`"`n",
                                   (New-Object System.Text.UTF8Encoding($false)))
    try {
        # The mangos user does not exist yet at this point, so the shared probe
        # in Initialize-MySqlOptions cannot have run. Ask here, as root.
        $extra = @()
        & $MySql "--defaults-extra-file=$optFile" "--abort-source-on-error" -e "SELECT 1" *> $null
        if ($LASTEXITCODE -eq 0) { $extra = @("--abort-source-on-error") }

        $output = & $MySql "--defaults-extra-file=$optFile" @extra `
                           -e "source $(ConvertTo-SqlPath $File)" 2>&1
        return [pscustomobject] @{ Ok = ($LASTEXITCODE -eq 0); Output = ($output | Out-String) }
    } finally {
        Remove-Item $optFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Sql {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [Parameter(Mandatory)] [string] $Query,
        [string] $Database = "",
        [string] $User = "mangos",
        [string] $Password = "mangos"
    )
    $mysqlArgs = @("--user=$User", "--password=$Password", "--batch", "--skip-column-names")
    if ($Database) { $mysqlArgs += $Database }
    return (& $MySql @mysqlArgs -e $Query 2>$null)
}

function Get-RowCount {
    param(
        [Parameter(Mandatory)] [string] $MySql,
        [Parameter(Mandatory)] [string] $Database,
        [Parameter(Mandatory)] [string] $Table,
        [string] $User = "mangos",
        [string] $Password = "mangos"
    )
    $answer = Invoke-Sql -MySql $MySql -Database $Database -User $User -Password $Password `
                         -Query "SELECT COUNT(*) FROM ``$Table``"
    if ($LASTEXITCODE -ne 0 -or -not $answer) { return -1 }
    return [int]($answer | Select-Object -First 1)
}

<#
.SYNOPSIS
    Starts the login server and the world server.

.DESCRIPTION
        powershell -ExecutionPolicy Bypass -File C:\wow\mangos-classic\setup\Start-Server.ps1

    or just double-click setup\start-server.bat, which does the same thing.

    realmd goes into its own window and is left alone. mangosd runs in THIS
    window, on purpose: its console is where you type `account create`, and a
    server started by double-clicking with nowhere to type is the usual reason
    people cannot make an account.

    Ctrl-C, or typing `server shutdown 0`, stops the world server. realmd keeps
    running in its window until you close it.
#>
[CmdletBinding()]
param(
    [string] $ServerPath = "C:\wow\server",
    [switch] $SkipChecks,
    [switch] $NoRealmd
)

. (Join-Path $PSScriptRoot "_Common.ps1")

if (-not (Test-Path (Join-Path $ServerPath "mangosd.exe"))) {
    Fail "No mangosd.exe in $ServerPath."
}

if (-not $SkipChecks) {
    foreach ($needed in @("dbc", "maps", "mangosd.conf", "aiplayerbot.conf")) {
        if (-not (Test-Path (Join-Path $ServerPath $needed))) {
            Write-Bad "$needed is missing from $ServerPath."
            Write-Note "Run setup\Test-Setup.ps1 to see everything that is not ready."
            exit 1
        }
    }
}

if (-not $NoRealmd) {
    # 3724 is the port the client connects to first. If something is already on
    # it, a second realmd would fail quietly behind its own window.
    $already = $false
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $handle = $client.BeginConnect("127.0.0.1", 3724, $null, $null)
        $already = $handle.AsyncWaitHandle.WaitOne(300) -and $client.Connected
        $client.Close()
    } catch { $already = $false }

    if ($already) {
        Write-Good "realmd is already running on 3724"
    } else {
        Write-Note "Starting realmd in its own window..."
        Start-Process -FilePath (Join-Path $ServerPath "realmd.exe") -WorkingDirectory $ServerPath
        Start-Sleep -Seconds 2
        Write-Good "realmd started"
    }
}

Write-Host ""
Write-Host "  Starting the world server. First start takes a few minutes:" -ForegroundColor Cyan
Write-Host "  it loads the world database and builds its caches." -ForegroundColor Gray
Write-Host ""
Write-Host "  Watch for these two lines:" -ForegroundColor Gray
Write-Host "    World initialized" -ForegroundColor Gray
Write-Host "    Bridge: listening on 127.0.0.1:8890" -ForegroundColor Gray
Write-Host ""
Write-Host "  Then this window is the server console. Useful things to type:" -ForegroundColor Gray
Write-Host "    account create <name> <password>" -ForegroundColor Gray
Write-Host "    account set gmlevel <name> 3" -ForegroundColor Gray
Write-Host "    server shutdown 0" -ForegroundColor Gray
Write-Host ""

# From its own directory: DataDir and the config names are relative, and the
# playerbots config in particular is looked up against the working directory.
Push-Location $ServerPath
try {
    & ".\mangosd.exe"
} finally {
    Pop-Location
}

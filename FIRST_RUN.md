# First run

Getting the server up, start to finish, assuming you have never done this
before. `RUNNING.md` is the same journey written for someone who has; this one
explains why each step exists and tells you what you should be seeing.

You need the server already built. That is `BUILDING_PLAYERBOTS.md`, and it
ends with `C:\wow\server\mangosd.exe --version` printing a revision. If that
works, you are in the right place.

---

## What you are actually building

Four programs, running at the same time, talking to each other:

```
   MySQL            holds the world: every creature, item, quest, and your characters
     |
   realmd.exe       the login server. The client talks to this first, on port 3724
     |
   mangosd.exe      the world server. Everything that happens, happens here, on 8085
     |              ...and inside it, the playerbots module, listening on 8890
     |
   narrator         Python. Connects to 8890, watches, and writes the party's lines
     |
   llama.cpp        the local language model on 8080, which writes them
```

Your WoW client connects to realmd, gets pointed at mangosd, and you are in.
The narrator is not part of the game; it is a separate program that watches
through a socket and speaks through the same socket. That separation is the
whole design. If the narrator crashes, the game keeps running.

## What this is going to cost you in time

| Step | How long | Can you walk away? |
|---|---|---|
| MySQL install | 10 minutes | no, it asks questions |
| Databases | 15 minutes | yes, mostly waiting |
| Extracting client data | **4 to 10 hours** | yes, and you should |
| Configs and first start | 15 minutes | no |

The extraction is the long pole and it does not need the databases, so start
it first and do everything else while it runs. That is the one scheduling
decision worth making, and it saves you most of a day.

## What you need in hand

- **A World of Warcraft 1.12.1 client.** Not optional and not substitutable.
  The server reads its map, terrain and spell data out of the client files.
  There is no download for this in any repository here.
- **MySQL 8**, Community Server.
- **Git for Windows**, which you already have if you built the server. It
  brings Git Bash, which two of these steps need.

---

## Step 1: MySQL

```powershell
winget install --id Oracle.MySQL -e --source winget
```

**Installing is not the same as configuring.** winget puts the files on disk
and stops there: no Windows service, no data directory, no root password. The
tool that does that part is **MySQL Configurator**, which ships alongside the
server. Find it and run it as administrator:

```powershell
Get-ChildItem "C:\Program Files\MySQL\MySQL Server 8.4\bin" -Filter "*onfigurator*"
```

Take the defaults except: **Development Computer**, port **3306**, and leave
**Windows Service** and **Start at System Startup** ticked - that is the part
winget skipped. Set a root password and write it down; you need it exactly
once, in step 3. Any character is fine in it.

If you would rather install by hand, dev.mysql.com has the MSI, which runs the
Configurator for you at the end.

**Checkpoint.** Two things. The service is running:

```powershell
Get-Service MySQL*
```

`Status` must say `Running`. If it says `Stopped`, start it and make it start
itself from now on:

```powershell
Start-Service MySQL84                          # use whatever name it printed
Set-Service  MySQL84 -StartupType Automatic
```

If `Get-Service` finds nothing at all, the server files were installed but the
service was never created. Re-run MySQL Installer and pick **Reconfigure** on
the server; that is the step that initialises the data directory and registers
the service.

And the client runs:

```powershell
mysql --version
```

If PowerShell says it does not recognise `mysql`, it is installed but not on
your PATH. That is fine — every script here can be told where it is:

```powershell
Get-ChildItem "C:\Program Files\MySQL" -Recurse -Filter mysql.exe | Select-Object -First 1 -ExpandProperty FullName
```

Keep that path. You will pass it as `-MySqlPath`.

---

## Step 2: start the extraction, then leave it alone

Do this now so it runs while you do steps 3 and 4.

Copy **everything** from `C:\wow\server\tools` into the root of your 1.12.1
client folder, next to `WoW.exe`. That is four extractor programs plus
`ExtractResources.sh`, `MoveMapGen.sh` and `offmesh.txt`.

Then open **Git Bash** (not PowerShell), move to the client folder, and run:

```bash
cd /c/path/to/your/wow/client
sh ExtractResources.sh
```

It asks what to extract. **Say yes to everything.** Four things come out:

| Folder | What it is | What breaks without it |
|---|---|---|
| `dbc` | spells, items, the rules | the server will not start |
| `maps` | terrain heights | the server will not start |
| `vmaps` | walls and line of sight | everything can see through walls |
| `mmaps` | pathfinding mesh | bots stand still or walk into rocks |

It asks how many CPU threads for the mmaps stage. Give it your core count (16
on a 7800X3D). That stage is the multi-hour one.

**Checkpoint.** `MaNGOSExtractor.log` in the client folder is growing, and
`dbc` appears within a few minutes. Now leave it and open a new window.

---

## Step 3: the databases

One command. It creates four databases, makes the server its own MySQL user,
loads the base tables, downloads and loads the full classic world database,
and applies the fourteen playerbots SQL files.

```powershell
cd C:\wow\mangos-classic\setup
.\setup.bat
```

Add `-MySqlPath "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"` on
the end if `mysql` is not on your PATH.

It asks for your MySQL root password once, to create the databases and the
`mangos` user. That password goes into a temporary MySQL option file that is
deleted straight afterwards, not onto a command line, so it never shows up in
the process list for anything else on the machine to read. Everything after
that step runs as `mangos`.

Any character is fine in that password — `@`, `#`, quotes, backslashes. The
script quotes and escapes it for the option file.

Then it prints rows going by for five to fifteen minutes. That is the world
database loading. It is meant to look like that.

**Checkpoint.** It ends with a table like this, and no red:

```
     ok    classicmangos.creature_template                18000 rows  (the world database)
     ok    classicmangos.ai_playerbot_texts               1943 rows   (what bots can say)
     ok    classicmangos.ai_playerbot_named_location      54055 rows  ('go to Goldshire')
     ok    classiccharacters.ai_playerbot_names           100000 rows (names for random bots)
     ok    classicrealmd.realmlist                        1 rows      (where the client is sent)
```

`ai_playerbot_random_bots` showing 0 rows is correct at this stage. The server
fills that pool itself, a few minutes after its first start.

If a step fails, it stops there and nothing after it runs. Read the last few
lines; they name the file and the error.

<details>
<summary>What <code>setup.bat</code> is actually doing, if you would rather do it by hand</summary>

It runs three PowerShell scripts in order, and you can run any of them alone:

```powershell
.\Install-Databases.ps1   # the four databases, the world data, the playerbots tables
.\Install-Configs.ps1     # .conf.dist -> .conf, and switches the bridge on
.\Test-Setup.ps1          # reads everything back and reports
```

`Install-Databases.ps1` takes `-Force` to drop and rebuild from scratch (it
makes you type `DROP` first), and `-SkipWorldDb` to do everything except the
long download.

Two things in there are worth knowing about, because they are the traps:

- **`mysql < file.sql` does not work in PowerShell.** `<` is reserved and the
  line fails before mysql starts. Everything here uses MySQL's own `source`
  instead. If you are following a guide written for cmd.exe or Linux, this is
  why its commands do nothing.
- **`source` reports success even when statements inside the file failed.**
  The scripts pass `--abort-source-on-error` so a real failure stops them.
  Without it a half-loaded database looks exactly like a good one.

</details>

---

## Step 4: point the server at its data

When the extraction from step 2 finishes, you will have `dbc`, `maps`, `vmaps`
and `mmaps` in your client folder. Move all four to `C:\wow\server`, beside
`mangosd.exe`.

Beside `mangosd.exe`. Not in a subfolder, not left in the client folder. The
shipped config says `DataDir = "."`, which means "look right here".

**Checkpoint.**

```powershell
cd C:\wow\mangos-classic\setup
.\Test-Setup.ps1
```

Every line should be green. This script only reads; it changes nothing, so run
it as often as you like. It is faster than reading a log.

---

## Step 5: start the server and make yourself an account

```powershell
cd C:\wow\mangos-classic\setup
.\start-server.bat
```

realmd opens in its own window and you can ignore it. mangosd runs in **this**
window on purpose: that window is the server console, and it is where you
create your account. A server started by double-clicking, with nowhere to
type, is the usual reason people get stuck here.

First start takes a few minutes. It loads the whole world database and builds
its caches. Watch for two lines:

```
World initialized
Bridge: listening on 127.0.0.1:8890 (protocol 1)
```

The second line is ours. If it is missing, the narrator will have nothing to
connect to; see the troubleshooting list at the bottom.

Now type into that window:

```
account create bale yourpassword
account set gmlevel bale 3
```

Level 3 is full admin. These are console commands, so they go in the mangosd
window, not into the game.

> The database ships with four accounts already in it — ADMINISTRATOR,
> GAMEMASTER, MODERATOR and PLAYER — whose passwords are their usernames.
> Harmless on a machine only you can reach. Delete them if that ever changes.

---

## Step 6: log in

In your client folder, edit `realmlist.wtf` so it contains exactly one line:

```
set realmlist 127.0.0.1
```

Delete the client's `Cache` folder if it has one. Then run `WoW.exe` and log
in with the account you just made.

Set the client to **windowed (borderless)** in its video options. The narrator
overlay draws on top of the game, and that only works over a borderless
window.

**Checkpoint.** You are standing in the world.

---

## Step 7: bots

In game:

```
.bot add <name>
.bot list
```

`.bot list` shows what is available. Wait a few minutes after first start
before expecting much: the module creates its random bot accounts and
characters in the background, and until it has, the pool is empty.

---

## Step 8: the narrator

Start your language model first — llama.cpp on port 8080, the way you already
run it. Then, in a new window:

```powershell
cd C:\wow\Azeroth_Narrator
pip install -e ".[dev,ui]"
narrator doctor --llm openai:http://127.0.0.1:8080/v1 --watch 30
```

`narrator doctor` connects to the running server and tells you what actually
works: the link and its handshake, the round trip, who is online, which events
arrive while it watches, whether the random bot pool has anyone in it, and how
fast the model answers. It changes nothing unless you pass `--act`. It is the
fastest way to find out whether everything is really talking, and its output is
meant to be copied and pasted.

Then the real thing:

```powershell
narrator run --llm openai:http://127.0.0.1:8080/v1 --record first-session.jsonl
narrator-ui
```

`--record` writes every message that crosses the bridge to a file that can be
replayed later with no server running. On a first session it is worth having.

**Checkpoint.** The console window's Link tab shows both links up and a
sequence number climbing. The overlay shows party chat. After a minute of
quiet with two companions nearby, one of them says something.

That last sentence is the actual goal. Everything above it is plumbing.

---

## When it does not work

**"Nothing is listening on 127.0.0.1:3306, so MySQL is not running."**
Exactly what it says, and it is checked before the password prompt so you do
not waste a password on a connection that was never going to happen. `mysql`
being installed is not the same as `mysqld` running. See the checkpoint in
step 1.

**`Get-Service MySQL*` finds nothing at all.**
The files are installed but nothing was ever configured - the usual result of
a command-line install. Run MySQL Configurator from the server's `bin` folder,
as described in step 1. If there is no configurator there either, you have a
bare unpacked copy, and it needs initialising by hand in an elevated prompt:

```powershell
$bin  = "C:\Program Files\MySQL\MySQL Server 8.4\bin"
$ini  = "C:\ProgramData\MySQL\MySQL Server 8.4\my.ini"

New-Item -ItemType Directory -Force -Path (Split-Path $ini) | Out-Null
@"
[mysqld]
basedir="C:/Program Files/MySQL/MySQL Server 8.4"
datadir="C:/ProgramData/MySQL/MySQL Server 8.4/Data"
port=3306
bind-address=127.0.0.1
"@ | Set-Content -Path $ini -Encoding ASCII

& "$bin\mysqld.exe" --defaults-file="$ini" --initialize-insecure --console
& "$bin\mysqld.exe" --install MySQL84 --defaults-file="$ini"
Start-Service MySQL84
& "$bin\mysql.exe" -u root --skip-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'PickAPassword';"
```

Check `Test-Path "C:\ProgramData\MySQL\MySQL Server 8.4\Data"` first: if that
directory already has files in it, skip the `--initialize-insecure` line, which
refuses to run over a populated data directory.

`--initialize-insecure` leaves root with no password for the few seconds before
the last line sets one, which is why `bind-address=127.0.0.1` is in the file.
Nothing off this machine can reach MySQL either way, and that binding is the
right one for this project permanently.

**"MySQL rejected that root password."**
This one really is the password. Different message, different cause — the
script tells the two apart by MySQL's own error number, 1045 against 2003.

**The server exits complaining about maps or DBC.**
The four extracted folders are not beside `mangosd.exe`, or the extraction did
not finish. `.\Test-Setup.ps1` says which.

**The log says playerbots is disabled.**
`aiplayerbot.conf` is not in the same folder as `mangosd.exe`. On Windows that
file is looked up as a bare relative name against the working directory,
unlike the other configs, so it has to be exactly there. Run
`.\Install-Configs.ps1`.

**No "Bridge: listening" line.**
`AiPlayerbot.Bridge.Port` is commented out or set to 0. `.\Install-Configs.ps1`
sets it. If it still does not appear, the installed `mangosd.exe` was built
before the bridge existed — rebuild.

**`narrator doctor` says the bridge did not answer.**
The server is not running, or it is running without the bridge. Check for that
line in the log first; the doctor cannot tell those two apart from outside.

**`narrator doctor` says the random-bot pool is empty.**
This is the one that breaks everything quietly. With no roster the narrator has
nobody to cast, so every scene is skipped and nothing appears to be wrong.
Give the server ten minutes after its first start and check again.

**Bots are there but never say anything.**
Open the console window's Journal tab. Silence is a decision the director makes
on purpose, and it writes down why, so the reason is in there.

**PowerShell refuses to run a `.ps1` file.**
Use the `.bat` files, which get past it, or allow local scripts once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

## Starting up next time

Once it is built, a session is:

```powershell
cd C:\wow\mangos-classic\setup
.\start-server.bat                    # realmd and mangosd
```

then your language model, then:

```powershell
cd C:\wow\Azeroth_Narrator
narrator run --llm openai:http://127.0.0.1:8080/v1
narrator-ui
```

then the client. MySQL starts itself with Windows.

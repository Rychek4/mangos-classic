# Running the server

From compiled binaries to a world you can log into, with playerbots and the
narrator bridge switched on. Assumes `BUILDING_PLAYERBOTS.md` is done and
`C:\wow\server\mangosd.exe --version` prints a revision.

If you have not done this before, read `FIRST_RUN.md` instead. Same journey,
explained rather than listed, with the scripts in `setup/` doing steps 2 to 5
and 7 to 8 in one command. This file is the reference: what each step does and
why, for when something needs doing by hand.

Most of what follows is stock CMaNGOS setup and the project's own wiki is the
authority on it. What is written here is the path for **this** fork, and every
path, database name and command below was read out of the source in these
repositories rather than recalled. Where a step depends on an upstream tool
this repository does not contain, that is said plainly.

## What you need first

- **A World of Warcraft 1.12.1 client.** There is no substitute. The map, line-of-sight and pathfinding data is extracted from it, and the server will not start without at least the DBC and map data.
- **MySQL 8.** Community Server is enough.
- **Git Bash**, which came with Git. Two upstream steps are shell scripts and this is the normal way to run them on Windows.

## 1. MySQL

```powershell
winget install --id Oracle.MySQL -e --source winget
```

If that package id is not found, take MySQL Installer from dev.mysql.com and
pick Server only. During setup, set a root password and keep the default port
3306. Nothing else needs changing.

## 2. Databases and the server's own user

The repository ships the script that makes them:

```powershell
cd C:\wow\mangos-classic
mysql -u root -p -e "source sql/create/db_create_mysql.sql"
```

**Not** `mysql -u root -p < sql\create\db_create_mysql.sql`. PowerShell
reserves `<` and the line fails before mysql starts. MySQL's own `source` does
the same job; note the forward slashes, which `source` wants on Windows. The
same applies to every `.sql` file below.

That creates four databases, `classicmangos`, `classiccharacters`,
`classicrealmd` and `classiclogs`, and a user `mangos` with password `mangos`
limited to localhost. Those are the defaults the shipped configs already
expect, so changing them means editing configs later. On a machine only you
reach, leave them.

## 3. The base schemas

```powershell
mysql -u mangos -pmangos --abort-source-on-error classicrealmd     -e "source sql/base/realmd.sql"
mysql -u mangos -pmangos --abort-source-on-error classiccharacters -e "source sql/base/characters.sql"
mysql -u mangos -pmangos --abort-source-on-error classiclogs       -e "source sql/base/logs.sql"
```

`--abort-source-on-error` is not decoration. Without it `source` exits 0 even
when statements inside the file failed, so a half-loaded database is
indistinguishable from a good one until the server will not start.

**Not** `sql\base\mangos.sql`. The world database comes from the content
repository in the next step, and that dump carries its own structure: 189
tables, each preceded by `DROP TABLE IF EXISTS`. Loading the base world schema
first is redundant rather than harmful, but it is not part of the path.

`realmd.sql` inserts a realm row pointing at `127.0.0.1:8085`, which is what
you want for a local server, so there is nothing to edit there.

## 4. The world database

This lives in a separate upstream repository and installs itself with its own
script.

```powershell
cd C:\wow
git clone https://github.com/cmangos/classic-db.git
```

Then in **Git Bash**, not PowerShell:

```bash
cd /c/wow/classic-db
./InstallFullDB.sh
```

The first run writes `InstallFullDB.config` and stops. Most of that file is
already right: the shipped defaults are `classicmangos`, `classicrealmd`,
`classiccharacters`, `classiclogs`, user `mangos`, password `mangos`, host
`localhost`, port 3306, which is exactly what step 2 created. Two things need
setting by hand:

```
CORE_PATH="/c/wow/mangos-classic"
FORCE_WAIT="NO"
```

Then:

```bash
./InstallFullDB.sh -World
```

`-World` runs the whole content install without the menu: the full dump, the
core world updates, the DBC data, ScriptDev2, ACID, the custom SQL and the
locales. It uses the ordinary `mangos` user from the config, so no root
password is involved. Without an argument the script opens an interactive menu
instead, which does the same work with more typing.

There is also `-InstallAll <rootuser> <rootpass>`, which drops and recreates
all four databases first and so replaces steps 2 and 3 as well. It forces
`PLAYERBOTS_DB="YES"` internally, which sounds useful and is not — see below.

**Leave `PLAYERBOTS_DB` set to `NO`.** It looks for the module's SQL at
`${CORE_PATH}/src/modules/PlayerBots/sql`, and our module is a sibling
checkout at `C:\wow\playerbots` instead. Worse, the loop is

```bash
for UPDATEFILE in ${CORE_PATH}/src/modules/PlayerBots/sql/world/*.sql; do
  if [ -e "$UPDATEFILE" ]; then
```

so when the glob matches nothing the existence test fails, the loop applies
nothing, and the script prints `> Trying to apply playerbots sql mods...` and
moves on without an error. Setting it to `YES` therefore looks like it worked
and does nothing at all. Step 5 does that work explicitly.

## 5. The playerbots tables

Apply them in the same order the upstream installer would, world first, then
the classic-specific set, then characters:

```powershell
cd C:\wow\playerbots
function Load-Sql($db, $file) {
    mysql -u mangos -pmangos --abort-source-on-error $db -e "source $($file -replace '\\','/')"
    if ($LASTEXITCODE -ne 0) { throw "failed: $file" }
}
Get-ChildItem sql\world\*.sql         | ForEach-Object { Load-Sql classicmangos     $_.FullName }
Get-ChildItem sql\world\classic\*.sql | ForEach-Object { Load-Sql classicmangos     $_.FullName }
Get-ChildItem sql\characters\*.sql    | ForEach-Object { Load-Sql classiccharacters $_.FullName }
```

Order matters. `ai_playerbot_indexes.sql` indexes the loot tables and
`ai_playerbot_rpg_races.sql` edits `gossip_menu_option`, so both need the world
database from step 4 to exist already. And the index file has no
`IF NOT EXISTS`, so running it a second time is an error rather than a no-op;
`setup\Install-Databases.ps1` checks for the index before applying it, which is
why that script is safe to re-run and this loop is not.

That is eight files into the world database (texts, rpg races, indexes, plus
enchants, named locations, travel nodes, weight scales and zone levels) and
six into characters (the random bot roster, the cache, name pools, the
strategy store and the auction house bot tables).

`ai_playerbot_random_bots` is the one the narrator's cast draws from, and
`ai_playerbot_named_location` is what makes "go to Goldshire" work.

## 6. Extract the client data

Copy everything from `C:\wow\server\tools` into the root of your 1.12.1
client folder, next to `WoW.exe`. That is the four extractors plus
`ExtractResources.sh`, `MoveMapGen.sh` and `offmesh.txt`.

Then, in Git Bash, from the client folder:

```bash
sh ExtractResources.sh
```

It asks what to extract. Say yes to everything. DBC and maps are required,
vmaps are expected, and mmaps are what let bots path, so for this project all
three are needed. It asks how many CPU threads for mmaps; give it the core
count.

This step is slow. The mmap stage in particular runs for hours, and on a
machine with more cores it is still hours. It writes `MaNGOSExtractor.log` as
it goes.

When it finishes you have `dbc`, `maps`, `vmaps` and `mmaps` folders in the
client directory. Move all four into `C:\wow\server`, beside `mangosd.exe`.
The shipped `DataDir = "."` then finds them with no edit.

## 7. The configuration files

The installer left `.conf.dist` templates. Copy each to the live name:

```powershell
cd C:\wow\server
Copy-Item mangosd.conf.dist     mangosd.conf
Copy-Item realmd.conf.dist      realmd.conf
Copy-Item aiplayerbot.conf.dist aiplayerbot.conf
Copy-Item anticheat.conf.dist   anticheat.conf
```

The database lines in both server configs already match what step 2 created,
so if you kept the defaults there is nothing to edit for the databases.

**`aiplayerbot.conf` must sit next to `mangosd.exe`.** On Windows the module
looks it up as a bare relative filename, resolved against the working
directory, unlike the other configs. If it is missing the server still starts
and simply logs that playerbots is disabled, which is a confusing way to find
out.

## 8. Turn on the bridge

In `C:\wow\server\aiplayerbot.conf`, uncomment one line:

```
AiPlayerbot.Bridge.Port = 8890
```

That is the whole switch. The other five `Bridge.` keys have working defaults:
local bind address, a 30 second reconciliation scene, a 500 ms bubble scan, a
40 yard bubble, four clients maximum. With the port at 0 or commented out the
bridge never opens a socket.

Check that `AiPlayerbot.Enabled = 1` while you are in there. It is the shipped
default.

## 9. An account

Start the world server once, from its own directory so the relative paths
resolve:

```powershell
cd C:\wow\server
.\mangosd.exe
```

First start is slow: it loads the whole world database and builds caches. When
the console is ready, create yourself an account and make it an administrator:

```
account create bale yourpassword
account set gmlevel bale 3
```

Level 3 is the highest. Both are console-only commands, so type them into the
`mangosd` window rather than in game.

## 10. Point the client at it

In the client folder, edit `realmlist.wtf` to a single line:

```
set realmlist 127.0.0.1
```

Delete the client's `Cache` folder if it has one. Then run both servers, login
server first:

```powershell
cd C:\wow\server
Start-Process .\realmd.exe
.\mangosd.exe
```

Log in with the account from step 9. Set the client to **borderless window**
so our overlay can draw over it.

## 11. Bots, and then the narrator

In game, add a companion the module owns:

```
.bot add <name>
```

The random bot accounts the module created are the pool; `.bot list` shows
what is available.

Then, from the narrator checkout:

```powershell
cd C:\wow\Azeroth_Narrator
pip install -e ".[dev,ui]"
narrator run --llm openai:http://127.0.0.1:8080/v1 --record first-session.jsonl
narrator-ui
```

The `--record` flag is worth using on the first run. It writes every bridge
message to a file that replays offline, which means the first real session can
be studied and the director tuned without the server running.

## Keeping the core and the databases in step

The classic-db content repository tracks cmangos master and carries core
schema updates with it; this fork's core is wherever it was last merged. Each
database's version table has one column named `required_<last update
applied>`, and each file in `sql/updates/<db>/` starts by renaming it. The
server compares the column against the revision it was built with and refuses
to start on any difference, printing "out of date" in both directions.

After pulling a newer core: build, install, then `setup\Update-Databases.ps1`,
which applies every file after the one the column names. If the column names a
file the checkout does not have, the database is ahead and the core is what
needs updating. `setup\Test-Setup.ps1` reports the state of all four.

## Checking it without starting a client

From the narrator checkout, against the running server:

```powershell
narrator doctor --llm openai:http://127.0.0.1:8080/v1 --watch 30
```

It reports the link and its handshake, the round trip, `scene.get`,
`bot.list`, the random-bot roster, which events arrive while it watches, and
how long the model takes to answer one line. Read-only unless you pass
`--act`, which summons a bot, places it, gives it a line and dismisses it.
`setup\Test-Setup.ps1` does the same for the server side: binaries, extracted
data, configs, database row counts, open ports.

## What success looks like

- `mangosd` logs `Bridge: listening on 127.0.0.1:8890 (protocol 1)` at startup.
- `narrator run` logs that it connected and asked for a scene.
- The console window's Link tab shows both links up and a rising sequence number.
- The overlay shows party chat, and typing in it puts words in your character's mouth.
- After a minute of quiet with two companions present, one of them says something.

That last line is the actual goal. Everything before it is plumbing.

## When it does not work

- **Server exits complaining about maps or DBC.** `DataDir` is not pointing at the four extracted folders, or the extraction did not finish. Check for `dbc`, `maps`, `vmaps`, `mmaps` beside `mangosd.exe`.
- **Playerbots disabled in the log.** `aiplayerbot.conf` is not next to `mangosd.exe`, or `AiPlayerbot.Enabled` is 0.
- **No bridge line in the log.** `AiPlayerbot.Bridge.Port` is still commented out, or the config file is the wrong one.
- **Narrator connects but the world stays empty.** No real player is online yet. The bridge reports the party and bubble of real players, so log in first.
- **Bots exist but never speak.** Check the console window's Journal tab. Silence is a decision the director makes deliberately and writes down, so the reason will be there.

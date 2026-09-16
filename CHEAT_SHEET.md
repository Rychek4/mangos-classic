# Cheat sheet

Starting and stopping every part of the stack, in the order that works. The
long version is `FIRST_RUN.md`; this is the card to keep open.

## The stack

Start from the bottom up. Stop from the top down.

```
  narrator-ui        overlay + console windows            8891 (UI socket)
  narrator run       the director, in a terminal
  llama.cpp          the local model                      8080
  game client        WoW 1.12.1, borderless windowed
  mangosd            world server + playerbots + bridge   8085 / 8890 (bridge)
  realmd             login server                         3724
  MySQL              service, starts with Windows         3306
```

## Ports

| Port | What | Started by |
|---|---|---|
| 3306 | MySQL | Windows service |
| 3724 | realmd, the login server | `start-server.bat` |
| 8085 | mangosd, the world server | `start-server.bat` |
| 8890 | the narrator bridge, inside mangosd | mangosd, when `aiplayerbot.conf` has `Bridge.Port = 8890` |
| 8080 | llama.cpp | you |
| 8891 | the narrator's UI socket | `narrator run` |
| 5001 | the narrator's playerbots proxy | `narrator run` |

`setup\Test-Setup.ps1` lists which of these are listening.

---

## MySQL

**Start** — normally already running; it starts with Windows.
```powershell
Get-Service MySQL*
Start-Service MySQL84            # whatever name it printed
```
**Stop** — leave it running. `Stop-Service MySQL84` if you must.

**It's up when** `Get-Service` says `Running`. Nothing else starts without it.

---

## realmd and mangosd (the game server)

**Start both**
```powershell
cd C:\wow\mangos-classic\setup
.\start-server.bat
```
realmd opens in its own window. mangosd runs in the window you ran that from, and **that window is the server console** — type into it even while the log scrolls.

**It's up when** you see, in order:
```
Bridge: listening on 127.0.0.1:8890 (protocol 1)
CMANGOS: World initialized
```

**Console commands** (type into the mangosd window)
```
account create <name> <password>
account set gmlevel <name> 3
server shutdown 0
```

**Stop mangosd** — either of these; they do the same clean shutdown:
```
server shutdown 0          typed into its window
Ctrl-C                     in its window
```
**Stop realmd** — Ctrl-C in its window, or `Stop-Process -Name realmd`.

If you used Ctrl-C, cmd then asks `Terminate batch job (Y/N)?` - that is the
`.bat` wrapper, not the server. By then mangosd has already printed
`Halting process...` and is down. Answer `Y`. (`server shutdown 0` never asks,
because no signal reaches cmd.)

A wall of `Delete Gameobject ... lost references to owner Player ... Crash
possible later.` during shutdown is the core tidying up hunter bots' traps
(Immolation Trap, Freezing Trap) after their owners were already logged out.
It appears whichever way you stopped the server, whenever a hunter had a trap
down, and "later" never comes: the process is exiting. Ignore it.

**Never** close a server window with the X. Windows kills it instead of asking it to stop, and any saves in flight are lost.

---

## Game client

`realmlist.wtf` contains one line: `set realmlist 127.0.0.1`. Video options: **windowed (borderless)**, or the overlay cannot draw over it.

**In game** - or `/add Name` and `/remove Name` in the overlay, which do the same
```
.bot add <name>          give yourself a companion (Alliance name for an Alliance character)
.bot remove <name>       send one home
.bot list                who you have
```
Companions are put on the module's `silent` strategy when they join, so the
party channel is them talking, not the module reporting what it equipped.

**Stop** — log out normally. Ctrl-C the director first if a cast bot is standing near you, so it can be sent home.

---

## llama.cpp

However you normally run it, on port 8080. Start it before `narrator run`; the director needs it the first time a companion wants to speak.

**Stop** — Ctrl-C.

---

## narrator run (the director)

**Start** — its own window:
```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator run --llm openai:http://127.0.0.1:8080/v1 --record session.jsonl
```
`--record` writes every bridge message to a file that replays offline; drop it once you stop wanting that.

**It's up when** it logs that it connected and asked for a scene, and the console's Link tab shows both links lit.

**Stop** — **Ctrl-C, always.** It ends the session in the database (the "how long since we last spoke" clock depends on it) and sends home any cast bot still standing. Do this *before* shutting the server down, while the bridge is still up.

`narrator` on its own launches the Windows screen reader; that is why it is `python -m narrator`. `azeroth-narrator` is the same program under a name Windows does not own.

---

## narrator-ui (overlay + console)

**Start** — its own window:
```powershell
narrator-ui                      # both windows
narrator-ui --overlay-only
narrator-ui --console-only
```

**The X on the console window only hides the console.** The overlay keeps running over the game; that is deliberate.

**Right-click the overlay** for the menu:
- **Console** — bring the console back
- **Quit** — close the whole UI cleanly

**Type in the overlay** — plain text is said by your character.
```
/p text            party         /y text      yell        /e text     emote
/w Name text       whisper
/add [Name]        a companion joins you (blank picks one) /remove Name  a companion goes home
/suggest           who is worth adding
/summon Name       bring a roster character to you       /dismiss    send the cast home
/cast Name text    put words in a cast member's mouth
/pause  /resume    the director
/weather rain 0.8  zone weather
/bot Name follow   a playerbots command to one companion
```

**Stop** — right-click the overlay → Quit.

---

## The story

```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator story brief --premise "Someone is paying the Defias to watch the roads."
```
Writes `story-brief.md` (needs the server up, for the roster). Paste it into a
frontier model; save the JSON it answers with; then
```powershell
python -m narrator story load story-bible.json     # strict; names every problem
python -m narrator story show                      # the bible, with played beats marked
python -m narrator story brief --revise            # after some of it has played
python -m narrator story reset                     # forget what was played
```
`STORY_BIBLE.md` is the file format.

## Characters made to order

Isaac's body and the recurring cast are created, not picked from the pool.
```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator character example               # writes characters.example.json (Ansel is in it)
copy characters.example.json characters.json       # then edit
python -m narrator character sync                  # makes whichever the server does not have (server up)
python -m narrator character list                  # the file, the record, what the server has
python -m narrator character delete Ansel          # must be logged out first
```
They land on `castbot0`, `castbot1`, ... accounts (`AiPlayerbot.Bridge.CastAccountPrefix`),
nine each, and the random-bot manager leaves them alone. Bring one in with
`/add Ansel` or `/summon Ansel` like anyone else. A character that exists is
never changed by a later sync.

## Diagnostics

```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator doctor --watch 20 --llm openai:http://127.0.0.1:8080/v1     # read-only
python -m narrator doctor --watch 20 --act                                     # also summons a bot beside you

cd C:\wow\mangos-classic\setup
powershell -ExecutionPolicy Bypass -File Test-Setup.ps1          # server side: data, configs, databases, ports, build freshness
```

Both are safe to run at any time; `--act` is the only thing that changes the world.

---

## A full start

1. `start-server.bat` — wait for `World initialized`
2. llama.cpp
3. `python -m narrator run --llm openai:http://127.0.0.1:8080/v1`
4. `narrator-ui`
5. game client, log in, `.bot add` a companion or two

## A full stop

1. Ctrl-C in the `narrator run` window
2. right-click the overlay → Quit
3. log out of the game
4. `server shutdown 0` in the mangosd window
5. Ctrl-C in the realmd window
6. MySQL stays up

---

## Pulling new code

All three, every time; a pull that finds nothing new is free:

```powershell
cd C:\wow\mangos-classic  ; git pull origin claude/documentation-review-s056qd
cd C:\wow\playerbots      ; git pull origin claude/documentation-review-s056qd
cd C:\wow\Azeroth_Narrator; git pull origin claude/documentation-review-s056qd
```

Then, depending on what came in:

**Narrator** — if `pyproject.toml` changed, `pip install -e ".[dev,ui]"`. Restart `narrator run` and `narrator-ui`. No rebuild, no server restart.

**Server or module** — servers down first, then:
```powershell
cd C:\wow\mangos-classic
cmake --build build --config Release --parallel
cmake --install build --config Release
powershell -ExecutionPolicy Bypass -File setup\Update-Databases.ps1
powershell -ExecutionPolicy Bypass -File setup\Test-Setup.ps1
```
If the module added new source files, run the `cmake -B build ...` configure line from `BUILDING_PLAYERBOTS.md` before the build. `Test-Setup.ps1` tells you if the installed binary is older than the module source.

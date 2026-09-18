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
narrator-ui --scale 1.5                          # 1.5 times the original strip, text with it (remembered)
narrator-ui --scale 2 --font 18 --opacity 0.9    # twice, a chosen text size, a little see-through
narrator-ui --height 1.5                         # how much taller than the strip's proportions (default 2; remembered)
```
The overlay is 1.75 times its original size by default, text included, and opaque, made to sit over
the game's own chat frame. Drag it there once; the position is remembered. `--scale` sizes the
window and the text together, `--font` sets the text size in points on its own (`--font 0` goes
back to scaled), `--height` makes the box taller without touching the text (2 by default: twice
the strip's proportions, so the lines keep their room under the activity rows and the buttons),
and the last value you passed for each is remembered until you pass another.

**The X on the console window only hides the console.** The overlay keeps running over the game; that is deliberate.

**Right-click the overlay** for the menu:
- **Console** — bring the console back
- **Quit** — close the whole UI cleanly

**The button row above the box** — one order to every companion: **Come** (`summon`), **Follow**,
**Near**, **Far**, **Errands**, **Stay**, **Attack** (your target), **Flee** (run to you). Come works
near an innkeeper unless `AiPlayerbot.SummonAtInnkeepersEnabled = 0` in `aiplayerbot.conf`. There is
no rest verb; a stopped companion eats and drinks by itself when low. `/all free` still lifts every
leash.

**Follow** is the formation, for a road march or a dungeon. **Near** lets them wander within 15 yards
of you (free inside 5, drifting back between, running back beyond), for towns and careful ground.
**Far** is the same within 25 yards, for open roads. **Errands** lets them sell, buy, repair and train
around you within 80 yards and keeps that up until you press another button. Whoever joins the party
takes its current mode; it starts in Near (`"default_mode"`, `"near_leash"`, `"far_leash"`,
`"errands_leash"` in `narrator.json`). For training to actually buy spells, set
`AiPlayerbot.AutoTrainSpells = yes` in `aiplayerbot.conf`. Weapon types at a weapon master are not
learned yet. The lit button is the mode you are in.

**A companion fighting far away is called back.** A fleeing wolf can drag a companion off, and the
next thing that aggroes keeps them there; the leash only pulls between fights. One reported fighting
more than 100 yards from you is told `flee` (the module's break off and run to you), once every
45 seconds (`"callback_distance"`, `"callback_gap"` in `narrator.json`; 0 turns it off). The log
says `Polai is fighting 300 yd off; told to break off and come back`. A fight that far off no longer
holds scenes back either: only your own, or a companion's within 60 yards (`"scene_fight_radius"`).

**What they are doing** shows under the status line as a small table, one row for every companion
whether or not there is a word on them yet: the name in its own column, what they are doing next to
it, the distance lined up on the right (`Felindy   selling to Godric Rothgar   22 yd`; `no word yet`
until the module reports). In a fight it says what they are actually doing: casting Smite, closing
in, on your target, pulling, buffing the party with Power Word: Fortitude. It needs the module
rebuilt at least once since this landed; without it the rows say `no word yet` and the buttons still work.

**Camp** — the button at the end of the row (or `/camp`, `/camp 20` for twenty minutes). The companions
stop, sit in a ring around you and talk among themselves, from their own memories; you can join in.
Press it again (or `/break`) and they stand and fall in behind you. Ten minutes by default. No fire yet.

**Quests** — when you accept a quest, every companion is told `accept` and takes what that NPC offers
them; when you turn one in, they are told `talk` and turn in what they have complete. The game's own
rules decide who can (a companion behind on a chain stays behind). It needs them near you, which
following does. Turn it off with `"quest_tell": false` in `narrator.json`. Strangers in scenes may
also mention work nearby that you could take up, in their own words (needs this round's rebuild).

**The scene box.** When a scene begins, a second box slides out above the chat box with that scene's
conversation, the premise as its title and the cast under it. After the strangers have gone it
counts down 45 seconds and slides back behind the chat box. **Pin** keeps it up to read later, **×**
puts it away now. `narrator-ui --scene-hold 90` changes the countdown. It takes a little over half
the chat box's height, or what fits above it on the screen when that is less.

**Enter hands the keyboard back to the game.** Type, press Enter, and the next keypress moves your
character. The buttons and Escape do the same. If your client's window is not titled
`World of Warcraft`, start with `narrator-ui --game "Your Title"`.

**Enter in the game brings the caret to the overlay.** With the game in front, press Enter: the
game's own chat frame stays shut and the overlay comes forward with the caret in its box, so the
round trip is Enter, type, Enter. The game keeps its own chat box for the `.` commands the overlay
refuses: press the **numpad's Enter**, or **Shift+Enter**, and the game opens its box as before.
To use a different key, `narrator-ui --hotkey ctrl+enter` (or `f12`, `shift+grave`); `--hotkey off`
leaves the game's keys alone; `--hotkey enter` puts it back. The key is remembered like `--scale`.
If the game's chat frame still opens when you press Enter, the client is reading the keyboard in a
way the hook cannot intercept: pick a key the game does not use, such as `--hotkey f12`.

**Pacing.** Everyone speaks from one clock: a line stays up for its reading time before the next,
and long replies come in sentence-sized beats. In `narrator.json`: `"speech_chars_per_second": 15`,
`"speech_floor": 1.5`, `"speech_cap": 9` (seconds), `"group_answers": 2` (how many companions answer
one group line).

**Type in the overlay** — plain text is said by your character.
```
/p text            party         /y text      yell        /e text     emote
/w Name text       whisper
/add [Name]        a companion joins you (blank picks one) /remove Name  a companion goes home
/all command       one playerbots command to every companion (follow, stay, attack, flee, summon, free)
/suggest           who is worth adding
/summon Name       bring a roster character to you; someone already in your party is told to come to you instead
/dismiss           send the cast home
/cast Name text    put words in a cast member's mouth
/camp [minutes]    make camp; /break ends it
/pause  /resume    the director
/weather rain 0.8  zone weather
/bot Name follow   a playerbots command to one companion
```

**Stop** — right-click the overlay → Quit.

---

## After a session: the file to send

Every `narrator run` writes one text file: `C:\wow\Azeroth_Narrator\sessions\<date>-<time>.log`.
It has everything said (and whether you could hear it), every zone change, fight,
level, quest, death, every companion line the model wrote and how long it took,
what you typed in the overlay, and any warnings. Send the newest `.log`; the
`.jsonl` beside it is the raw traffic if more is needed.

**Scenes are weather.** The storyteller offers itself an opening every 3 minutes (`scene_interval`)
and waits at least 2 minutes between scenes (`scene_min_gap`), on top of arrivals and fights. A scene
waits until you have stood still for 8 seconds, and an arrival scene until you have been in the new
place for 15 seconds, so you are there to see it. Scene lines show in the overlay in a lavender colour.

**When the overlay glows,** the caption says where to look. Three shapes: someone appears about
9 yards in front of you and walks up (sometimes two of them); two or three people stand off to one
side talking to each other and you overhear them (they never come over); or a pair comes past you
mid-conversation and keeps going. In a town most scenes are overheard; on the road most come over.
They stand 12 seconds after their last line, then walk off for 20 seconds before they log out. The
log says `story:gone Name is gone` when they have. Companions remember the scenes they stood through.

**If you still cannot see them,** the log will say why. `placed 74 yards below Bale` means the
module is older than the height fix (rebuild it; see *Pulling new code*). No such line and no stranger
in front of you: send the log.

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

## Briefs: who the companions are

One brief per companion, the same round trip for each. Ansel's was the first;
the rest of the party works the same way, by name.

```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator isaac brief Wenna               # writes wenna-brief.md (server up is better: it sees the party)
python -m narrator isaac load wenna.json           # strict; names every problem; rewrites her profile from it
python -m narrator isaac load wenna.json --fresh   # and forgets what she has from play
python -m narrator isaac show                      # every loaded brief, with [now] and [done]
python -m narrator isaac show Wenna
python -m narrator isaac reset Wenna               # forget which of her wants were done
python -m narrator isaac unload Wenna              # no longer driven from a brief
```
`narrator isaac brief` with no name is Ansel's (the `isaac_character` in the config).

**The round trip, per companion:** run `brief <name>`, paste the `.md` into the frontier model, talk it
through until the character is what you want, save the JSON it answers with as `<name>.json`, `load`
it. The brief's `name` says who it is for, so load takes no name. `ISAAC_BRIEF.md` is the file format;
the `.md` carries it, so the model has everything.

**What is in the brief for a companion who has already played:** the local model made up a
personality and three core memories the first time they joined; the brief shows them under *What the
local model made up for them so far*, so you can keep what is worth keeping and drop the rest. You do
not need to pull anything from the database first.

**What load overwrites, and what it keeps.** Load rewrites the character's profile at once:
presence, voice and the rules become the personality, the brief's memories the core memories; the
old ones are gone. What the character has from play stays: recent memories, relationships, and the
conversation log. At low level that is a handful of lines, and load says how many
(`Kept from play: 3 memories, 12 conversations, 2 relationships`). Add `--fresh` to forget those too and
start the character clean. Either way the briefed companions are driven from the next `narrator run`.

## Characters made to order

Isaac's body and the recurring cast are created, not picked from the pool.
```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator character example               # writes characters.example.json (Ansel is in it)
copy characters.example.json characters.json       # then edit
python -m narrator character sync                  # makes whichever the server does not have (server up)
python -m narrator character list                  # the file, the record, what the server has
python -m narrator character level Ansel 3         # set his level in place (he must be in the party)
python -m narrator character delete Ansel          # logs him out first, then deletes
```
**Always from `C:\wow\Azeroth_Narrator`.** The command reads `characters.json` and `narrator.sqlite3`
from the folder you are standing in; run from `C:\WINDOWS\system32` it looks for them there.
`Could not reach the bridge at 127.0.0.1:8890 (WinError 1225)` means mangosd is not running (the
server refused the connection), not that anything is locked: start the server, then run it again.
It is fine to run these while `narrator run` is up; the two share the database.

**The easy way, from the overlay** while everything is running:
```
/remake Ansel        deletes him (logging him out first) and makes him again from characters.json
/level Ansel 3       sets his level in place (he must be in the party: /add Ansel first)
```
Ansel is made at level 3. Before this round the module re-rolled him to a random level the first
time he logged in (that is where the level-43 Ansel and "too low level" came from); the rebuilt
module leaves made characters and requested logins at the level they were given.
**A recurring stranger** is a character in the file with `"owner": "cast"` and a `"home"` (a zone or
area name, like `Elwynn Forest`). The storyteller brings them back in scenes there, remembering the
last time; the example file has Wenna, a pedlar on the Goldshire road. Set `"level": 3` on Ansel in
your copy of the file (the example says so now).
They land on `castbot0`, `castbot1`, ... accounts (`AiPlayerbot.Bridge.CastAccountPrefix`),
nine each, and the random-bot manager leaves them alone. Bring one in with
`/add Ansel` or `/summon Ansel` like anyone else. A character that exists is
never changed by a later sync.

## The auction bot

The playerbots module carries an auction-house bot (ike3's AhBot) that this project does not use. It
reads `ahbot.conf` from the folder your `mangosd.conf` is in. If the console fills with
`AhBot is now checking auctions in the background ... Next check in 0 seconds`, that file is missing
and an older build ran the bot on uninitialised settings. Fix on the spot: make `ahbot.conf` next to
`mangosd.conf` with one line
```
AhBot.Enabled = 0
```
and restart mangosd. The rebuilt module is off by itself when the file is missing, refuses a zero
interval, and says at startup `AhBot enabled (ahbot.conf); checking auctions every N seconds` or
`AhBot is Disabled`.

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
This round's module changes need the rebuild: strangers placed on the ground instead of under it,
no re-roll of Ansel or a stranger at login, no `<AFK>` over a stranger's head, `bot.face` so two
strangers talking to each other look at each other (without it they both face you, and the log says
`the module does not know bot.face` once), and `quest.nearby` so a stranger can mention work close by
(without it the log says `the module does not know quest.nearby` once).
If the module added new source files, run the `cmake -B build ...` configure line from `BUILDING_PLAYERBOTS.md` before the build. `Test-Setup.ps1` tells you if the installed binary is older than the module source.

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
**Far** is the same within 25 yards, for open roads. **Errands** lets them get on with their own
life within 80 yards and keeps that up until you press another button. Whoever joins the party
takes its current mode; it starts in Near (`"default_mode"`, `"near_leash"`, `"far_leash"`,
`"errands_leash"` in `narrator.json`). For training to actually buy spells, set
`AiPlayerbot.AutoTrainSpells = yes` in `aiplayerbot.conf`. Weapon types at a weapon master are not
learned yet. The lit button is the mode you are in, and it lights the moment you press it.

**If Errands looked broken — stepping, freezing, floating, drifting back to you — that was a real
bug and it is fixed.** The leash has an inner band inside which the module stops pulling a companion
back, and it used to be a third of the leash: 27 yards on Errands, most of a town square. Inside that
band the module's "stop follow" outranks the sell/repair/train actions about two ticks in three, so
the companions were told to stop roughly twice as often as they were told to work, and never got
close enough to a vendor to finish anything. The band is now a small fixed 5 yards (`"wander_inner"`
in `narrator.json`), so they are out in the open band where the errand wins every tick. **Needs no
rebuild** — restart the narrator and press Errands again.

**Errands does more than shopping.** It sends the module's `+rpg`, and that is eight behaviours at
once, not one: sell and buy, repair and train, **take and turn in quests from anyone they walk past**,
both sides of the auction house, collect mail, use the bank, discover flight points, bind at an inn,
and buy a guild charter. The quest-taking is the one worth knowing about — it is why a quest can turn
up in the log that you did not accept. Companions will *not* fly off or queue for a battleground: the
module already refuses both to a bot that has a master. To make the button mean only shopping and
upkeep, set `"errand_strategies": "+rpg vendor,+rpg maintenance"` in `narrator.json` — though they
will do less wandering-to-a-target, since that part lives in `rpg` itself.

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

**Your companions have never once spoken first — and now can.** Every companion line in every
session so far was an answer to you; the director's own triggers (zone banter, class banter, two
companions talking, one turning to you) had fired zero times. They waited for five minutes of total
silence — no line, no fight, no zone, no quest — and then still refused if any companion had asked you
anything in the last five minutes, or if anyone in the party was fighting anywhere. The last two are
gone; the wait is on the `pace` dial (2½ minutes at 2.0). **To see it:** stand still, stop typing,
stay out of fights for 2½ minutes. The sauce window's `banter cooling: …` line then shows which
clocks are running. **Needs no rebuild.**

**Companions do not join passing bots' guilds.** A random bot walks up, asks, and the companion used
to answer "Sounds good, sign me up!" and join. The module tries not to recruit someone's alt but makes
an exception for random bots, and every companion here is a random bot with a master put on it, so the
exception cancelled the protection. A companion now refuses a guild invite and a guild charter from
another bot, silently. An invite from a human still works, so you can take your own companions into
your own guild. **This one needs a rebuild of the module.** Without rebuilding,
`AiPlayerbot.RandomBotGuildNearby = 0` in `aiplayerbot.conf` stops every random bot from recruiting
anyone nearby, which also works but is blunter.

**NPC text reads properly now.** The server sends creature and gossip text with the client's
placeholders still in it (`$N` your name, `$C` class, `$R` race, `$G he:she;`), and the game's speech
bubble fills them while the overlay used to show them raw — a guard hailing you read `$N, eh? Oy!
Citizen $N, come 'ere.` in the chat box. The overlay fills them the same way the client does.

**Pacing.** Everyone speaks from one clock: a line stays up for its reading time before the next,
and long replies come in sentence-sized beats. In `narrator.json`: `"speech_chars_per_second": 15`,
`"speech_floor": 1.5`, `"speech_cap": 9` (seconds), `"group_answers": 2` (how many companions answer
one group line).

**For streaming: the sauce.** `narrator-ui --sauce` opens a third window up the right-hand side
(drag it anywhere; it remembers) that shows how the sauce is made — what each system is doing and
why. The top few lines are live: what the storyteller is doing right now and, if it is holding back,
the exact reason (`waiting: too soon after the last scene`); whether an NPC may speak up; the party's
mode and how long it has been quiet; the model's queue and last timing; who is in the cast and whether
they were borrowed from nearby or logged in. Below that scrolls the decision feed: every refusal with
its reason, every opening, `Engonn, Urnund borrowed from nearby; walking over` (the forty seconds when
nothing seems to be happening), every NPC aside with the role, moment and hooks it was built from,
every model call with its time. Colour says whose decision it was: lavender story, teal NPCs, amber
companions, grey model. Spoken lines are not in it — the chat box has those. `--no-sauce` puts it
away; so does the × on it or the chat box's right-click menu, which also brings it back. It takes the
chat box's `--scale`, `--font` and `--opacity`.

**Type in the overlay** — plain text is said by your character.

**The box stays in the channel you last used.** Type `/p something` and the next plain line goes to
party too, until you pick another channel with `/s`, `/y`, `/ra` or `/g`. The grey hint text in the
box says which one you are in (`[Party] say something ...`). Two do not stick on purpose: `/e`
(an emote is a turn of phrase, not somewhere to talk from) and `/w` (so a later line is never
privately addressed to someone without the box saying so).
```
/s text            say           /p text      party       /y text     yell
/e text            emote         /ra text     raid        /g text     guild
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

**If it feels too quiet (or too busy), turn one dial.** `"pace"` in `narrator.json` is how often the
world speaks up: `1.0` is the numbers as written, `2.0` twice as often, `0.5` half. It shortens every
wait between things at once — scenes, NPC asides, how soon the same NPC may speak to you again, how
soon a recurring stranger may come back, how long the companions wait in silence before one of them
speaks up on their own, and how long after that before they may again — and leaves alone everything
about whether you *see* a thing:
how long a walk takes, how long people stand there, how long you must be still. It ships at **2.0**
for testing. There is no need to edit the individual gaps; move the dial, play, and move it again.

**Nowhere runs out of scenes.** There is a limit on how many scenes one place may host in a while
(`scene_max_per_area` over `scene_area_memory`), so that standing in one square all evening does not
make that square the only theatre in the world. **It is off for testing** (`"scene_max_per_area": 0`
is no limit). Set it to 8 to turn it back on. A "place" is the subzone — Goldshire, the Trade
District, Valley of Heroes — not the whole zone. If you ever see `this place has had its share` in
the log, that is this rule, and 0 switches it off.

**When the overlay glows,** the caption says where to look. Three shapes: someone appears about
9 yards in front of you and walks up (sometimes two of them); two or three people stand off to one
side talking to each other and you overhear them (they never come over); or a pair comes past you
mid-conversation and keeps going. In a town most scenes are overheard; on the road most come over.
They stand 12 seconds after their last line, then walk off for 20 seconds before they log out. The
log says `story:gone Name is gone` when they have. Companions remember the scenes they stood through.

**Who the strangers are.** A bot already wandering within 40 yards of you (one of the server's random
bots with nobody to follow, of your faction, not fighting) is borrowed first: it walks over, plays
the part, and afterwards goes back to its own business rather than logging out. The scene line says
`borrowed Marla` and the end says `Marla goes back to their own business`. Only the places left over
are filled by logging someone in from the roster, and a recurring stranger the scene wants by name is
still fetched. If a borrowed bot cannot reach you in 20 seconds it is put on its spot anyway.

**Level does not exclude anyone from being borrowed.** A level 60 bot standing in Stormwind can have
a conversation near your level 5 party; it only matters to someone reading the nameplate, and the
alternative was that nothing was ever borrowed in a city. `"scene_borrow_level_spread": 15` in
`narrator.json` puts a window back if you want one (0, the default, means no limit), and
`"scene_borrow": false` goes back to fetching everyone.

**If nothing plays at all,** the log now says why. `story:quiet no scene on this encounter: ...` and
`npc:quiet nobody speaks up: ...` name the reason once, each time it changes. The whole list:
`combat`, `the player is moving`, `the player has only just arrived`, `too soon after the last scene`,
`this place has had its share`, `a scene is playing`, `nobody is here`, `paused`. If you see the same
reason for a whole session, that is the thing to send me.

**Strangers and NPCs will interrupt you**, on purpose. Somebody walking up while a companion is
mid-sentence is how a tavern sounds, and lines never land on top of each other because everyone
speaks from one clock. Nothing is held back because the party is talking.

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

## NPCs speak up

The innkeeper, the guard at the gate, the questgiver with work for you: an NPC you come up to may
say one thing to you, in a voice that fits its job, from facts the game supplies. It turns to face
you first, gestures, and the bubble appears over its head in the client. This needs the module
rebuilt (it adds `npc.about` and `npc.face`). One thing to check: the module's old LLM hook, if it is
still on, makes bots and NPCs small-talk through the module's own endpoint, and that would talk over
the narrator's lines for the same NPC. It is off by default; make sure it stayed that way:

```powershell
Select-String LLMEnabled C:\wow\server\aiplayerbot.conf     # nothing, or a # line, or = 0 is fine; = 1 or = 2 set to 0
```

**How often.** One aside every 90 seconds at most, whoever speaks; the same NPC not again for half an
hour (both divided by `pace`, so 45 seconds and a quarter hour at the shipped 2.0); never in a fight
near you, never over a scene or a conversation; an NPC with no service and no quest only one time in four. It speaks when you stop within 10 yards of it, or pass within 5 (a guard
at a gate). In `narrator.json`: `"npc_asides": true`, `"npc_gap": 90`, `"npc_revisit": 1800`,
`"npc_greet_radius": 10`, `"npc_pass_radius": 5`, `"npc_civilian_chance": 0.25`.

**In the log** each one is a line like
`npc:aside  Innkeeper Farley to Bale: Mind the step.  [npc Innkeeper Farley, role innkeeper, moment stopped, hook quest_offer, gesture wave]`
followed by the `chat [monster_say]` line as the world heard it. `role` is what the game said it
is; `hook` is the facts the line hung on. If the module is old, the log says
`the module does not know npc.about` and the NPC still speaks, from less.

**What to watch for, this first time:** too many, too few, the wrong ones (a vendor when the
questgiver was right there), lines that ignore the hook, and the bubble on the wrong head. All five
are numbers or facts I can tune from the log.

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

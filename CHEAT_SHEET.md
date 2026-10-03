# Cheat sheet

Starting and stopping every part of the stack, in the order that works. The
long version is `FIRST_RUN.md`; this is the card to keep open.

## The stack

Start from the bottom up. Stop from the top down.

```
  narrator-ui        overlay + console windows            8891 (UI socket)
  narrator run       the narrator, in a terminal
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

**Stop** — log out normally. Ctrl-C the narrator first if a moment is playing, so any stranger in it is sent home.

---

## llama.cpp

However you normally run it, on port 8080. Start it before `narrator run`; the narrator asks it for the first moment as soon as you are in the world.

**Stop** — Ctrl-C.

---

## narrator run (the narrator)

**Start** — its own window:
```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator run --llm openai:http://127.0.0.1:8080/v1 --record session.jsonl
```
`--record` writes every bridge message to a file that replays offline; drop it once you stop wanting that.

**It's up when** it logs that it connected and asked for a scene, and the console's Link tab shows both links lit.

**Stop** — **Ctrl-C, always.** It ends the session in the database (the "how long since we last spoke" clock depends on it) and sends home any cast bot still standing. Do this *before* shutting the server down, while the bridge is still up.

`narrator` on its own launches the Windows screen reader; that is why it is `python -m narrator`. `azeroth-narrator` is the same program under a name Windows does not own.

**If it will not start with `unknown config keys: [...]`,** your `narrator.json` names a setting that
has been removed; delete those lines. The narrator refuses unknown keys rather than ignoring them, so
a typo never silently does nothing. Removed since 20 September, when the clocks came out and one
narrator took over deciding every moment:

```
enable_moments  moment_gap  unified_conversation_check_interval  global_min_gap
zone_banter_cooldown  class_banter_cooldown  bot_to_player_cooldown  multi_turn_cooldown
interjection_cooldown  interjection_subzone_stale_threshold  bot_conversation_turn_probabilities
enable_banter_conversations  enable_class_banter_conversations  enable_zone_lore_conversations
enable_multi_turn_conversations  enable_proactive_interjections  enable_bot_to_player_initiation
enable_temporal_need_banter  temporal_need_cooldown_hours  temporal_need_speak_chance
temporal_need_threshold_max_hours  enable_storyteller
scene_interval  scene_min_gap  scene_max_per_area  scene_area_memory  scene_settle
scene_arrival_delay  scene_pending_for  scene_shapes  scene_company  scene_third
scene_borrow_arrive  scene_borrow_wait  scene_linger  scene_leave_seconds
scene_line_gap_min  scene_line_gap_max
npc_asides  npc_gap  npc_revisit  npc_passed_retry  npc_greet_radius  npc_pass_radius
npc_civilian_chance  npc_face_seconds  npc_settle
poll_interval  poll_cast_offered
memory_extraction_every_rows  memory_extraction_window_rows  core_memory_consolidation
story_rest_yards
```

The last three came out on 29 September: what the companions remember is decided in the quiet now,
not every ten lines or every seventy-five memories (see *What they remember*). `story_rest_yards`
came out on 30 September with the first story bible: a breadcrumb rests like any other topic now,
by `"hook_rest_yards"` (see *The story*).

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
- **Notes** — your notebook (the Notes button does the same)
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
says `Polai is fighting 300 yd off; told to break off and come back`. A fight that far off is not
"a fight going on near them" on the narrator's page either: only your own, or a companion's within
60 yards (`"scene_fight_radius"`), is.

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
following does. Turn it off with `"quest_tell": false` in `narrator.json`. Strangers may also
mention work nearby that you could take up, in their own words, and a questgiver you walk up to
raises their own quest from the quest's own text (both need the module rebuilt; without the
22 September rebuild a questgiver knows only the quest's title).

**Each moment is named as it starts.** A line in the scene colour, `✦` and the moment's premise,
shows in the overlay under the chat lines, above the buttons, for six seconds. The border no longer flashes: every remark is a moment
now, so it would be flashing most of the time.

**The moment shows on the overlay.** The line under the chat names the moment while it plays
(`✦ Cylina makes her pitch.`), says who is waiting for your answer (`· Cylina Darkheart waits for
your answer`), and says `· done` for a few seconds when it is over; a moment a story turn played
in ends `❖ ... · the story turned`. It used to be a caption for six seconds at the start.

**The story shows on the overlay.** When a story turn reveals something, it goes into the chat as a
`❖` line and the edge of the chat box glows once.

**Your notebook.** The **Notes** button at the right of the order row opens a window of your own notes,
jotted as you hear things: a call you were told, with who said it, where you stood and their words
(`Word of Steelgrill's Depot, Dun Morogh: "They say the gnomes…"`), a chapter turning as a heading,
and what you learned under it. Every call you have heard is kept, not just the last. The button shows
a pen (`Notes ✎`) when something has been written since you last opened the book. It is written top
to bottom and opens to the last line; drag it where you like, **×** puts it away, and it is all still
there after a restart, in the narrator's own save. The `❖ Word of` line above the chat is gone; the
book is where that went.

**When the story turns, a card says so.** A card appears at the top of the screen, `❖ The story
turns`, with the zone, the chapter it left and the one it reached (`Elwynn Forest · The rent is
paid → Somebody's landlord`) and what you learned, in the author's words. It stays until you click it
(or press Escape in the chat box), so it cannot slip past, but it never takes the keyboard: the
game keeps every key while it is up. It waits until a fight is over before showing. Drag it where
you want it; it remembers. Only a change of chapter raises it: breadcrumbs and calls stay in the
chat, and calls go in your notes.

**When somebody is waiting for your answer, the card asks you.** `✦ Melika Isenstrider is waiting
for your answer`, her words under it, and a box. Nothing takes the keyboard from the game: click into
the box when you want it, type, Enter. The line is said in the game as you, to her, and she answers
it; the companions leave it to her. **×** is nothing to say. She waits as long as you stand with her,
through a fight if one starts; walk off and she shrugs and goes back to her day. The eight-second
wait is gone. The card comes up as she starts asking, with the whole line, so you can read it before
she has finished saying it; if you have already walked off when she starts, she says it to your back
and no card comes.

**The scene box is off by default.** `narrator-ui --scene-box` brings it back: a second box slides
out above the chat box for each moment, the premise as its title and the cast under it, and after
the moment ends it counts down 45 seconds and slides back. **Pin** keeps it up to read later, **×**
puts it away now. `--scene-hold 90` changes the countdown. Without it, the chat box carries every
line.

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

**Things that happen to you show up, and can be remarked on.** A level gained, a death, a quest
you accepted or turned in, crossing into a new zone, a companion joining: the overlay shows each one
in grey in the chat box, whether or not anyone comments. Each also goes on the narrator's page as
something that happened since it last looked, so when nobody else is about a companion may pick it
up in the next moment, or may not; not every level deserves a remark. There is no setting for this
any more: `"moment_gap"` and `"enable_moments"` are gone, and the narrator refuses to start with
either in `narrator.json` (see *If it will not start*, under `narrator run`).

One local model answers one request at a time, so a moment being written when you speak delays your
own reply by up to one generation. Your line still jumps the queue ahead of anything merely waiting.

**Whoever speaks to you while you run is ahead of you.** The narrator measures where you are going from
the scene's positions (your heading and pace, every two seconds) and, at a run, picks the people who
live here from a headlight: a beam from your feet along your heading, eighty yards long and thirty
degrees either side. Nobody beside or behind you is offered, even when they are the only ones about;
at seven yards a second they are gone before they could speak. Standing or walking, it is the circle
of 25 yards round you it always was. People have headings too, so a guard walking across your way is
on the menu and a vendor walking off it is not, and the list is ordered by how far apart you will be
when the words land. The narrator's page says `the party is running north` and lists each person as
`18 yd ahead, closing`. It is a heading, not a prophecy: a corner is seen two to four seconds late.
The beam needs the bridge to see as far as it reaches, so `AiPlayerbot.Bridge.SceneRadius = 80` in
`aiplayerbot.conf` (`Install-Configs.ps1` sets it; a restart, not a rebuild). `"reach"` in
`narrator.json` switches the shape: `"headlight"`, `"ahead"` (the circle moved ahead of you, as
played on 2 October) or `"circle"` (round where you stand, as before that).

**They can point the way.** The narrator's page lists the named places round about - the areas the
game names and the innkeepers, trainers and vendors a traveller asks after, within 600 yards
(`"places_yards"`), each as yards and a compass word from where you stand - out of the playerbots
module's own travel data (`world.places` on the bridge, so **the module needs rebuilding** for it).
Ask a farmer the way to the mine and she can say south, past the vineyard; the narrator never
invents a place, only points at one the page listed.

**Some NPCs are never company.** The game calls a Spirit Healer a humanoid, and one came over from a
graveyard to chat. `"npc_never": ["Spirit Healer"]` in `narrator.json` is the list of names the narrator
never treats as somebody who lives here; add to it when the next one turns up.

**Companions speak first, when nobody else is about.** Nothing waits for a silence any more. When
nobody who lives here and none of the server's wandering bots is within 25 yards of you
(`"here_yards"`), the companions are the moment: one says something, another may answer, and they
talk about the road, the place or what just happened. Then they are winded: the companions share about 20 seconds of talk before
they need 45 seconds of quiet, and the log says `narrator:quiet nobody with the breath to speak: the
party is catching its breath`. When they finish a topic, the narrator says so and they stay quiet
for 90 seconds while nobody is about (`"banter_lull"`; `narrator:lull` in the log, and `between
topics` in the sauce). Towns are not held: anybody you walk up to still talks, and leaving them is
not followed by a wait. Walk up to somebody and whatever they were saying trails off, half
said (`narrator:cut trails off: somebody is here`), and the person you walked up to is the next
moment. **Needs no rebuild.**

**What they remember.** Nothing is written down as it happens. The moments that play, what you say,
and the game's own moments (a level, a death, a quest you take or turn in) are only noticed. When
the narrator goes quiet, the model is idle, and the party thinks back: one question over everything
since the last time, answered with who keeps what, or nothing, which is usual. The log says
`memory:kept Polai: ...` or `memory:kept nothing, of 7 things seen`. Stopping with Ctrl-C thinks
back one last time before the model goes. Each companion also has up to three lines of what play
has made them, beside the three memories they joined with; after they keep something, the same
quiet asks whether it changes who they are, and rewrites those three lines if so
(`memory:portrait`). Loading a brief does not wipe them. What a story turn reveals is the one
exception to the quiet: everyone remembers it at once (see *The story*). **Needs no rebuild.**

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
`"speech_floor": 1.5`, `"speech_cap": 9` (seconds), `"group_answers": 1` (how many companions answer
a line said to the group; naming somebody is not limited by it), and `"tempo": 1.0`, one multiplier
over every pause inside a moment that is not speech (1.5 gives a moment half again as much room).

**For streaming: the sauce.** `narrator-ui --sauce` opens a third window up the right-hand side
(drag it anywhere; it remembers) that shows how the sauce is made. The top lines are live:

- `scenes` — `looking`, `between topics: quiet for 62 s`, or `playing:` and the moment's premise;
  under it, how long ago the last moment was and how many looks the narrator has taken (`5 taken of
  9 looks, 1 failed`)
- `pace` — what the last moment cost (`4 pieces in 18 s`), the average so far, and the `tempo`
- `residents` — who is on the narrator's menu, and who is catching their breath and for how long
- `story` — always there: the module playing where you are and its state, your level and zone, a
  turn on offer, and how many have turned this session (`westfall_watchers: The roads are watched
  (levels 10–20) · you: level 12, Westfall · turn on offer: caught_watcher · 1 turn this
  session`). Where nothing plays, `no module here` and the zones calling you (`· calling:
  Redridge Mountains`). `no campaign loaded` when there is none
- `party` — the mode, whether a companion has asked you something, replies and silences
- `model` — the queue and the last timing
- `cast` — who is standing in a moment, and whether they were borrowed from nearby

Below that scrolls the decision feed: every look the narrator took, with what it took and the
premise (`narrator:took`), every quiet and failure with its reason, which situations were put on the
page (`narrator:assembled`), who was borrowed or logged in, who went back to their own business, and
every model call with its time. Colour says whose it was: lavender the stage, teal the people who
live here, amber the companions, grey the narrator and the model. Spoken lines are not in it; the
chat box has those. `--no-sauce` puts it away; so does the × on it or the chat box's right-click
menu, which also brings it back. It takes the chat box's `--scale`, `--font` and `--opacity`.

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
/weather rain 0.8  zone weather
/bot Name follow   a playerbots command to one companion
```

`/pause` and `/resume` are gone, with the console's Pause button: the game server cannot be paused,
so a pause only stopped the companions answering while the world went on.

**Stop** — right-click the overlay → Quit.

---

## After a session: the file to send

Every `narrator run` writes one text file: `C:\wow\Azeroth_Narrator\sessions\<date>-<time>.log`.
It has everything said (and whether you could hear it), every zone change, fight,
level, quest, death, every companion line the model wrote and how long it took,
what you typed in the overlay, and any warnings. Send the newest `.log`; the
`.jsonl` beside it is the raw traffic if more is needed.

**How often things happen is not a setting.** There is no scene timer and no gap between scenes.
The narrator looks, chooses the next moment, plays it, and looks again, so the size of each moment
is the wait after it: a companion's remark is over in seconds, strangers arriving, talking and going
on their way take about a minute and a half. What keeps it from being a chatterbox is measured, not
timed:

- **Breath.** Talking spends a voice's breath and quiet gives it back. The companions and any
  stranger fetched to talk to them share one breath (about 20 seconds of talk, then 45 seconds of
  quiet); each person who lives here has their own (about 60 seconds, then 90). A winded voice
  leaves the menu until it has rested.
- **Topics are spent by distance.** Something a person has said, and somebody arriving on the road,
  comes back only after the party has walked about 500 yards (`"hook_rest_yards"`).
- **Nobody left is a quiet.** When nobody has anything to say or the breath to say it, the model is
  not asked; the narrator checks again within a second or two.

`"pace"` still exists but now moves only how soon the narrator checks again after a quiet or a failed
look, and how soon a recurring stranger may come back (`"scene_recur_gap"`). It is no longer the
dial for how often the world speaks.

**Who the strangers are.** A bot already wandering within 40 yards of you (one of the server's random
bots with nobody to follow, of your faction, not fighting) is borrowed first: it walks over talking,
plays the part, and afterwards goes back to its own business. Only the places left over are filled
by logging someone in from the roster, and a recurring stranger the scene wants by name is still
fetched. A borrowed bot is not waited for: the moment starts as it sets off, because people walk
up talking. One logged in from the roster appears on its spot once the login completes.
Afterwards everyone is let go where they stand, fetched strangers too; they carry on as travellers
rather than logging out. Once strangers have been fetched, nobody else is fetched until you have
walked about 500 yards, so a camp you are grinding at does not fill up with travellers; bots really
standing about can still walk over, and a story turn's figure can still arrive. Companions remember the moments they stood through.

The shapes are the narrator's choice: someone walks up to you, two people talk to each other off to
one side and you overhear, a pair passes mid-conversation, or nobody moves and the people already
here speak. Each stranger goes to their spot in the shape: logged in on it from the roster, or
walking to it if borrowed from nearby, so a borrowed pair talking to each other stops off to one side
rather than beside you. In a pair, whoever speaks turns to the other.

**Level does not exclude anyone from being borrowed.** A level 60 bot standing in Stormwind can have
a conversation near your level 5 party; it only matters to someone reading the nameplate, and the
alternative was that nothing was ever borrowed in a city. `"scene_borrow_level_spread": 15` in
`narrator.json` puts a window back if you want one (0, the default, means no limit), and
`"scene_borrow": false` goes back to fetching everyone.

**If nothing plays at all,** the log says why, as `narrator:` lines:
`narrator:quiet nobody with the breath to speak: ...` once when a quiet begins (everyone is winded or
has said their piece), `narrator:nobody nobody to cast: ...` when there was nobody to put in a
moment, and `narrator:failed ...` when the model answered with nothing playable, cast somebody it
was not offered, or could not be reached. With no line at all, the narrator has not seen you in the
world yet. If you see the same line for a whole session, that is the thing to send me.

**Strangers and the people who live here will interrupt you**, on purpose. Somebody walking up while
a companion is mid-sentence is how a tavern sounds, and lines never land on top of each other because
everyone speaks from one clock. Nothing is held back because the party is talking.

**If you still cannot see them,** the log will say why. `placed 74 yards below Bale` means the
module is older than the height fix (rebuild it; see *Pulling new code*). No such line and no stranger
in front of you: send the log.

## The story

```powershell
cd C:\wow\Azeroth_Narrator
python -m narrator story brief                     # the whole road, levels 1 to 60
python -m narrator story brief --idea "Someone is paying the Defias to watch the roads."
```
Writes `story-brief.md` and `STORY_BIBLE.md` beside it. With the server up the brief carries the
party and the roster; without it, it is the blank template for every Alliance zone. Paste it into a
frontier model; save the JSON it answers with; then
```powershell
python -m narrator story load campaign.json        # strict; names every problem
python -m narrator story show                      # every module, with where it stands marked >>
python -m narrator story brief --revise            # after some of it has played
python -m narrator story reset                     # every module back to its first state
```
`STORY_BIBLE.md` is the file format. A version 1 bible is refused; write a campaign instead.

**What a campaign is.** Modules, each with the zones it lives in and the levels it plays at. A
module is in one state at a time: a standing fact (what the place is like now), breadcrumbs (what
people there talk about) and turns (the moments that move it on). Where you are and your level
decide everything; nothing is scheduled.

**What happens once it is loaded.** In a module's home zone at its levels, its breadcrumbs go into
the mouths of the people who live there, one to a companion and one to a stranger, each said once
and back again, from a new angle, after about 500 yards (`"hook_rest_yards"`). The state's
standing fact is on the narrator's page. Somewhere else at the right level for a module, the people
there pass on its *call*: word of what is happening where you should go next, for as long as
something can still happen there (a module resting in its last state stops calling). Out-levelled,
a module is silent.

A turn is offered to the narrator when its opening holds (`any`; `arrival` in a new area;
`aftermath` of a fight; `quiet`, neither of those), in its `area` if it names one (the forge at
Kharanos, not anywhere in Dun Morogh): its figure (a roster character, a made one, or whoever is
standing about) and any residents it needs (an innkeeper as host) are put on the menu. When a moment casts all of them
and plays through uncut, the module moves to its next state for good, and what the turn revealed
is remembered by every companion with you. The log shows `narrator:took` as usual, then
`narrator:story turned '<turn>' -> <state>` and `memory:kept everyone, from the story: ...`.

**Said, not handed over.** A resident's topic, a call or a breadcrumb is spent when the words that
say it went out, not when its holder was cast: `narrator:heard word of ...` now means somebody
named the place, and a topic the model skipped is still theirs to raise. And where each turn
stands is in the log once per change: `narrator:offered the story's turn '<module:turn>' on the
page with <figure>`, or `waits for an innkeeper within reach`.

**What the party knows is on the page.** From the next look on, the last few reveals (six,
`"story_known"`), oldest first and each with the zone it was learned in, are on the narrator's page
as what the party already knows, so a turn that follows from an earlier one is written knowing
it. The log shows `narrator:assembled story so far` on every look while there is anything to know.

**Area names** are the game's own, checked on load: 1.12 names fewer places than later versions
(Stormwind City is one area, with no Trade District), and a wrong word would mean the turn never
plays. The list is `narrator\story\areas.txt`.

**Companions in a moment answer the last line, with the page in view.** A companion cast into a
moment is told what was just said and sees the narrator's page as a person standing there would
(what has happened, what you said, who is about, what the party knows of the story), so its line is
a reply rather than a remark beside the others. What you say out loud is on the page on a line of its
own, so a line to a resident who was mid-speech is answered at the next look.

**Made figures.** `story load` prints any *made* figure the server does not have yet as a
`characters.json` entry; add it and run `python -m narrator character sync` (see *Characters made
to order*). A made figure needs a name nobody else has: one already taken by a different character
(the example file's Wenna, say) is refused by name. The level in the file is only what they are
made at: a made figure is the party's age, brought to the party's level each time they arrive for
a turn, fetched or borrowed, so a courier made at 8 for Elwynn is not a level 8 in Deadwind Pass.
The log shows `cast: Ellory is level 23 for this moment (was 8)`; a bridge that refuses is a
warning and the moment plays on. A made figure appears only for the story's turns: never as a
walk-on stranger, however long since they were met. What the game knows about a resident (their
quests for you) is read again after any quest event, so nobody offers you the quest you just turned
in.

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
old ones are gone. What the character has from play stays: recent memories, relationships, the
conversation log, and what play has made them (their portrait, below). At low level that is a handful
of lines, and load says how many (`Kept from play: 3 memories, 12 conversations, 2 relationships, 1
portrait lines`). Add `--fresh` to forget those too and start the character clean. Either way the briefed companions are driven from the next `narrator run`.

## The people who live here

The innkeeper, the guard at the gate, the farmer with work for you: walk within 25 yards
(`"here_yards"`) and they are on the narrator's menu, and whoever you walk up to is usually the next
moment. They turn to face you, gesture now and then, and the bubble appears over their head in the
client; once you walk on (out of those 25 yards) they turn back the way they stood. Now and then the
narrator has one walk over to you, walk along with you to the edge of where they live, or go back to
their work (`npc.move`); a patrolling guard or an escort never moves. Anybody moved is back at their
spot when you walk on, and a server restart resets everyone anyway. What they say is
hung on facts the game supplies, one topic at a time, each spent by saying it:

1. a vendor's wares, for somebody whose job is selling or repairing (an innkeeper who also sells is
   an innkeeper first)
2. the quest they have for you, or the one you have finished for them, from the quest's own text,
   in their own words and never read out
3. something locals grumble about in this zone (the list is `narrator/world/local_talk.md`); a
   grumble said by one person is said for everybody
4. their own day, for somebody with nothing to ask of you

A topic comes back once the party has walked about 500 yards. Each resident also has their own
breath (about a minute of talk, then a minute and a half of quiet), so a vendor talks shop, then the
town, then takes a minute or two off. None of the old `npc_*` settings exist any more; whether
somebody speaks is the narrator's choice from what it is shown.

This needs the module rebuilt (it adds `npc.about` and `npc.face`). One thing to check: the module's
old LLM hook, if it is still on, makes bots and NPCs small-talk through the module's own endpoint,
and that would talk over the narrator's lines for the same NPC. It is off by default; make sure it stayed that way:

```powershell
Select-String LLMEnabled C:\wow\server\aiplayerbot.conf     # nothing, or a # line, or = 0 is fine; = 1 or = 2 set to 0
```

**In the log** a resident's moment is a `narrator:took` line naming who was taken and why, then their
line as the world heard it. If the module is old, the log says `npc: the module does not know
npc.about` and the person still speaks, from less.

**What to watch for:** the wrong person chosen (a vendor when the questgiver was right there), the
same thing said twice, lines that ignore what they were holding, and the bubble on the wrong head.

## Voices

Every spoken line can be said out loud by Kokoro, for companions, strangers and the people who live
here alike, in step with the chat bubble. Emotes stay silent. It is **off by default**.

```powershell
cd C:\wow\Azeroth_Narrator
pip install -e ".[voice]"
```
Put `kokoro-v1.0.onnx` and `voices-v1.0.bin` (the kokoro-onnx model files) in that folder, then add
to `narrator.json`:
```json
"tts": true,
"tts_cast": {"Ansel": "bm_fable"}
```
`tts_cast` gives a companion a voice by name; pick them by ear. Everyone else gets a voice from their
gender's pool by a hash of their name, so the same farmer sounds the same every session, and nobody
else draws a voice named in `tts_cast`. NPCs have a gender only with the module rebuilt since 28 September;
before that they draw from either pool. `"tts_device": "cuda"` is the default and falls back to the
CPU when onnxruntime has no CUDA (then `"tts_threads": 2` keeps the server's bots their cores);
`"tts_speed"` and `"tts_gap"` (a pause between voiced pieces) are the other two dials. A missing
model file or no audio device turns voices off and logs why once, as `voices: ... lines go out
silent`; a line that fails to render goes out silent with a warning of its own. Neither ever stops a
line being said.

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
area name, like `Elwynn Forest`). The narrator may be offered them there once 15 minutes have passed
since they were last met (`"scene_recur_gap"`, halved at the shipped `pace` of 2.0), and they
remember the last time; the example file has Wenna, a pedlar on the Goldshire road. Set `"level": 3` on Ansel in
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

All three, every time; a pull that finds nothing new is free. Work is merged into each repository's
default branch, so pull that (a branch that is still being tried out gets its own name in the
message that asks you to test it):

```powershell
cd C:\wow\mangos-classic  ; git checkout master; git pull origin master
cd C:\wow\playerbots      ; git checkout master; git pull origin master
cd C:\wow\Azeroth_Narrator; git checkout main;   git pull origin main
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
The latest module changes that need the rebuild: `npc.move`, so somebody who lives here can walk
over to you, walk along with you, and go back to their work (29 September; without it they stay where
they stand and the log says `the module does not know npc.move` once), and `bot.place` can walk a bot to its spot, so a
stranger borrowed from nearby walks to its place in the scene (28 September; without it they are put
there instead), and NPCs report their gender, so voices match them (28 September; without it an NPC's
voice comes from either pool), and quest leads carry the quest's
own text, so a questgiver raises their work in its own words (22 September; without it they know
only the title). Earlier rounds brought strangers placed on the ground instead of under it, no
re-roll of Ansel or a stranger at login, `bot.face` so two strangers talking to each other look at
each other, `quest.nearby` for work close by, and `npc.about` and `npc.face` for the people who live
here; a module missing any of those says `the module does not know ...` once in the log.
If the module added new source files, run the `cmake -B build ...` configure line from `BUILDING_PLAYERBOTS.md` before the build. `Test-Setup.ps1` tells you if the installed binary is older than the module source.

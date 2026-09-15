# setup

Windows scripts for the three things between a compiled server and a running
one: databases, configuration, and starting it. `FIRST_RUN.md` in the
repository root is the walkthrough these belong to; `RUNNING.md` is the same
ground covered by hand.

| | |
|---|---|
| `setup.bat` | The whole thing: databases, configs, then a check. Start here. |
| `start-server.bat` | realmd in its own window, mangosd in this one. |
| `Install-Databases.ps1` | Four databases, the server's MySQL user, base schemas, the classic world database, the fourteen playerbots SQL files. `-Force` rebuilds from scratch, `-SkipWorldDb` leaves out the long download. |
| `Install-Configs.ps1` | `*.conf.dist` to `*.conf`, and switches the narrator bridge on. Keeps your edits unless you pass `-Overwrite`. |
| `Test-Setup.ps1` | Reads everything back: binaries, extracted client data, configs, database row counts, open ports. Changes nothing. Exits non-zero if anything is wrong. |
| `Start-Server.ps1` | What `start-server.bat` calls. |
| `_Common.ps1` | Shared helpers. Dot-sourced, not run. |

All of them take `-MySqlPath` if `mysql` is not on PATH, and paths for the
checkouts (`-CorePath`, `-PlayerbotsPath`, `-ServerPath`) if yours are not
under `C:\wow`.

The root password is asked for once, written to a temporary MySQL option file
passed as `--defaults-extra-file`, and the file is deleted immediately. It
never goes on a command line, where any other process could read it out of the
argument list - which is also why you do not see mysql's "using a password on
the command line interface can be insecure" warning.

Four things these scripts know that a hand-written command line usually does
not:

- **`mysql < file.sql` does not work in PowerShell.** `<` is reserved, and the
  line fails before mysql starts. Everything here uses MySQL's own `source`.
- **`source` exits 0 even when statements inside the file failed.**
  `--abort-source-on-error` is passed everywhere, and probed for first, because
  an older client does not have it.
- **A connection refused and a rejected password are different problems.**
  MySQL says 2003 for one and 1045 for the other; the scripts read the number
  and say which. Reachability is checked before the password prompt, so a
  stopped service never costs you a password.
- **`ai_playerbot_indexes.sql` has no `IF NOT EXISTS`**, so it fails on a
  second run. The index is checked for before the file is applied, which is
  what makes `Install-Databases.ps1` safe to run again.

These were written and tested against MySQL's wire-compatible behaviour and a
real schema load, on Linux. The Windows-specific parts - finding `mysql.exe`,
finding Git Bash, launching realmd - are written from the documented
behaviour, not from a run on Windows. If one misbehaves, the equivalent
commands by hand are in `RUNNING.md`.

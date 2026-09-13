# Building this core with the PlayerBots module

This fork's build fetches the PlayerBots module from
[`Rychek4/playerbots`](https://github.com/Rychek4/playerbots) when
`BUILD_PLAYERBOTS` is on. The wiring is in `src/CMakeLists.txt`.

Keep the repositories as sibling directories:

```
work/
  mangos-classic/      this repository
  playerbots/          the module
  Azeroth_Narrator/    the control center
```

Never place a playerbots checkout at `src/modules/PlayerBots` by hand: CMake's
fetch step deletes that directory before cloning into it.

## Configure

```
# day to day: compile the sibling checkout, nothing to push first
cmake -DBUILD_PLAYERBOTS=ON -DFETCHCONTENT_SOURCE_DIR_PLAYERBOTS=$PWD/../playerbots -B build -S .

# clean build from what is pushed to the fork's master
cmake -DBUILD_PLAYERBOTS=ON -B build -S .

# another repository or ref of the module
cmake -DBUILD_PLAYERBOTS=ON -DPLAYERBOTS_GIT_REPOSITORY=https://github.com/cmangos/playerbots.git -DPLAYERBOTS_GIT_TAG=master -B build -S .
```

| Variable | Default | Meaning |
|---|---|---|
| `PLAYERBOTS_GIT_REPOSITORY` | `https://github.com/Rychek4/playerbots.git` | where the module is fetched from |
| `PLAYERBOTS_GIT_TAG` | `master` | branch, tag or commit to fetch |
| `FETCHCONTENT_SOURCE_DIR_PLAYERBOTS` | unset | use this local checkout instead of fetching anything |

The module's narrator bridge needs `dep/json/json.hpp`, which this core ships.

## Debug builds with GCC 13 and newer

`src/mangosd/WorldRunnable.cpp` logs the world loop counter, a `std::atomic`,
through a printf-style call inside `#ifdef MANGOS_DEBUG`. C++20 forbids
copying an atomic, so Debug builds failed on recent GCC until the counter was
read with `.load()`. Release builds never compiled that line.

## Windows 11, from a PowerShell prompt

What the fork's Windows CI uses, and all a fresh machine needs to compile:
Visual Studio 2022 (the C++ workload), CMake, Git and prebuilt Boost. The
MySQL client library and OpenSSL are shipped under `dep\lib` for Windows
builds; nothing else is installed for the compile.

1. Tools (one prompt, then close and reopen PowerShell so PATH is fresh):

```powershell
winget install --id Git.Git -e --source winget
winget install --id Kitware.CMake -e --source winget
winget install --id Microsoft.VisualStudio.2022.Community -e --source winget --override "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --passive --norestart"
winget install --id Python.Python.3.12 -e --source winget   # for the narrator, not the compile
```

   The Build Tools edition (`Microsoft.VisualStudio.2022.BuildTools` with
   `Microsoft.VisualStudio.Workload.VCTools`) is a smaller substitute when the
   IDE is not wanted.

2. Boost, prebuilt for MSVC 14.3, from
   <https://sourceforge.net/projects/boost/files/boost-binaries/>: run
   `boost_1_87_0-msvc-14.3-64.exe` and accept `C:\local\boost_1_87_0`.
   Then tell CMake where it is and reopen PowerShell:

```powershell
[Environment]::SetEnvironmentVariable("BOOST_ROOT", "C:\local\boost_1_87_0", "User")
```

3. The three repositories as siblings, on the working branch:

```powershell
mkdir C:\wow; cd C:\wow
git clone -b claude/documentation-review-s056qd https://github.com/Rychek4/mangos-classic.git
git clone -b claude/documentation-review-s056qd https://github.com/Rychek4/playerbots.git
git clone -b claude/documentation-review-s056qd https://github.com/Rychek4/Azeroth_Narrator.git
```

4. Configure, build, install (the first build is the long one):

```powershell
cd C:\wow\mangos-classic
cmake -B build -S . -G "Visual Studio 17 2022" -A x64 `
  -DBUILD_PLAYERBOTS=ON -DFETCHCONTENT_SOURCE_DIR_PLAYERBOTS=C:\wow\playerbots `
  -DBUILD_EXTRACTORS=ON -DCMAKE_INSTALL_PREFIX=C:\wow\server
cmake --build build --config Release --parallel
cmake --install build --config Release
C:\wow\server\mangosd.exe --version
```

   `C:\wow\server` then holds `mangosd.exe`, `realmd.exe`, the extractors,
   the shipped DLLs, and the `.conf.dist` files (`mangosd`, `realmd`,
   `aiplayerbot`, `anticheat`). `build\` holds a solution file Visual Studio
   can open. A rebuild after editing the module is `cmake --build build
   --config Release --parallel` again; CMake never touches the sibling
   checkout.

If CMake reports that Boost was not found, pass
`-DBOOST_ROOT=C:\local\boost_1_87_0` on the configure line as well and check
that `C:\local\boost_1_87_0\lib64-msvc-14.3\cmake\Boost-1.87.0\BoostConfig.cmake`
exists. If Git complains about path length, `git config --global
core.longpaths true`. Debug builds are several times slower; use Release, or
RelWithDebInfo when a stack trace is needed.

Running the server needs more than compiling it: a MySQL 8 server
(`winget install --id Oracle.MySQL -e`), the classic world database from
<https://github.com/cmangos/classic-db>, and map, vmap and mmap data extracted
from a 1.12.1 client with the extractors built above. Then
`AiPlayerbot.Bridge.Port = 8890` in `aiplayerbot.conf`, and the narrator
from its own README.

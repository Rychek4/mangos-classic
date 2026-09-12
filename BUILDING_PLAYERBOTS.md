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

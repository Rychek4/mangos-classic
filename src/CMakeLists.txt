#
# This file is part of the CMaNGOS Project. See AUTHORS file for Copyright information
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

if(BUILD_GAME_SERVER OR BUILD_LOGIN_SERVER OR BUILD_EXTRACTORS)
  add_subdirectory(framework)
  add_subdirectory(shared)
endif()

# Playerbots module
#
# By default the module is fetched from this fork's own playerbots repository.
# Override either value at configure time to build against another source:
#   -DPLAYERBOTS_GIT_REPOSITORY=https://github.com/cmangos/playerbots.git
#   -DPLAYERBOTS_GIT_TAG=<branch, tag or commit>
# To compile a local checkout instead of fetching (day-to-day development), use
# CMake's standard FetchContent override; no download happens at all:
#   -DFETCHCONTENT_SOURCE_DIR_PLAYERBOTS=/path/to/playerbots
if(BUILD_PLAYERBOTS)
  include(FetchContent)

  set(PLAYERBOTS_GIT_REPOSITORY "https://github.com/Rychek4/playerbots.git"
      CACHE STRING "Git repository the PlayerBots module is fetched from")
  set(PLAYERBOTS_GIT_TAG "master"
      CACHE STRING "Branch, tag or commit of the PlayerBots module to fetch")

  FetchContent_Declare(
    PlayerBots
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/modules/PlayerBots"
    GIT_REPOSITORY "${PLAYERBOTS_GIT_REPOSITORY}"
    GIT_TAG "${PLAYERBOTS_GIT_TAG}"
  )

  FetchContent_GetProperties(PlayerBots)
  if (NOT playerbots_POPULATED)
    FetchContent_Populate(PlayerBots)
    message(STATUS "Playerbots module source dir: ${playerbots_SOURCE_DIR}")
  else()
    message(STATUS "Playerbots module already populated: ${playerbots_POPULATED}")
  endif()

  # The binary dir is passed explicitly so that a source dir outside this tree
  # (the FETCHCONTENT_SOURCE_DIR_PLAYERBOTS override) is accepted by CMake.
  add_subdirectory(${playerbots_SOURCE_DIR} ${playerbots_BINARY_DIR})

else()
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/modules/PlayerBots)
    message(STATUS "PlayerBots module exists, but not building. You can remove it manually if you don't need it. (rm -rf ${CMAKE_CURRENT_SOURCE_DIR}/modules/PlayerBots)")

    #file(REMOVE_RECURSE ${CMAKE_CURRENT_SOURCE_DIR}/modules/PlayerBots)
  endif()
endif()

if(BUILD_GAME_SERVER)
  add_subdirectory(game)
  add_subdirectory(mangosd)
endif()

if(BUILD_LOGIN_SERVER)
  add_subdirectory(realmd)
endif()
-- Luacheck configuration for the mod's scripts (npm run lint:lua).
--
-- TTS runs Lua 5.2 (MoonSharp) with its own API on top. Object scripts and
-- the includes they require share one set of global functions, defined in
-- one file and called from another, so the globals the mod itself defines
-- are read from mod/src below: what is left as "undefined" is a name defined
-- nowhere, usually a typo.

std = "lua52+tts"

include_files = { "**/*.lua", "**/*.ttslua" }
exclude_files = {
  "mod/src/includes/generated/**",
  "mod/src/includes/common/SHA256.ttslua", -- third-party, kept as published
}

-- Script state lives in globals set inside functions (selectedUnitObj = ...):
-- a global assigned anywhere in its file counts as defined there.
allow_defined = true
-- ... and a global function nobody calls in its own file is normal: buttons,
-- the UI and other objects call it.
-- A leading underscore on a used argument is only a naming habit here.
ignore = { "131", "214" }

-- TTS calls event handlers with fixed signatures, and long data lines (URLs,
-- tables) are normal here.
unused_args = false
max_line_length = false

local function apiObject()
  return { other_fields = true, read_only = false }
end

stds.tts = {
  read_globals = {
    -- Global functions
    "addContextMenuItem", "addHotkey", "broadcastToAll", "broadcastToColor",
    "clearContextMenu", "clearPixelPaint", "clearVectorPaint", "copy",
    "destroyObject", "flipTable", "getAllObjects", "getObjectFromGUID",
    "getObjects", "getObjectsWithAllTags", "getObjectsWithAnyTags",
    "getObjectsWithTag", "getSeatedPlayers", "group", "log", "logStyle",
    "paste", "printToAll", "printToColor", "sendExternalMessage",
    "showHotkeyConfig", "spawnObject", "spawnObjectData", "spawnObjectJSON",
    "startLuaCoroutine", "stringColorToRGB", "unpack",
    -- Global objects
    Backgrounds = apiObject(), Color = apiObject(), Global = apiObject(),
    Grid = apiObject(), Hands = apiObject(), Info = apiObject(),
    JSON = apiObject(), Lighting = apiObject(), Music = apiObject(),
    MusicPlayer = apiObject(), Notes = apiObject(), Physics = apiObject(),
    Player = apiObject(), Tables = apiObject(), Time = apiObject(),
    Timer = apiObject(), Turns = apiObject(), UI = apiObject(),
    Vector = apiObject(), Wait = apiObject(), WebRequest = apiObject(),
    self = apiObject(),
  },
}

-- Globals defined by the mod's own scripts: top-level functions and
-- assignments ("function name(", "name =", "function Name.field("). The
-- includes are pasted into the scripts that require them, so their top-level
-- locals (local tablex = ..., local function initListSpawner) count too.
local defined = {}
local list = io.popen('find mod/src -name "*.lua" -o -name "*.ttslua"')
if list then
  for path in list:lines() do
    local file = io.open(path)
    if file then
      for line in file:lines() do
        local name = line:match("^function%s+([%a_][%w_]*)")
          or line:match("^([%a_][%w_]*)%s*=[^=]")
        if not name and path:find("/includes/", 1, true) then
          name = line:match("^local%s+function%s+([%a_][%w_]*)")
            or line:match("^local%s+([%a_][%w_]*)%s*=[^=]")
        end
        if name then
          defined[name] = true
        end
      end
      file:close()
    end
  end
  list:close()
end

globals = {}
for name in pairs(defined) do
  globals[#globals + 1] = name
end

-- Set from outside by other scripts (setTable / setVar / setLuaScript).
files["mod/src/StarWarsLegion/Order_Token.a57c41.lua"] = { globals = { "unitData" } }
files["mod/src/StarWarsLegion/Model_Template_A.1f03c9.lua"] = { globals = { "isDeploy", "unitInfo" } }
files["mod/src/StarWarsLegion/Model_Template_B.a486ae.lua"] = { globals = { "unitInfo" } }
-- A unit leader's script is written by SpawnList when its army is imported.
files["mod/src/StarWarsLegion/Unit_Leader.99f1c8.lua"] = {
  globals = {
    "baseSize", "colorSide", "commandType", "miniGUIDs", "selectedSpeed",
    "silhHeight", "silhOffset", "silhType", "unitID", "unitName",
  },
}
files["mod/src/StarWarsLegion/Deck_Builder.082f27.lua"] = { globals = { "selectedFaction", "selectedScenario" } }
files["mod/src/includes/LineOfSight.ttslua"] = {
  globals = {
    "CardsSchema",          -- _G.CardsSchema, set by initCardsSchema
    "LOS_EXPOSE_FOR_TESTS", -- set by tool/los/geometry.test.lua
  },
}

-- Libraries: their top-level locals are used by the scripts that require them.
files["mod/src/includes/common/Stringx.ttslua"] = { ignore = { "211/stringx" } }
files["mod/src/includes/common/Tablex.ttslua"] = { ignore = { "211/tablex" } }
files["mod/src/includes/common/Zonex.ttslua"] = { ignore = { "211/zonex" } }
files["mod/src/includes/SpawnList.ttslua"] = { ignore = { "211/initListSpawner" } }

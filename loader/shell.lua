-- Star Wars: Legion loader shell.
--
-- This is the whole Global script of the Workshop mod. It never changes with
-- the mod: it downloads a release of the mod and installs it on the table.
--
--   brain.lua     the mod's logic, run by a locked object with a fixed GUID
--   ui.xml        the global UI, its handlers already pointing at the brain
--   objects.jsonl the mod's objects, one JSON object per line
--   manifest.json the version, the file names and the UI's image assets
--
-- Every event the mod listens to reaches an object script too (measured in
-- TTS), so nothing is relayed: the brain hears them itself.
--
-- A game keeps the version it started with. Only a fresh table (a Workshop
-- load, or a save packed with !loader pack) installs the channel's latest
-- release; offline, it keeps the version that was saved in it.

SHELL_VERSION = 1

RELEASES = {
  stable = 'http://127.0.0.1:8765/stable/',
  beta = 'http://127.0.0.1:8765/beta/',
}

BRAIN_GUID = 'b7a1e0'
BRAIN_POSITION = {55.2, -3.5, -1.42} -- hidden inside the computer screen

state = {channel = 'stable', version = nil, fresh = true, ui = nil, uiAssets = nil, objects = {}}

local function say(text)
  print('[loader] ' .. text)
end

function onLoad(saved)
  if saved and saved ~= '' then
    local ok, decoded = pcall(JSON.decode, saved)
    if ok and type(decoded) == 'table' then
      state = decoded
    end
  end
  state.objects = state.objects or {}
  -- TTS does not save a UI set by a script: put it back on every load.
  if state.ui then
    if state.uiAssets then
      UI.setCustomAssets(state.uiAssets)
    end
    UI.setXml(state.ui)
  end
  if state.fresh then
    check()
  else
    say('game on ' .. tostring(state.version) .. ' (' .. state.channel .. ')')
  end
end

function onSave()
  return JSON.encode(state)
end

-- Downloads the channel's manifest and installs it when it is newer than
-- what the table holds.
function check()
  local base = RELEASES[state.channel]
  WebRequest.get(base .. 'manifest.json', function(request)
    if request.is_error then
      say('release server unreachable (' .. tostring(request.error) .. '), keeping ' .. tostring(state.version))
      state.fresh = false
      return
    end
    local ok, manifest = pcall(JSON.decode, request.text)
    if not ok or type(manifest) ~= 'table' or not manifest.version then
      say('unreadable manifest, nothing changed')
      state.fresh = false
      return
    end
    if manifest.version == state.version and getObjectFromGUID(BRAIN_GUID) then
      say('up to date: ' .. manifest.version)
      state.fresh = false
      return
    end
    download(base, manifest)
  end)
end

-- Fetches every file first and installs only when all of them arrived: a
-- half-downloaded release changes nothing.
function download(base, manifest)
  local names = {manifest.brain, manifest.ui, manifest.objects}
  local texts = {}
  local started = os.clock()
  local function fetch(i)
    if i > #names then
      say(string.format('downloaded %s in %.2f s', manifest.version, os.clock() - started))
      return install(manifest, texts[1], texts[2], texts[3])
    end
    WebRequest.get(base .. names[i], function(request)
      if request.is_error then
        say('could not download ' .. names[i] .. ', keeping ' .. tostring(state.version))
        state.fresh = false
        return
      end
      texts[i] = request.text
      fetch(i + 1)
    end)
  end
  fetch(1)
end

-- Runs one install step, and names it if it fails.
local function step(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    say('FAILED at ' .. name .. ': ' .. tostring(err))
  end
  return ok
end

function install(manifest, brainText, uiText, objectsText)
  if not step('clear the table', clearTable) then return end
  if manifest.uiAssets and not step('UI assets', function() UI.setCustomAssets(manifest.uiAssets) end) then return end
  if not step('UI', function() UI.setXml(uiText) end) then return end
  state.ui = uiText
  state.uiAssets = manifest.uiAssets
  -- The mod's onload expects its UI to be there, as it is on a save load.
  local function go()
    step('spawn', function() spawnRelease(manifest, brainText, objectsText) end)
  end
  Wait.condition(go, function()
    return not UI.loading
  end, 10, go)
end

-- The brain goes first, then the objects in the same frame: that is the
-- order of a save load (the brain's onLoad sees every object, and every
-- object's onLoad sees the brain ready).
function spawnRelease(manifest, brainText, objectsText)
  local started = os.clock()
  local brain = spawnObjectData({data = {
    Name = 'BlockSquare',
    GUID = BRAIN_GUID,
    Nickname = 'Star Wars: Legion',
    Locked = true,
    Transform = {
      posX = BRAIN_POSITION[1], posY = BRAIN_POSITION[2], posZ = BRAIN_POSITION[3],
      rotX = 0, rotY = 0, rotZ = 0, scaleX = 0.1, scaleY = 0.1, scaleZ = 0.1,
    },
    LuaScript = brainText,
    LuaScriptState = manifest.brainState or '',
  }})
  brain.interactable = false
  local guids = {}
  local position = 1
  while true do
    local stop = objectsText:find('\n', position, true)
    local line = objectsText:sub(position, (stop or 0) - 1)
    if line:find('{', 1, true) then
      table.insert(guids, spawnObjectJSON({json = line}).getGUID())
    end
    if not stop then break end
    position = stop + 1
  end
  state.objects = guids
  state.version = manifest.version
  state.fresh = false
  say(string.format('installed %s (%s): brain + %d objects in %.2f s',
    manifest.version, state.channel, #guids, os.clock() - started))
end

-- Before an install, the table is emptied of the previous release. Only
-- ever on a fresh table or on a player's explicit request.
function clearTable()
  local brain = getObjectFromGUID(BRAIN_GUID)
  if brain then
    brain.destruct()
  end
  for _, object in ipairs(getObjects()) do
    object.destruct()
  end
  state.objects = {}
end

-- !loader                 what this table runs
-- !loader stable | beta   choose a channel (applies to the next fresh table)
-- !loader reinstall       wipe this table and install the channel's latest
-- !loader pack            mark this save as fresh before a Workshop upload
function onChat(message, player)
  if message:sub(1, 7) ~= '!loader' then
    return true
  end
  if not player.host then
    return false
  end
  local command = message:sub(9)
  if command == 'stable' or command == 'beta' then
    state.channel = command
    say('channel: ' .. command .. ' (applies to the next fresh table; !loader reinstall to apply now)')
  elseif command == 'reinstall' then
    state.version = nil
    state.fresh = true
    check()
  elseif command == 'pack' then
    state.fresh = true
    say('this save will install the latest ' .. state.channel .. ' release when opened')
  else
    say('shell ' .. SHELL_VERSION .. ', ' .. tostring(state.version) .. ' (' .. state.channel .. ')')
  end
  return false
end

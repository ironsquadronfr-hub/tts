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
-- A fresh table (a Workshop load, or a save packed with !loader pack) first
-- asks the host which version to run, Stable or Beta, then installs that
-- channel's latest release. The Workshop item also carries a version of its
-- own, held until the host chooses: it is kept when it is still the latest,
-- and it is what an offline table plays. A game in progress keeps the
-- version it started with.

SHELL_VERSION = 2

-- Test releases on the Iron Squadron fork, each under a fixed tag replaced
-- in place. On swlegion/tts the stable becomes the newest full release.
RELEASES = {
  stable = 'https://github.com/ironsquadronfr-hub/tts/releases/download/loader-stable/',
  beta = 'https://github.com/ironsquadronfr-hub/tts/releases/download/loader-beta/',
}

-- The chooser's pictures, in the asset store: they belong to the shell, so
-- they never move.
CHOOSER_ASSETS = {
  {name = 'loaderChoiceStable', url = 'https://raw.githubusercontent.com/ironsquadronfr-hub/swl-assets/main/assets/loader_choice_stable_v1.jpg'},
  {name = 'loaderChoiceBeta', url = 'https://raw.githubusercontent.com/ironsquadronfr-hub/swl-assets/main/assets/loader_choice_beta_v1.jpg'},
  {name = 'loaderTab', url = 'https://raw.githubusercontent.com/ironsquadronfr-hub/swl-assets/main/assets/ui_tab_v2.png'},
  {name = 'loaderTabActive', url = 'https://raw.githubusercontent.com/ironsquadronfr-hub/swl-assets/main/assets/ui_tab_active_v2.png'},
}

BRAIN_GUID = 'b7a1e0'
BRAIN_POSITION = {55.2, -3.5, -1.42} -- hidden inside the computer screen

state = {channel = 'stable', version = nil, fresh = true, ui = nil, uiAssets = nil, objects = {}}

-- Read by the saved brain's onload: while true, it waits for loaderGo.
LOADER_HOLD = false

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
  if state.fresh then
    -- Global's onLoad runs before any object's: the saved brain sees this.
    LOADER_HOLD = true
    showChooser()
  else
    -- TTS does not save a UI set by a script: put it back on every load.
    if state.ui then
      setUi(state.uiAssets, state.ui)
    end
    say('game on ' .. tostring(state.version) .. ' (' .. state.channel .. ')')
  end
end

function onSave()
  return JSON.encode(state)
end

-- Sets the global UI. Images declared a second time in a session only show
-- once the XML is set again (measured), hence the blank step.
function setUi(assets, xml, done)
  UI.setCustomAssets(assets or {})
  UI.setXml('')
  Wait.time(function()
    UI.setXml(xml)
    if done then
      Wait.condition(done, function() return not UI.loading end, 10, done)
    end
  end, 0.3)
end

----------------------------------------------------------------------------
-- The chooser: two halves, Stable on the left, Beta on the right. Everyone
-- sees it and sees the host's hover live (the global UI is shared), but only
-- the host's mouse counts.

local DIM = 0.62 -- brightness of a half at rest; 1 under the host's mouse
local level = {loaderStable = DIM, loaderBeta = DIM}
local target = {loaderStable = DIM, loaderBeta = DIM}

local function veil(v)
  return string.format('#000000%02X', math.floor((1 - v) * 255 + 0.5))
end

local function chooserHalf(id, image, tagline, label)
  return [[
  <Panel id="]] .. id .. [[" color="#090D23" onMouseEnter="loaderEnter" onMouseExit="loaderExit" onClick="loaderChoose">
    <Image id="]] .. id .. [[Art" image="]] .. image .. [[" width="100%" height="100%" preserveAspect="true" raycastTarget="false" color="#FFFFFF00" />
    <Panel id="]] .. id .. [[Shade" width="100%" height="100%" raycastTarget="false" color="]] .. veil(DIM) .. [[" />
    <Text id="]] .. id .. [[Tag" raycastTarget="false" rectAlignment="LowerCenter" offsetXY="0 182" width="800" height="30"
      fontSize="16" color="#C9D2E0">]] .. tagline .. [[</Text>
    <Image id="]] .. id .. [[Btn" image="loaderTab" raycastTarget="false" rectAlignment="LowerCenter" offsetXY="0 110" width="395" height="60" />
    <Text id="]] .. id .. [[Label" raycastTarget="false" rectAlignment="LowerCenter" offsetXY="0 110" width="395" height="60"
      fontSize="24" fontStyle="Bold" color="#E6E8EE">]] .. label .. [[</Text>
  </Panel>]]
end

CHOOSER_XML = [[
<Panel id="loaderChooser" width="100%" height="100%" color="#090D23">
  <HorizontalLayout childForceExpandWidth="true" childForceExpandHeight="true" spacing="0">
]] .. chooserHalf('loaderStable', 'loaderChoiceStable', 'Recommended  ·  tested by the community', 'LOAD STABLE')
   .. chooserHalf('loaderBeta', 'loaderChoiceBeta', 'New features  ·  help us test them', 'LOAD BETA') .. [[
  </HorizontalLayout>
  <Text id="loaderWaiting" active="false" raycastTarget="false" rectAlignment="UpperCenter" offsetXY="0 -28" width="900" height="30"
    fontSize="16" color="#C9D2E0">The host is choosing the mod version</Text>
</Panel>
]]

chooserOpen = false

function showChooser()
  chooserOpen = true
  local assets = {}
  for _, asset in ipairs(CHOOSER_ASSETS) do table.insert(assets, asset) end
  -- The saved version's own images too: if the host keeps it, the mod's
  -- UI comes up without declaring images a second time.
  for _, asset in ipairs(state.uiAssets or {}) do table.insert(assets, asset) end
  setUi(assets, CHOOSER_XML, updateWaitingLine)
  -- The pictures start invisible: until it has downloaded one, TTS draws a
  -- white box in its place. On a player's very first load they are still
  -- downloading when the XML goes up, and TTS does not redraw them when they
  -- arrive, so the XML is set once more a little later, and the pictures
  -- fade in.
  Wait.time(function()
    if not chooserOpen then return end
    level.loaderStable, level.loaderBeta = DIM, DIM
    target.loaderStable, target.loaderBeta = DIM, DIM
    UI.setXml(CHOOSER_XML)
    Wait.condition(function()
      updateWaitingLine()
      for i = 1, 12 do
        Wait.frames(function()
          local alpha = string.format('#FFFFFF%02X', math.floor(255 * i / 12))
          UI.setAttribute('loaderStableArt', 'color', alpha)
          UI.setAttribute('loaderBetaArt', 'color', alpha)
        end, i)
      end
    end, function() return not UI.loading end, 10)
  end, 1.5)
end

-- The guests' line: everyone but the host.
function updateWaitingLine()
  if not chooserOpen then return end
  local colors = {}
  for _, player in ipairs(Player.getPlayers()) do
    if not player.host then table.insert(colors, player.color) end
  end
  if #colors == 0 then
    UI.setAttribute('loaderWaiting', 'active', 'false')
  else
    UI.setAttribute('loaderWaiting', 'visibility', table.concat(colors, '|'))
    UI.setAttribute('loaderWaiting', 'active', 'true')
  end
end

function onPlayerConnect() Wait.frames(updateWaitingLine, 1) end
function onPlayerChangeColor() Wait.frames(updateWaitingLine, 1) end

local function tween(id)
  local from = level[id]
  for i = 1, 8 do
    Wait.frames(function()
      local v = from + (target[id] - from) * i / 8
      level[id] = v
      UI.setAttribute(id .. 'Shade', 'color', veil(v))
    end, i)
  end
end

function loaderEnter(player, _, id)
  if not player.host or not chooserOpen then return end
  target[id] = 1
  tween(id)
  UI.setAttribute(id .. 'Btn', 'image', 'loaderTabActive')
  UI.setAttribute(id .. 'Label', 'color', '#E8801A')
  UI.setAttribute(id .. 'Tag', 'color', '#F5F6FA')
end

function loaderExit(player, _, id)
  if not player.host or not chooserOpen then return end
  target[id] = DIM
  tween(id)
  UI.setAttribute(id .. 'Btn', 'image', 'loaderTab')
  UI.setAttribute(id .. 'Label', 'color', '#E6E8EE')
  UI.setAttribute(id .. 'Tag', 'color', '#C9D2E0')
end

function loaderChoose(player, _, id)
  if not player.host or not chooserOpen then return end
  chooserOpen = false
  state.channel = (id == 'loaderBeta') and 'beta' or 'stable'
  say(player.steam_name .. ' chose ' .. state.channel)
  check()
end

----------------------------------------------------------------------------
-- Getting the version on the table.

-- Plays the version saved in the Workshop item: its UI, then the held brain.
function keepSaved(reason)
  say(reason)
  local brain = getObjectFromGUID(BRAIN_GUID)
  if not brain or not state.ui then
    say('no version saved in this table and none could be downloaded')
    return
  end
  LOADER_HOLD = false
  state.fresh = false
  setUi(state.uiAssets, state.ui, function()
    brain.call('loaderGo')
  end)
end

-- Downloads the channel's manifest and installs it when it is newer than
-- what the table holds.
function check()
  local base = RELEASES[state.channel]
  WebRequest.get(base .. 'manifest.json', function(request)
    if request.is_error then
      return keepSaved('release server unreachable (' .. tostring(request.error) .. '), playing ' .. tostring(state.version))
    end
    local ok, manifest = pcall(JSON.decode, request.text)
    if not ok or type(manifest) ~= 'table' or not manifest.version then
      return keepSaved('unreadable manifest, playing ' .. tostring(state.version))
    end
    if manifest.version == state.version and state.channelOfVersion == state.channel and getObjectFromGUID(BRAIN_GUID) then
      return keepSaved('up to date: ' .. manifest.version .. ' (' .. state.channel .. ')')
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
        return keepSaved('could not download ' .. names[i] .. ', playing ' .. tostring(state.version))
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
  LOADER_HOLD = false
  state.ui = uiText
  state.uiAssets = manifest.uiAssets
  -- The mod's onload expects its UI to be there, as it is on a save load.
  setUi(manifest.uiAssets, uiText, function()
    step('spawn', function() spawnRelease(manifest, brainText, objectsText) end)
  end)
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
  state.channelOfVersion = state.channel
  state.fresh = false
  say(string.format('installed %s (%s): brain + %d objects in %.2f s',
    manifest.version, state.channel, #guids, os.clock() - started))
end

-- Before an install, the table is emptied of the previous release. Only
-- ever on a fresh table or on the host's explicit request.
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
-- !loader reinstall       wipe this table and choose a version again
-- !loader pack            mark this save as fresh before a Workshop upload
function onChat(message, player)
  if message:sub(1, 7) ~= '!loader' then
    return true
  end
  if not player.host then
    return false
  end
  local command = message:sub(9)
  if command == 'reinstall' then
    state.version = nil
    state.fresh = true
    clearTable()
    showChooser()
  elseif command == 'pack' then
    state.fresh = true
    say('this save will ask for a version when opened')
  else
    say('shell ' .. SHELL_VERSION .. ', ' .. tostring(state.version) .. ' (' .. tostring(state.channelOfVersion or state.channel) .. ')')
  end
  return false
end

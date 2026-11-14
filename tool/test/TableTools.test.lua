-- Tests for mod/src/includes/TableTools.ttslua, run with standalone Lua:
--
--   npm run test:lua
--
-- The table's small tools lost their scripts: the brain gives them their
-- buttons. These tests check that each tool gets the button its script made
-- (same function, same look) and that a click does what the script did.

-- Fake TTS ---------------------------------------------------------------

local objects, calls, broadcasts, dialogs

local loadText = rawget(_G, "loadstring") or load
JSON = {
  decode = function(s)
    local text = s:gsub('"([%w_]+)":', "%1=")
    return loadText("return " .. text)()
  end,
}

function getObjectFromGUID(guid)
  return objects[guid]
end

function getAllObjects()
  local list = {}
  for _, o in pairs(objects) do list[#list + 1] = o end
  return list
end

function broadcastToColor(text, color)
  broadcasts[#broadcasts + 1] = {text = text, color = color}
end

self = {name = "brain"}

Player = setmetatable({}, {__index = function(_, color)
  return {showInputDialog = function(_, _, fn)
    dialogs[#dialogs + 1] = {color = color, answer = fn}
  end}
end})

-- Wait.condition runs at once here: the bag is always loaded.
Wait = {condition = function(fn) fn() end}

local function fake(guid, memo, extra)
  local o = {memo = memo, buttons = {}, interactable = true, gm = "", pressed = 0}
  for k, v in pairs(extra or {}) do o[k] = v end
  function o.getGUID() return guid end
  function o.getGMNotes() return o.gm end
  function o.createButton(b) o.buttons[#o.buttons + 1] = b end
  function o.clearButtons() o.buttons = {} end
  function o.setColorTint(c) o.tint = c end
  function o.call(fn, arg) calls[#calls + 1] = {guid = guid, fn = fn, arg = arg} end
  function o.getStateId() return o.state or 1 end
  function o.setState(n) o.newState = n end
  function o.clearContextMenu() o.menu = {} end
  function o.addContextMenuItem(label, fn) o.menu[#o.menu + 1] = {label = label, fn = fn} end
  function o.getObjects() return o.held or {} end
  function o.setScale(sc) o.scale = sc end
  o.AssetBundle = {playTriggerEffect = function() o.pressed = o.pressed + 1 end}
  objects[guid] = o
  return o
end

local failures = 0
local function test(name, fn)
  objects, calls, broadcasts, dialogs = {}, {}, {}, {}
  dieRollerInfo = {redDieRollerGUID = "rr", blueDieRollerGUID = "br"}
  fake("rr")
  fake("br")
  dofile("mod/src/includes/TableTools.ttslua")
  local ok, err = pcall(fn)
  if ok then
    print("PASS " .. name)
  else
    failures = failures + 1
    print("FAIL " .. name .. "\n  " .. tostring(err))
  end
end

-- Tests ------------------------------------------------------------------

test("a spawn button gets the old button and calls its own roller", function()
  local b = fake("b", '{"tool":"spawnDice","side":"blue","dice":"WhiteDefense"}')
  tableToolEquip(b)
  assert(not b.interactable, "still clickable")
  assert(#b.buttons == 1, "buttons: " .. #b.buttons)
  local btn = b.buttons[1]
  assert(btn.function_owner == self and btn.click_function == "tableToolSpawnDice", "owner or function")
  assert(btn.tooltip == "Spawn White Defense Dice" and btn.label == "", "look")
  assert(btn.font_color[1] == 0.7692, "white dice have red text")
  _G[btn.click_function](b, "Red")
  assert(#calls == 1 and calls[1].guid == "br" and calls[1].fn == "spawnWhiteDefenseDice", "call")
  assert(b.pressed == 1, "no animation")
end)

test("roll passes the player's colour, clear passes nothing", function()
  local r = fake("r", '{"tool":"roll","side":"red"}')
  local c = fake("c", '{"tool":"clear","side":"red"}')
  tableToolEquip(r)
  tableToolEquip(c)
  assert(r.buttons[1].label == "ROLL" and c.buttons[1].label == "CLEAR", "labels")
  _G[r.buttons[1].click_function](r, "Blue")
  _G[c.buttons[1].click_function](c, "Blue")
  assert(calls[1].guid == "rr" and calls[1].fn == "rollDie" and calls[1].arg[1] == "Blue", "roll")
  assert(calls[2].fn == "clearDie" and calls[2].arg == nil, "clear")
end)

test("equipping twice leaves one button", function()
  local b = fake("b", '{"tool":"spawnDice","side":"red","dice":"BlackAttack"}')
  tableToolEquip(b)
  tableToolEquip(b)
  assert(#b.buttons == 1, "buttons: " .. #b.buttons)
end)

test("a page box calls the lectern with the same number, or says it is missing", function()
  local box = fake("box", '{"tool":"rulesPage"}', {gm = "rules-page-2"})
  fake("l1", nil, {gm = "rules-lectern-1"})
  fake("l2", nil, {gm = "rules-lectern-2"})
  tableToolEquip(box)
  assert(box.interactable, "page boxes stay clickable, as before")
  assert(box.tint and box.tint[1] == 0.93, "tint")
  local pages = {}
  objects.l2.Book = {getPage = function() return 1 end, setPage = function(n) pages[#pages + 1] = n return n <= 300 end}
  tableToolRulesPage(box, "Red")
  assert(#dialogs == 1 and dialogs[1].color == "Red", "no page dialog")
  dialogs[1].answer("42.7")
  assert(pages[1] == 42, "page")
  box.gm = "rules-page-9"
  tableToolRulesPage(box, "Red")
  assert(#broadcasts == 1 and broadcasts[1].color == "Red", "missing lectern")
end)

test("inert tools only become unclickable, other objects are left alone", function()
  local t = fake("t", '{"tool":"inert"}')
  local plain = fake("p", nil)
  local other = fake("o", '{"template":"A"}')
  tableToolsInit()
  assert(not t.interactable and #t.buttons == 0, "inert")
  assert(plain.interactable and other.interactable, "touched another object")
end)

test("the token buttons keep their tint and tooltips", function()
  local ret = fake("ret", '{"tool":"returnTokens"}')
  local sup = fake("sup", '{"tool":"removeSuppression"}')
  tableToolEquip(ret)
  tableToolEquip(sup)
  assert(ret.tint[1] == 0.7 and ret.buttons[1].click_function == "tableToolReturnTokens", "return")
  assert(sup.buttons[1].click_function == "tableToolRemoveSuppression", "suppression")
  assert(ret.interactable and sup.interactable, "the asset buttons were clickable before")
end)

test("a lectern gets its Go to page menu, and a page past the end is said", function()
  local l = fake("l", '{"tool":"lectern"}')
  local pages = {}
  l.Book = {getPage = function() return 3 end, setPage = function(n) pages[#pages + 1] = n return n <= 10 end}
  tableToolEquip(l)
  assert(#l.menu == 1 and l.menu[1].label == "Go to page", "menu")
  l.menu[1].fn("Blue")
  dialogs[1].answer("12")
  assert(pages[1] == 12 and #broadcasts == 1 and broadcasts[1].color == "Blue", "no page 12")
end)

test("the turn counter shows < from turn 2 and > up to turn 4", function()
  local first = fake("t1", '{"tool":"turnCounter"}', {state = 1})
  local mid = fake("t3", '{"tool":"turnCounter"}', {state = 3})
  local last = fake("t5", '{"tool":"turnCounter"}', {state = 5})
  tableToolEquip(first)
  tableToolEquip(mid)
  tableToolEquip(last)
  assert(#first.buttons == 1 and first.buttons[1].label == ">", "turn 1")
  assert(#mid.buttons == 2, "turn 3")
  assert(#last.buttons == 1 and last.buttons[1].label == "<", "turn 5")
  _G[mid.buttons[1].click_function](mid)
  assert(mid.newState == 2, "previous")
  _G[mid.buttons[2].click_function](mid)
  assert(mid.newState == 4, "next")
end)

test("a command stack is as tall as its tokens, and blue when empty", function()
  local st = fake("st", '{"tool":"commandStack"}', {held = {1, 2, 3}})
  tableToolEquip(st)
  assert(st.scale[2] == 3 and st.tint[1] == 1, "three tokens")
  st.held = {}
  tableToolOnLeaveContainer(st)
  assert(st.scale[2] == 1 and st.tint[3] == 114 / 255, "empty")
  st.held = {1}
  tableToolUpdateCommandStack({guid = "st"})
  assert(st.scale[2] == 1 and st.tint[1] == 1, "from a tray")
  local bag = fake("bag", nil, {held = {}})
  tableToolOnLeaveContainer(bag)
  assert(bag.scale == nil, "another bag was resized")
end)

test("the chess clocks keep their time through the brain's save", function()
  local value = {red = 0, blue = 0}
  clockGUIDs = {red = "cr", blue = "cb"}
  fake("cr").Clock = {getValue = function() return 125 end, setValue = function(v) value.red = v end}
  fake("cb").Clock = {getValue = function() return 7 end, setValue = function(v) value.blue = v end}
  local saved = tableToolsSaveClocks()
  assert(saved.red == 125 and saved.blue == 7, "save")
  tableToolsRestoreClocks({red = 30, blue = "9"})
  assert(value.red == 30 and value.blue == 9, "restore")
  tableToolsRestoreClocks(nil)
end)

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

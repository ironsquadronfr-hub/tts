-- Tests for mod/src/includes/TableTools.ttslua, run with standalone Lua:
--
--   npm run test:lua
--
-- The table's small tools lost their scripts: the brain gives them their
-- buttons. These tests check that each tool gets the button its script made
-- (same function, same look) and that a click does what the script did.

-- Fake TTS ---------------------------------------------------------------

local objects, calls, broadcasts

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

local function fake(guid, memo, extra)
  local o = {memo = memo, buttons = {}, interactable = true, gm = "", pressed = 0}
  for k, v in pairs(extra or {}) do o[k] = v end
  function o.getGUID() return guid end
  function o.getGMNotes() return o.gm end
  function o.createButton(b) o.buttons[#o.buttons + 1] = b end
  function o.clearButtons() o.buttons = {} end
  function o.setColorTint(c) o.tint = c end
  function o.call(fn, arg) calls[#calls + 1] = {guid = guid, fn = fn, arg = arg} end
  o.AssetBundle = {playTriggerEffect = function() o.pressed = o.pressed + 1 end}
  objects[guid] = o
  return o
end

local failures = 0
local function test(name, fn)
  objects, calls, broadcasts = {}, {}, {}
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
  tableToolRulesPage(box, "Red")
  assert(#calls == 1 and calls[1].guid == "l2" and calls[1].fn == "rulesLecternGoToPage" and calls[1].arg == "Red", "lectern")
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

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

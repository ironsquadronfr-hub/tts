-- Tests for mod/src/includes/MiniInfo.ttslua and MiniUpright.ttslua, run
-- with standalone Lua:
--
--   npm run test:lua
--
-- The minis that are not their unit's leader lost their script: their
-- wiring moved to the memo, their uprighting to the brain. These tests hold
-- the brain to the rule of the old script (!/data/MiniShared), copied below,
-- and check that minis of both kinds read the same.

-- Fake TTS ---------------------------------------------------------------

local objects, started, clock = {}, 0, 0

local loadText = rawget(_G, "loadstring") or load
JSON = {
  decode = function(s)
    local text = s:gsub('"([%w_]+)":', "%1=")
    return loadText("return " .. text)()
  end,
}

function getAllObjects()
  local list = {}
  for _, o in pairs(objects) do list[#list + 1] = o end
  return list
end

function startLuaCoroutine(_, _)
  started = started + 1
end

self = {}
-- The settle deadline reads os.clock: the tests move time by hand.
os.clock = function() return clock end -- luacheck: ignore 122

local function fakeMini(guid, opts)
  opts = opts or {}
  local o = {
    memo = opts.memo, vars = opts.vars or {}, tags = {},
    resting = opts.resting or false, held_by_color = nil,
    up = opts.up or {x = 0, y = 1, z = 0},
    forward = opts.forward or {x = 0, y = 0, z = 1},
    right = opts.right or {x = 1, y = 0, z = 0},
    rot = nil, registered = 0,
  }
  function o.getGUID() return guid end
  function o.getVar(name) return o.vars[name] end
  function o.hasTag(t) return o.tags[t] == true end
  function o.addTag(t) o.tags[t] = true end
  function o.removeTag(t) o.tags[t] = nil end
  function o.getTransformUp() return o.up end
  function o.getTransformForward() return o.forward end
  function o.getTransformRight() return o.right end
  function o.getPosition() return {x = 1, y = 2, z = 3} end
  function o.setPosition(p) o.pos = p end
  function o.setRotation(r) o.rot = r end
  function o.setVelocity() end
  function o.setAngularVelocity() end
  function o.registerCollisions(stay) o.registered = o.registered + 1; o.stay = stay end
  objects[guid] = o
  return o
end

local MEMO = '{"isqMini":1,"leader":"lead","color":"red","type":"Trooper"}'

local function loop()
  return coroutine.create(miniUprightLoop)
end
local function frame(co)
  local ok, err = coroutine.resume(co)
  assert(ok, err)
  return coroutine.status(co)
end

local failures = 0
local function test(name, fn)
  -- Fresh modules each time: their state is local.
  objects, started, clock = {}, 0, 0
  dofile("mod/src/includes/MiniInfo.ttslua")
  dofile("mod/src/includes/MiniUpright.ttslua")
  local ok, err = pcall(fn)
  if ok then
    print("PASS " .. name)
  else
    failures = failures + 1
    print("FAIL " .. name .. "\n  " .. tostring(err))
  end
end

local function near(a, b, label)
  if math.abs(a - b) > 1e-9 then
    error((label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
  end
end

-- The old script's yaw, as it was (fixUpright in !/data/MiniShared).
local atan2 = math.atan2 or math.atan
local function oldYaw(forward, right)
  if math.abs(forward.y) < 0.9 then
    return math.deg(atan2(forward.x, forward.z))
  end
  return math.deg(atan2(right.x, right.z)) - 90
end

-- Tests ------------------------------------------------------------------

test("a mini reads its leader from its script or from its memo", function()
  assert(miniLeaderGUID(fakeMini("old", {vars = {leaderGUID = "lead"}})) == "lead", "scripted")
  assert(miniLeaderGUID(fakeMini("new", {memo = MEMO})) == "lead", "memo")
  assert(miniLeaderGUID(fakeMini("die")) == nil, "no memo")
  assert(miniLeaderGUID(fakeMini("tok", {memo = '{"isqTpl":"A"}'})) == nil, "another memo")
  assert(miniLeaderGUID(nil) == nil, "nil")
end)

test("the yaw a tipped mini stands up on is the old script's", function()
  local cases = {
    {{x = 0.6, y = 0.1, z = -0.79}, {x = 1, y = 0, z = 0}},
    {{x = -0.2, y = -0.3, z = 0.93}, {x = 0, y = 0, z = 1}},
    {{x = 0.1, y = 0.95, z = 0.29}, {x = -0.7, y = 0.1, z = 0.7}},
    {{x = 0, y = -0.99, z = 0.1}, {x = 0.5, y = 0, z = -0.86}},
  }
  for i, c in ipairs(cases) do
    near(miniUprightYaw(c[1], c[2]), oldYaw(c[1], c[2]), "case " .. i)
  end
  assert(miniIsTipped({y = 0.3}) and not miniIsTipped({y = 0.34}), "70 degree limit")
end)

test("a dropped tipped mini stands up once it rests", function()
  local m = fakeMini("m", {memo = MEMO, up = {x = 1, y = 0, z = 0}, forward = {x = 0, y = 0, z = 1}})
  miniUprightOnDrop(m)
  assert(started == 1, "loop not started")
  local co = loop()
  frame(co)
  assert(m.rot == nil, "stood up before resting")
  m.resting = true
  frame(co)
  assert(m.rot and m.rot[1] == 0 and m.rot[3] == 0, "not stood up")
  near(m.rot[2], 0, "yaw")
  near(m.pos[2], 2.3, "lifted 0.3")
end)

test("an upright mini, a held one and a flipped one are left alone", function()
  local upright = fakeMini("u", {memo = MEMO, resting = true})
  local held = fakeMini("h", {memo = MEMO, up = {x = 1, y = 0, z = 0}})
  local flipped = fakeMini("f", {memo = MEMO, up = {x = 0, y = -1, z = 0}, resting = true})
  flipped.tags.Flipped = true
  miniUprightOnDrop(upright)
  miniUprightOnDrop(held)
  miniUprightOnDrop(flipped)
  held.held_by_color = "Red"
  local co = loop()
  frame(co)
  assert(upright.rot == nil and held.rot == nil and flipped.rot == nil, "one was moved")
end)

test("a mini that never rests is let go after 6 seconds", function()
  local m = fakeMini("m", {memo = MEMO, up = {x = 1, y = 0, z = 0}})
  miniUprightOnDrop(m)
  local co = loop()
  frame(co)
  clock = 7
  frame(co)
  assert(frame(co) == "dead", "still watched")
  assert(m.rot == nil, "stood up")
end)

test("scripted minis are left to their own script", function()
  local old = fakeMini("old", {vars = {leaderGUID = "lead"}, up = {x = 1, y = 0, z = 0}})
  miniUprightOnDrop(old)
  miniUprightOnCollision(old)
  miniUprightOnRotate(old, 180, 0)
  miniUprightWatch(old)
  assert(started == 0 and old.tags.Flipped == nil and old.registered == 0, "handled")
end)

test("a collision only counts for a mini neither held nor resting", function()
  local m = fakeMini("m", {memo = MEMO, resting = true})
  miniUprightOnCollision(m)
  assert(started == 0, "a resting mini was watched")
  m.resting = false
  miniUprightOnCollision(m)
  assert(started == 1, "a moving mini was not watched")
end)

test("turning a mini over tags it, turning it back untags it", function()
  local m = fakeMini("m", {memo = MEMO})
  miniUprightOnRotate(m, 180, 0)
  assert(m.tags.Flipped, "not tagged")
  miniUprightOnRotate(m, 15, 15)
  assert(m.tags.Flipped, "a spin untagged it")
  miniUprightOnRotate(m, 0, 180)
  assert(not m.tags.Flipped, "still tagged")
end)

test("on load every mini with the memo is registered for enter only", function()
  local a = fakeMini("a", {memo = MEMO})
  local b = fakeMini("b", {vars = {leaderGUID = "lead"}})
  miniUprightInit()
  assert(a.registered == 1 and a.stay == false, "memo mini")
  assert(b.registered == 0, "scripted mini")
end)

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

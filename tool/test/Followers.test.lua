-- Tests for mod/src/includes/Followers.ttslua, run with standalone Lua:
--
--   npm run test:lua
--
-- The range rulers and extended overlays used to follow their figure with an
-- onFixedUpdate script of their own. The brain now moves them: these tests
-- drive its loop frame by frame with fake TTS objects.

-- Fake TTS ---------------------------------------------------------------

local objects, started = {}, 0

-- Enough of JSON.decode for the memos the mod writes. loadstring: the CI's
-- `lua` can be 5.1, whose load() takes no string.
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

function startLuaCoroutine(_, _)
  started = started + 1
end

self = {}

local function fakeObject(guid, x, y, z, yaw, memo)
  local o = {memo = memo, moves = 0, destroyed = false}
  o.pos, o.yaw = {x = x, y = y, z = z}, yaw
  function o.getGUID() return guid end
  function o.getPosition() return {x = o.pos.x, y = o.pos.y, z = o.pos.z} end
  function o.getRotation() return {x = 0, y = o.yaw, z = 0} end
  function o.setPosition(p)
    o.moves = o.moves + 1
    o.pos = {x = p[1], y = p[2], z = p[3]}
  end
  function o.setRotation(r) o.yaw = r[2] end
  function o.destruct() o.destroyed = true end
  objects[guid] = o
  return o
end

-- One coroutine per test, resumed once per frame as TTS would.
local function loop()
  return coroutine.create(followersLoop)
end
local function frame(co)
  local ok, err = coroutine.resume(co)
  assert(ok, err)
  return coroutine.status(co)
end

local failures = 0
local function test(name, fn)
  -- A fresh module each time: its follower list and loop flag are local.
  objects, started = {}, 0
  dofile("mod/src/includes/Followers.ttslua")
  local ok, err = pcall(fn)
  if ok then
    print("PASS " .. name)
  else
    failures = failures + 1
    print("FAIL " .. name .. "\n  " .. tostring(err))
  end
end

-- Tests ------------------------------------------------------------------

test("a follower sits 20in above its target, turned like it", function()
  local fig = fakeObject("fig", 3, 1, -4, 37)
  local ruler = fakeObject("rul", 0, 0, 0, 0, '{"isqFollow":"fig","kill":true}')
  followersAdd(ruler)
  local co = loop()
  frame(co)
  assert(ruler.pos.x == 3 and ruler.pos.y == 21 and ruler.pos.z == -4, "position")
  assert(ruler.yaw == 37, "yaw")
  fig.pos.x, fig.yaw = 10, 90
  frame(co)
  assert(ruler.pos.x == 10 and ruler.yaw == 90, "after the figure moved")
end)

test("a follower whose target stands still is not moved again", function()
  fakeObject("fig", 1, 1, 1, 0)
  local ruler = fakeObject("rul", 0, 0, 0, 0, '{"isqFollow":"fig"}')
  followersAdd(ruler)
  local co = loop()
  for _ = 1, 10 do frame(co) end
  assert(ruler.moves == 1, "moved " .. ruler.moves .. " times")
end)

test("an object without the memo is ignored and starts nothing", function()
  followersAdd(fakeObject("die", 0, 0, 0, 0, ""))
  followersAdd(fakeObject("card", 0, 0, 0, 0, '{"other":1}'))
  assert(started == 0, "loop started")
end)

test("the same follower added twice is followed once", function()
  fakeObject("fig", 1, 1, 1, 0)
  local ruler = fakeObject("rul", 0, 0, 0, 0, '{"isqFollow":"fig"}')
  followersAdd(ruler)
  followersAdd(ruler)
  assert(started == 1, "loop started " .. started .. " times")
end)

test("a gone target destroys a kill follower and ends the loop", function()
  local ruler = fakeObject("rul", 0, 0, 0, 0, '{"isqFollow":"gone","kill":true}')
  followersAdd(ruler)
  local co = loop()
  frame(co)
  -- The loop yields once more, then finds its list empty.
  assert(frame(co) == "dead", "loop still running")
  assert(ruler.destroyed, "ruler kept")
end)

test("a gone target leaves an overlay to its owner", function()
  local overlay = fakeObject("ovl", 0, 0, 0, 0, '{"isqFollow":"gone"}')
  followersAdd(overlay)
  local co = loop()
  frame(co)
  -- The loop yields once more, then finds its list empty.
  assert(frame(co) == "dead", "loop still running")
  assert(not overlay.destroyed, "overlay destroyed by the follower")
end)

test("the loop restarts once it has ended", function()
  fakeObject("fig", 1, 1, 1, 0)
  followersAdd(fakeObject("a", 0, 0, 0, 0, '{"isqFollow":"gone"}'))
  local co = loop()
  frame(co)
  assert(frame(co) == "dead")
  followersAdd(fakeObject("b", 0, 0, 0, 0, '{"isqFollow":"fig"}'))
  assert(started == 2, "loop not restarted")
end)

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

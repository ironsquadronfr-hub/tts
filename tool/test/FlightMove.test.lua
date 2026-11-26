-- Tests for mod/src/includes/FlightMove.ttslua (the move of a flying
-- vehicle, rulebook appendix F), run with standalone Lua:
--
--   npm run test:lua

dofile("mod/src/includes/FlightMove.ttslua")

local atan2 = math.atan2 or math.atan

local failures = 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    print("PASS " .. name)
  else
    failures = failures + 1
    print("FAIL " .. name .. "\n  " .. tostring(err))
  end
end

local function near(actual, expected, label)
  if math.abs(actual - expected) > 1e-9 then
    error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

-- the stand at the origin facing +z (heading 0), its ruler's foot at r = 1
test("the ruler points at the pointer inside the front arc", function()
  local x, z, yaw = flightRulerPose(0, 0, 0, 1, 45, 3, 10)
  near(yaw, math.deg(atan2(3, 10)), "yaw")
  near(math.sqrt(x * x + z * z), 1, "foot at r from the start")
end)

test("the ruler stops with its axis on the arc line", function()
  local _, _, right = flightRulerPose(0, 0, 0, 1, 45, 10, 0)
  near(right, 45, "pointer to the right")
  local _, _, left = flightRulerPose(0, 0, 0, 1, 45, -10, -1)
  near(left, -45, "pointer behind on the left")
end)

test("the ruler follows a turned stand", function()
  local _, _, yaw = flightRulerPose(5, 5, 90, 1, 45, 15, 5)
  near(yaw, 90, "straight ahead of a stand facing +x")
end)

-- line along +z from the origin; minimum move 14 (base 1 + ruler 12 + base 1)
test("a stand goes on the line, past the ruler, with no limit beyond", function()
  local x, z = flightStandSnap(0, 0, 0, 3, 10, 14)
  near(x, 0, "on the line"); near(z, 14, "the minimum move")
  x, z = flightStandSnap(0, 0, 0, -2, 16, 14)
  near(x, 0, "on the line"); near(z, 16, "where it was, along the line")
  _, z = flightStandSnap(0, 0, 0, 0, 300, 14)
  near(z, 300, "as far as it goes")
  x, z = flightStandSnap(0, 0, 90, 20, 5, 8)
  near(x, 20, "along +x"); near(z, 0, "on the +x line")
end)

test("short of half the minimum, the stand stays at the start", function()
  local x, z, atStart = flightStandSnap(0, 0, 0, 0.4, 0.2, 14)
  near(x, 0, "start x"); near(z, 0, "start z")
  assert(atStart, "back at the start")
  x, z, atStart = flightStandSnap(0, 0, 0, 0.4, 8, 14)
  near(x, 0, "on the line"); near(z, 14, "past half the minimum: the minimum")
  assert(not atStart, "not the start")
end)

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

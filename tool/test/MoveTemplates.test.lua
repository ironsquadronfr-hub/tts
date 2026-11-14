-- Tests for mod/src/includes/MoveTemplates.ttslua, run with standalone Lua:
--
--   npm run test:lua
--
-- The movement templates used to carry their own scripts (Model Template A
-- and B). Their math now lives in the brain: these tests hold the new
-- functions to the old formulas, copied below as they were.

dofile("mod/src/includes/MoveTemplates.ttslua")

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

-- Model Template A, positionTemplate(), as it was.
local function oldA(basePos, aStart, mouseX, mouseZ)
  local a = basePos.x - mouseX
  local b = basePos.z - mouseZ
  local q = math.deg(atan2(a, b))
  local rotY = q + 180
  local a2 = aStart * math.cos(atan2(b, a))
  local b2 = aStart * math.sin(atan2(b, a))
  return basePos.x - a2, basePos.z - b2, rotY
end

-- Model Template B, positionTemplate(), as it was. aRotY is half A's yaw
-- when B was picked up (TTS reports it in [0, 360)); lastY B's last yaw.
local function oldB(objPos, aRotY, lastY, mouseX, mouseZ)
  local baseRot2 = aRotY - 180
  local a = objPos.x - mouseX
  local b = objPos.z - mouseZ
  local q = math.deg(atan2(a, b))
  if baseRot2 > 180 then
    baseRot2 = baseRot2 - 360
  end
  if baseRot2 > -90 and baseRot2 < 90 then
    if q < baseRot2 + 90 and q > baseRot2 - 90 then
      return q
    end
    return lastY
  elseif baseRot2 >= 90 then
    if q > baseRot2 - 90 or q < baseRot2 - 270 then
      return q
    end
    return lastY
  elseif baseRot2 <= -90 then
    if q < baseRot2 + 90 or q > baseRot2 + 270 then
      return q
    end
    return lastY
  end
end

-- A deterministic spread of pointers around a point, angles every 7.5
-- degrees (both sides of every quadrant boundary) at several distances.
local function pointers(cx, cz)
  local out = {}
  for step = 0, 47 do
    local angle = math.rad(step * 7.5 + 0.3)
    for _, r in ipairs({0.5, 3, 11}) do
      out[#out + 1] = {cx + r * math.sin(angle), cz + r * math.cos(angle)}
    end
  end
  return out
end

test("half A lands where the old script put it", function()
  for _, base in ipairs({{x = 0, z = 0}, {x = -12.4, z = 7.9}, {x = 20, z = -15}}) do
    for _, aStart in ipairs({2.007874016, 4.311023622, 7.263779528}) do
      for _, m in ipairs(pointers(base.x, base.z)) do
        local x, z, yaw = moveTemplateAPose(base.x, base.z, aStart, m[1], m[2])
        local ox, oz, oyaw = oldA(base, aStart, m[1], m[2])
        near(x, ox, "x")
        near(z, oz, "z")
        near(yaw, oyaw, "yaw")
      end
    end
  end
end)

test("half A stays aStart from the base, on the pointer's side", function()
  local x, z = moveTemplateAPose(1, 2, 3, 1, 10)
  near(x, 1, "x")
  near(z, 5, "z")
end)

test("half B turns as the old script did, every quadrant", function()
  for aYaw = 0, 359, 15 do
    for _, m in ipairs(pointers(3, -4)) do
      for _, lastY in ipairs({-170, 0, 42}) do
        local new = moveTemplateBYaw(3, -4, aYaw, lastY, m[1], m[2])
        local old = oldB({x = 3, z = -4}, aYaw, lastY, m[1], m[2])
        near(new, old, "yaw (A at " .. aYaw .. ")")
      end
    end
  end
end)

test("half B keeps its yaw beyond 90 degrees off half A", function()
  -- A at yaw 180 points B's allowed arc around yaw 0 (towards -z).
  local towards = moveTemplateBYaw(0, 0, 180, 99, 0, -5)
  near(towards, 0, "pointer straight ahead")
  local behind = moveTemplateBYaw(0, 0, 180, 99, 0, 5)
  near(behind, 99, "pointer behind")
end)

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

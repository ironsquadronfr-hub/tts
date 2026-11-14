-- Tests for mod/src/includes/DeploymentZones.ttslua, run with standalone Lua:
--
--   npm run test:lua
--
-- Needs the generated card schema (npm run generate, done by test:lua) for
-- the official missions.

dofile("mod/src/includes/DeploymentZones.ttslua")
dofile("mod/src/includes/data/DeploymentZoneBundles.ttslua")
dofile("mod/src/includes/generated/cards.ttslua")

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

local function eq(actual, expected, label)
  if actual ~= expected then
    error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

-- A 12 x 6 grid with the given rows (top first), blank elsewhere.
local function grid(rows)
  local matrix = {}
  for z = 1, 6 do
    matrix[z] = {}
    for x = 1, 12 do
      matrix[z][x] = (rows[z] or {})[x] or " "
    end
  end
  return matrix
end

local function row(cell)
  local r = {}
  for x = 1, 12 do
    r[x] = cell
  end
  return r
end

-- Cauldron: a full row and a half row on each long edge.
local cauldron = grid({ row("r"), row("rh"), nil, nil, row("bh"), row("b") })

test("each zone is one shape across the table, 9 inches deep", function()
  local pieces = DeploymentZones.pieces(cauldron, false)
  local red = DeploymentZones.zone(pieces, "r")
  local blue = DeploymentZones.zone(pieces, "b")
  eq(red.key:match("^[^/]+"), "48x6", "red size in 1.5 inch steps")
  eq(red.x, 8, "red centre x")
  eq(red.z, -13.5, "red is on the near edge")
  eq(blue.z, 13.5, "blue is on the far edge")
end)

-- Three red cells in the top left corner of the card.
local corner = grid({ { "r", "r", "r" } })

test("the card is turned around: top left becomes bottom right", function()
  local red = DeploymentZones.zone(DeploymentZones.pieces(corner, false), "r")
  eq(red.x, 35, "red centre x")
  eq(red.z, -15, "red centre z")
end)

test("mirror keeps the card's layout and swaps the colors", function()
  local pieces = DeploymentZones.pieces(corner, true)
  eq(DeploymentZones.zone(pieces, "r"), nil, "no red")
  local blue = DeploymentZones.zone(pieces, "b")
  eq(blue.x, -19, "blue centre x")
  eq(blue.z, 15, "blue centre z")
end)

test("a color with no piece has no zone", function()
  local pieces = DeploymentZones.pieces(grid({ row("r") }), false)
  eq(DeploymentZones.zone(pieces, "b"), nil)
end)

test("overlapping pieces fall back to the cells", function()
  local pieces = { { cell = "r", x = -25, z = 15 }, { cell = "rh", x = -25, z = 15 } }
  eq(DeploymentZones.zone(pieces, "r"), nil)
end)

test("every official mission draws each zone with one bundle, both ways", function()
  local count = 0
  for scenario, deck in pairs(GENERATED_CARDS_SCHEMA.battlefield) do
    for name, deployment in pairs(deck.deployment or {}) do
      if deployment.zone and #deployment.zone > 0 then
        for _, mirror in ipairs({ false, true }) do
          local pieces = DeploymentZones.pieces(deployment.zone, mirror)
          for _, color in ipairs({ "r", "b" }) do
            local zone = DeploymentZones.zone(pieces, color)
            local where = scenario .. " " .. name .. " " .. color .. (mirror and " mirror" or "")
            if not zone then
              error("no single shape: " .. where)
            end
            if not DEPLOYMENT_ZONE_BUNDLES[color .. "|" .. zone.key] then
              error("no bundle: " .. where)
            end
            count = count + 1
          end
        end
      end
    end
  end
  eq(count > 0, true, "missions found")
end)

if failures > 0 then
  print(failures .. " test(s) failed")
  os.exit(1)
end
print("All tests passed")

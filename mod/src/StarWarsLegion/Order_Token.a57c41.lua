require('!/common/Math')
require('!/RangeRulers')
require('!/data/MovementLinks')
require('!/Cohesion')


-- Model Token

function onload()
  -- LOAD VALUES
  _G.battlefieldZone = getObjectFromGUID(Global.getVar("battlefieldZoneGUID"))
  _G.templateInfo = Global.getTable("templateInfo")
  _G.highlightTints = Global.getTable("highlightTints")

  -- set info
  _G.selectedUnit = nil
  _G.activated = false

  -- setUp
  if _G.unitData ~= nil then
    local dieRollerInfo = Global.getTable("dieRollerInfo")
    _G.isAToken = true
    _G.dieRoller = getObjectFromGUID(dieRollerInfo[_G.unitData.colorSide.."DieRollerGUID"])
    setTemplateVariables()
    initialize()
  end
end

--
function setTemplateVariables()
    unitData.aStart = templateInfo.aStart[unitData.baseSize][unitData.selectedSpeed]
    unitData.templateMesh = templateInfo.templateMesh[unitData.selectedSpeed]
    unitData.templateBallCollider = templateInfo.templateBallCollider
    unitData.tint = templateInfo.tint[unitData.selectedSpeed]
    unitData.buttonPosition = templateInfo.buttonPosition[unitData.selectedSpeed]
    unitData.buttonColor = templateInfo.buttonColor[unitData.selectedSpeed]
    unitData.fontColor = templateInfo.fontColor[unitData.selectedSpeed]
end
------------------------------------------------- MATH FIND PROXIMITY------------------------------------------------------------
function findProximity(targetObj, object)
    local objectPos = object.getPosition()
    local targetPos = targetObj.getPosition()

    local xDistance = math.abs(targetPos.x - objectPos.x)
    local zDistance = math.abs(targetPos.z - objectPos.z)
    local distance = xDistance^2 + zDistance^2
    return math.sqrt(distance)
end




------------------------------------------------- getSelectedUnit() ------------------------------------------------------------
function getEligibleUnit()
    eligibleUnits = nil
    eligibleUnits = {}
    eligibleUnitsNumber = 0
    selectedUnitObj = nil

    local allUnits = nil
    local allUnits = battlefieldZone.getObjects()

    if allUnits ~= nil then
        local closestDistance = 9999999999999

        -- check all units
        for i, unit in pairs(allUnits) do
            -- check eligibility

            local miniData = unit.getTable("unitData")
            local isAMini = unit.getVar("isAMini")
            if miniData and miniData.commandType then
                if isAMini == true and unitData.commandType == miniData.commandType and unit.getVar("colorSide") == unitData.colorSide then
                    -- add to eligible units
                    eligibleUnitsNumber = eligibleUnitsNumber + 1
                    eligibleUnits[eligibleUnitsNumber] = unit

                    -- find distance
                    local distance = findProximity(self, unit)


                    if distance < closestDistance then
                        selectedUnitObj = unit
                        selectedUnitNumber = eligibleUnitsNumber
                        closestDistance = distance
                    end
                end
            end

        end
        -- if success
        if selectedUnitObj then
            getSelectedUnitObjVariables()
            setTemplateVariables()
        end
    end
end

function highlightUnit(selectedMiniGUIDs, highlightColor)
  for _, guidEntry in ipairs(selectedMiniGUIDs) do
    obj = getObjectFromGUID(guidEntry)
    if obj then
      obj.highlightOn(highlightColor)
    end
  end
end

function unhighlightUnit(selectedMiniGUIDs)
    if selectedMiniGUIDs then
        for k, guidEntry in pairs(selectedMiniGUIDs) do
            obj = getObjectFromGUID(guidEntry)
            if obj then
                obj.highlightOff()
            end
        end
    end
end

function highlightCard(selectedUnitCard)
    if selectedUnitCard then
        selectedUnitCard.highlightOn({0,1,0})
    end
end

function forceUnhighlight()
    local allObjs = getAllObjects()
    for _, obj in pairs(allObjs) do
        obj.highlightOff()
    end
end


function unHighlightCard(selectedUnitCard)
    if selectedUnitCard then
        selectedUnitCard.highlightOff()
    end
end

function getSelectedUnitObjVariables()
    if selectedUnitObj then
        newUnitData = selectedUnitObj.getTable("unitData")
        unitData.baseSize = newUnitData.baseSize
        unitData.selectedSpeed = newUnitData.selectedSpeed
    end
end

------------------------------------------------- STANDBY ------------------------------------------------------------
function initialize()

    activated = false
    --getEligibleUnit()

    createStandbyButtons()

end

function createStandbyButtons()
    if selectedUnitObj then
        self.createButton({
            click_function = "activate",
            function_owner = self,
            label = "ACT", position = {0, 0.05, 0.4}, width = 350, height = 250, font_size = 120, color = {0.03, 0.6, 0.03, 1}, font_color = {1, 1, 1, 1},
            tooltip = "Activate nearest " .. unitData.commandType .. " unit",
            color = {0.03, 0.6, 0.03}
        })
    else

        self.createButton({
            click_function = "standby",
            function_owner = self,
            label = "",
            position = {0, 0.05, 0.4}, width = 350, height = 250,
            font_size = 150,
            tooltip = "No unit of this type left on board",
            color = {0.6, 0.03, 0.03},
            font_color = {1, 1, 1}
        })
    end
end

function standby()
    activated = false
    self.clearButtons()
    clearTemplates()
    forceUnhighlight()

    getEligibleUnit()

    createStandbyButtons()
end
------------------------------------------------- ACTIVATE ------------------------------------------------------------
function activate()
  getEligibleUnit()
  if selectedUnitObj then
    moveDirection = "forward"
    activated = true
    self.clearButtons()
    getSelectedUnitObjVariables()
    setTemplateVariables()

    selectedUnitObj.call("setStartPos")

    highlightUnit(selectedUnitObj.getTable("miniGUIDs"),{0,1,0})
    highlightCard(getObjectFromGUID(selectedUnitObj.getVar("cardGUID")))

    resetButtons()
  else
    standby()
  end
end
------------------------------------------------- ResetButtons------------------------------------------------------------
function resetButtons()
    self.clearButtons()
    if selectedUnitObj then

        self.createButton({
            click_function = "nextUnit",
            function_owner = self,
            label = "NEXT",
            position = {0, 0.2, -1.2},
            width = 550,
            height = 350,
            font_size = 150,
            tooltip = "Toggle between " .. selectedUnitObj.getName() .. " Units",
            font_color = {0,0,0},
            color = {1, 0.9946, 0, 1}
        })

        self.createButton({
            click_function = "initMove",
            function_owner = self,
            label = "  MOVE",
            position = {1.7, 0.2, 0.4},
            width = 750,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0.9167, 0.9167, 0.9167, 1},
            tooltip = "Spawn movement templates. Unit leader spawns cohesion rulers when moved"
        })

        self.createButton({
            click_function = "aim",
            function_owner = self,
            label = "A",
            position = {-2, 0.2, -0.4},
            width = 370,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0, 0.8705, 0.0941, 1},
            tooltip = "Take an Aim token",
            alignment = 2
        })

        self.createButton({
            click_function = "attack",
            function_owner = self,
            label = "  ATTACK",
            position = {1.6, 0.2, 1.2},
            width = 850,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {1, 0, 0, 1},
            tooltip = "Draw Attack Die or Spawn Range Rulers"
        })

        self.createButton({
            click_function = "dodge",
            function_owner = self,
            label = "D",
            position = {-1.1, 0.2, -0.4},
            width = 370,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0, 0.8705, 0.0941, 1},
            tooltip = "Take a Dodge token"
        })

        self.createButton({
            click_function = "overwatch",
            function_owner = self,
            label = "ST",
            position = {-2, 0.2, 0.4},
            width = 370,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0.65, 0.65, 0.65, 1},
            tooltip = "Take a Standby token"
        })

        self.createButton({
            click_function = "surge",
            function_owner = self,
            label = "SU",
            position = {-1.1, 0.2, 0.4},
            width = 370,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0, 0.8705, 0.0941, 1},
            tooltip = "Take a Surge token"
        })

        self.createButton({
            click_function = "initDeploy",
            function_owner = self,
            label = "DEPLOY",
            position = {-1.6, 0.2, 1.2},
            width = 850,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0, 0.8705, 0.0941, 1},
            tooltip = "Start a Deploy Move"
        })

        self.createButton({
            click_function = "resetActivation",
            function_owner = self,
            label = "X            ",
            position = {-1.6, 0.2, -1.2},
            width = 850,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {1, 0.9135, 0, 1},
            tooltip = "Cancel",
        })

        self.createButton({
            click_function = "endActivation",
            function_owner = self,
            label = "END",
            position = {0, 0.2, 1.2},
            width = 550,
            height = 350,
            font_size = 150,
            color = {0.7, 0.03, 0.03, 1},
            font_color = {1, 1, 1, 1},
            tooltip = "End your Activation",
        })

        self.createButton({
            click_function = "toggleCohesionRuler",
            function_owner = self,
            label = "COHESION", position = {1.6, 0.2, -1.2}, width = 850, height = 350, font_size = 150, color = {0, 0, 0, 1}, font_color = {0.4709, 0.9759, 0.9162, 1},
            tooltip = "Spawn Cohesion Rulers"
        })

        self.createButton({
            click_function = "targetingMode",
            function_owner = self,
            label = "  RANGE",
            position = {1.7, 0.2, -0.4},
            width = 750,
            height = 350,
            font_size = 150,
            color = {0, 0, 0, 1},
            font_color = {0.4709, 0.9759, 0.9162, 1},
            tooltip = "Spawn Range Rulers"
        })
    end
end

function toggleCohesionRuler()
    -- Iron Squadron overlays (see !/IsqOverlays): route this button to the
    -- Projector renderer when they are on. Off by default, in which case
    -- everything below runs unchanged.
    if isqOverlaysOn() then
        if not selectedUnitObj then return end
        -- Clear before toggling on: the hover hotkey writes to the same key as
        -- this unit, so without the clear the first click here would turn that
        -- overlay off while we set rulerOn = true, leaving the button inverted
        -- from then on.
        isqClearCohesion({figGUID = selectedUnitObj.getGUID()})
        if rulerOn then
            rulerOn = false
        else
            isqToggleCohesion({figGUID = selectedUnitObj.getGUID()})
            rulerOn = true
        end
        return
    end
    if not rulerOn then
        selectedUnitObj.call("spawnCohesionRuler", selectedUnitObj)
        rulerOn = true
    else
        selectedUnitObj.call("clearCohesionRuler")
        rulerOn = false
    end

end

------------------------------------------------- NEXTUNIT ------------------------------------------------------------
function nextUnit()
    local out = false
    local originalUnitNumber = selectedUnitNumber
    while out == false do
        -- ++ selection
        selectedUnitNumber = selectedUnitNumber + 1
        -- loop selection
        if selectedUnitNumber > eligibleUnitsNumber then
            selectedUnitNumber = 1
        end
        -- check if back to originalUnitNumber
        if selectedUnitNumber == originalUnitNumber then
            out = true
            if selectedUnitObj == nil then
                standby()
            end
        else
            -- examine nil status
            if eligibleUnits[selectedUnitNumber] then
                clearTint()
                stopUnit()
                stopAttack()
                selectedUnitObj = eligibleUnits[selectedUnitNumber]

                selectedUnitObj.call("setStartPos")
                highlightUnit(selectedUnitObj.getTable("miniGUIDs"),{0,1,0})
                highlightCard(getObjectFromGUID(selectedUnitObj.getVar("cardGUID")))
                getSelectedUnitObjVariables()
                setTemplateVariables()
                out = true
            end
        end


    end

end

function clearTint()
    unhighlightEnemies()

    if selectedUnitObj then
        unhighlightUnit(selectedUnitObj.getTable("miniGUIDs"))
        unHighlightCard(getObjectFromGUID(selectedUnitObj.getVar("cardGUID")))
    end
end
------------------------------------------------- MOVE UNIT ------------------------------------------------------------
function initMove()
    initPos = selectedUnitObj.getPosition()
    initRot = selectedUnitObj.getRotation()
    selectedUnitObj.call("setStartPos")
    moveUnit(false)
end

function initDeploy()
    initPos = selectedUnitObj.getPosition()
    initRot = selectedUnitObj.getRotation()
    selectedUnitObj.call("setStartPos")   
    moveUnit(true)
end


function moveUnit(isDeploy)
    local startOffset = 0.0
    if isDeploy and isDeploy == true then
        local baseSize = unitData.baseSize
        startOffset = templateInfo.deployMod[baseSize]
    end
    stopAttack()
    resetButtons()
    clearTemplates()
    selectedUnitObj.setVar("moveState", true)
    self.editButton({
        index = 1,
        click_function = "stopUnit",
        label = "  DONE",
        color = {0.7, 0.03, 0.03},
        font_color = {1, 1, 1}
    })
    lockUnitsExcept(selectedUnitObj, "MoveInProgress")

    ------------------------------------------- PLACEMENT MATH -------------------------------------------
    basePos = selectedUnitObj.getPosition()
    basePos.y = basePos.y + 0.05
    baseRot = selectedUnitObj.getRotation()

    if moveDirection == "backward" then
        baseRot.y = baseRot.y + 180

    elseif moveDirection == "left" then
        baseRot.y = baseRot.y - 90
    elseif moveDirection == "right" then
        baseRot.y = baseRot.y + 90
    end

    local q = math.rad(baseRot.y)
    local a = (unitData.aStart + startOffset) * math.cos(q)
    local b = (unitData.aStart + startOffset) * math.sin(q)

    ------------------------------------------- SPAWN TEMPLATES -------------------------------------------

    local modelTemplateA = getObjectFromGUID(templateInfo.modelTemplateAGUID)

    templateA = spawnObject({
        type = "Custom_AssetBundle",
        position = {basePos.x - b, basePos.y, basePos.z - a},
        rotation = {0, baseRot.y + 180, 0},        
        scale = {1,1,1}
    })
    templateA.setCustomObject({
        type = 0,
        assetbundle = templateInfo.moveTemplate[unitData.selectedSpeed].longBundle,
        assetbundle_secondary = templateInfo.moveTemplate[unitData.selectedSpeed].sharedBundle,
        material = 1,
    })

    templateA.mass = 0.0

    local templateLuaScriptA = "unitInfo = {}\nunitInfo.baseSize = '"..unitData.baseSize.."'\nunitInfo.selectedSpeed = "..unitData.selectedSpeed.."\n"..modelTemplateA.getLuaScript()

    templateA.setLuaScript(templateLuaScriptA)
    templateA.sticky = false
    templateA.setName("Movement Template (A)")
    templateA.setColorTint(templateInfo.moveTemplate[unitData.selectedSpeed].colorTint)

    local modelTemplateB = getObjectFromGUID(templateInfo.modelTemplateBGUID)

    templateB = spawnObject({
        type = "Custom_AssetBundle",
        position = {basePos.x - b, basePos.y, basePos.z - a},
        rotation = {0, baseRot.y, 0},
        --make the second bit a tiny bit taller to stop zfighting at the joint
        scale = {1,1.1,1}
    })
    templateB.setCustomObject({
        type = 0,
        assetbundle = templateInfo.moveTemplate[unitData.selectedSpeed].shortBundle,
        assetbundle_secondary = templateInfo.moveTemplate[unitData.selectedSpeed].sharedBundle,
        material = 1
    })

    templateB.mass = 0.0

    local templateLuaScriptB = "unitInfo = {}\nunitInfo.baseSize = '"..unitData.baseSize.."'\nunitInfo.selectedSpeed = "..unitData.selectedSpeed.."\n"..modelTemplateB.getLuaScript()

    templateB.setLuaScript(templateLuaScriptB)
    templateB.sticky = false
    templateB.setName("Movement Template (B)")
    templateB.setColorTint(templateInfo.moveTemplate[unitData.selectedSpeed].colorTint)

    -- SET VALUES

    templateA.setTable("basePos", basePos)
    templateA.setTable("baseRot", baseRot)
    templateA.setVar("templateB", templateB)

    local fixedMove = false
    if isDeploy then
        fixedMove = true
    else
        fixedMove = unitData.baseSize ~= "small"
    end
    templateA.setLock(fixedMove)

    templateB.setTable("basePos", basePos)
    templateB.setTable("baseRot", baseRot)
    templateB.setVar("templateA", templateA)
    templateB.setLock(false)

    templateA.setVar("isDeploy", isDeploy)

    local maxMoveBundles = getMovementLinks()
    local baseSizeMoveBundles = maxMoveBundles[unitData.baseSize]
    local maxMoveTemplateBundleToSpawn = baseSizeMoveBundles[unitData.selectedSpeed]

    -- changeSpeed1/2/3 rappellent moveUnit() sans argument apres avoir detruit
    -- les gabarits, donc isDeploy vaut nil et non false. Avec une egalite
    -- stricte, le cercle de mouvement disparaissait des qu'on changeait de
    -- vitesse et ne revenait jamais.
    if isDeploy ~= true then
        --max movement ring projector
        if maxMoveTemplateBundleToSpawn ~= nil then
            maxMoveTemplate = spawnObject({
                type = "Custom_AssetBundle",
                position = {basePos.x, basePos.y + 20, basePos.z},
                -- Le lacet se prend sur baseRot.y, l'orientation de l'unite.
                -- Il valait basePos.y, c'est-a-dire sa HAUTEUR au-dessus de la
                -- table : le projecteur etait donc toujours pose a ~1 degre dans
                -- le repere du monde, sans jamais suivre le vehicule. Invisible
                -- tant que l'empreinte est un disque, faux des qu'elle ne l'est
                -- plus.
                rotation = {0, baseRot.y, 0},
                scale = {0,0,0} -- 0 scale will hide TTS default box and won't impact projector
            })

            maxMoveTemplate.setCustomObject({
                type = 0,
                assetbundle = maxMoveTemplateBundleToSpawn
            })

            maxMoveTemplate.setLock(true)
            maxMoveTemplate.use_gravity = false
            maxMoveTemplate.setName("Maximum Move")
        end
    end
    ------------------------------------------- SPAWN BUTTON -------------------------------------------


    local data = {click_function = "INSERT_FUNCTION", function_owner = self, label = "1", position = {3, 0.2, -0.4}, width = 300, height = 350, font_size = 200, tooltip = "1"}

    self.createButton({
        click_function = "changeSpeed1",
        function_owner = self,
        label = "1", position = {3, 0.2, -0.4}, width = 300, height = 350, font_size = 200,
        tooltip = "Move Speed 1",
        color = {1, 1, 1},
        font_color = {0, 0, 0}
    })

    self.createButton({
        click_function = "changeSpeed2",
        function_owner = self,
        label = "2", position = {3, 0.2, 0.4}, width = 300, height = 350, font_size = 200, color = {0, 0, 0, 1}, font_color = {1, 1, 1, 1},
        tooltip = "Move Speed 2"
    })
    self.createButton({
        click_function = "changeSpeed3",
        function_owner = self,
        label = "3",
        position = {3, 0.2, 1.2}, width = 300, height = 350, font_size = 200, color = {0.8103, 0.0857, 0.0857, 1}, font_color = {1, 1, 1, 1},
        tooltip = "Move Speed 3"
    })
    if fixedMove then

        if true then -- TODO: Is it worth enforcing this? "unitData.strafeMove" 

              self.createButton({
                  click_function = "moveForward",
                  function_owner = self,
                  label = "F",
                  position = {3, 0.200000002980232, -1.2}, width = 300, height = 350, font_size = 200,
                  tooltip = "Move Forwards",
                  color = {1, 1, 0},
                  font_color = {0, 0, 0}
              })
              self.createButton({
                  click_function = "moveBackwards",
                  function_owner = self,
                  label = "B",
                  position = {3.8, 0.2, -1.2}, width = 300, height = 350, font_size = 200,
                  tooltip = "Move Backwards",
                  color = {1, 1, 0},
                  font_color = {0, 0, 0}
              })
              self.createButton({
                  click_function = "moveLeft",
                  function_owner = self,
                  label = "L",
                  position = {4.6, 0.2, -1.2}, width = 300, height = 350, font_size = 200,
                  tooltip = "Strafe Left",
                  color = {1, 1, 0},
                  font_color = {0, 0, 0}
              })
              self.createButton({
                  click_function = "moveRight",
                  function_owner = self,
                  label = "R",
                  position = {5.4, 0.2, -1.2}, width = 300, height = 350, font_size = 200,
                  tooltip = "Strafe Right",
                  color = {1, 1, 0},
                  font_color = {0, 0, 0}
              })

        else
              self.createButton({
                  click_function = "moveBackwards",
                  function_owner = self,
                  label = "B",
                  position = {3, 0.200000002980232, -1.2}, width = 300, height = 350, font_size = 200,
                  tooltip = "Move Backwards",
                  color = {1, 1, 0},
                  font_color = {0, 0, 0}
              })

              if moveDirection == "backward" then
                  self.editButton({
                      index = 13,
                      click_function = "moveForward",
                      label = "F",
                      tooltip = "Move Forwards"
                  })
              end
        end



    end

    self.createButton({
        click_function = "moveFull",
        function_owner = self,
        label = "FULL",
        position = {4.2, 0.2, 1.2}, width = 700, height = 350, font_size = 200, color = {0, 0, 0, 1}, font_color = {0.0551, 0.9312, 0, 1},
        tooltip = "Execute Full Move"
    })


    self.createButton({
        click_function = "moveStart",
        function_owner = self,
        label = "START",
        position = {4.2, 0.2, 0.4}, width = 700, height = 350, font_size = 200, color = {0, 0, 0, 1}, font_color = {0, 0.9294, 0.8752, 1},
        tooltip = "Move back to start position"
    })

end
------------------------------------------------- MOVE BACK------------------------------------------------------------

function moveFull()
    if templateB then
        local startPos = templateB.getPosition()
        local startRot = templateB.getRotation()
        local endOffset = unitData.baseSize == "small" and templateInfo.deployMod.small or 0.0
        local endPos = translatePos(startPos, startRot, unitData.aStart + endOffset, 0)
        endPos.y = endPos.y + 2

        local endRot = startRot
        if moveDirection == "backward" then
            endRot.y = endRot.y + 180
        elseif moveDirection == "left" then
            endRot.y = endRot.y + 90
        elseif moveDirection == "right" then
            endRot.y = endRot.y - 90
        end

        selectedUnitObj.setPositionSmooth(endPos, false, false)
        selectedUnitObj.setRotationSmooth(startRot, false, false)
        Wait.frames(function()
          selectedUnitObj.call("checkVelocity")
        end)
    end
end


function moveStart()
    local endPos = initPos
    endPos.y = initPos.y + 2
    selectedUnitObj.setPositionSmooth(endPos, false, false)
    selectedUnitObj.setRotationSmooth(initRot, false, false)
    Wait.frames(function()
        selectedUnitObj.call("checkVelocity")
    end)
end

function moveBackwards()
    self.editButton({
        index = 11,
        click_function = "moveForward",
        label = "F",
        tooltip = "Move Forwards"
    })
    moveDirection = "backward"
    moveUnit()
end

function moveForward()
    self.editButton({
        index = 11,
        click_function = "moveBackwards",
        label = "B",
        tooltip = "Move Backwards"
    })
    moveDirection = "forward"
    moveUnit()
end

function moveLeft()
    moveDirection = "left"
    moveUnit()
end

function moveRight()
    moveDirection = "right"
    moveUnit()
end

------------------------------------------------- stop UNIT ------------------------------------------------------------
function stopUnit()
    -- destroy templates
    selectedUnitObj.call("printMovement")
    selectedUnitObj.call("setStartPos")
    self.clearButtons()
    clearTemplates()
    resetButtons()
    unhighlightEnemies()
    unlockAllUnits("MoveInProgress")
end

------------------------------------------------- Clear templates------------------------------------------------------------
function clearTemplates()
    clearMovementTemplates()
    -- Iron Squadron overlays (see !/IsqOverlays): clearRangeRulers only wipes
    -- the vanilla ruler, so ours has to be cleared alongside it. No-op when the
    -- overlays are off, which is the default.
    isqOrderClearRange()
    clearRangeRulers()
    clearCohesionRulers()
end

function clearMovementTemplates()
    if templateA ~= nil then
        destroyObject(templateA)
    end
    if templateB ~= nil then
        destroyObject(templateB)
    end
    if maxMoveTemplate ~= nil then
        -- pcall : l'objet peut avoir deja disparu (Clear Map, standbyTokens),
        -- auquel cas destroyObject leve et le reste du nettoyage sautait.
        pcall(destroyObject, maxMoveTemplate)
        maxMoveTemplate = nil
    end
end

function clearCohesionRulers()
    if selectedUnitObj then
        selectedUnitObj.setVar("moveState", false)
        selectedUnitObj.call("clearCohesionRuler")
    end
end

function clearAttackLine()
    -- Any verdict still computing is now stale: the coroutine checks the
    -- generation at every resume point and bows out.
    losGeneration = (losGeneration or 0) + 1
    Global.setVectorLines({})
    if losSilhouetteGUIDs then
        for _, guid in pairs(losSilhouetteGUIDs) do
            local leader = getObjectFromGUID(guid)
            -- Only lower a silhouette that is still up: the player may have
            -- toggled it off themselves mid-attack.
            if leader ~= nil and leader.getVar("silhouetteState") then
                leader.call("clearSilhouette")
            end
        end
        losSilhouetteGUIDs = nil
    end
end


------------------------------------------------- CHANGESPEED------------------------------------------------------------
function changeSpeed1()
    unitData.selectedSpeed = 1
    setTemplateVariables()
    clearTemplates()
    moveUnit()
end

function changeSpeed2()
    unitData.selectedSpeed = 2
    setTemplateVariables()
    clearTemplates()
    moveUnit()
end

function changeSpeed3()
    unitData.selectedSpeed = 3
    setTemplateVariables()
    clearTemplates()
    moveUnit()
end
------------------------------------------------- AIM------------------------------------------------------------
function aim()
    basePos = selectedUnitObj.getPosition()
    baseRot = selectedUnitObj.getRotation()

    local q = math.rad(baseRot.y)
    local a = 1 * math.cos(q)
    local b = 1 * math.sin(q)

    local tokenPosition = {basePos.x + b, basePos.y + 1, basePos.z + a}
    local tokenRotation = {0, baseRot.y, 0}

    aimBag = getObjectFromGUID(Global.getVar("aimBagGUID"))
    aimBag.takeObject({
        position = tokenPosition,
        rotation = tokenRotation
    })

end

------------------------------------------------- dodge------------------------------------------------------------
function dodge()
    basePos = selectedUnitObj.getPosition()
    baseRot = selectedUnitObj.getRotation()

    local q = math.rad(baseRot.y + 50)
    local a = 1 * math.cos(q)
    local b = 1 * math.sin(q)

    local tokenPosition = {basePos.x + b, basePos.y + 1, basePos.z + a}
    local tokenRotation = {0, baseRot.y - 30, 0}

    aimBag = getObjectFromGUID(Global.getVar("dodgeBagGUID"))
    aimBag.takeObject({
        position = tokenPosition,
        rotation = tokenRotation
    })

end

------------------------------------------------- overwatch------------------------------------------------------------
function overwatch()
    basePos = selectedUnitObj.getPosition()
    baseRot = selectedUnitObj.getRotation()

    local q = math.rad(baseRot.y - 50)
    local a = 1 * math.cos(q)
    local b = 1 * math.sin(q)

    local tokenPosition = {basePos.x + b, basePos.y + 1, basePos.z + a}
    local tokenRotation = {0, baseRot.y, 0}

    aimBag = getObjectFromGUID(Global.getVar("standbyBagGUID"))
    aimBag.takeObject({
        position = tokenPosition,
        rotation = tokenRotation
    })

end

------------------------------------------------- surge------------------------------------------------------------
function surge()
    basePos = selectedUnitObj.getPosition()
    baseRot = selectedUnitObj.getRotation()

    local q = math.rad(baseRot.y - 50)
    local a = 1 * math.cos(q)
    local b = 1 * math.sin(q)

    local tokenPosition = {basePos.x + b, basePos.y + 1, basePos.z + a}
    local tokenRotation = {0, baseRot.y, 0}

    aimBag = getObjectFromGUID(Global.getVar("surgeBagGUID"))
    aimBag.takeObject({
        position = tokenPosition,
        rotation = tokenRotation
    })

end


------------------------------------------------- attack------------------------------------------------------------
function attack()
    clearTemplates()
    resetButtons()
    self.editButton({
        index = 3,
        click_function = "stopAttack",
        function_owner = self,
        label = "     DONE",
        color = {0.7, 0.03, 0.03},
        font_color = {1, 2, 1}
    })
    attackMode()
end

-- Iron Squadron overlays (see !/IsqOverlays): draw and clear this token's range
-- with the Projector renderer when they are on. Both are no-ops when they are
-- off, which is the default, so the vanilla calls around them are untouched.
--
-- These two only ever call into the module. The vanilla spawnRangeRuler and
-- clearRangeRulers are deliberately NOT overridden on this object: doing so
-- crashed Tabletop Simulator on macOS whenever a figure hotkey spawned a range
-- bundle, so only their callers are adapted.
function isqOrderSpawnRange()
    if not selectedUnitObj then return end
    if not isqOverlaysOn() then return end
    -- Clear before triggering: the module toggles by GUID and the hover hotkey
    -- writes to this same unit, so without the clear a click meant to draw
    -- could erase instead.
    isqClearRange({figGUID = selectedUnitObj.getGUID()})
    isqRangeTrigger({figGUID = selectedUnitObj.getGUID()})
end

function isqOrderClearRange()
    if not selectedUnitObj then return end
    if not isqOverlaysOn() then return end
    isqClearRange({figGUID = selectedUnitObj.getGUID()})
end

function targetingMode()
    if not enemyHighlighted then
        exitAttackMode()
        highlightEnemies()
        if isqOverlaysOn() then
            isqOrderSpawnRange()
        else
            spawnRangeRuler(selectedUnitObj)
        end
        enemyHighlighted = true
        resetRangeButtons()
    else
        exitTargetingMode()
    end
end

function attackMode()
    if not attackModeOn then
        exitTargetingMode()
        highlightEnemies()
        if isqOverlaysOn() then
            isqOrderSpawnRange()
        else
            spawnRangeRuler(selectedUnitObj)
        end
        attackModeOn = true
        resetTargetingButtons()
    else
        exitTargetingMode()
    end
end

function exitTargetingMode()
    enemyHighlighted = false
    attackModeOn = false
    isqOrderClearRange()
    clearRangeRulers()
    unhighlightEnemies()
    clearAttackLine()
end

function exitAttackMode()
    enemyHighlighted = false
    attackModeOn = false
    isqOrderClearRange()
    clearRangeRulers()
    unhighlightEnemies()
end

function resetRangeButtons()
    enemyLeaders = getEnemyUnits()

    for _, leader in pairs(enemyLeaders) do
        createRangeButton(leader)
    end
end

function resetTargetingButtons()
    enemyLeaders = getEnemyUnits()

    for _, leader in pairs(enemyLeaders) do
        createAttackButton(leader)
        createRangeButton(leader)
    end
end

function attackMenu(attackTargetObj)
    unhighlightEnemies()
    highlightEnemy(attackTargetObj)
    clearRangeRulers()
    -- Switching targets goes through here again: drop the previous target's
    -- beams and silhouettes before drawing the new ones.
    clearAttackLine()

    -- this used to be configurable per unit type, which meant that we made the
    -- ion/wound/suppression buttons vertically higher to make up for variable
    -- height minis.
    --
    -- it's possible we can use the actual collider height of the mini in the
    -- future in order to tune this.
    local buttonHeight = attackTargetObj.getVar("height") or 2


    _G["addIon"..self.getGUID()] = function() addIon(attackTargetObj) end
    _G["addWound"..self.getGUID()] = function() addWound(attackTargetObj) end
    _G["addSuppression"..self.getGUID()] = function() addSuppression(attackTargetObj) end

    attackTargetObj.createButton({
        click_function = "addIon"..self.getGUID(), function_owner = self, label = "I", position = {-0.9, buttonHeight, 0}, rotation = {0, 180, 0}, scale = {0.5, 0.5, 0.5}, width = 700, height = 700, font_size = 500, color = {0, 0.1711, 1, 1}, tooltip = "I"
    })
    attackTargetObj.createButton({
        click_function = "addWound"..self.getGUID(), function_owner = self, label = "W", position = {0.9, buttonHeight, 0}, rotation = {0, 180, 0}, scale = {0.5, 0.5, 0.5}, width = 700, height = 700, font_size = 500, color = {1, 0, 0, 1}, tooltip = "W"
    })
    attackTargetObj.createButton({
        click_function = "addSuppression"..self.getGUID(), function_owner = self, label = "S", position = {0, buttonHeight, 0}, rotation = {0, 180, 0}, scale = {0.5, 0.5, 0.5}, width = 700, height = 700, font_size = 500, color = {1, 0.8723, 0, 1}, tooltip = "S"
    })

    -- For every defending mini, draw the two witness lines (one clear of
    -- terrain, one crossing it) in the background; the players judge line of
    -- sight and cover themselves. Silhouettes rise when the rays are done.
    computeLosVerdicts(attackTargetObj)
end

function addSuppression(selectedSuppressionObj)
    local suppressionPos = selectedSuppressionObj.getPosition()
    suppressionPos.y = suppressionPos.y + 1
    suppressionBag = getObjectFromGUID(Global.getVar("suppressionBagGUID"))
    suppressionBag.takeObject({
        position = suppressionPos,
        rotation = selectedSuppressionObj.getRotation()
    })
end

function addWound(selectedWoundObj)
    local woundPos = selectedWoundObj.getPosition()
    woundPos.y = woundPos.y + 1
    woundBag = getObjectFromGUID(Global.getVar("woundBagGUID"))

    woundPos = translatePos(woundPos,selectedWoundObj.getRotation(),1, 0)

    woundBag.takeObject({
        position = woundPos,
        rotation = selectedWoundObj.getRotation()
    })
end

function addIon(selectedIonObj)
    local ionPos = selectedIonObj.getPosition()
    ionPos.y = ionPos.y + 1
    ionBag = getObjectFromGUID(Global.getVar("ionBagGUID"))

    ionPos = translatePos(ionPos,selectedIonObj.getRotation(),1, 180)

    ionBag.takeObject({
        position = ionPos,
        rotation = selectedIonObj.getRotation()
    })
end

-- The silhouette a mini is judged by: a cylinder standing on its base, as wide
-- as the base and as tall as its unit's silhouette. Base size and custom
-- silhouettes live on the unit leader, not on each mini, so that is who gets
-- asked. Same rules Unit_Leader uses to spawn the visible ones, so the beams
-- line up with what SIL draws.
function silhouetteOf(leaderObj)
    local leaderData = leaderObj.getTable("unitData")
    local baseSize = (leaderData and leaderData.baseSize) or "small"
    local radius = (templateInfo.baseRadius[baseSize] or templateInfo.baseRadius.small) / 2
    local height = templateInfo.silhouetteHeight.small
    local offset = 0

    if leaderObj.getVar("silhType") == "custom" then
        height = leaderObj.getVar("silhHeight") or templateInfo.silhouetteHeight.custom
        offset = leaderObj.getVar("silhOffset") or 0
    elseif baseSize ~= "small" then
        height = templateInfo.silhouetteHeight.notched
    end

    return radius, height, offset
end

------------------------------------------------- LIGNE DE VUE ------------------------------------------------------------
-- The tool shows evidence, the players make the ruling. For each defending
-- mini it draws up to two lines from the attacking leader's silhouette to
-- that mini's silhouette: a green one that crosses no terrain, and a red one
-- that does. Line of sight and cover are then judged by eye, at the table,
-- exactly like the rule intends -- nothing is decided by the mod.

-- Rays per frame: the search spreads over frames instead of freezing. Pure
-- arithmetic since the engine moved off Physics.cast, so the budget is wide.
local LOS_CASTS_PER_FRAME = 200
-- Printed with every attack so a play test can never run an older build
-- unnoticed (the save-patching workflow makes that mistake silent). Bump it
-- with every LoS change.
local LOS_BUILD = "v16"

losGeneration = 0
losCtx = nil

-- Fifteen sampling points of a silhouette, facing the other figure: three
-- heights on five verticals spread over the facing half of the contour (the
-- facing line, both 45-degree diagonals, both tangents). A line may leave
-- from any point of the silhouette, so the whole visible edge gets a say --
-- the corners and side edges, not just the apparent center. The facing
-- column comes first so open terrain resolves in the very first rays.
function losSamplePoints(obj, leaderObj, towardPos)
    local radius, height, offset = silhouetteOf(leaderObj)
    local p = obj.getPosition()
    local baseY = p.y + offset
    local dx, dz = towardPos.x - p.x, towardPos.z - p.z
    local g = math.sqrt(dx * dx + dz * dz)
    if g < 0.001 then dx, dz, g = 1, 0, 1 end
    dx, dz = dx / g, dz / g
    local c = math.sqrt(0.5)
    local r = radius * 0.95
    local points = {}
    local dirs = {
        {dx, dz},
        {(dx - dz) * c, (dz + dx) * c}, {(dx + dz) * c, (dz - dx) * c},
        {-dz, dx}, {dz, -dx},
    }
    for _, d in ipairs(dirs) do
        for _, y in ipairs({baseY + height / 2, baseY + height - 0.05, baseY + 0.1}) do
            table.insert(points, {x = p.x + d[1] * r, y = y, z = p.z + d[2] * r})
        end
    end
    return points
end

-- Does a segment cross the silhouette cylinder of a third-party ground
-- vehicle? Pure arithmetic, no physics call: a quadratic in the ground
-- plane, then a height window over the crossed interval.
function losSegmentHitsCylinder(p, q, cyl)
    local dx, dz = q.x - p.x, q.z - p.z
    local fx, fz = p.x - cyl.x, p.z - cyl.z
    local a = dx * dx + dz * dz
    local t0, t1
    if a < 0.000001 then
        if fx * fx + fz * fz > cyl.r * cyl.r then return false end
        t0, t1 = 0, 1
    else
        local b = 2 * (fx * dx + fz * dz)
        local c = fx * fx + fz * fz - cyl.r * cyl.r
        local disc = b * b - 4 * a * c
        if disc <= 0 then return false end
        local s = math.sqrt(disc)
        t0 = math.max((-b - s) / (2 * a), 0)
        t1 = math.min((-b + s) / (2 * a), 1)
        if t0 > t1 then return false end
    end
    local ya = p.y + (q.y - p.y) * t0
    local yb = p.y + (q.y - p.y) * t1
    return math.max(ya, yb) >= cyl.y0 and math.min(ya, yb) <= cyl.y1
end

-- What counts as terrain for a ray: not a mini (minis only block through the
-- ground-vehicle cylinders), not a game aid, not something tiny. The rest of
-- the scenery does.
function losIsTerrain(ctx, o)
    if ctx.miniGuids[o.getGUID()] then return false end
    if o.getVar("isAMini") == true then return false end
    -- Asset bundles are game aids here, never terrain: silhouettes, smoke,
    -- rulers, effects. The map's terrain pieces are all Custom_Model. A
    -- raised silhouette especially must not block the very rays it frames.
    -- (.name is the internal type name; .type can report plain "Generic".)
    if o.name == "Custom_Assetbundle" then return false end
    local t = o.type
    if t == "Card" or t == "Deck" or t == "Die" or t == "Bag" or t == "Infinite" then
        return false
    end
    local name = string.lower(o.getName() or "")
    -- The table and the battlefield board are not terrain: everything rests
    -- on them, so they always touch the attacker and only add noise.
    if name == "table" or name == "battlefield" then
        return false
    end
    -- The map annotates its pieces: anything tagged [No Cover] (landing
    -- platforms, decorative floors) never blocks sight -- that is also what
    -- lets a unit standing on such a piece shoot off it freely.
    if string.find(name, "no cover") then
        return false
    end
    if string.find(name, "token") or string.find(name, "ruler")
        or string.find(name, "template") or string.find(name, "dice")
        or string.find(name, "silhouette") or string.find(name, "objective") then
        return false
    end
    local b = o.getBounds()
    if b and b.size.x < 1.2 and b.size.z < 1.2 and b.size.y < 0.8 then
        return false
    end
    return true
end

-- The oriented visual box of a terrain piece: its renderer bounds at zero
-- rotation (so, the VISUAL mesh, never the collider -- terrain colliders in
-- this mod can be flat resting plates a few hundredths tall) plus enough of
-- the piece's rotation to test rays in its local frame.
function losMakeObb(obj)
    -- getVisualBoundsNormalized, NOT getBoundsNormalized: the plain one
    -- measures the COLLIDER (a barricade's came back 0.06 tall, its resting
    -- plate), the visual one measures the renderers the players see.
    local b = obj.getVisualBoundsNormalized()
    local p = obj.getPosition()
    local r = obj.getRotation()
    return {
        pos = p,
        rx = math.rad(r.x), ry = math.rad(r.y), rz = math.rad(r.z),
        center = {x = b.center.x - p.x, y = b.center.y - p.y, z = b.center.z - p.z},
        half = {x = b.size.x / 2, y = b.size.y / 2, z = b.size.z / 2},
    }
end

-- World point -> the box's local frame. Unity composes rotations as
-- yaw(Y) * pitch(X) * roll(Z), so the inverse unwinds yaw, pitch, roll.
function losToObbFrame(obb, pt)
    local x, y, z = pt.x - obb.pos.x, pt.y - obb.pos.y, pt.z - obb.pos.z
    local c, s = math.cos(obb.ry), math.sin(obb.ry)
    x, z = x * c - z * s, x * s + z * c
    c, s = math.cos(obb.rx), math.sin(obb.rx)
    y, z = y * c + z * s, -y * s + z * c
    c, s = math.cos(obb.rz), math.sin(obb.rz)
    x, y = x * c + y * s, -x * s + y * c
    return {x = x, y = y, z = z}
end

-- Segment against the oriented visual box: slab test in the box's local
-- frame. Purely geometric -- what the players see is what blocks, and
-- shooting over your own barricade works because the high silhouette
-- points genuinely clear its top, not through any forgiveness rule.
function losSegmentHitsObb(p, q, obb)
    local lp = losToObbFrame(obb, p)
    local lq = losToObbFrame(obb, q)
    local t0, t1 = 0, 1
    for _, axis in ipairs({"x", "y", "z"}) do
        local d = lq[axis] - lp[axis]
        local lo = obb.center[axis] - obb.half[axis]
        local hi = obb.center[axis] + obb.half[axis]
        if math.abs(d) < 0.000001 then
            if lp[axis] < lo or lp[axis] > hi then return false end
        else
            local ta = (lo - lp[axis]) / d
            local tb = (hi - lp[axis]) / d
            if ta > tb then ta, tb = tb, ta end
            t0 = math.max(t0, ta)
            t1 = math.min(t1, tb)
            if t0 > t1 then return false end
        end
    end
    return true
end

-- Is this silhouette-to-silhouette line clear? Blocked by the oriented
-- VISUAL box of any terrain piece, or by a third-party ground vehicle
-- silhouette (cylinders). Pure arithmetic, no physics: the mod's terrain
-- colliders do not match what the players see.
function losCastLine(ctx, p, q)
    for _, cyl in ipairs(ctx.blockers) do
        if losSegmentHitsCylinder(p, q, cyl) then return false end
    end
    for _, obb in ipairs(ctx.obbs) do
        if losSegmentHitsObb(p, q, obb) then return false end
    end
    return true
end

-- A snapshot of the table for one verdict: every mini to ignore in the rays,
-- the silhouette cylinders of third-party ground vehicles (the only minis
-- that block sight), and the defending minis still on the battlefield.
function buildLosContext(attackTargetObj)
    local ctx = {
        gen = losGeneration,
        attackTargetObj = attackTargetObj,
        leaderPos = selectedUnitObj.getPosition(),
        miniGuids = {},
        blockers = {},
        obbs = {},
        defenders = {},
    }
    local zoneObjects = battlefieldZone.getObjects()
    local attackerGUID = selectedUnitObj.getGUID()
    local targetGUID = attackTargetObj.getGUID()
    for _, obj in pairs(zoneObjects) do
        if obj.getVar("isAMini") == true then
            ctx.miniGuids[obj.getGUID()] = true
            local thirdParty = obj.getGUID() ~= attackerGUID and obj.getGUID() ~= targetGUID
            local unitType = obj.getVar("unitType") or ""
            local blocks = thirdParty and string.find(unitType, "Ground Vehicle") ~= nil
            local radius, height, offset = silhouetteOf(obj)
            for _, guid in pairs(obj.getTable("miniGUIDs") or {}) do
                ctx.miniGuids[guid] = true
                if blocks then
                    local m = getObjectFromGUID(guid)
                    if m ~= nil and isMiniOnTable(m, zoneObjects) then
                        local mp = m.getPosition()
                        table.insert(ctx.blockers, {
                            x = mp.x, z = mp.z,
                            y0 = mp.y + offset, y1 = mp.y + offset + height,
                            r = radius,
                        })
                    end
                end
            end
        end
    end
    -- Terrain blocks through its VISUAL oriented box, never its collider:
    -- the mod's terrain colliders can be flat resting plates a few
    -- hundredths tall (a barricade's is), so Physics.cast is blind to what
    -- the players actually see. Swept from the full object list, NOT from
    -- the zone: the zone's trigger misses locked scenery that never moved,
    -- and an empty terrain list blocks nothing at all. A piece counts when
    -- it stands within the battlefield zone's footprint.
    local zonePos = battlefieldZone.getPosition()
    local zoneScale = battlefieldZone.getScale()
    for _, obj in pairs(getAllObjects()) do
        if losIsTerrain(ctx, obj) then
            local p = obj.getPosition()
            if math.abs(p.x - zonePos.x) <= zoneScale.x / 2 + 1
                and math.abs(p.z - zonePos.z) <= zoneScale.z / 2 + 1 then
                local obb = losMakeObb(obj)
                table.insert(ctx.obbs, obb)
                -- Diagnostic (temporaire) : la première barricade imprime sa
                -- boîte et se tire un rayon vertical dessus. RATE = la boîte
                -- est construite au mauvais endroit, sans rien supposer.
                if ctx.dbgObb == nil
                    and string.find(string.lower(obj.getName() or ""), "barricade") then
                    ctx.dbgObb = true
                    local b = obj.getVisualBoundsNormalized()
                    print(string.format(
                        "[ISQ LDV] obb %s pos(%.1f,%.1f,%.1f) rotY %.0f brut centre(%.2f,%.2f,%.2f) taille(%.2f,%.2f,%.2f) local(%.2f,%.2f,%.2f)",
                        obj.getName(), obb.pos.x, obb.pos.y, obb.pos.z,
                        math.deg(obb.ry), b.center.x, b.center.y, b.center.z,
                        b.size.x, b.size.y, b.size.z,
                        obb.center.x, obb.center.y, obb.center.z))
                    local hit = losSegmentHitsObb(
                        {x = obb.pos.x, y = obb.pos.y + 10, z = obb.pos.z},
                        {x = obb.pos.x, y = obb.pos.y - 1, z = obb.pos.z}, obb)
                    print("[ISQ LDV] autotest rayon vertical sur elle : "
                        .. (hit and "TOUCHE" or "RATE"))
                end
            end
        end
    end
    for _, guid in pairs(attackTargetObj.getTable("miniGUIDs") or {}) do
        local m = getObjectFromGUID(guid)
        if m ~= nil and isMiniOnTable(m, zoneObjects) then
            table.insert(ctx.defenders, m)
        end
    end
    print("[ISQ LDV] " .. LOS_BUILD .. " — contexte : " .. #ctx.blockers
        .. " véhicule(s)-cylindre, " .. #ctx.obbs .. " boîte(s) de décor, "
        .. #ctx.defenders .. " défenseur(s)")
    return ctx
end

function computeLosVerdicts(attackTargetObj)
    losGeneration = losGeneration + 1
    losCtx = buildLosContext(attackTargetObj)
    startLuaCoroutine(self, "losVerdictCoroutine")
end

-- For each defending mini, find the two witness lines: the first clear one
-- and the first blocked one, then stop. Open terrain finds its clear line on
-- the very first facing rays; a hidden mini finds its blocked line just as
-- fast. Only the search for a line that does not exist reads every pair.
function losVerdictCoroutine()
    local ctx = losCtx
    local casts = 0
    local witnesses = {}
    for _, def in ipairs(ctx.defenders) do
        local defPos = def.getPosition()
        local apts = losSamplePoints(selectedUnitObj, selectedUnitObj, defPos)
        local dpts = losSamplePoints(def, ctx.attackTargetObj, ctx.leaderPos)
        local clearLine, blockedLine = nil, nil
        for _, ap in ipairs(apts) do
            for _, dp in ipairs(dpts) do
                if losCastLine(ctx, ap, dp) then
                    if clearLine == nil then clearLine = {ap, dp} end
                else
                    if blockedLine == nil then blockedLine = {ap, dp} end
                end
                casts = casts + 1
                if casts >= LOS_CASTS_PER_FRAME then
                    casts = 0
                    coroutine.yield(0)
                    if ctx.gen ~= losGeneration then return 1 end
                end
                if clearLine ~= nil and blockedLine ~= nil then break end
            end
            if clearLine ~= nil and blockedLine ~= nil then break end
        end
        table.insert(witnesses, {clear = clearLine, blocked = blockedLine})
        print("[ISQ LDV] " .. (def.getName() or "figurine") .. " : "
            .. (clearLine and "verte trouvée" or "PAS de verte") .. ", "
            .. (blockedLine and "rouge trouvée" or "PAS de rouge"))
    end
    if ctx.gen ~= losGeneration then return 1 end
    drawLosWitnesses(ctx, witnesses)
    return 1
end

-- Green: a line crossing no terrain. Red: a line crossing some. A mini with
-- only a green line is plainly seen, one with only a red line is plainly
-- hidden, and one with both is where the players lean in and judge cover --
-- the mod hands them the two lines the discussion needs, nothing more.
function drawLosWitnesses(ctx, witnesses)
    local lines = {}
    for _, w in ipairs(witnesses) do
        if w.clear ~= nil then
            table.insert(lines, {
                points = {w.clear[1], w.clear[2]},
                color = {0.2, 0.9, 0.2},
                thickness = 0.06,
            })
        end
        if w.blocked ~= nil then
            table.insert(lines, {
                points = {w.blocked[1], w.blocked[2]},
                color = {0.9, 0.15, 0.15},
                thickness = 0.06,
            })
        end
    end
    Global.setVectorLines(lines)

    -- Silhouettes only rise HERE, once the rays are done, and only on units
    -- that did not have them up already -- those belong to the player.
    losSilhouetteGUIDs = {}
    for _, leader in ipairs({selectedUnitObj, ctx.attackTargetObj}) do
        if leader ~= nil and not leader.getVar("silhouetteState") then
            print("[ISQ LDV] showSilhouette → " .. leader.getGUID() .. " …")
            leader.call("showSilhouette")
            print("[ISQ LDV] showSilhouette ← " .. leader.getGUID() .. " ok")
            table.insert(losSilhouetteGUIDs, leader.getGUID())
        end
    end
end

function getAngle(originObj, angleTargetObj)
    --local localVector = originObj.positionToLocal(angleTargetObj.getPosition())
    local aTargetPos = angleTargetObj.getPosition()
    local originPos = originObj.getPosition()

    local localVector = {
          x = aTargetPos.x - originPos.x,
          y = aTargetPos.y - originPos.y,
          z = aTargetPos.z - originPos.z}


    local q = math.deg(math.atan2(localVector.x, localVector.z))

    local c = math.sqrt((localVector.x * localVector.x) + (localVector.z * localVector.z))

    local q2 = math.deg(math.atan2(localVector.y, c))

    -- set rotation and rotation
    return {x=q2,y=q,z=0}
end

function createAttackButton(leaderObj)
    local buttonHeight = leaderObj.getVar("height") or 2

    _G["attackMenu"..leaderObj.getGUID()] = function() attackMenu(leaderObj) end

    local data = {click_function = "attackMenu"..leaderObj.getGUID(), function_owner = self, label = "ATTACK", position = {0, buttonHeight, -0.9}, rotation = {0, 180, 0}, scale = {0.5, 0.5, 0.5}, width = 1800, height = 700, font_size = 400, color = {1, 0, 0, 1}, font_color = {0, 0, 0, 1}}

    leaderObj.createButton(data)
end

function isMiniOnTable(mini, allUnits)
    for _, check in pairs(allUnits) do
      if check == mini then
        return true
      end
    end
    return false
  end

function createRangeButton(leaderObj)
    local selectedUnitObjUnitName = selectedUnitObj.getVar("unitName")
    local allUnitsOnTable = battlefieldZone.getObjects()
    local enemyBaseSize = leaderObj.getVar("baseSize")
    local enemyMinis = leaderObj.getTable("miniGUIDs")
    local lowestDistance = 99
    for k, guidEntry in pairs(enemyMinis) do
        local obj = getObjectFromGUID(guidEntry)

        if obj and isMiniOnTable(obj, allUnitsOnTable) then
            distance = getDistance(selectedUnitObj, obj)
            if distance < lowestDistance then
                lowestDistance = distance
            end
        end
    end

    -- getDistance mesure de centre a centre, alors qu'en jeu une portee se
    -- mesure de bord de socle a bord de socle. Il faut donc retrancher le rayon
    -- de l'unite qui mesure PUIS celui de la cible. C'est celui de la cible qui
    -- etait retranche deux fois : la bande affichee etait fausse des que les
    -- deux socles differaient, de rayon(cible) - rayon(mesureur), soit jusqu'a
    -- 2,4 pouces entre un trooper et un AAT, sur des bandes de 6.
    -- (templateInfo.baseRadius contient des diametres, d'ou les moities.)
    local ownBaseSize = selectedUnitObj.getVar("baseSize") or unitData.baseSize
    lowestDistance = lowestDistance
        - templateInfo.baseRadius[ownBaseSize]/2
        - templateInfo.baseRadius[enemyBaseSize]/2

    finalRange = math.ceil(lowestDistance/6)
    if finalRange > 4 then
        finalRange = ">4"
    end

    local buttonHeight = leaderObj.getVar("height") or 2
    local data = {click_function = "dud", function_owner = self, label = finalRange, position = {0, buttonHeight, 0}, rotation = {0, 180, 0}, scale = {0.5, 0.5, 0.5}, width = 900, height = 700, font_size = 500, color = {1, 1, 0, 1}, font_color = {0, 0, 0, 1}}

    leaderObj.createButton(data)
end

function dud()
end

function highlightEnemies()
  for _, leader in ipairs(getEnemyUnits()) do
    highlightEnemy(leader)
  end
end

function highlightEnemy(leader)
  local enemyID = leader.getVar("unitID")
  local enemyMinis = leader.getTable("miniGUIDs")
  highlightUnit(enemyMinis, highlightTints[enemyID])
end

function unhighlightEnemies()
  for _, leader in ipairs(getEnemyUnits()) do
    local enemyID = leader.getVar("unitID")
    local enemyMinis = leader.getTable("miniGUIDs")
    unhighlightUnit(enemyMinis)
    leader.call("resetUnitButtons")
  end
end

function getEnemyUnits()
  local miniObjs = {}
  local allUnits = battlefieldZone.getObjects()

  for _, obj in pairs(allUnits) do
    if obj.getVar("isAMini") == true and obj.getVar("colorSide") ~= unitData.colorSide then
      table.insert(miniObjs, obj)
    end
  end

  return miniObjs
end


function stopAttack()
    exitTargetingMode()
    stopUnit()
end


------------------------------------------------- end UNIT ------------------------------------------------------------

function endActivation()
    resetActivation()
    self.flip()
end

function resetActivation()
    stopUnit()
    stopAttack()
    standby()
end

function getDistance(originObj, targetObj)
  local originPos = originObj.getPosition()
  local targetPos = targetObj.getPosition()

  -- set the y-value for each position to 0 to ignore height differences
  originPos:set(nil, 0, nil)
  targetPos:set(nil, 0, nil)
  
  return Vector.distance(originPos, targetPos)
end


function allUnitLeaders()
   local unitLeaders = nil
   unitLeaders = {}
   local leaderCount = 1
   local allUnits = nil
   local allUnits = battlefieldZone.getObjects()

   if allUnits ~= nil then
      for i, unit in pairs(allUnits) do
         local miniData = unit.getTable("unitData")
         local isAMini = unit.getVar("isAMini")
         if miniData and miniData.commandType then
            if isAMini == true then
               unitLeaders[leaderCount] = unit
               leaderCount = leaderCount + 1
            end
         end
      end
   end
   return unitLeaders
end

function lockUnitsExcept(exceptionUnit, lockName)
   local unitLeaders = allUnitLeaders()

   if unitLeaders ~= nil then
      for i, unit in pairs(unitLeaders) do
         if unit ~= exceptionUnit then
            unit.call("tryAddLock", lockName)
         end
      end
   end
end

function unlockAllUnits(lockName)
   local unitLeaders = allUnitLeaders()

   if unitLeaders ~= nil then
      for i, unit in pairs(unitLeaders) do
         unit.call("tryRemoveLock", lockName)
      end
   end
end

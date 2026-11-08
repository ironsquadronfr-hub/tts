require('!/Brain')

function onload(save_state)
    self.interactable = false

    -- defaults
    battlefieldZone = getObjectFromGUID(Brain().getVar("battlefieldZoneGUID"))
    aimBag = getObjectFromGUID(Brain().getVar("aimBagGUID"))
    dodgeBag = getObjectFromGUID(Brain().getVar("dodgeBagGUID"))
    standbyBag = getObjectFromGUID(Brain().getVar("standbyBagGUID"))
    surgeBag = getObjectFromGUID(Brain().getVar("surgeBagGUID"))
    smokeBag = getObjectFromGUID(Brain().getVar("smokeBagGUID"))
    ionBag = getObjectFromGUID(Brain().getVar("ionBagGUID"))
    suppressionBag = getObjectFromGUID(Brain().getVar("suppressionBagGUID"))
    observationBag = getObjectFromGUID(Brain().getVar("observationBagGUID"))
    commandTokenTrayData = Brain().getTable("commandTokenTrayData")

    assetButton = getObjectFromGUID("9a68d8")



    assetButton.createButton({
            click_function = "returnTokens", function_owner = self, label = "", position = {0, 0.65, 0}, scale = {1, 1, 0.7}, width = 1500, height = 2000, font_size = 400, color = {0.7573, 0.7573, 0.7573, 0.01}, font_color = {0, 0, 0, 100}, tooltip = "Return all Aim, Dodge, Standby and Command Tokens to the respective Players"
    })
    assetButton.setColorTint({0.7,0,0})
end


function returnTokens()
    assetButton.AssetBundle.playTriggerEffect(0)

    local allObjects = battlefieldZone.getObjects()
    local aimNumber = 1
    local dodgeNumber = 1
    local standbyNumber = 1
    local surgeNumber = 1
    local smokeNumber = 1
    local commandNumber = 1
    local observationNumber = 1

    if allObjects then
        for i, obj in pairs(allObjects) do
            if obj.getName() == "Aim Token" then
                aimNumber = returnToken(aimBag,obj,aimNumber)
            elseif obj.getName() == "Dodge Token" then
                dodgeNumber = returnToken(dodgeBag,obj,dodgeNumber)
            elseif obj.getName() == "Standby Token" then
                standbyNumber = returnToken(standbyBag,obj,standbyNumber)
            elseif obj.getName() == "Surge Token" then
                surgeNumber = returnToken(surgeBag,obj,surgeNumber)
            elseif obj.getName() == "Smoke Token" then
                smokeNumber = returnToken(smokeBag,obj,smokeNumber)
            elseif obj.getName() == "Observation Token" then
                observationNumber = returnToken(observationBag,obj,observationNumber)
            elseif obj.getVar("isAToken") == true then
                local unitData = obj.getTable("unitData")
                local commandTray = getObjectFromGUID(commandTokenTrayData[unitData.colorSide][unitData.commandType])
                local pos = commandTray.getPosition()
                pos.y = pos.y + 0.5 +(0.2 * commandNumber)
                local rot = commandTray.getRotation()

                obj.setPositionSmooth(pos, false, false)
                obj.setRotationSmooth(rot, false, false)
                commandNumber = commandNumber + 1
            end
        end
    end
end

function returnToken(bag, obj, number)
    chipNumber = obj.getQuantity()
    if chipNumber > 0 then
        for i=1, chipNumber, 1 do
            local takenObj = obj.takeObject({
                top            = true
            })
            takenObj.setRotation({0,0,0})
            takenObj.setPositionSmooth({bag.getPosition().x,bag.getPosition().y+number,bag.getPosition().z})
            number = number + 2
        end

    else
        obj.setRotation({0,0,0})
        obj.setPositionSmooth({bag.getPosition().x,bag.getPosition().y+number,bag.getPosition().z})
        number = number + 2
    end
    return number
end

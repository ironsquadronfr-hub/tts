require('!/Analytics')
require('!/Deck')

existingMasks = {}
existingPoiGuide = nil

function onload(save_state)
    _G.Deck = Deck:create()

    -- init values
    gameData = getObjectFromGUID(Global.getVar("gameDataGUID"))
    battlefieldTint = gameData.getTable("battlefieldTint")

    gameController = Global.getTable("gameController")
    mountZone = getObjectFromGUID(gameController.mountZoneGUID)
    battlefieldZone = getObjectFromGUID(Global.getVar("battlefieldZoneGUID"))
    battlefieldTable = getObjectFromGUID(Global.getVar("battlefieldTable"))
    customMapsCartridge = getObjectFromGUID(gameController.customMapsGUID)
    deploymentOverlays = getObjectFromGUID(gameController.deploymentOverlaysGUID)

    listBuilder = Global.getTable("listBuilder")
    redZone = getObjectFromGUID(listBuilder.redZoneGUID)
    blueZone = getObjectFromGUID(listBuilder.blueZoneGUID)
    screen = getObjectFromGUID(Global.getVar("screenGUID"))
    objectiveCards = getObjectFromGUID(gameController.objectiveCardsGUID)
    deploymentCards = getObjectFromGUID(gameController.deploymentCardsGUID)
    conditionsCards = getObjectFromGUID(gameController.conditionsCardsGUID)
    setUpData = Global.getTable("setUpData")
    setUpData.deploymentMount = getObjectFromGUID(setUpData.deploymentMountGUID)
    setUpData.conditionsMount = getObjectFromGUID(setUpData.conditionsMountGUID)
    setUpData.objectiveMount = getObjectFromGUID(setUpData.objectiveMountGUID)
    commandTokenTrayData = Global.getTable("commandTokenTrayData")
    commandTokenData = Global.getTable("commandTokenData")
    zonesGUIDs = Global.getTable("zonesGUIDs")

    setUpController = getObjectFromGUID(Global.getVar("setUpControllerGUID"))
    battleDeckTypes = {"deployment", "objective", "conditions"}

    blueDeckMount = getObjectFromGUID(listBuilder.blueDeckMountGUID)
    redDeckMount = getObjectFromGUID(listBuilder.redDeckMountGUID)
    blueDeckZone = getObjectFromGUID(listBuilder.blueDeckZoneGUID)
    redDeckZone = getObjectFromGUID(listBuilder.redDeckZoneGUID)


    -- button Models
    dataDiskMount = getObjectFromGUID("a44dcb")

    optionObjs = {}

    optionObjs.gameControllerOption1 = getObjectFromGUID("9200f4")
    optionObjs.gameControllerOption2 = getObjectFromGUID("de5eb8")
    optionObjs.gameControllerOption3 = getObjectFromGUID("44c5b4")
    optionObjs.gameControllerOption4 = getObjectFromGUID("a4448e")
    optionObjs.gameControllerOption5 = getObjectFromGUID("971605")

    optionButtons = {}

    optionButtons.gameControllerOption1Button = getObjectFromGUID("4663eb")
    optionButtons.gameControllerOption2Button = getObjectFromGUID("3c301d")
    optionButtons.gameControllerOption3Button = getObjectFromGUID("05d327")
    optionButtons.gameControllerOption4Button = getObjectFromGUID("6cfaf1")
    optionButtons.gameControllerOption5Button = getObjectFromGUID("3cd1bf")

    backButton = getObjectFromGUID("ae44c9")
    prevButton = getObjectFromGUID("f563ce")
    nextButton = getObjectFromGUID("d81a06")

    homeScreen()
    mainMenu()
end

function homeScreen()
    screen.createButton({click_function = "dud", function_owner = self, label = "", position = {0.9, 0.25, 0}, rotation = {0, -90, 90}, scale = {0.5, 0.5, 0.5}, width = 0, height = 0, font_size = 100, font_color = {0.8867, 0.7804, 0, 1}, alignment = 1})
    printToScreen("STAR WARS LEGION TTS MOD\n by SWL Dev Foundation\n\nThe home of BLITZ!\nSelect an option below to start", 80, 3)
end


-- MENU

function mainMenu()
    timerScreen = false

    printToScreen("STAR WARS LEGION TTS MOD\n by SWL Dev Foundation\n\nThe home of BLITZ!\nSelect an option below to start", 80, 3)

    clearAllButtons()
    local menuEntries = {}
    menuEntries[1] = {functionName = "mapMenu", label = "Maps", tooltip = "Map Menu", buttonTint = {0,0.913,1}}
    menuEntries[2] = {functionName = "gameOptionsMenu", label = "Set Up", tooltip = "Set Up options menu", buttonTint = {0,0.913,1}}

    createMenu(menuEntries, 1)

end

function defineBattlefieldMenuBlue()
    blueDeckMount.call("defineBattlefield")
end

function enterTintData(obj, dataString, tintTable)
    local tintString =  "{r = "..tintTable.r..", g = "..tintTable.g..", b = "..tintTable.b.."}"
    enterData(obj, dataString, tintString)
    obj.setTable(dataString, tintTable)
end

function enterData(obj, dataString, newValue)
    dataScript = obj.getLuaScript()
    dataString = dataString .. " = "
    local stringStart = 0
    local valueStart = 0
    stringStart, valueStart = string.find(dataScript, dataString)
    valueStart = valueStart

    local valueEnd = 0
    local valueNil = 0
    valueEnd, valueNil = string.find(dataScript, "\n", valueStart)
    valueEnd = valueEnd

    local newDataScript = string.sub(dataScript, 1, valueStart).. newValue .. string.sub(dataScript, valueEnd)

    obj.setLuaScript(newDataScript)
end

function reset()
    clearSetUpCards("all")
    mainMenu()
end

function debug()
    local battlefieldObjs = battlefieldZone.getObjects()
    local redObjs = redZone.getObjects()
    local blueObjs = blueZone.getObjects()
    removeLockedRulers()
    reloadObj(battlefieldObjs)
    reloadObj(redObjs)
    reloadObj(blueObjs)
end

function reloadObj(selectedObjs)
    for _, obj in pairs(selectedObjs) do
        if obj.getName() == "Movement Template" then
            destroyObject(obj)
        else
            obj.reload()
        end

    end
end

function removeLockedRulers()
    local allObjs = getAllObjects()
    for _, obj in pairs(allObjs) do
        if obj.getName() == "Cohesion Ruler" or obj.getName() == "Range Ruler" then
            destroyObject(obj)
        end
    end
end

function standbyTokens()
    local allObjs = getAllObjects()
    for i, obj in pairs(allObjs) do
        if obj.getVar("isAToken") == true then
            obj.call("standby")
        end
    end
end

function clearPlayerZones()
    local redZoneObjs = redZone.getObjects()
    local blueZoneObjs = blueZone.getObjects()

    for i, obj in pairs(redZoneObjs) do
        if obj ~= battlefieldTable then
            destroyObject(obj)
        end
    end
    for i, obj in pairs(blueZoneObjs) do
        if obj ~= battlefieldTable then
            destroyObject(obj)
        end
    end
end

function defineBattlefieldMenu(params)
    local selectedDeck = params.deck
    local selectedScenario = params.scenario
    if #selectedDeck.getObjects() < 12 then
      broadcastToAll("At least 12 cards are required to use battlefield vetoes. Move your choices manually to the right places!")
      return
    end
    _G.selectedScenario = selectedScenario
    print(selectedScenario)
    ga_view("game_controller/define_battlefield")
    clearAllButtons()
    changeBackButton("reset", "Go back to Main Menu")
    local menuEntries = {}
    menuEntries[1] = {functionName = "finishDefineBattlefieldMenu", label = "NEXT", tooltip = "NEXT", buttonTint = {0,0.913,1}}
    createMenu(menuEntries, 1)
    revealBattleCards(selectedDeck, selectedScenario)
    printToScreen("DEFINE BATTLEFIELD\nStarting with Blue player, players eliminate left most card.\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 60, 2)
end

function finishDefineBattlefieldMenu()
    defineBattlefield()
    spawnObjectiveConditionsDelay()
    mainMenu()
end

function gameOptionsMenu()
    ga_view("game_controller/game_options")
    clearAllButtons()
    changeBackButton("mainMenu", "Go back to Main Menu")
    local menuEntries = {}
    menuEntries[1] = {
      functionName = "flipMap",
      label = "Flip Map",
      tooltip = "Flip the map to the other side",
      buttonTint = {0,0.913,1}
    }
    menuEntries[2] = {
      functionName = "defineBattlefieldMenuBlue",
      label = "Blue Player: Define Battlefield",
      tooltip = "Spawn Battlefield Objective, Deployment and Condition cards from Blue Deck",
      buttonTint = {0,0.913,1}
    }
    menuEntries[3] = {
      functionName = "debug",
      label = "Debug Objects",
      tooltip = "Corrects terrain that is spawned incorrectly or removes stuck rulers or movement templates",
      buttonTint = {0,0.913,1}
    }
    menuEntries[4] = {
      functionName = "spawnCardDecks",
      label = "Spawn Card Decks",
      tooltip = "Spawn Unit/Upgrade/Command cards for manual use",
      buttonTint = {0,0.913,1}
    }
    menuEntries[5] = {
      functionName = "enableExperimentalFeatures",
      label = "Enable Experiments",
      tooltip = "Enables experimental unsupported features",
      buttonTint = {0,0.913,1}
    }
    createMenu(menuEntries, 1)
end

function mapMenu()
    ga_view("game_controller/map_menu")
    printToScreen("MAP MENU", 80, 3)

    clearAllButtons()
    changeBackButton("mainMenu", "Go back to Main Menu")

    callBackMapMenu = "mapMenu"

    local menuEntries = {}
    menuEntries[1] = {functionName = "featuredMapsMenu", label = "Featured Maps", tooltip = "List and download pre-made maps", buttonTint = {0,0.913,1}}
    menuEntries[2] = {functionName = "loadMap", label = "Load Map", tooltip = "Load Map from Data Cartridge", buttonTint = {0,0.913,1}}
    menuEntries[3] = {functionName = "saveMap", label = "Save Map", tooltip = "Save Map to a Data Cartridge", buttonTint = {0,0.913,1}}
    menuEntries[4] = {functionName = "flipMap", label = "Flip Map", tooltip = "Flip the map to the other side", buttonTint = {0,0.913,1}}
    menuEntries[5] = {functionName = "customMapMenu", label = "Custom Maps", tooltip = "Create a Custom Map", buttonTint = {0,0.913,1}}
    menuEntries[6] = {functionName = "clearZones", label = "Clear Map", tooltip = "Clears everything from current Battlefield area", buttonTint = {0,0.913,1}}
    menuEntries[7] = {functionName = "saveConditions", label = "Save Battlefield Tokens", tooltip = "Saves Objects from the Objective/Deployment/Conditions", buttonTint = {0,0.913,1}}
    menuEntries[8] = {functionName = "toggleMaskMid", label = "Toggle Masks : Mid", tooltip = "Toggles Masking Objects for the middle of the Battlefield", buttonTint = {0,0.913,1}}
    menuEntries[9] = {functionName = "togglePoiGuide", label = "Toggle Poi Guide", tooltip = "Toggles Poi Layout Projector to help with Map Creation", buttonTint = {0,0.913,1}}
    createMenu(menuEntries, 1)
end

function featuredMapsMenu()
  ga_view("game_controller/featured_maps")
  printToScreen("FEATURED MAPS\n\nThese are maps featured by the community.\n\nSee https://go.swlegion.dev/maps for details.", 80, 3)
  changeBackButton("mapMenu", "Go back to Maps Menu")
  local buttonTint = {0,0.913,1}
  local menuEntries = {
    {
      label = "Competitive",
      tooltip = "View Competitive Maps",
      functionName = "featuredCompetitiveMenu",
      buttonTint = buttonTint,
    },
    {
      -- Skirmish is called Recon since the rules update; the data files and
      -- the swlegion.dev links still use the old name.
      label = "Recon",
      tooltip = "View Recon (3x3) Maps",
      functionName = "featuredSkirmisMenu",
      buttonTint = buttonTint,
    }
  }
  createMenu(menuEntries, 1)
end

function featuredCompetitiveMenu()
  ga_view("game_controller/featured_maps/competitive")
  printToScreen("FEATURED MAPS\n\nThese are maps featured by the community.\n\nSee https://go.swlegion.dev/maps for details.", 80, 3)
  changeBackButton("featuredMapsMenu", "Go back to featured maps")
  local url = "https://raw.githubusercontent.com/swlegion/tts/master/contrib/maps/competitive.json"
  WebRequest.get(url, function(data)
    -- GitHub answers an outage or a hiccup with an HTML page, and decoding
    -- that raises inside the download handler where nothing catches it.
    local ok, items = pcall(function() return JSON.decode(data.text) end)
    if not ok or type(items) ~= "table" then
      printToAll("Could not read the featured map list. Check your connection.")
      return mainMenu()
    end
    local menu = {}
    for _, entry in pairs(items) do
      table.insert(menu, {
        label = entry['name'],
        tooltip = 'Download map',
        url = entry['url'],
        buttonTint = {0,0.913,1}
      })
    end
    createMenu(menu, 1)
  end)
end

function featuredSkirmisMenu()
  ga_view("game_controller/featured_maps/skirmish")
  printToScreen("FEATURED MAPS\n\nThese are maps featured by the community.\n\nSee https://go.swlegion.dev/maps for details.\n\nFull support for Recon is currently limited:\nhttps://go.swlegion.dev/skirmish.", 80, 3)
  changeBackButton("featuredMapsMenu", "Go back to featured maps")
  local url = "https://raw.githubusercontent.com/swlegion/tts/master/contrib/maps/skirmish.json"
  WebRequest.get(url, function(data)
    -- GitHub answers an outage or a hiccup with an HTML page, and decoding
    -- that raises inside the download handler where nothing catches it.
    local ok, items = pcall(function() return JSON.decode(data.text) end)
    if not ok or type(items) ~= "table" then
      printToAll("Could not read the featured map list. Check your connection.")
      return mainMenu()
    end
    local menu = {}
    for _, entry in pairs(items) do
      table.insert(menu, {
        label = entry['name'],
        tooltip = 'Download map',
        url = entry['url'],
        buttonTint = {0,0.913,1}
      })
    end
    createMenu(menu, 1)
  end)
end

function createMapMenu(selectedCartridge, mapMenuCallback)
  local selectedMapsTable = selectedCartridge.getObjects()
  local menuEntries = {}
  for iM, entry in pairs(selectedMapsTable) do
      _G["spawnCustomMap"..entry.name] = function() spawnCustomMap(entry.name, selectedCartridge, mapMenuCallback) end
      table.insert(menuEntries, {functionName = "spawnCustomMap"..entry.name, label = entry.name, tooltip = "Load ".. entry.name .." map", buttonTint = {0,0.913,1}})
  end
  createMenu(menuEntries, 1)
end

function customMapMenu()
  ga_view("game_controller/custom_maps")
  clearAllButtons()
  changeBackButton("mapMenu", "Go back to Maps Menu")
  createMapMenu(customMapsCartridge, "mapMenu")
end

-- SETUP Menu

function spawnCardDecks()
  ga_event("Game", "spawnCardDecks")
  local factions = Deck:getFactions()
  for _, faction in ipairs(factions) do
    Deck:spawnUnitDeck(faction, {52.43, 1.42, 32.53})
  end
  Deck:spawnUpgradeDeck({52.43, 1.84, 29.23})
  Deck:spawnCommandDeck({52.51, 1.42, 26.35})
  Deck:spawnBattleDeck({52.43, 1.42, 23})
end

function setBattleCardPos()
    for i, battleDeckType in pairs(battleDeckTypes) do
        for n=1, 4, 1 do
            local setUpCardPos = gameController.setUpCardsPos[battleDeckType][n]
            local spawnPos = {}
            
            spawnPos.x = screen.getPosition().x - setUpCardPos[1]
            spawnPos.y = screen.getPosition().y - setUpCardPos[2]
            spawnPos.z = screen.getPosition().z - setUpCardPos[3]

            local spawnRot = {55.91, 270.00, 0.00}
            local spawnedCardObj = setUp5Data.spawnedCards[battleDeckType][n]

            spawnedCardObj.setLock(true)
            spawnedCardObj.setScale({0.5,1,0.5})
            spawnedCardObj.setRotation(spawnRot)
            spawnedCardObj.setPosition(spawnPos)

            Wait.frames(function()
              debugSpawnSetupCard(spawnedCardObj)
            end)
        end
    end
end

function createMatrixFromDeck(battleDeckInserted, battleDeckScenario)
  -- CLONE DECK
  local battleDeckClone = battleDeckInserted.clone({
      position     = {0,-10,0},
      rotation     = {55.91, 270.00, 0.00},
      scale        = {0.5, 1, 0.5},
  })
  battleDeckClone.shuffle()
  local battleDeckTable = battleDeckClone.getObjects()

  -- for each card
  
  local cardMatrixSelected = {
    deployment = {},
    objective  = {},
    conditions = {},
  }

  for i, card in ipairs(battleDeckClone.getObjects()) do
    local object = battleDeckClone.takeObject({
      position     = {i*1, -10, 0},
    })
    local name = object.getName()
    local type = Deck:getBattleCardType(name, battleDeckScenario)
    -- TODO: Rename conditions -> condition
    if type == "condition" then
      type = "conditions"
    end
    table.insert(cardMatrixSelected[type], object)
  end

  if battleDeckClone then
    destroyObject(battleDeckClone)
  end

  return cardMatrixSelected.objective, 
         cardMatrixSelected.deployment,
         cardMatrixSelected.conditions
end

function revealBattleCards(insertedDeck, battleDeckScenario)
    clearSetUpCards("all")
    setUp5Data = {
      objectiveCards  = objectiveCards,
      deploymentCards = deploymentCards,
      conditionsCards = conditionsCards,
      spawnedCards    = {},
    }
    if insertedDeck == nil then
        setUp5Data.spawnedCards.objective = spawnSetupCards("objective")
        setUp5Data.spawnedCards.deployment = spawnSetupCards("deployment")
        setUp5Data.spawnedCards.conditions = spawnSetupCards("conditions")
    else
        objectiveCardMatrix, deploymentCardMatrix, conditionsCardMatrix = createMatrixFromDeck(insertedDeck, battleDeckScenario)
        setUp5Data.spawnedCards.objective = objectiveCardMatrix
        setUp5Data.spawnedCards.deployment = deploymentCardMatrix
        setUp5Data.spawnedCards.conditions = conditionsCardMatrix
        setBattleCardPos()
    end
    setUp5Data.cardSelection = {objective = 1, deployment = 1, conditions = 1}

    createButtonSetUpCard("objective", 1)
    createButtonSetUpCard("deployment", 1)
    createButtonSetUpCard("conditions", 1)
    Wait.frames(debugSetupCards)
end

function debugSetupCards()
    for i = 1, 4, 1 do
        if setUp5Data.spawnedCards.objective[i] then
            setUp5Data.spawnedCards.objective[i].setRotation({55.91, 270.00, 0.00})
        end

        if setUp5Data.spawnedCards.deployment[i] then
            setUp5Data.spawnedCards.deployment[i].setRotation({55.91, 270.00, 0.00})
        end
        if setUp5Data.spawnedCards.conditions[i] then
            setUp5Data.spawnedCards.conditions[i].setRotation({55.91, 270.00, 0.00})
        end
    end
end

function clearSetUpCards(clearedCards)
    if setUp5Data then
        for i = 1, 4, 1 do
            if setUp5Data.cardSelection.objective == i and clearedCards == "eliminate" then
            else
                if setUp5Data.spawnedCards.objective[i] then
                    destroyObject(setUp5Data.spawnedCards.objective[i])
                end
            end

            if setUp5Data.cardSelection.deployment == i and clearedCards == "eliminate" then
            else
                if setUp5Data.spawnedCards.deployment[i] then
                    destroyObject(setUp5Data.spawnedCards.deployment[i])
                end
            end

            if setUp5Data.cardSelection.conditions == i and clearedCards == "eliminate" then
            else
                if setUp5Data.spawnedCards.conditions[i] then
                    destroyObject(setUp5Data.spawnedCards.conditions[i])
                end
            end
        end
    end

    if clearedCards == "all" then
        setUp5Data = nil
    end

end

function defineBattlefield()
    clearSetUpCards("eliminate")
    insertSetUpCard("objective")
    insertSetUpCard("deployment")
    insertSetUpCard("conditions")
end

function insertSetUpCard(cardType)
    local mount = setUpData[cardType.."Mount"]
    local finalPos = {mount.getPosition().x, mount.getPosition().y+0.23, mount.getPosition().z}
    local finalCard = setUp5Data.spawnedCards[cardType][setUp5Data.cardSelection[cardType]]
    finalCard.setScale({0.83,1,0.83})
    finalCard.setLock(false)
    finalCard.setPosition(finalPos)
    finalCard.setRotation(mount.getRotation())
    finalCard.clearButtons()
end

function spawnObjectiveConditionsDelay()
    Wait.frames(spawnObjectiveConditions)
end

function spawnObjectiveConditions()
    local scenario = _G.selectedScenario
    setUpController.call("changeScenario", {scenario})
    setUpController.call("checkCardCall", {"deployment"})
    setUpController.call("checkCardCall", {"objective"})
    setUpController.call("checkCardCall", {"conditions"})
end


function eliminateCard(eliminatedCategory, eliminateNumber)
    local eliminiatedCard = setUp5Data.spawnedCards[eliminatedCategory][eliminateNumber]
    local cardRot = eliminiatedCard.getRotation()
    cardRot.x = cardRot.x + 180
    eliminiatedCard.setRotation(cardRot)
    eliminiatedCard.clearButtons()

    if eliminateNumber ~= 3 then
        createButtonSetUpCard(eliminatedCategory, eliminateNumber+1)
    end

    setUp5Data.cardSelection[eliminatedCategory] = eliminateNumber+1
end

function createButtonSetUpCard(cardType, selectedNumber)
    _G["eliminate"..cardType..selectedNumber] = function() eliminateCard(cardType, selectedNumber) end

    local data = {click_function = "eliminate"..cardType..selectedNumber, function_owner = self, label = "ELIMINATE", position = {-1, 1, 0}, rotation = {0, -90, 0}, scale = {0.7, 0.5, 0.5}, width = 2000, height = 400, font_size = 300, color = {1, 0, 0, 0.8}, font_color = {0,0,0, 1.25}}

    setUp5Data.spawnedCards[cardType][selectedNumber].createButton(data)
end

function spawnSetupCards(selection)
        setUp5Data[selection.."CardsClone"] = setUp5Data[selection .."Cards"].clone({
            position     = {0,-10,0}
        })

        setUp5Data[selection.."CardsClone"].shuffle()

        local spawnedCardTable = {}

        for n=1, #gameController.setUpCardsPos[selection], 1 do
            local setUpCardPos = gameController.setUpCardsPos[selection][n]

            local spawnPos = {}
            spawnPos.x = screen.getPosition().x - setUpCardPos[1]
            spawnPos.y = screen.getPosition().y - setUpCardPos[2]
            spawnPos.z = screen.getPosition().z - setUpCardPos[3]

            local spawnRot = {55.91, 270.00, 0.00}

            spawnedCard = setUp5Data[selection.."CardsClone"].takeObject({
                position       = spawnPos,
                rotation       = spawnRot,
                smooth         = false,
                top            = true
            })

            spawnedCard.setLock(true)
            spawnedCard.setRotation(spawnRot)

            spawnedCardTable[n] = spawnedCard

            Wait.frames(function()
              debugSpawnSetupCard(spawnedCard)
            end)
        end

        destroyObject(setUp5Data[selection.."CardsClone"])

        return spawnedCardTable
end

function debugSpawnSetupCard(spawnedSetupCard)
    spawnedSetupCard.setRotation({55.91, 270.00, 0.00})
end

function flipObjPos(pObj)
    local objPos = pObj.getPosition()
    local newPos = objPos
    local objRot = pObj.getRotation()
    objRot.y = objRot.y+180
    newPos.x = 8-(objPos.x - 8)
    newPos.z = -objPos.z

    pObj.setPosition(newPos)
    pObj.setRotation(objRot)
end

function flipMap()
    ga_event("Game", "flipMap")
    --Get a list of any objects which are inside of the zone.
    local allObjs = battlefieldZone.getObjects()

    --Check if the table we made is empty due to the zone being empty
    if #allObjs == 0 then
    else
        for _, obj in ipairs(allObjs) do
            -- flip obj
            if obj ~= battlefieldTable then
                flipObjPos(obj)
            end
        end
    end
end

function spawnCustomMap(selectedMap, selectedCartridgeObj, mapMenuCallback, clearZone)
    ga_event("Creative", "spawnCustomMap", selectedMap)
    if mapMenuCallback ~= nil then
        self.call(mapMenuCallback)
    end

    if clearZone ~= false then
        clearZones()
    end

    -- clone cartridge
    local selectedCartridgeObjClone = selectedCartridgeObj.clone({
        position     = {0,-10,0}
    })


    -- get guid
    local selectedCartridgeTable = selectedCartridgeObj.getObjects()

    for i, entry in pairs(selectedCartridgeTable) do
        if entry.name == selectedMap then
            selectedGUID = entry.guid
            break
        end
    end

    selectedCartridgeObjClone.takeObject({
        position       = {0,-10,3},
        callback       = "spawnFromCartridgeDelay",
        callback_owner = self,
        smooth         = false,
        guid           = selectedGUID
    })

    -- delete clone
    destroyObject(selectedCartridgeObjClone)
end

function spawnFromCartridgeDelay(spawnFromCartridgeObj)
    spawnFromCartridgeObj.setLock(true)
    Wait.frames(function()
      spawnMapFromCartridge(spawnFromCartridgeObj, function()
        destroyIfAlive(spawnFromCartridgeObj)
      end)
    end)
end


-- Spawning the whole cartridge in one frame freezes the table for seconds
-- (same failure mode as the list import): pump one object per frame instead,
-- with progress on the screen. onDone runs once the cartridge is drained -
-- callers that destroy the cartridge must do it there, not right after this
-- call returns.
mapDeployGeneration = 0

-- destroyObject raises on an object that is already gone, and a cartridge can
-- disappear while its map is still deploying: a player grabs it, or saving the
-- map sweeps the mount zone. Ask before destroying, and treat an object that
-- cannot answer as already destroyed.
function destroyIfAlive(obj)
  if obj == nil then return end
  local ok, gone = pcall(function() return obj.isDestroyed() end)
  if ok and not gone then
    obj.destroyObject()
  end
end

function spawnMapFromCartridge(selectedCartridge, onDone)
    ga_event("Game", "spawnMapFromCartridge", selectedCartridge.getName())
    clearZones()
    changeBattlefieldTint(selectedCartridge.getTable("battlefieldTint"))
    mapDeployGeneration = mapDeployGeneration + 1
    local generation = mapDeployGeneration
    local total = #selectedCartridge.getObjects()
    local i = 0
    -- onDone always runs, even when the pump gives up: it is what disposes of
    -- the cartridge. Left undone, an abandoned featured-map cartridge stays
    -- parked in the mount zone still holding half a map, and loadMap() picks
    -- it up in place of the player's own. `abandoned` tells the caller not to
    -- touch the screen, which by then belongs to whoever took over.
    local function finish(abandoned)
      if onDone ~= nil then onDone(abandoned) end
    end
    local function pumpStep()
      -- a newer map load owns the screen and the battlefield now
      if generation ~= mapDeployGeneration then return finish(true) end
      if i >= total then return finish(false) end
      i = i + 1
      -- pcall: the cartridge can vanish mid-cascade (player grabbed it)
      local ok = pcall(function()
        selectedCartridge.takeObject({
          position          = {0,-10-i,0},
          smooth            = false,
          callback_function = function(spawnedObject)
            Wait.frames(function()
              -- This piece was already in flight when another load took over;
              -- placing it now would drop it onto the new map.
              if generation ~= mapDeployGeneration then
                return destroyIfAlive(spawnedObject)
              end
              placeTerrain(spawnedObject)
            end)
          end,
        })
      end)
      -- The player took the cartridge: nobody else owns the screen, so the
      -- menu must come back (the caller then drops its dead disk handle).
      if not ok then return finish(false) end
      if i % 10 == 0 or i == total then
        printToScreen("LOADING MAP...\n\n" .. i .. " / " .. total, 80, 3)
      end
      Wait.frames(pumpStep, 1)
    end
    pumpStep()
end

function clearZones()
    clearMap()
end

function clearMap()

    --Get a list of any objects which are inside of the zone.
    local objectsInZone = battlefieldZone.getObjects()

    --Check if the table we made is empty due to the zone being empty
    if #objectsInZone == 0 then
    else
        --If it isn't empty, we use a for loop to look at each entry in the list
        for _, object in ipairs(objectsInZone) do
            -- destroy object
            if object ~= battlefieldTable then
                destroyObject(object)
            end
        end
    end
end

function prepareToSave()
    -- delete cartridgeObjs
    local mountObjs = mountZone.getObjects()

    for i, obj in pairs(mountObjs) do
        if obj ~= dataDiskMount then
            destroyObject(obj)
        end
    end

    -- create data cartridge
    local spawnPos = dataDiskMount.getPosition()
    -- offset to "snap" the cartridge neatly
    spawnPos.x = spawnPos.x + 0.05
    spawnPos.y = spawnPos.y - 0.41
    spawnPos.z = spawnPos.z + 0.02
    local dataCartridgeOriginal = getObjectFromGUID(gameController.dataCartridgeGUID)

    dataCartridge = dataCartridgeOriginal.clone({
        position     = spawnPos
    })

    dataCartridge.setLock(false)
    dataCartridge.setScale({1,1,1})

    battlefieldTint = gameData.getTable("battlefieldTint")

    local cartridgeScript = "battlefieldTint = {r = " .. battlefieldTint.r .. ", g = " .. battlefieldTint.g .. ", b = " .. battlefieldTint.b .. "}"
    dataCartridge.setLuaScript(cartridgeScript)
end

function saveConditions()
    prepareToSave()

    local zoneBox = getObjectFromGUID(zonesGUIDs.conditions)
    local zoneObjs = zoneBox.getObjects()
    logObj(zoneObjs)
end

function saveMap()
    prepareToSave()

    local zoneBox = getObjectFromGUID(zonesGUIDs.battlefield)
    local zoneObjs = zoneBox.getObjects()
    ga_event("Creative", "saveMap", #zoneObjs)
    logObj(zoneObjs)
end

function logObj(selectedObjs)
    for _, obj in pairs(selectedObjs) do
        if obj.getName() ~= "TABLE" then
            local objLuaScript = getLuaScriptData(obj)

            if string.len(obj.getLuaScript()) > 5 then
                objLuaScript = objLuaScript .. "\nscripted = true"
            else
                objLuaScript = objLuaScript
            end
            obj.setLuaScript(objLuaScript.."\n"..obj.getLuaScript())

            dataCartridge.putObject(obj)
        end
    end
end

function getLuaScriptData(targetObj)
    local returnString = ""

    local returnPos = targetObj.getPosition()
    returnString = returnString .. "position = {x = " .. returnPos.x .. ", y = " .. returnPos.y .. ", z = " .. returnPos.z .. "}\n"

    local returnRot = targetObj.getRotation()
    returnString = returnString .. "rotation = {x = " .. returnRot.x .. ", y = " .. returnRot.y .. ", z = " .. returnRot.z .. "}\n"

    return returnString
end

function loadMap()
    -- get cartridge
    local mountObjs = mountZone.getObjects()

    for i, obj in pairs(mountObjs) do
        if obj.getTable("battlefieldTint") ~= nil then
            loadedCartridge = obj
        end
    end

    -- spawn cartridge
    if loadedCartridge ~= nil then
        clearZones()
        spawnMapFromCartridge(loadedCartridge)
    else
    end
end

function placeTerrain(paObj)
    local spawnPos = paObj.getTable("position")
    local spawnRot = paObj.getTable("rotation")
    -- A cartridge holds where each piece goes in the piece's own script. A
    -- piece saved without one, or whose asset failed to build, has neither -
    -- and setPosition(nil) raises, which used to kill the rest of the map.
    -- Leave it where it landed and name it instead.
    if spawnPos == nil or spawnRot == nil then
      printToAll("Map piece has no saved position: " .. tostring(paObj.getName()))
      return
    end
    paObj.setPosition(spawnPos)
    paObj.setRotation(spawnRot)

    if paObj.getVar("scripted") == true then
    else
        paObj.setLuaScript("")
    end


    if paObj.getName() == "BATTLEFIELD" then
        paObj.interactable = false
        paObj.setLock(true)
        paObj.setLuaScript("function onload() self.interactable = false end")
    end
end

-- UTILITY FUNCTIONS

function dud()
end

function clearAllButtons(exception)
    for _, optionObjEntry in pairs(optionObjs) do
        optionObjEntry.clearButtons()
    end

    for _, optionButtonEntry in pairs(optionButtons) do
        optionButtonEntry.clearButtons()
        optionButtonEntry.setColorTint({0,0,0})
    end

    if exception ~= backButton then
        backButton.clearButtons()
        backButton.setColorTint({0,0,0})
    end

    prevButton.clearButtons()
    prevButton.setColorTint({0,0,0})
    nextButton.clearButtons()
    nextButton.setColorTint({0,0,0})
end

function printToScreen(screenText, fontSize, selectedAlignment)
    screen.editButton({
        int = 0, click_function = "dud", function_owner = self, label = screenText, position = {0.9, 0.25, 0}, rotation = {0, -90, 90}, scale = {0.5, 0.5, 0.5}, width = 0, height = 0, font_size = fontSize, font_color = {0.8867, 0.7804, 0, 1}, alignment = selectedAlignment
    })
end


function createOptionButton(optionNumber, optionClickFunction, optionLabel, optionToolTip,tint)
    optionObj = optionObjs["gameControllerOption"..optionNumber]
    optionButton = optionButtons["gameControllerOption"..optionNumber.."Button"]

    _G["gameControllerOptionFunction"..optionNumber] = function()
        optionButtons["gameControllerOption"..optionNumber.."Button"].AssetBundle.playTriggerEffect(0)
        _G[optionClickFunction](optionNumber)
    end
    local stringLength = string.len(optionLabel)

    if stringLength < 24 then
        buttonFontSize = 400
    else
        local stringDif = stringLength - 22
        buttonFontSize = 400 - (stringDif * 8)
    end

    optionObj.createButton({
        click_function = "gameControllerOptionFunction"..optionNumber, function_owner = self, label = optionLabel, position = {-0.35, 0.3, 0}, scale = {0.5, 0.5, 0.5}, width = 4200, height = 600, font_size = buttonFontSize, color = {0.7573, 0.7573, 0.7573, 0.01}, font_color = {0, 0, 0, 100},tooltip = optionToolTip
    })

    optionButton.createButton({
        click_function = "gameControllerOptionFunction"..optionNumber, function_owner = self, label = "", position = {0, 0.65, 0}, width = 1400, height = 1400, font_size = 1100, color = {1,1,1,0.01},font_color = {1,1,1,100}, tooltip = optionToolTip, alignment = 3
    })

    optionButton.setColorTint(tint)
end

function changeBackButton(optionClickFunction, optionToolTip)
    _G["gameControllerBackButtonFunction"] = function()
        backButton.AssetBundle.playTriggerEffect(0)
        _G[optionClickFunction]()
    end

    backButton.createButton({
        click_function = "gameControllerBackButtonFunction", function_owner = self, label = "BACK", position = {0, 0.65, 0}, scale = {1, 1, 1.4}, width = 1500, height = 2000, font_size = 400, color = {0.7573, 0.7573, 0.7573, 0.01}, font_color = {0, 0, 0, 100}, tooltip = optionToolTip
    })
    backButton.setColorTint({1,0,0})
end

function changeNextButton(optionClickFunction, optionToolTip)
    _G["gameControllerNextButtonFunction"] = function()
        nextButton.AssetBundle.playTriggerEffect(0)
        _G[optionClickFunction]()
    end

    nextButton.createButton({
        click_function = "gameControllerNextButtonFunction", function_owner = self, label = "NEXT", position = {0, 0.65, 0}, scale = {1, 1, 0.7}, width = 1500, height = 2000, font_size = 400, color = {0.7573, 0.7573, 0.7573, 0.01}, font_color = {0, 0, 0, 100}, tooltip = optionToolTip
    })
    nextButton.setColorTint({0.7,0.7,0})
end

function changePrevButton(optionClickFunction, optionToolTip)
    _G["gameControllerPrevButtonFunction"] = function()
        prevButton.AssetBundle.playTriggerEffect(0)
        _G[optionClickFunction]()
    end

    prevButton.createButton({
        click_function = "gameControllerPrevButtonFunction", function_owner = self, label = "PREV", position = {0, 0.65, 0}, scale = {1, 1, 0.7}, width = 1500, height = 2000, font_size = 400, color = {0.7573, 0.7573, 0.7573, 0.01}, font_color = {0, 0, 0, 100}, tooltip = optionToolTip
    })
    prevButton.setColorTint({0.7,0.7,0})
end

optionUrls = {}

function downloadMap(mapIndex)
  local url = optionUrls[mapIndex]
  printToScreen("DOWNLOADING MAP...")
  downloadMapByUrl(url)
end

-- cloud-3.steamusercontent.com is gone (HTTP 403 on everything); Steam now
-- serves the same UGC paths from Akamai. Repair both the map URL itself and
-- every asset URL inside the downloaded map JSON.
--
-- Six assets never made it to Akamai (404 on every host, gone from the
-- Wayback Machine too). The community map packs ship the same terrain
-- pieces under other UGC paths, so swap the dead paths for those live
-- equivalents.
DEAD_UGC_SWAPS = {
  -- Scarif Landing, "Sand Mound (Blast Hole)": the league packs use the
  -- plain Sand Mound assets for the same piece.
  ["866242507558372594/6E91C689398356425C48138EC9FD73DD213DBE25"] =
    "785234540542465659/30348E08551EAA3E8D5164E0D2931B3EB72DCEC1",
  ["874120511627020981/C8D3FAC8EFDCDB836ECC7E1B74C7929F6C77F5EF"] =
    "785234540542470239/CFB22A69010911784880172594A7106CBC1F8DF1",
  ["874120913887641068/75C737DD596381693CCA671B3BD6A1D227CCBBB8"] =
    "785234540542467139/4036C31123FF00D2459B3ED1E57CD8141ACFAC8D",
  -- Geonosis, "Destroyed Advanced Dwarf Spider Droid": NOT substituted, on
  -- purpose. The only other copy in circulation is a different sculpt whose
  -- texture does not match, and swapping to it is worse than leaving the
  -- dead link: a player who owns the real one has it in their TTS cache, and
  -- pointing somewhere else is exactly what stops them seeing it. The two
  -- original files survive in a cache and are waiting to be rehosted; until
  -- then the piece is missing for a fresh install and correct for everyone
  -- who played this map before it died.
  -- Imperial Checkpoint, "Walkway [Light Cover]" state 1: collider of the
  -- same walkway mesh as found in the other packs.
  ["924802058713318404/E46A0DB14CBAD8B6711484041D221EC8DFE6498A"] =
    "785234780857945420/BD98F26583D35B354CE52BC7F624EFD69FF167A7",
  -- Geonosis, rock formation: the map data pasted the collider gist URL
  -- twice in a row in one ColliderURL field.
  ["rock_formation_collider.txthttps://gist.githubusercontent.com/nashjaee/3375e9ebe255d751196483c59c545591/raw/fe2fa562af6874076a3dc4e0f74dc7c68eeafa63/rock_formation_collider.txt"] =
    "rock_formation_collider.txt",
  -- Imperial Checkpoint: wildtextures.com no longer serves this jpg (404
  -- page); the Wayback Machine still has the original (im_ = raw file).
  ["http://www.wildtextures.com/wp-content/uploads/wildtextures-tiles-stone-marble-480x279.jpg"] =
    "http://web.archive.org/web/20230807160829im_/https://wildtextures.com/wp-content/uploads/wildtextures-tiles-stone-marble-480x279.jpg",
  -- Geonosis: infinitebucket.com is gone, dead DNS, and no copy survives in
  -- any cache or archive. Nothing can bring this decorative dust effect
  -- back, so drop it rather than keep pointing at a host that will never
  -- answer again.
  ["http://infinitebucket.com/tts/scenesystem/dust.unity3d"] = "",
}

function repairDeadSteamHost(text)
  local repaired = text:gsub("https?://cloud%-3%.steamusercontent%.com/", "https://steamusercontent-a.akamaihd.net/")
  for dead, alive in pairs(DEAD_UGC_SWAPS) do
    -- A gsub rebuilds the whole string, and a map file is 70-160 KB, so never
    -- run one blind: a map carries at most a couple of these. Escape only the
    -- ones that hit - gsub wants the magic characters quoted, find wants the
    -- raw text.
    if repaired:find(dead, 1, true) then
      repaired = repaired:gsub(dead:gsub("%W", "%%%0"), (alive:gsub("%%", "%%%%")))
    end
  end
  return repaired
end

function downloadMapByUrl(url)
  WebRequest.get(repairDeadSteamHost(url), function(data)
    -- Read data.text now: TTS drops the download handler as soon as we yield.
    unpackMap(data.text)
  end)
end

-- Walk back from an anchor over the handful of characters of whitespace and
-- punctuation that separate two JSON tokens. Bounded on purpose: if the file
-- is not shaped as expected we give up and the caller falls back to decoding.
function lastCharBefore(text, char, limit)
  local floor = math.max(1, limit - 200)
  for i = limit - 1, floor, -1 do
    if text:sub(i, i) == char then
      return i
    end
  end
  return nil
end

-- Cut the cartridge out of the downloaded text without parsing it.
--
-- Measured in game: JSON.decode of a map costs 1.7 to 5.5 s in MoonSharp,
-- while the engine parses the very same JSON in 0.07 s inside
-- spawnObjectJSON. So the fastest decode is the one we never run - hand the
-- raw substring to the engine and let it do the single parse.
--
-- The shape a TTS save export produces is fixed, and it holds on all ten
-- featured maps: ObjectStates carries exactly one object, and the top-level
-- LuaScript / LuaScriptState / XmlUI / VersionNumber keys come after it.
-- The contained objects carry plain `"LuaScript"` keys of their own, but the
-- ObjectStates array closes before the top-level LuaScript key, so the last
-- occurrence in the file is always the top-level one - and the cartridge
-- ends at the last } before the ] just above it.
function extractCartridgeJson(text)
  local arrayKey = text:find('"ObjectStates"', 1, true)
  if not arrayKey then return nil end
  local objectStart = text:find("{", arrayKey, true)
  if not objectStart then return nil end

  local lastScript, pos = nil, arrayKey
  while true do
    local found = text:find('"LuaScript"', pos, true)
    if not found then break end
    lastScript, pos = found, found + 1
  end
  if not lastScript then return nil end

  local arrayEnd = lastCharBefore(text, "]", lastScript)
  if not arrayEnd then return nil end
  local objectEnd = lastCharBefore(text, "}", arrayEnd)
  if not objectEnd or objectEnd <= objectStart then return nil end

  return text:sub(objectStart, objectEnd)
end

-- Unpacking used to repair the links, decode 70-160 KB of JSON and encode the
-- cartridge back out, all in one frame - seconds of frozen table. The decode
-- and the encode are gone (see extractCartridgeJson); the link repair still
-- rebuilds the whole string, 0.07 to 0.41 s measured, so it waits a frame to
-- let the label paint first. Cutting the cartridge out costs 0.14 ms and
-- rides along in the same frame.
function unpackMap(text)
  printToScreen("UNPACKING MAP...", 80, 3)
  Wait.frames(function()
    text = repairDeadSteamHost(text)
    -- Every way out of here either loads the map or hands the menu back:
    -- the screen is showing UNPACKING MAP and nothing else would clear it.
    if not text:find('"ObjectStates"', 1, true) then
      printToAll("Failed to download map.")
      return mainMenu()
    end
    local json = extractCartridgeJson(text)
    if json == nil then
      -- Unexpected shape: pay for the full decode rather than fail.
      local map = JSON.decode(text)
      if not map or not map.ObjectStates or not map.ObjectStates[1] then
        printToAll("Failed to decode map.")
        return mainMenu()
      end
      json = JSON.encode(map.ObjectStates[1])
    end
    -- Don't hold the whole file alive through the spawn cascade.
    text = nil
    local spawned = false
    spawnObjectJSON({
      json = json,
      position = dataDiskMount.getPosition(),
      callback_function = function(disk)
        spawned = true
        spawnMapFromCartridge(disk, function(abandoned)
          -- Restore the menu first: it is what lets the player act again,
          -- and the disk may already be gone by now.
          if not abandoned then mainMenu() end
          destroyIfAlive(disk)
        end)
      end
    })
    -- extractCartridgeJson trusts the shape of the file, and the featured
    -- list is fetched live, so one day a map may not match it. The engine
    -- rejects JSON it cannot read by never calling back at all - without
    -- this the screen would sit on UNPACKING MAP for ever, saying nothing.
    Wait.time(function()
      if not spawned then
        printToAll("Failed to unpack map.")
        mainMenu()
      end
    end, 10)
  end, 1)
end

function createMenu(optionTable, selectedIndex)
    clearAllButtons(backButton)

    if #optionTable > 5 then
        -- create prev and next buttons
        if selectedIndex-5 > 0 then
            _G["prevButtonFunction"] = function() createMenu(optionTable, selectedIndex-5) end
            changePrevButton("prevButtonFunction", "Previous Menu options")
        end
        if selectedIndex+4 < #optionTable then
            _G["nextButtonFunction"] = function() createMenu(optionTable,selectedIndex+5) end
            changeNextButton("nextButtonFunction", "More menu options")
        end
    end

    for oI=0,4,1 do
        if optionTable[selectedIndex+oI] ~= nil then
            local entry = optionTable[selectedIndex+oI]
            if entry.url ~= nil then
              optionUrls[selectedIndex+oI] = entry.url
              createOptionButton(oI+1, "downloadMap", entry.label,entry.tooltip, entry.buttonTint)
            else
              createOptionButton(oI+1, entry.functionName, entry.label,entry.tooltip, entry.buttonTint)
            end
        end
    end
end



function changeBattlefieldTint(tint)
    enterTintData(gameData, "battlefieldTint", tint)

    local allUnits = getAllObjects()
    for _,unit in pairs(allUnits) do
        if unit.getCustomObject().type == 1 then
            unit.setColorTint(tint)
            --unit.setTable("battlefieldTint", tint)
        end
    end
end

function onPlayerChangedColor(player_color)
    if player_color == "Red" or player_color == "Blue" then
        if Player[player_color].host == false and Player[player_color].promoted == false then
            Player[player_color].promote()
        end
    end
end

function enableExperimentalFeatures()
    ga_event("Global", "enableExperimentalFeatures")
    Global.UI.show("legionDisplay")
end

function getExistingMaskLength()
    local length = 0
    if existingMasks != nil then
        for i, obj in pairs(existingMasks) do
            length = length + 1
        end
    end
    return length
end

function toggleMaskMid()   
    local length = getExistingMaskLength() 
    if length > 0 then
        clearMasks()
    else
        placeMask(35,9)
        placeMask(-19,9)
        placeMask(35,-9)
        placeMask(-19,-9)
    end
end

function toggleMaskRight()
    local length = getExistingMaskLength() 
    if length > 0 then
        clearMasks()
    else
        placeMask(35,9)
        placeMask(17,9)
        placeMask(35,-9)
        placeMask(17,-9)
    end
end

function toggleMaskLeft()
    local length = getExistingMaskLength() 
    if length > 0 then
        clearMasks()
    else
        placeMask(-1,9)
        placeMask(-19,9)
        placeMask(-1,-9)
        placeMask(-19,-9)
    end
end

function clearMasks()
    if existingMasks != nil then
        for i, obj in pairs(existingMasks) do
            if obj != nil then
                destroyObject(obj)
            end
        end
        existingMasks = {}
    end
end

function placeMask(x, z)
    local projector = spawnObject({
        type        = "Custom_AssetBundle",
        position    = {
          x,
          75,
          z,
        },
        scale       = {0, 0, 0},
      })
      local asset = "https://steamusercontent-a.akamaihd.net/ugc/2264809616949875099/DB2BBB502F11E04185A603B8A4FD0F2391B905C6/"
      projector.setName("Masking Boundary")
      projector.setLock(true)
      projector.setCustomObject({
        assetbundle = asset,
      })  
    table.insert(existingMasks, projector)
end

function togglePoiGuide()   
    local length = getExistingMaskLength() 
    if existingPoiGuide ~= nil then
        destroyObject(existingPoiGuide)
        existingPoiGuide = nil
    else
        local projector = spawnObject({
            type = "Custom_AssetBundle",
            position = { 8, 30, 0 },
            scale = {0,0,0}
        })
        local asset = "https://steamusercontent-a.akamaihd.net/ugc/2491137781649901469/35992792768FE398E61633C99C02D069A54F65B1/"
        projector.setName("Poi Guide")
        projector.setLock(true)
        projector.setCustomObject({
            assetbundle = asset
        })
        existingPoiGuide = projector
    end
end
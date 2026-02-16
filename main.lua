local currentGame = nil
local currentMenu = nil
local hub = require("hub")
local leucadia = require("leucadia")
local singularity = require("singularity")
local mixia = require("mixia")
local currency = require("hub.currency")
local currentHubType = "hometown"  -- Track which hub we're in
local saves = require("menu.saves")
local mainMenu = require("menu.main_menu")
local continueMenu = require("menu.continue_menu")
local optionsMenu = require("menu.options_menu")
local introCrawl = require("menu.intro_crawl")
local nameEntry = require("menu.name_entry")
local introCutscene = require("menu.intro_cutscene")
local saveMenu = require("menu.save_menu")

local gameModules = {
  slotmachine = nil,
  roulette = nil,
  blackjack = nil,
  pooltable = nil,
  asteroids = nil,
  starfox = nil,
  shop = nil,
  casino_exchange = nil,
  hangar = nil,
  mainstage = nil,
  studio = nil,
  shipyard = nil,
  lookout = nil,
  planetmap = nil
}

local casinoGames = {slotmachine = true, roulette = true, blackjack = true, pooltable = true}
local pendingPlayerName = "Player"

function switchToGame(gameName)
  if not gameModules[gameName] then
    if gameName == "shop" then
      gameModules[gameName] = require("hub.shop")
    elseif gameName == "casino_exchange" then
      gameModules[gameName] = require("hub.casino_exchange")
    elseif gameName == "hangar" then
      gameModules[gameName] = require("hub.hangar")
    elseif gameName == "mainstage" then
      gameModules[gameName] = require("hub.mainstage")
    elseif gameName == "studio" then
      gameModules[gameName] = require("hub.studio")
    elseif gameName == "shipyard" then
      gameModules[gameName] = require("hub.shipyard")
    elseif gameName == "lookout" then
      gameModules[gameName] = require("hub.lookout")
    elseif gameName == "planetmap" then
      gameModules[gameName] = require("hub.planetmap")
    elseif gameName == "science_lab" then
      gameModules[gameName] = require("singularity.sciencelab")
    elseif gameName == "secret_base" then
      gameModules[gameName] = require("leucadia.secretbase")
    else
      local ok, mod = pcall(require, gameName)
      if not ok then
        print("[switchToGame] Module not found: " .. gameName)
        return
      end
      gameModules[gameName] = mod
    end
  end

  currentGame = gameModules[gameName]

  -- Pass credits to casino games
  if casinoGames[gameName] then
    -- Track credits before casino for Mixia casino winnings
    if currentHubType == "mixia" then
      mixia.setCreditsBeforeCasino(hub.getCredits())
    end
    currentGame.load(hub.getCredits())
  elseif gameName == "mainstage" then
    -- Mainstage: enter with random act
    currentGame.enter()
  elseif gameName == "studio" then
    -- Studio: enter the DJ booth
    currentGame.enter()
  elseif gameName == "shipyard" then
    -- Shipyard: pass purchased ships and notes
    currentGame.enter(hub.getPurchasedShips())
    currentGame.onPurchase = function(shipId, price)
      hub.spendNotes(price)
      local purchased = hub.getPurchasedShips()
      purchased[shipId] = true
      hub.setPurchasedShips(purchased)
    end
  elseif gameName == "lookout" then
    -- Lookout: enter with high scores and stats
    currentGame.enter()
  elseif gameName == "planetmap" then
    -- Planet Map: LOTR-style map of planets and stations
    currentGame.enter()
    currentGame.returnToHub = returnToHub
  elseif gameName == "science_lab" then
    -- Science Lab: NASA sublevel beneath The Singularity
    currentGame.load()
    currentGame.returnToHub = function()
      returnToHub({hubType = currentHubType, fromPlanetMap = false})
    end
  elseif gameName == "secret_base" then
    -- Secret Base: USS Pendleton carrier beneath Leucadia
    currentGame.load()
    currentGame.returnToHub = function()
      returnToHub({hubType = currentHubType, fromPlanetMap = false})
    end
  else
    currentGame.load()
  end

  -- Set up asteroids callbacks
  if gameName == "asteroids" then
    currentGame.returnToHub = returnToHub
    -- Sync map progression (antenna installed + sentinel defeated)
    if currentGame.setProgression then
      currentGame.setProgression(hub.hasMegaAntenna(), hub.hasPowerAmplifier())
    end
    -- Refresh missiles when entering from Hometown Station
    if currentHubType == "hometown" and currentGame.refreshMissiles then
      currentGame.refreshMissiles()
    end
    currentGame.goToMixiaPD = function()
      -- Busted: send player to Mixia Level 4 Galaxy PD HQ
      returnToHub({hubType = "mixia", fromPlanetMap = false})
      -- Override spawn position to PD HQ door
      if mixia.spawnAtPDHQ then
        mixia.spawnAtPDHQ()
      end
    end
    currentGame.enterStarfox = function(levelId)
      -- Mark this level as visited via portal
      hub.markPortalLevelVisited(levelId)

      -- Switch from asteroids to starfox with a specific level
      switchToGame("starfox")
      if gameModules.starfox then
        -- Set up return to asteroids callback
        gameModules.starfox.setReturnToAsteroids(function()
          switchToGame("asteroids")
          -- Restore to portal entry tile
          if gameModules.asteroids and gameModules.asteroids.restoreFromPortal then
            gameModules.asteroids.restoreFromPortal()
          end
        end)
        if gameModules.starfox.startLevel then
          gameModules.starfox.startLevel(levelId)
        end
      end
    end
    -- Sync ship selection
    local ships = require("starfox.ships")
    ships.setSelected(hub.getSelectedShip())
  end

  -- Pass shop items to starfox
  if gameName == "starfox" then
    currentGame.setShopItems(hub.getShopItems())
    hub.clearShopItems()
    -- Ensure ship selection is synced
    local ships = require("starfox.ships")
    ships.setSelected(hub.getSelectedShip())
    -- Sync progression state
    currentGame.setProgression(hub.hasMegaAntenna(), hub.hasPowerAmplifier())
    -- Pass visited portal levels for Floor 4 level select
    currentGame.setVisitedPortalLevels(hub.getVisitedPortalLevels())
    -- Set return to hub callback for station selection
    currentGame.setReturnToHub(returnToHub)
    -- Set progression reward callbacks
    currentGame.onMegaAntennaAwarded = function()
      hub.setMegaAntenna(true)
      -- Flag asteroids to show acquisition overlay on return
      if gameModules.asteroids then
        gameModules.asteroids.pendingMegaAntenna = true
      end
    end
    currentGame.onPowerAmplifierAwarded = function()
      hub.setPowerAmplifier(true)
      -- Flag asteroids to show acquisition overlay on return
      if gameModules.asteroids then
        gameModules.asteroids.pendingPowerAmplifier = true
      end
    end
    -- Prototype acquisition callback
    currentGame.onPrototypeAcquired = function()
      local purchased = hub.getPurchasedShips()
      purchased["prototype"] = true
      hub.setPurchasedShips(purchased)
      local quests = hub.getUnlockedQuests()
      quests["the_prototype_complete"] = true
      hub.setUnlockedQuests(quests)
    end
  end
end

function returnToHub(stationInfo)
  -- Retrieve credits from casino games before returning
  if currentGame.getCredits then
    local newCredits = currentGame.getCredits()
    -- Track casino winnings for Mixia (Level 1 casino)
    if currentHubType == "mixia" then
      local creditsBefore = mixia.getCreditsBeforeCasino()
      local profit = newCredits - creditsBefore
      if profit > 0 then
        mixia.addCasinoWinnings(profit)
      end
    end
    hub.setCredits(newCredits)
  end

  -- Award notes from starfox
  if currentGame.getNotesEarned then
    local notesEarned = currentGame.getNotesEarned()
    if notesEarned > 0 then
      hub.addNotes(notesEarned)
      currency.save(hub.getNotes())
    end
  end

  -- Track high scores from starfox
  if currentGame.getLevelId and currentGame.getScore then
    local levelId = currentGame.getLevelId()
    local score = currentGame.getScore()
    if levelId and score then
      hub.updateHighScore(levelId, score)
    end
  end

  -- Retrieve purchased ships from shipyard
  if currentGame.purchasedShips then
    hub.setPurchasedShips(currentGame.purchasedShips)
  end

  -- Determine which hub to go to
  -- If stationInfo is provided, we're landing at a station from space
  -- If nil, we're returning from a game played inside a hub (stay in current hub)
  local hubType = currentHubType  -- Default to current hub
  local freshLanding = false
  local fromPlanetMap = false  -- Track if traveling via planet map
  if stationInfo and stationInfo.hubType then
    hubType = stationInfo.hubType
    freshLanding = true
    -- Check if explicitly flagged as from planet map
    fromPlanetMap = stationInfo.fromPlanetMap or false
  end
  -- Note: Don't update currentHubType unless freshLanding, to preserve hub context
  if freshLanding then
    currentHubType = hubType
  end

  local pauseMenu = require("hub.pause_menu")
  if hubType == "leucadia" then
    leucadia.setFadeInFromStarfox(true)
    currentGame = leucadia
    if freshLanding then
      leucadia.load()
    else
      leucadia.returnFromGame()
    end
    leucadia.returnToAsteroids = function()
      switchToGame("asteroids")
      if gameModules.asteroids and gameModules.asteroids.restoreFromPortal then
        gameModules.asteroids.restoreFromPortal()
      end
    end
    leucadia.switchToGame = switchToGame
    -- Return to Ship (from space) vs Return to Station (from planet map)
    if fromPlanetMap then
      pauseMenu.returnToShip = nil
      pauseMenu.onFastTravel = nil
      pauseMenu.returnToStation = function()
        switchToGame("planetmap")
      end
    else
      pauseMenu.returnToShip = leucadia.returnToAsteroids
      pauseMenu.returnToStation = nil
      pauseMenu.onFastTravel = function(tileX, tileY)
        switchToGame("asteroids")
        if gameModules.asteroids then
          gameModules.asteroids.restoreFromPortal()
          local wm = require("asteroids.worldmap")
          gameModules.asteroids.transitionToTile(tileX, tileY, 683, 384)
        end
      end
    end
  elseif hubType == "singularity" then
    singularity.setFadeInFromStarfox(true)
    currentGame = singularity
    if freshLanding then
      singularity.load()
    else
      singularity.returnFromGame()
    end
    singularity.returnToAsteroids = function()
      switchToGame("asteroids")
      if gameModules.asteroids and gameModules.asteroids.restoreFromPortal then
        gameModules.asteroids.restoreFromPortal()
      end
    end
    singularity.switchToGame = switchToGame
    -- Return to Ship (from space) vs Return to Station (from planet map)
    if fromPlanetMap then
      pauseMenu.returnToShip = nil
      pauseMenu.onFastTravel = nil
      pauseMenu.returnToStation = function()
        switchToGame("planetmap")
      end
    else
      pauseMenu.returnToShip = singularity.returnToAsteroids
      pauseMenu.returnToStation = nil
      pauseMenu.onFastTravel = function(tileX, tileY)
        switchToGame("asteroids")
        if gameModules.asteroids then
          gameModules.asteroids.restoreFromPortal()
          local wm = require("asteroids.worldmap")
          gameModules.asteroids.transitionToTile(tileX, tileY, 683, 384)
        end
      end
    end
  elseif hubType == "mixia" then
    mixia.setFadeInFromStarfox(true)
    currentGame = mixia
    if freshLanding then
      mixia.load()
    else
      mixia.returnFromGame()
    end
    mixia.returnToAsteroids = function()
      switchToGame("asteroids")
      if gameModules.asteroids and gameModules.asteroids.restoreFromPortal then
        gameModules.asteroids.restoreFromPortal()
      end
    end
    mixia.switchToGame = switchToGame
    -- Return to Ship (from space) vs Return to Station (from planet map)
    if fromPlanetMap then
      pauseMenu.returnToShip = nil
      pauseMenu.onFastTravel = nil
      pauseMenu.returnToStation = function()
        switchToGame("planetmap")
      end
    else
      pauseMenu.returnToShip = mixia.returnToAsteroids
      pauseMenu.returnToStation = nil
      pauseMenu.onFastTravel = function(tileX, tileY)
        switchToGame("asteroids")
        if gameModules.asteroids then
          gameModules.asteroids.restoreFromPortal()
          local wm = require("asteroids.worldmap")
          gameModules.asteroids.transitionToTile(tileX, tileY, 683, 384)
        end
      end
    end
  else
    -- Default to Hometown Station hub
    hub.setFadeInFromStarfox(true)
    currentGame = hub
    hub.returnFromGame()
    pauseMenu.returnToShip = nil
    pauseMenu.returnToStation = nil
    pauseMenu.onFastTravel = nil
  end
end

function goToMainMenu()
  currentMenu = mainMenu
  currentGame = nil
  mainMenu.load()
end

function goToContinueMenu()
  currentMenu = continueMenu
  continueMenu.load()
end

function goToOptionsMenu()
  currentMenu = optionsMenu
  optionsMenu.load()
end

function goToSaveMenu()
  currentMenu = saveMenu
  saveMenu.load()
end

function returnFromSaveMenu()
  currentMenu = nil
  currentGame = hub
  hub.setPaused(true) -- Stay paused after save
end

function startNewGame()
  -- Go directly to intro cutscene (handles fade, eye opening, name entry, and dialogue)
  currentMenu = introCutscene
  currentGame = nil
  introCutscene.load()
end

function startNewGameWithName(name)
  -- Store name for after intro (legacy, used by old name_entry flow)
  pendingPlayerName = name

  -- Reset game state
  hub.setCredits(1000)
  hub.setNotes(0)
  hub.setTimePlayed(0)
  hub.setActiveSlot(nil)
  hub.setHighScores({})
  hub.setMegaAntenna(false)
  hub.setPowerAmplifier(false)
  hub.setPurchasedShips({ starwing = true })
  hub.setCurrentFloor(2)
  hub.setUnlockedQuests({})
  hub.setVisitedPortalLevels({})
  currency.save(0)

  -- Show intro crawl (legacy path)
  currentMenu = introCrawl
  currentGame = nil
  introCrawl.load()
end

function startGameAfterCutscene(playerName)
  -- Called when intro cutscene finishes - start hub on Floor 4 with tutorial
  pendingPlayerName = playerName or "Player"

  -- Reset game state for new game
  hub.setCredits(1000)
  hub.setNotes(0)
  hub.setTimePlayed(0)
  hub.setActiveSlot(nil)
  hub.setHighScores({})
  hub.setMegaAntenna(false)
  hub.setPowerAmplifier(false)
  hub.setPurchasedShips({ starwing = true })
  hub.setCurrentFloor(4)  -- Start on Floor 4 (Flight Deck) after cutscene
  hub.setUnlockedQuests({})
  hub.setVisitedPortalLevels({})
  currency.save(0)

  -- Start hub game
  currentMenu = nil
  currentGame = hub
  currentHubType = "hometown"
  hub.switchToGame = switchToGame
  hub.load()
  hub.setPlayerName(pendingPlayerName)

  -- Trigger tutorial (Associate NPC greets player)
  hub.startTutorial()
end

function startGameAfterIntro()
  -- Start hub game after old intro crawl finishes (legacy)
  currentMenu = nil
  currentGame = hub
  currentHubType = "hometown"  -- Starting at Hometown Station
  hub.switchToGame = switchToGame
  hub.load()
  hub.setPlayerName(pendingPlayerName)
end

function loadGame(slot, saveData)
  -- Load save data into hub
  hub.setCredits(saveData.credits or 1000)
  hub.setNotes(saveData.notes or 0)
  hub.setTimePlayed(saveData.timePlayed or 0)
  hub.setActiveSlot(slot)
  hub.setPlayerName(saveData.name or "Player")
  hub.setHighScores(saveData.highScores or {})
  hub.setSelectedShip(saveData.selectedShip or "starwing")
  hub.setMegaAntenna(saveData.hasMegaAntenna or false)
  hub.setPowerAmplifier(saveData.hasPowerAmplifier or false)
  hub.setPurchasedShips(saveData.purchasedShips or { starwing = true })
  hub.setCurrentFloor(saveData.currentFloor or 2)
  hub.setUnlockedQuests(saveData.unlockedQuests or {})
  hub.setVisitedPortalLevels(saveData.visitedPortalLevels or {})
  currency.save(saveData.notes or 0)

  -- Restore Mixia-specific state
  if saveData.mixiaCasinoWinnings then
    mixia.addCasinoWinnings(saveData.mixiaCasinoWinnings - mixia.getCasinoWinnings())
  end
  if saveData.mixiaHasCompressedAir then
    mixia.setCompressedAir(saveData.mixiaHasCompressedAir)
  end

  -- Restore Prototype quest state
  local prototype = require("starfox.prototype")
  if saveData.prototypeData then
    prototype.loadSaveData(saveData.prototypeData)
  else
    -- Legacy save fallback: restore from unlockedQuests
    local quests = saveData.unlockedQuests or {}
    if quests["the_prototype"] then
      prototype.questStarted = true
    end
    if quests["the_prototype_complete"] then
      prototype.questStarted = true
      prototype.questComplete = true
    end
  end

  -- Start game
  currentMenu = nil
  currentGame = hub
  currentHubType = "hometown"  -- Starting at Hometown Station
  hub.switchToGame = switchToGame
  hub.load()
end

function love.load()
  love.window.setTitle("Starlight Symphony")
  love.window.setMode(1366, 768)

  -- Set up menu callbacks
  mainMenu.onNewGame = startNewGame
  mainMenu.onContinue = goToContinueMenu
  mainMenu.onOptions = goToOptionsMenu

  continueMenu.onSelectSave = loadGame
  continueMenu.onBack = goToMainMenu

  optionsMenu.onBack = goToMainMenu

  -- Set up name entry callbacks
  nameEntry.onComplete = startNewGameWithName
  nameEntry.onBack = goToMainMenu

  -- Set up save menu callbacks
  saveMenu.onSave = function(slot)
    hub.setActiveSlot(slot)
  end
  saveMenu.onBack = returnFromSaveMenu
  saveMenu.getSaveData = function()
    local prototype = require("starfox.prototype")
    return {
      name = hub.getPlayerName(),
      credits = hub.getCredits(),
      notes = hub.getNotes(),
      level = 1,
      timePlayed = hub.getTimePlayed(),
      highScores = hub.getHighScores(),
      selectedShip = hub.getSelectedShip(),
      hasMegaAntenna = hub.hasMegaAntenna(),
      hasPowerAmplifier = hub.hasPowerAmplifier(),
      purchasedShips = hub.getPurchasedShips(),
      currentFloor = hub.getCurrentFloor(),
      unlockedQuests = hub.getUnlockedQuests(),
      visitedPortalLevels = hub.getVisitedPortalLevels(),
      prototypeData = prototype.getSaveData(),
      mixiaCasinoWinnings = mixia.getCasinoWinnings(),
      mixiaHasCompressedAir = mixia.hasCompressedAir(),
    }
  end

  -- Set up intro crawl callback (legacy)
  introCrawl.onComplete = startGameAfterIntro

  -- Set up intro cutscene callback (new game flow)
  introCutscene.onComplete = startGameAfterCutscene

  -- Set up pause menu callbacks (use currentGame so they work for all hubs)
  local pauseMenu = require("hub.pause_menu")
  pauseMenu.onResume = function()
    if currentGame and currentGame.setPaused then
      currentGame.setPaused(false)
    end
  end
  pauseMenu.onOptions = function()
    -- Options are now handled inside pause_menu sub-menu
  end
  pauseMenu.onSave = goToSaveMenu
  pauseMenu.onExitToMenu = function()
    goToMainMenu()
  end

  -- Omnia warp callback: teleport to any stage/floor/constellation
  pauseMenu.onWarpTo = function(entry)
    if entry.type == "starfox" then
      -- Launch starfox at the selected level
      if currentGame and currentGame.setPaused then
        currentGame.setPaused(false)
      end
      switchToGame("starfox")
      if gameModules.starfox then
        gameModules.starfox.setReturnToHub(returnToHub)
        gameModules.starfox.setProgression(true, true) -- Full access
        gameModules.starfox.setVisitedPortalLevels(hub.getVisitedPortalLevels())
        gameModules.starfox.setShopItems(hub.getShopItems())
        local ships = require("starfox.ships")
        ships.setSelected(hub.getSelectedShip())
        if gameModules.starfox.startLevel then
          gameModules.starfox.startLevel(entry.levelId)
        end
        gameModules.starfox.setReturnToAsteroids(function()
          switchToGame("asteroids")
          if gameModules.asteroids and gameModules.asteroids.restoreFromPortal then
            gameModules.asteroids.restoreFromPortal()
          end
        end)
      end

    elseif entry.type == "hub_floor" then
      -- Warp to a specific floor on a hub
      if currentGame and currentGame.setPaused then
        currentGame.setPaused(false)
      end
      if entry.hubType == "hometown" then
        currentHubType = "hometown"
        currentGame = hub
        hub.switchToGame = switchToGame
        hub.setCurrentFloor(entry.floorId)
        hub.setUnlockedQuests({quest_floor0 = true, quest_floor6 = true}) -- Unlock all
        hub.setFadeInFromStarfox(true)  -- Fade in from white
        hub.load()
      elseif entry.hubType == "mixia" then
        currentHubType = "mixia"
        currentGame = mixia
        mixia.switchToGame = switchToGame
        mixia.setFadeInFromStarfox(true)  -- Fade in from white
        mixia.load()
        if mixia.changeFloor then
          mixia.changeFloor(entry.floorId)
        end
      end
      pauseMenu.returnToShip = nil
      pauseMenu.returnToStation = nil
      pauseMenu.onFastTravel = nil

    elseif entry.type == "hub_area" then
      -- Warp to a non-floor hub (leucadia, singularity)
      if currentGame and currentGame.setPaused then
        currentGame.setPaused(false)
      end
      if entry.hubType == "leucadia" then
        currentHubType = "leucadia"
        currentGame = leucadia
        leucadia.switchToGame = switchToGame
        leucadia.setFadeInFromStarfox(true)  -- Fade in from white
        leucadia.load()
      elseif entry.hubType == "singularity" then
        currentHubType = "singularity"
        currentGame = singularity
        singularity.switchToGame = switchToGame
        singularity.setFadeInFromStarfox(true)  -- Fade in from white
        singularity.load()
      end
      pauseMenu.returnToShip = nil
      pauseMenu.returnToStation = nil
      pauseMenu.onFastTravel = nil

    elseif entry.type == "constellation" then
      -- Warp to a constellation center in asteroids
      if currentGame and currentGame.setPaused then
        currentGame.setPaused(false)
      end
      switchToGame("asteroids")
      if gameModules.asteroids then
        -- Set progression so barrier is max
        local constellation = require("asteroids.constellation")
        constellation.currentTier = constellation.TIER_OUTER_SPACE
        constellation.sentinelDefeated = true
        constellation.antennaInstalled = true
        local worldmap = require("asteroids.worldmap")
        worldmap.updateBounds()
        worldmap.setPosition(entry.tileX, entry.tileY)
        -- Fade in from white
        gameModules.asteroids.setFadeInFromWhite()
      end
    end
  end

  hub.goToMainMenu = goToMainMenu
  hub.setPausedMenu = pauseMenu

  -- Set up Leucadia hub callbacks
  leucadia.goToMainMenu = goToMainMenu
  leucadia.switchToGame = switchToGame

  -- Set up Singularity hub callbacks
  singularity.goToMainMenu = goToMainMenu
  singularity.switchToGame = switchToGame

  -- Set up Mixia hub callbacks
  mixia.goToMainMenu = goToMainMenu
  mixia.switchToGame = switchToGame

  -- Start at main menu
  goToMainMenu()
end

function love.update(dt)
  if currentMenu then
    currentMenu.update(dt)
  elseif currentGame then
    currentGame.update(dt)
  end
end

function love.draw()
  if currentMenu then
    currentMenu.draw()
  elseif currentGame then
    currentGame.draw()
  end
end

function love.keypressed(key)
  if currentMenu then
    currentMenu.keypressed(key)
  elseif currentGame then
    -- Let starfox, asteroids and new hub modules handle their own escape key
    local selfHandled = false
    if currentGame == gameModules.starfox and gameModules.starfox then
      selfHandled = true
    elseif currentGame == gameModules.asteroids and gameModules.asteroids then
      selfHandled = true
    elseif currentGame == gameModules.mainstage and gameModules.mainstage then
      selfHandled = true
    elseif currentGame == gameModules.studio and gameModules.studio then
      selfHandled = true
    elseif currentGame == gameModules.shipyard and gameModules.shipyard then
      selfHandled = true
    elseif currentGame == gameModules.lookout and gameModules.lookout then
      selfHandled = true
    end
    if key == "escape" and currentGame ~= hub and currentGame ~= leucadia and currentGame ~= singularity and currentGame ~= mixia and not selfHandled then
      returnToHub()
    else
      -- For self-handled non-starfox/non-asteroids games, check if they exited
      if selfHandled and currentGame ~= gameModules.starfox and currentGame ~= gameModules.asteroids then
        currentGame.keypressed(key)
        -- If the module exited itself (active = false), return to hub
        if currentGame.active == false then
          returnToHub()
        end
      else
        currentGame.keypressed(key)
      end
    end
  end
end

function love.textinput(text)
  if currentMenu and currentMenu.textinput then
    currentMenu.textinput(text)
  elseif currentGame and currentGame.textinput then
    currentGame.textinput(text)
  end
end

function love.mousepressed(x, y, button)
  if currentMenu then
    if currentMenu.mousepressed then
      currentMenu.mousepressed(x, y, button)
    end
  elseif currentGame then
    if currentGame.mousepressed then
      currentGame.mousepressed(x, y, button)
    end
  end
end

function love.keyreleased(key)
  if currentGame and currentGame.keyreleased then
    currentGame.keyreleased(key)
  end
end

function love.quit()
  if currentGame then
    currency.save(hub.getNotes())
  end
end

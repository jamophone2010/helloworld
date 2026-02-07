local currentGame = nil
local currentMenu = nil
local hub = require("hub")
local currency = require("hub.currency")
local saves = require("menu.saves")
local mainMenu = require("menu.main_menu")
local continueMenu = require("menu.continue_menu")
local optionsMenu = require("menu.options_menu")
local introCrawl = require("menu.intro_crawl")
local nameEntry = require("menu.name_entry")
local saveMenu = require("menu.save_menu")

local gameModules = {
  slotmachine = nil,
  roulette = nil,
  blackjack = nil,
  asteroids = nil,
  starfox = nil,
  shop = nil,
  casino_exchange = nil,
  hangar = nil
}

local casinoGames = {slotmachine = true, roulette = true, blackjack = true}
local pendingPlayerName = "Player"

function switchToGame(gameName)
  if not gameModules[gameName] then
    if gameName == "shop" then
      gameModules[gameName] = require("hub.shop")
    elseif gameName == "casino_exchange" then
      gameModules[gameName] = require("hub.casino_exchange")
    elseif gameName == "hangar" then
      gameModules[gameName] = require("hub.hangar")
    else
      gameModules[gameName] = require(gameName)
    end
  end

  currentGame = gameModules[gameName]

  -- Pass credits to casino games
  if casinoGames[gameName] then
    currentGame.load(hub.getCredits())
  else
    currentGame.load()
  end

  -- Pass shop items to starfox
  if gameName == "starfox" then
    currentGame.setShopItems(hub.getShopItems())
    hub.clearShopItems()
    -- Ensure ship selection is synced
    local ships = require("starfox.ships")
    ships.setSelected(hub.getSelectedShip())
  end
end

function returnToHub()
  -- Retrieve credits from casino games before returning
  if currentGame.getCredits then
    hub.setCredits(currentGame.getCredits())
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

  currentGame = hub
  hub.returnFromGame()
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
  -- Show name entry screen first
  currentMenu = nameEntry
  currentGame = nil
  nameEntry.load()
end

function startNewGameWithName(name)
  -- Store name for after intro
  pendingPlayerName = name

  -- Reset game state
  hub.setCredits(1000000)
  hub.setNotes(0)
  hub.setTimePlayed(0)
  hub.setActiveSlot(nil)
  hub.setHighScores({})
  currency.save(0)

  -- Show intro crawl
  currentMenu = introCrawl
  currentGame = nil
  introCrawl.load()
end

function startGameAfterIntro()
  -- Start hub game after intro crawl finishes
  currentMenu = nil
  currentGame = hub
  hub.switchToGame = switchToGame
  hub.load()
  hub.setPlayerName(pendingPlayerName)
end

function loadGame(slot, saveData)
  -- Load save data into hub
  hub.setCredits(saveData.credits or 1000000)
  hub.setNotes(saveData.notes or 0)
  hub.setTimePlayed(saveData.timePlayed or 0)
  hub.setActiveSlot(slot)
  hub.setPlayerName(saveData.name or "Player")
  hub.setHighScores(saveData.highScores or {})
  hub.setSelectedShip(saveData.selectedShip or "starwing")
  currency.save(saveData.notes or 0)

  -- Start game
  currentMenu = nil
  currentGame = hub
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
    return {
      name = hub.getPlayerName(),
      credits = hub.getCredits(),
      notes = hub.getNotes(),
      level = 1,
      timePlayed = hub.getTimePlayed(),
      highScores = hub.getHighScores(),
      selectedShip = hub.getSelectedShip()
    }
  end

  -- Set up intro crawl callback
  introCrawl.onComplete = startGameAfterIntro

  -- Set up pause menu callbacks
  local pauseMenu = require("hub.pause_menu")
  pauseMenu.onResume = function()
    hub.setPaused(false)
  end
  pauseMenu.onOptions = function()
    -- Options functionality can be added later
  end
  pauseMenu.onSave = goToSaveMenu
  pauseMenu.onExitToMenu = function()
    goToMainMenu()
  end
  hub.goToMainMenu = goToMainMenu
  hub.setPausedMenu = pauseMenu

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
    -- Let starfox handle its own escape key for pause menu
    if key == "escape" and currentGame ~= hub and currentGame ~= gameModules.starfox then
      returnToHub()
    else
      currentGame.keypressed(key)
    end
  end
end

function love.textinput(text)
  if currentMenu and currentMenu.textinput then
    currentMenu.textinput(text)
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

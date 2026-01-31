local currentGame = nil
local hub = require("hub")

local gameModules = {
  slotmachine = nil,
  roulette = nil,
  blackjack = nil,
  asteroids = nil,
  starfox = nil
}

function switchToGame(gameName)
  if not gameModules[gameName] then
    gameModules[gameName] = require(gameName)
  end

  currentGame = gameModules[gameName]
  currentGame.load()
end

function returnToHub()
  currentGame = hub
  hub.load()
end

function love.load()
  love.window.setTitle("Game Hub")
  love.window.setMode(800, 600)

  hub.switchToGame = switchToGame

  currentGame = hub
  currentGame.load()
end

function love.update(dt)
  currentGame.update(dt)
end

function love.draw()
  currentGame.draw()
end

function love.keypressed(key)
  if key == "escape" and currentGame ~= hub then
    returnToHub()
  else
    currentGame.keypressed(key)
  end
end

function love.mousepressed(x, y, button)
  if currentGame.mousepressed then
    currentGame.mousepressed(x, y, button)
  end
end

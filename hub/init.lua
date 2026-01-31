local M = {}

local player = require("hub.player")
local portals = require("hub.portals")
local camera = require("hub.camera")
local audio = require("hub.audio")
local ui = require("hub.ui")

local gameState = {}

M.switchToGame = nil

function M.load()
  gameState.player = player.new(400, 300)
  gameState.camera = camera.new()
  gameState.nearbyPortal = nil

  audio.load()
  ui.load()
end

function M.update(dt)
  local vx = 0
  local vy = 0

  if love.keyboard.isDown("left") then
    vx = vx - 1
  end
  if love.keyboard.isDown("right") then
    vx = vx + 1
  end
  if love.keyboard.isDown("up") then
    vy = vy - 1
  end
  if love.keyboard.isDown("down") then
    vy = vy + 1
  end

  if vx ~= 0 or vy ~= 0 then
    local length = math.sqrt(vx * vx + vy * vy)
    vx = vx / length
    vy = vy / length
  end

  player.setVelocity(gameState.player, vx, vy)
  player.update(gameState.player, dt, 800, 600)
  camera.update(gameState.camera, gameState.player.x, gameState.player.y)

  gameState.nearbyPortal = portals.getNearbyPortal(gameState.player)
end

function M.draw()
  ui.draw(gameState.player, gameState.nearbyPortal)
end

function M.keypressed(key)
  if key == "e" then
    local enteredPortal = portals.getEnteredPortal(gameState.player)
    if enteredPortal then
      audio.playPortal()
      if M.switchToGame then
        M.switchToGame(enteredPortal.game)
      end
    end
  end
end

return M

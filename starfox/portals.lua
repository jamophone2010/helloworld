local M = {}
local screen = require("starfox.screen")
M.collected = 0
M.totalRequired = 7
M.warpTriggered = false

local PORTAL_SPEED = 120

function M.reset()
  M.portals = {}
  M.collected = 0
  M.warpTriggered = false
end

function M.spawn(x, y)
  local portal = {
    x = x,
    y = y or -60,
    radius = 35,
    innerRadius = 25,
    vy = PORTAL_SPEED,
    active = true,
    rotation = 0,
    pulse = 0
  }
  table.insert(M.portals, portal)
  return portal
end

function M.update(dt)
  for i = #M.portals, 1, -1 do
    local portal = M.portals[i]

    portal.y = portal.y + portal.vy * dt
    portal.rotation = portal.rotation + dt * 2
    portal.pulse = portal.pulse + dt * 4

    -- Remove if off screen
    if portal.y > screen.HEIGHT + 50 then
      table.remove(M.portals, i)
    end
  end
end

function M.checkCollision(playerX, playerY)
  for i = #M.portals, 1, -1 do
    local portal = M.portals[i]
    if portal.active then
      local dist = math.sqrt((portal.x - playerX)^2 + (portal.y - playerY)^2)
      if dist < portal.radius + 15 then
        portal.active = false
        M.collected = M.collected + 1
        table.remove(M.portals, i)
        return true
      end
    end
  end
  return false
end

function M.getCollected()
  return M.collected
end

function M.isWarpReady()
  return M.collected >= M.totalRequired and not M.warpTriggered
end

function M.triggerWarp()
  M.warpTriggered = true
end

function M.wasWarpTriggered()
  return M.warpTriggered
end

return M

local M = {}

local SPEED = 100
local RUN_SPEED_MULTIPLIER = 1.8
local GRID_SIZE = 32

function M.new(x, y)
  return {
    x = x,
    y = y,
    gridX = math.floor(x / GRID_SIZE),
    gridY = math.floor(y / GRID_SIZE),
    direction = "down", -- up, down, left, right
    moving = false,
    moveProgress = 0,
    targetX = x,
    targetY = y,
    width = 24,
    height = 24,
    running = false
  }
end

function M.update(player, dt, collisionMap)
  if player.moving then
    local currentSpeed = player.running and (SPEED * RUN_SPEED_MULTIPLIER) or SPEED
    player.moveProgress = player.moveProgress + currentSpeed * dt
    
    if player.moveProgress >= GRID_SIZE then
      player.x = player.targetX
      player.y = player.targetY
      player.gridX = math.floor(player.x / GRID_SIZE)
      player.gridY = math.floor(player.y / GRID_SIZE)
      player.moving = false
      player.moveProgress = 0
    else
      local t = player.moveProgress / GRID_SIZE
      local startX = player.gridX * GRID_SIZE + GRID_SIZE / 2
      local startY = player.gridY * GRID_SIZE + GRID_SIZE / 2
      player.x = startX + (player.targetX - startX) * t
      player.y = startY + (player.targetY - startY) * t
    end
  end
end

function M.setRunning(player, isRunning)
  player.running = isRunning
end

function M.tryMove(player, direction, collisionMap, npcs)
  if player.moving then
    return false
  end

  player.direction = direction

  local newGridX = player.gridX
  local newGridY = player.gridY

  if direction == "up" then
    newGridY = newGridY - 1
  elseif direction == "down" then
    newGridY = newGridY + 1
  elseif direction == "left" then
    newGridX = newGridX - 1
  elseif direction == "right" then
    newGridX = newGridX + 1
  end

  -- Check wall collision
  if collisionMap and collisionMap[newGridY] then
    if collisionMap[newGridY][newGridX] then
      return false
    end
  end

  -- Check NPC collision
  if npcs then
    for _, npc in ipairs(npcs) do
      local npcGridX = npc.gridX or npc.x
      local npcGridY = npc.gridY or npc.y
      -- Also check NPC's target position if they're moving
      local npcTargetX = npc.moving and npc.targetX or npcGridX
      local npcTargetY = npc.moving and npc.targetY or npcGridY

      if (npcGridX == newGridX and npcGridY == newGridY) or
         (npcTargetX == newGridX and npcTargetY == newGridY) then
        return false
      end
    end
  end

  player.targetX = newGridX * GRID_SIZE + GRID_SIZE / 2
  player.targetY = newGridY * GRID_SIZE + GRID_SIZE / 2
  player.moving = true
  player.moveProgress = 0

  return true
end

return M

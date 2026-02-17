local M = {}

local ui = require("hub.ui")

local SPEED = 60
local GRID_SIZE = 32
local WANDER_MIN_DELAY = 2.0  -- Minimum seconds between moves
local WANDER_MAX_DELAY = 5.0  -- Maximum seconds between moves

function M.new(name, x, y, dialogue, gender, extras)
  local obj = {
    name = name,
    x = x,
    y = y,
    gridX = x,
    gridY = y,
    targetX = x,
    targetY = y,
    dialogue = dialogue,
    gender = gender or "male",  -- default male, set explicitly per NPC
    width = 24,
    height = 24,
    direction = "down",
    moving = false,
    moveProgress = 0,
    wanderTimer = math.random() * WANDER_MAX_DELAY,
    canWander = name ~= "Piano Robot"  -- Piano Robot stays seated
  }
  -- Copy extra fields (outfit, design, etc.)
  if extras then
    for k, v in pairs(extras) do
      if obj[k] == nil then
        obj[k] = v
      end
    end
  end
  return obj
end

function M.update(npc, dt, collisionMap, allNPCs, player, doorPositions)
  -- Handle movement animation
  if npc.moving then
    npc.moveProgress = npc.moveProgress + SPEED * dt

    if npc.moveProgress >= GRID_SIZE then
      npc.x = npc.targetX
      npc.y = npc.targetY
      npc.gridX = npc.targetX
      npc.gridY = npc.targetY
      npc.moving = false
      npc.moveProgress = 0
    else
      local t = npc.moveProgress / GRID_SIZE
      local startX = npc.gridX
      local startY = npc.gridY
      npc.x = startX + (npc.targetX - startX) * t
      npc.y = startY + (npc.targetY - startY) * t
    end
  elseif npc.canWander then
    -- Wander logic
    npc.wanderTimer = npc.wanderTimer - dt
    if npc.wanderTimer <= 0 then
      M.tryRandomMove(npc, collisionMap, allNPCs, player, doorPositions)
      npc.wanderTimer = WANDER_MIN_DELAY + math.random() * (WANDER_MAX_DELAY - WANDER_MIN_DELAY)
    end
  end
end

function M.tryRandomMove(npc, collisionMap, allNPCs, player, doorPositions)
  local directions = {"up", "down", "left", "right"}
  local dir = directions[math.random(1, 4)]

  local newGridX = npc.gridX
  local newGridY = npc.gridY

  if dir == "up" then
    newGridY = newGridY - 1
  elseif dir == "down" then
    newGridY = newGridY + 1
  elseif dir == "left" then
    newGridX = newGridX - 1
  elseif dir == "right" then
    newGridX = newGridX + 1
  end

  -- Check wall collision
  if collisionMap and collisionMap[newGridY] then
    if collisionMap[newGridY][newGridX] then
      npc.direction = dir  -- Still face that direction
      return false
    end
  end

  -- Check doorway collision (NPCs should not block doorways)
  if doorPositions then
    for _, door in ipairs(doorPositions) do
      if door.x == newGridX and door.y == newGridY then
        npc.direction = dir
        return false
      end
    end
  end

  -- Check collision with other NPCs
  if allNPCs then
    for _, other in ipairs(allNPCs) do
      if other ~= npc then
        local otherX = other.moving and other.targetX or other.gridX
        local otherY = other.moving and other.targetY or other.gridY
        if otherX == newGridX and otherY == newGridY then
          npc.direction = dir
          return false
        end
      end
    end
  end

  -- Check collision with player
  if player then
    local playerGridX = math.floor(player.x / GRID_SIZE)
    local playerGridY = math.floor(player.y / GRID_SIZE)
    if playerGridX == newGridX and playerGridY == newGridY then
      npc.direction = dir
      return false
    end
  end

  -- Move is valid
  npc.direction = dir
  npc.targetX = newGridX
  npc.targetY = newGridY
  npc.moving = true
  npc.moveProgress = 0

  return true
end

function M.draw(npcObj, time)
  ui.drawNPC(npcObj, nil, time)
end

return M

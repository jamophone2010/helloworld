local M = {}
local screen = require("starfox.screen")

-- Squadron tracking
M.nextSquadronId = 1
M.rotationTime = 0

function M.reset()
  M.enemies = {}
  M.nextSquadronId = 1
  M.rotationTime = 0
end

function M.spawn(x, y, type, color)
  local enemy = {
    x = x,
    y = y,
    type = type or "fighter",
    color = color or "red",
    health = 1,
    maxHealth = 1,
    score = 10,
    width = 25,
    height = 25,
    shootTimer = math.random() * 2 + 1,
    -- Squadron fields (nil for non-squadron enemies)
    squadronId = nil,
    squadronShielded = false,  -- true when squadron shield is active
  }

  if type == "fighter" then
    enemy.vx = 0
    enemy.vy = 150

    if color == "red" then
      enemy.health = 1
      enemy.maxHealth = 1
      enemy.score = 10
    elseif color == "green" then
      enemy.health = 2
      enemy.maxHealth = 2
      enemy.score = 20
    elseif color == "blue" then
      enemy.health = 3
      enemy.maxHealth = 3
      enemy.score = 30
    else
      enemy.health = 1
      enemy.maxHealth = 1
      enemy.score = 10
    end
  end

  table.insert(M.enemies, enemy)
  return enemy
end

--- Spawn a squadron of 3-4 enemies that can only be damaged when ALL are multi-targeted
function M.spawnSquadronGroup(x, y, count)
  count = count or 3
  if count < 3 then count = 3 end
  if count > 4 then count = 4 end

  local sqId = M.nextSquadronId
  M.nextSquadronId = M.nextSquadronId + 1

  local members = {}
  local spacing = 35

  for i = 1, count do
    local angle = ((i - 1) / count) * math.pi * 2 - math.pi / 2
    local ox = math.cos(angle) * spacing
    local oy = math.sin(angle) * spacing * 0.6
    local e = M.spawn(x + ox, y + oy, "fighter", "red")
    e.squadronId = sqId
    e.squadronShielded = true
    e.health = 2
    e.maxHealth = 2
    e.score = 50
    e.vy = 100  -- Slower than normal
    e.type = "squadron"
    e.color = "squadron"
    e.width = 20
    e.height = 20
    -- Store formation offset for maintaining formation
    e.formationOffsetX = ox
    e.formationOffsetY = oy
    e.formationCenterX = x
    e.formationCenterY = y
    table.insert(members, e)
  end

  return members
end

--- Get all living squadron members with the given ID
function M.getSquadronMembers(squadronId)
  local members = {}
  for _, e in ipairs(M.enemies) do
    if e.squadronId == squadronId then
      table.insert(members, e)
    end
  end
  return members
end

--- Check if all squadron members are currently multi-targeted
function M.isSquadronFullyTargeted(squadronId, targeting)
  local members = M.getSquadronMembers(squadronId)
  if #members == 0 then return false end
  for _, m in ipairs(members) do
    if not (targeting.locks[m] and targeting.locks[m].locked) then
      return false
    end
  end
  return true
end

function M.spawnFormation(formation, x, y, count, color)
  local enemies = {}

  if formation == "v" then
    for i = 1, count do
      local offset = (i - math.ceil(count / 2)) * 40
      local yOff = math.abs(offset) * 0.5
      table.insert(enemies, M.spawn(x + offset, y + yOff, "fighter", color))
    end
  elseif formation == "line" then
    for i = 1, count do
      local offset = (i - math.ceil(count / 2)) * 50
      table.insert(enemies, M.spawn(x + offset, y, "fighter", color))
    end
  elseif formation == "wave" then
    for i = 1, count do
      local offset = (i - 1) * 60
      table.insert(enemies, M.spawn(100 + offset, y, "fighter", color))
    end
  elseif formation == "diamond" then
    -- Diamond: red sides, blue/green center
    table.insert(enemies, M.spawn(x, y - 40, "fighter", "blue"))
    table.insert(enemies, M.spawn(x - 50, y, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 50, y, "fighter", "red"))
    table.insert(enemies, M.spawn(x, y + 40, "fighter", "green"))
  elseif formation == "box" then
    -- Box: green corners, blue center
    table.insert(enemies, M.spawn(x - 40, y - 40, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 40, y - 40, "fighter", "red"))
    table.insert(enemies, M.spawn(x, y, "fighter", "blue"))
    table.insert(enemies, M.spawn(x - 40, y + 40, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 40, y + 40, "fighter", "red"))
  elseif formation == "triangle" then
    -- Triangle: red base, green/blue tip
    table.insert(enemies, M.spawn(x, y - 50, "fighter", "blue"))
    table.insert(enemies, M.spawn(x - 30, y, "fighter", "green"))
    table.insert(enemies, M.spawn(x + 30, y, "fighter", "green"))
    table.insert(enemies, M.spawn(x - 60, y + 30, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 60, y + 30, "fighter", "red"))
  elseif formation == "squadron3" then
    -- Squadron of 3 (requires multi-target to kill)
    local squad = M.spawnSquadronGroup(x, y, 3)
    for _, s in ipairs(squad) do table.insert(enemies, s) end
  elseif formation == "squadron4" then
    -- Squadron of 4 (requires multi-target to kill)
    local squad = M.spawnSquadronGroup(x, y, 4)
    for _, s in ipairs(squad) do table.insert(enemies, s) end
  end

  return #enemies
end

function M.update(dt, playerX, playerY, speedScale, attractToPlayer)
  local escapedCount = 0
  local scaledDt = dt * (speedScale or 1.0)
  M.rotationTime = M.rotationTime + dt

  -- First pass: update squadron center positions
  local squadronCenters = {}
  for _, enemy in ipairs(M.enemies) do
    if enemy.squadronId and enemy.formationCenterY then
      enemy.formationCenterY = enemy.formationCenterY + (enemy.vy or 100) * scaledDt
      if not squadronCenters[enemy.squadronId] then
        squadronCenters[enemy.squadronId] = {x = enemy.formationCenterX, y = enemy.formationCenterY}
      end
    end
  end

  for i = #M.enemies, 1, -1 do
    local enemy = M.enemies[i]

    -- Attract enemies toward player if ability active
    if attractToPlayer and playerX and playerY then
      local dx = playerX - enemy.x
      local dy = playerY - enemy.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 1 then
        local attractSpeed = 80
        enemy.x = enemy.x + (dx / dist) * attractSpeed * scaledDt
        enemy.y = enemy.y + (dy / dist) * attractSpeed * scaledDt
      end
    end

    -- Squadron enemies maintain formation with rotation
    if enemy.squadronId and enemy.formationOffsetX then
      local center = squadronCenters[enemy.squadronId]
      if center then
        local rot = M.rotationTime * 1.5  -- Rotation speed
        local ox = enemy.formationOffsetX * math.cos(rot) - enemy.formationOffsetY * math.sin(rot)
        local oy = enemy.formationOffsetX * math.sin(rot) + enemy.formationOffsetY * math.cos(rot)
        enemy.x = center.x + ox
        enemy.y = center.y + oy
        enemy.formationCenterX = center.x
        enemy.formationCenterY = center.y
      end
    else
      if enemy.vx then
        enemy.x = enemy.x + enemy.vx * scaledDt
      end
      if enemy.vy then
        enemy.y = enemy.y + enemy.vy * scaledDt
      end
    end

    enemy.shootTimer = enemy.shootTimer - dt

    if enemy.y > screen.HEIGHT + 50 or enemy.y < -50 then
      if enemy.y > screen.HEIGHT + 50 then
        escapedCount = escapedCount + 1
      end
      table.remove(M.enemies, i)
    end
  end
  return escapedCount
end

function M.damage(enemy, amount)
  -- Squadron enemies are shielded unless their shield has been dropped
  if enemy.squadronId and enemy.squadronShielded then
    -- Damage is blocked by squadron shield - visual feedback only
    return false
  end
  enemy.health = enemy.health - amount
  return enemy.health <= 0
end

--- Drop squadron shields when all members are multi-targeted
--- Called from init.lua when missiles are fired at a fully-targeted squadron
function M.dropSquadronShields(squadronId)
  for _, e in ipairs(M.enemies) do
    if e.squadronId == squadronId then
      e.squadronShielded = false
    end
  end
end

function M.remove(enemy)
  for i, e in ipairs(M.enemies) do
    if e == enemy then
      table.remove(M.enemies, i)
      return true
    end
  end
  return false
end

return M

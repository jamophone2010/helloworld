local M = {}

local screen = require("starfox.screen")
local enemies = require("starfox.enemies")

M.mothership = nil

function M.reset()
  M.mothership = nil
end

function M.spawn(x)
  M.mothership = {
    x = x,
    y = -150,
    targetY = 120,
    width = 300,
    height = 150,
    hullHealth = 240,
    hullMaxHealth = 240,
    coreHealth = 160,
    coreMaxHealth = 160,
    phase = 1,
    score = 2000,
    time = 0,
    spawnTimer = 3,
    shootTimer = 2,
    active = true,
    entering = true,
    shouldSpawnFighters = false,
    shouldShoot = false
  }
  return M.mothership
end

function M.update(dt, playerX, playerY)
  local m = M.mothership
  if not m or not m.active then return end

  m.time = m.time + dt

  -- Entry animation
  if m.entering then
    m.y = m.y + 60 * dt
    if m.y >= m.targetY then
      m.y = m.targetY
      m.entering = false
    end
    return
  end

  -- Horizontal sway
  local centerX = screen.WIDTH / 2
  m.x = centerX + math.sin(m.time * 0.5) * 100

  -- Spawn timer
  m.spawnTimer = m.spawnTimer - dt
  if m.spawnTimer <= 0 then
    m.spawnTimer = 3
    m.shouldSpawnFighters = true
  else
    m.shouldSpawnFighters = false
  end

  -- Shoot timer
  m.shootTimer = m.shootTimer - dt
  if m.shootTimer <= 0 then
    m.shootTimer = 2
    m.shouldShoot = true
  else
    m.shouldShoot = false
  end
end

function M.damage(amount)
  local m = M.mothership
  if not m or not m.active then return {dead = false} end

  if m.phase == 1 then
    m.hullHealth = m.hullHealth - amount
    if m.hullHealth <= 0 then
      m.hullHealth = 0
      m.phase = 2
      return {dead = false, hullDestroyed = true}
    end
    return {dead = false, hitHull = true}
  else
    m.coreHealth = m.coreHealth - amount
    if m.coreHealth <= 0 then
      m.coreHealth = 0
      m.active = false
      return {dead = true}
    end
    return {dead = false, hitCore = true}
  end
end

function M.isActive()
  return M.mothership ~= nil and M.mothership.active
end

function M.isDefeated()
  return M.mothership ~= nil and not M.mothership.active and M.mothership.coreHealth <= 0
end

function M.getSpawnPositions()
  local m = M.mothership
  if not m then return nil end
  return {
    {x = m.x - 80, y = m.y + m.height/2 + 20},
    {x = m.x + 80, y = m.y + m.height/2 + 20}
  }
end

function M.getShootPositions()
  local m = M.mothership
  if not m then return nil end
  return {
    {x = m.x - 60, y = m.y + m.height/2},
    {x = m.x, y = m.y + m.height/2},
    {x = m.x + 60, y = m.y + m.height/2}
  }
end

return M

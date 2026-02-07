local M = {}

M.active = false
M.explosion = nil

function M.reset()
  M.active = false
  M.explosion = nil
end

function M.start(x, y, bossWidth, bossHeight)
  M.active = true
  M.explosion = {
    x = x,
    y = y,
    bossW = bossWidth or 80,
    bossH = bossHeight or 80,
    time = 0,
    duration = 3.0,

    -- Chain explosions
    chainTimer = 0,
    chainInterval = 0.12,
    chainBursts = {},

    -- Stage 3: Shockwave + bloom
    shockwaveRadius = 0,
    shockwaveMaxRadius = 500,
    shockwaveStarted = false,
    bloomAlpha = 1,

    -- Stage 4: Fade
    fadeAlpha = 1,

    -- Particles
    debris = {},
    sparks = {}
  }
end

function M.isActive()
  return M.active
end

local debrisColors = {
  {1, 0.8, 0.2},
  {1, 0.5, 0.1},
  {1, 0.3, 0.1},
  {0.8, 0.2, 0.1},
  {1, 1, 0.6}
}

local function spawnDebris(e, x, y, count)
  for i = 1, count do
    local angle = math.random() * math.pi * 2
    local speed = math.random(80, 300)
    table.insert(e.debris, {
      x = x, y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = math.random() * 1.0 + 0.5,
      maxLife = 1.5,
      size = math.random(3, 8),
      color = debrisColors[math.random(1, #debrisColors)],
      glowing = math.random() < 0.3
    })
  end
end

local function spawnSparks(e, x, y, count)
  for i = 1, count do
    local angle = math.random() * math.pi * 2
    local speed = math.random(150, 500)
    table.insert(e.sparks, {
      x = x, y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = math.random() * 0.3 + 0.2,
      maxLife = 0.5
    })
  end
end

function M.update(dt)
  if not M.active then return end
  local e = M.explosion

  e.time = e.time + dt

  -- Stage 2: Chain explosions
  if e.time > 0.15 and e.time < 1.5 then
    e.chainTimer = e.chainTimer + dt
    while e.chainTimer >= e.chainInterval do
      e.chainTimer = e.chainTimer - e.chainInterval
      local spread = 1 + (e.time / 1.5) * 2
      local ox = (math.random() - 0.5) * e.bossW * spread
      local oy = (math.random() - 0.5) * e.bossH * spread
      table.insert(e.chainBursts, {
        x = e.x + ox, y = e.y + oy,
        radius = 0, maxRadius = math.random(20, 50),
        life = 0.4, maxLife = 0.4
      })
      spawnDebris(e, e.x + ox, e.y + oy, 4)
      spawnSparks(e, e.x + ox, e.y + oy, 6)
    end
  end

  -- Update chain bursts
  for i = #e.chainBursts, 1, -1 do
    local b = e.chainBursts[i]
    b.life = b.life - dt
    b.radius = b.maxRadius * (1 - b.life / b.maxLife)
    if b.life <= 0 then table.remove(e.chainBursts, i) end
  end

  -- Stage 3: Shockwave
  if e.time >= 1.0 and not e.shockwaveStarted then
    e.shockwaveStarted = true
    spawnDebris(e, e.x, e.y, 30)
    spawnSparks(e, e.x, e.y, 40)
  end
  if e.shockwaveStarted then
    local t = (e.time - 1.0) / 1.5
    e.shockwaveRadius = e.shockwaveMaxRadius * math.min(t, 1)
    e.bloomAlpha = math.max(0, 1 - t * 0.8)
  end

  -- Stage 4: Fade
  if e.time >= 2.5 then
    e.fadeAlpha = math.max(0, 1 - (e.time - 2.5) / 0.5)
  end

  -- Update debris
  for i = #e.debris, 1, -1 do
    local d = e.debris[i]
    d.x = d.x + d.vx * dt
    d.y = d.y + d.vy * dt
    d.vx = d.vx * 0.97
    d.vy = d.vy * 0.97
    d.life = d.life - dt
    if d.life <= 0 then table.remove(e.debris, i) end
  end

  -- Update sparks
  for i = #e.sparks, 1, -1 do
    local s = e.sparks[i]
    s.x = s.x + s.vx * dt
    s.y = s.y + s.vy * dt
    s.life = s.life - dt
    if s.life <= 0 then table.remove(e.sparks, i) end
  end

  -- Finish
  if e.time >= e.duration then
    M.active = false
  end
end

function M.draw()
  if not M.active or not M.explosion then return end
  local e = M.explosion

  local prevBlend = love.graphics.getBlendMode()

  -- Chain explosion bursts (additive bloom)
  love.graphics.setBlendMode("add")
  for _, b in ipairs(e.chainBursts) do
    local alpha = b.life / b.maxLife
    for layer = 5, 1, -1 do
      local r = b.radius * (1 + layer * 0.3)
      local a = alpha * (0.4 / layer)
      love.graphics.setColor(1, 0.6, 0.1, a)
      love.graphics.circle("fill", b.x, b.y, r)
    end
    -- Hot core
    love.graphics.setColor(1, 1, 0.8, alpha * 0.9)
    love.graphics.circle("fill", b.x, b.y, b.radius * 0.4)
  end

  -- 3) Central bloom
  if e.shockwaveStarted and e.bloomAlpha > 0 then
    for i = 8, 1, -1 do
      local r = 30 + i * 25
      local a = e.bloomAlpha * (0.3 / i)
      love.graphics.setColor(1, 0.7, 0.3, a)
      love.graphics.circle("fill", e.x, e.y, r)
    end
    -- White hot center
    love.graphics.setColor(1, 1, 0.9, e.bloomAlpha * 0.7)
    love.graphics.circle("fill", e.x, e.y, 30 * e.bloomAlpha)
  end

  -- 4) Sparks
  for _, s in ipairs(e.sparks) do
    local alpha = s.life / s.maxLife
    love.graphics.setColor(1, 1, 0.8, alpha)
    love.graphics.circle("fill", s.x, s.y, 2)
    love.graphics.setColor(1, 0.8, 0.3, alpha * 0.4)
    love.graphics.circle("fill", s.x, s.y, 5)
  end

  -- 5) Shockwave ring
  if e.shockwaveStarted and e.shockwaveRadius > 0 then
    local ringAlpha = math.max(0, 1 - e.shockwaveRadius / e.shockwaveMaxRadius)
    -- Outer glow ring
    love.graphics.setColor(1, 0.6, 0.2, ringAlpha * 0.3)
    love.graphics.setLineWidth(12)
    love.graphics.circle("line", e.x, e.y, e.shockwaveRadius)
    -- Inner bright ring
    love.graphics.setColor(1, 0.9, 0.6, ringAlpha * 0.6)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", e.x, e.y, e.shockwaveRadius)
    -- Second ring (trailing)
    love.graphics.setColor(1, 0.4, 0.1, ringAlpha * 0.2)
    love.graphics.setLineWidth(8)
    love.graphics.circle("line", e.x, e.y, e.shockwaveRadius * 0.85)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setBlendMode(prevBlend)

  -- 6) Debris (normal blend)
  for _, d in ipairs(e.debris) do
    local alpha = d.life / d.maxLife
    love.graphics.setColor(d.color[1], d.color[2], d.color[3], alpha)
    love.graphics.circle("fill", d.x, d.y, d.size)
    if d.glowing then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(d.color[1], d.color[2], d.color[3], alpha * 0.3)
      love.graphics.circle("fill", d.x, d.y, d.size * 2.5)
      love.graphics.setBlendMode(prevBlend)
    end
  end
end

return M

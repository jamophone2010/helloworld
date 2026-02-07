local M = {}

M.particles = {}

function M.reset()
  M.particles = {}
end

function M.spawn(x, y, count, color)
  for i = 1, (count or 10) do
    local angle = math.random() * math.pi * 2
    local speed = math.random(50, 200)

    table.insert(M.particles, {
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = math.random() * 0.5 + 0.5,
      maxLife = 1,
      color = color or {1, 0.5, 0},
      size = math.random(2, 5)
    })
  end
end

function M.spawnPaladinExplosion(x, y, radius, chargeLevel)
  local particleCount = math.floor(30 + radius * 0.5)  -- More particles for larger blasts

  -- Outer ring burst
  for i = 1, particleCount do
    local angle = math.random() * math.pi * 2
    local speed = math.random(100, 300) * (1 + chargeLevel * 0.5)

    table.insert(M.particles, {
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 1.0 + chargeLevel * 0.5,
      maxLife = 1.0 + chargeLevel * 0.5,
      color = {0.3, 1, 0.5},
      size = math.random(4, 8),
      bloom = true  -- Flag for bloom effect
    })
  end

  -- Inner bright flash particles
  for i = 1, math.floor(15 + radius * 0.3) do
    local angle = math.random() * math.pi * 2
    local speed = math.random(50, 150)

    table.insert(M.particles, {
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.6,
      maxLife = 0.6,
      color = {1, 1, 1},
      size = math.random(6, 12),
      bloom = true
    })
  end

  -- Shockwave ring particles
  for i = 0, 20 do
    local angle = (i / 20) * math.pi * 2
    local speed = 200 + chargeLevel * 100

    table.insert(M.particles, {
      x = x + math.cos(angle) * radius * 0.3,
      y = y + math.sin(angle) * radius * 0.3,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.8,
      maxLife = 0.8,
      color = {0.5, 1, 0.7},
      size = 5,
      bloom = true
    })
  end
end

function M.update(dt)
  for i = #M.particles, 1, -1 do
    local p = M.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    p.vx = p.vx * 0.98
    p.vy = p.vy * 0.98

    if p.life <= 0 then
      table.remove(M.particles, i)
    end
  end
end

return M

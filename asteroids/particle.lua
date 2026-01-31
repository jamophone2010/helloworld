local M = {}

function M.new(xloc, yloc)
  local particles = {}
  for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2
    local speed = math.random(50, 150)
    table.insert(particles, {
      x = xloc,
      y = yloc,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      lifetime = math.random() * 0.5 + 0.5,
      maxLife = 1
    })
  end
  return particles
end

function M.update(particles, dt)
  for i = #particles, 1, -1 do
    local p = particles[i]

    if p.vx == nil then
      p.vx = 1
    end
    if p.vy == nil then
      p.vy = 1
    end

    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.lifetime = p.lifetime - dt

    if p.lifetime <= 0 then
      table.remove(particles, i)
    end
  end
end

return M

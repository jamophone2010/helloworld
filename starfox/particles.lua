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

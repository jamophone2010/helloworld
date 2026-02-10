local M = {}

-- Nebula cloud data
local clouds = {}
local stars = {}
local dustLanes = {}
local time = 0

-- Color palettes inspired by Webb/Hubble images
local palettes = {
  -- Carina Nebula (orange/blue/purple)
  {
    {0.6, 0.3, 0.15, 0.18},  -- orange
    {0.2, 0.35, 0.6, 0.15}, -- blue
    {0.4, 0.2, 0.5, 0.12},  -- purple
    {0.5, 0.4, 0.2, 0.1}, -- gold
  },
  -- Pillars of Creation (green/gold/brown)
  {
    {0.3, 0.4, 0.2, 0.18},  -- green
    {0.5, 0.35, 0.15, 0.15}, -- gold
    {0.35, 0.2, 0.15, 0.12},  -- brown
    {0.2, 0.3, 0.35, 0.1}, -- teal
  },
  -- Orion Nebula (pink/blue/cyan)
  {
    {0.6, 0.3, 0.35, 0.18},  -- pink
    {0.2, 0.4, 0.6, 0.15}, -- blue
    {0.2, 0.5, 0.5, 0.12},  -- cyan
    {0.5, 0.2, 0.4, 0.1}, -- magenta
  },
  -- Deep field (red/blue/violet)
  {
    {0.5, 0.15, 0.2, 0.18},  -- red
    {0.15, 0.2, 0.5, 0.15}, -- deep blue
    {0.35, 0.15, 0.45, 0.12},  -- violet
    {0.2, 0.3, 0.4, 0.1}, -- slate
  },
}

local currentPalette = 1

function M.init(width, height, tileX, tileY)
  -- Use tile coordinates to generate unique seed per tile
  local seed = (tileX * 1000 + tileY * 100) + os.time()
  math.randomseed(seed)
  clouds = {}
  stars = {}
  dustLanes = {}
  time = 0

  -- Pick palette based on tile coordinates for consistency
  currentPalette = ((tileX + tileY + 10) % #palettes) + 1

  -- Generate background stars (distant)
  for i = 1, 200 do
    table.insert(stars, {
      x = math.random() * width,
      y = math.random() * height,
      size = math.random() * 1.5 + 0.5,
      brightness = math.random() * 0.5 + 0.3,
      twinkleSpeed = math.random() * 2 + 1,
      twinkleOffset = math.random() * math.pi * 2,
      color = math.random() < 0.1 and {0.8, 0.9, 1.0} or {1.0, 1.0, 1.0}
    })
  end

  -- Generate bright foreground stars
  for i = 1, 30 do
    local brightness = math.random() * 0.3 + 0.7
    local starColor = math.random()
    local r, g, b
    if starColor < 0.3 then
      r, g, b = 1.0, 0.9, 0.8  -- warm
    elseif starColor < 0.6 then
      r, g, b = 0.9, 0.95, 1.0  -- cool
    else
      r, g, b = 1.0, 1.0, 1.0  -- white
    end
    table.insert(stars, {
      x = math.random() * width,
      y = math.random() * height,
      size = math.random() * 2 + 2,
      brightness = brightness,
      twinkleSpeed = math.random() * 3 + 2,
      twinkleOffset = math.random() * math.pi * 2,
      color = {r, g, b},
      hasDiffraction = math.random() < 0.3
    })
  end

  -- Generate nebula clouds
  local palette = palettes[currentPalette]
  for i = 1, 15 do
    local colorIdx = math.random(1, #palette)
    table.insert(clouds, {
      x = math.random() * width,
      y = math.random() * height,
      radius = math.random() * 200 + 100,
      color = palette[colorIdx],
      driftX = (math.random() - 0.5) * 5,
      driftY = (math.random() - 0.5) * 5,
      pulseSpeed = math.random() * 0.5 + 0.2,
      pulseOffset = math.random() * math.pi * 2,
      layers = math.random(2, 4)
    })
  end

  -- Generate dust lanes (darker regions)
  for i = 1, 5 do
    local points = {}
    local startX = math.random() * width
    local startY = math.random() * height
    local angle = math.random() * math.pi * 2
    for j = 1, 8 do
      table.insert(points, {
        x = startX + math.cos(angle) * j * 80 + (math.random() - 0.5) * 60,
        y = startY + math.sin(angle) * j * 80 + (math.random() - 0.5) * 60
      })
    end
    table.insert(dustLanes, {
      points = points,
      width = math.random() * 40 + 30,
      opacity = math.random() * 0.3 + 0.2
    })
  end
end

function M.update(dt)
  time = time + dt

  -- Slowly drift clouds
  for _, cloud in ipairs(clouds) do
    cloud.x = cloud.x + cloud.driftX * dt * 0.1
    cloud.y = cloud.y + cloud.driftY * dt * 0.1
  end
end

function M.draw(width, height)
  -- Dark space background with subtle gradient
  love.graphics.setColor(0.02, 0.02, 0.05)
  love.graphics.rectangle("fill", 0, 0, width, height)

  -- Draw dust lanes first (darkening)
  for _, lane in ipairs(dustLanes) do
    love.graphics.setColor(0, 0, 0, lane.opacity * 0.5)
    for i = 1, #lane.points - 1 do
      local p1, p2 = lane.points[i], lane.points[i + 1]
      -- Draw thick line segments
      local dx = p2.x - p1.x
      local dy = p2.y - p1.y
      local len = math.sqrt(dx * dx + dy * dy)
      local nx, ny = -dy / len, dx / len
      local w = lane.width

      love.graphics.polygon("fill",
        p1.x + nx * w, p1.y + ny * w,
        p1.x - nx * w, p1.y - ny * w,
        p2.x - nx * w, p2.y - ny * w,
        p2.x + nx * w, p2.y + ny * w
      )
    end
  end

  -- Draw nebula clouds (multiple layers for depth)
  for _, cloud in ipairs(clouds) do
    local pulse = math.sin(time * cloud.pulseSpeed + cloud.pulseOffset) * 0.1 + 1
    local baseRadius = cloud.radius * pulse

    -- Draw multiple layers with decreasing opacity
    for layer = cloud.layers, 1, -1 do
      local layerRadius = baseRadius * (0.3 + layer * 0.25)
      local layerOpacity = cloud.color[4] * (1 - layer * 0.2)

      -- Use multiple overlapping circles for soft edges
      for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2 + time * 0.05
        local offsetX = math.cos(angle) * layerRadius * 0.3
        local offsetY = math.sin(angle) * layerRadius * 0.3

        love.graphics.setColor(cloud.color[1], cloud.color[2], cloud.color[3], layerOpacity * 0.3)
        love.graphics.circle("fill",
          (cloud.x + offsetX) % width,
          (cloud.y + offsetY) % height,
          layerRadius * 0.7
        )
      end

      -- Core glow
      love.graphics.setColor(cloud.color[1], cloud.color[2], cloud.color[3], layerOpacity * 0.5)
      love.graphics.circle("fill", cloud.x % width, cloud.y % height, layerRadius * 0.5)
    end
  end

  -- Draw background stars
  for _, star in ipairs(stars) do
    local twinkle = math.sin(time * star.twinkleSpeed + star.twinkleOffset) * 0.3 + 0.7
    local alpha = star.brightness * twinkle

    love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha)
    love.graphics.circle("fill", star.x, star.y, star.size)

    -- Diffraction spikes for bright stars
    if star.hasDiffraction then
      love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha * 0.4)
      local spikeLen = star.size * 4
      love.graphics.setLineWidth(1)
      love.graphics.line(star.x - spikeLen, star.y, star.x + spikeLen, star.y)
      love.graphics.line(star.x, star.y - spikeLen, star.x, star.y + spikeLen)
      -- Diagonal spikes (fainter)
      love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha * 0.2)
      local diagLen = spikeLen * 0.7
      love.graphics.line(star.x - diagLen, star.y - diagLen, star.x + diagLen, star.y + diagLen)
      love.graphics.line(star.x - diagLen, star.y + diagLen, star.x + diagLen, star.y - diagLen)
    end
  end
end

-- Regenerate with new palette for tile transitions
function M.changePalette(width, height)
  currentPalette = (currentPalette % #palettes) + 1
  local palette = palettes[currentPalette]

  -- Update cloud colors
  for _, cloud in ipairs(clouds) do
    local colorIdx = math.random(1, #palette)
    cloud.color = palette[colorIdx]
  end
end

return M

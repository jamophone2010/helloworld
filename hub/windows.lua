-- hub/windows.lua
-- Galaxy window views for the space station
-- Each floor has a different vista visible through station windows
-- Inspired by the views in No Man's Sky / Mass Effect Citadel

local M = {}

-- Star field particles (persistent, scroll slowly)
M.stars = {}
M.nebulaClouds = {}
M.initialized = false

function M.init()
  if M.initialized then return end
  M.initialized = true

  -- Generate persistent star field
  for i = 1, 200 do
    M.stars[i] = {
      x = math.random() * 1600,
      y = math.random() * 900,
      brightness = 0.3 + math.random() * 0.7,
      size = 0.5 + math.random() * 1.5,
      twinkleSpeed = 1 + math.random() * 3,
      twinkleOffset = math.random() * math.pi * 2,
      layer = math.random(1, 3) -- parallax depth
    }
  end

  -- Generate nebula clouds
  for i = 1, 8 do
    M.nebulaClouds[i] = {
      x = math.random() * 1600,
      y = math.random() * 900,
      radius = 80 + math.random() * 200,
      r = math.random() * 0.3,
      g = math.random() * 0.15,
      b = 0.1 + math.random() * 0.3,
      alpha = 0.02 + math.random() * 0.05,
      driftSpeed = 0.5 + math.random() * 1.5
    }
  end
end

-- Window style definitions per floor
-- Each defines what you see through the windows
local windowStyles = {
  void = {
    -- Floor 0: Dark void with occasional red emergency lights
    bgColor = {0.01, 0.01, 0.02},
    showStars = false,
    showNebula = false,
    special = "void_pulse"
  },
  docking = {
    -- Floor 1: Docking bay view, cargo ships passing
    bgColor = {0.02, 0.03, 0.05},
    showStars = true,
    showNebula = false,
    special = "docking_lights"
  },
  nebula = {
    -- Floor 2: Colorful nebula vista (casino atmosphere)
    bgColor = {0.03, 0.01, 0.05},
    showStars = true,
    showNebula = true,
    special = "nebula_shimmer"
  },
  starfield = {
    -- Floor 3: Classic starfield, peaceful residential view
    bgColor = {0.01, 0.01, 0.04},
    showStars = true,
    showNebula = false,
    special = "shooting_stars"
  },
  launch = {
    -- Floor 4: Launch bay, ships taking off, runway lights
    bgColor = {0.02, 0.04, 0.06},
    showStars = true,
    showNebula = false,
    special = "runway_lights"
  },
  panorama = {
    -- Floor 5: Full panoramic galaxy view (Skyfall Macau bar vibes)
    bgColor = {0.02, 0.01, 0.04},
    showStars = true,
    showNebula = true,
    special = "galaxy_spiral"
  },
  cosmos = {
    -- Floor 6: Above it all, command bridge view of entire galaxy
    bgColor = {0.01, 0.02, 0.03},
    showStars = true,
    showNebula = true,
    special = "command_holo"
  }
}

-- Draw the base star field
local function drawStars(time, style)
  for _, star in ipairs(M.stars) do
    local twinkle = 0.5 + 0.5 * math.sin(time * star.twinkleSpeed + star.twinkleOffset)
    local alpha = star.brightness * twinkle

    -- Parallax drift
    local drift = time * (4 - star.layer) * 2
    local sx = (star.x - drift) % 1600
    local sy = star.y

    love.graphics.setColor(0.8, 0.85, 1.0, alpha)
    love.graphics.circle("fill", sx, sy, star.size)

    -- Bright stars get a small cross
    if star.brightness > 0.8 and twinkle > 0.7 then
      love.graphics.setColor(0.9, 0.95, 1.0, alpha * 0.4)
      love.graphics.line(sx - 3, sy, sx + 3, sy)
      love.graphics.line(sx, sy - 3, sx, sy + 3)
    end
  end
end

-- Draw nebula clouds
local function drawNebula(time)
  for _, cloud in ipairs(M.nebulaClouds) do
    local cx = (cloud.x + time * cloud.driftSpeed) % 1600
    local cy = cloud.y + math.sin(time * 0.3 + cloud.x) * 10

    -- Multiple layered circles for soft cloud effect
    for j = 1, 4 do
      local r = cloud.radius * (1 - j * 0.15)
      local a = cloud.alpha * (1 - j * 0.2)
      love.graphics.setColor(cloud.r, cloud.g, cloud.b, a)
      love.graphics.circle("fill", cx + j*5, cy + j*3, r)
    end
  end
end

-- Special effects per window style
local function drawVoidPulse(time)
  -- Eerie red pulsing in the void
  local pulse = 0.02 + 0.02 * math.sin(time * 0.5)
  love.graphics.setColor(0.3, 0.0, 0.0, pulse)
  love.graphics.rectangle("fill", 0, 0, 1600, 900)

  -- Occasional emergency light flash
  if math.sin(time * 3) > 0.95 then
    love.graphics.setColor(0.5, 0.0, 0.0, 0.15)
    love.graphics.rectangle("fill", 0, 0, 1600, 900)
  end
end

local function drawDockingLights(time)
  -- Blinking docking guide lights
  for i = 0, 8 do
    local phase = (time * 2 + i * 0.3) % 1
    local alpha = phase < 0.5 and 0.5 or 0.1
    love.graphics.setColor(0.2, 0.8, 0.2, alpha)
    love.graphics.circle("fill", 200 + i * 150, 700, 3)
  end

  -- Beacon
  local beaconPulse = 0.3 + 0.3 * math.sin(time * 4)
  love.graphics.setColor(1.0, 0.5, 0.0, beaconPulse)
  love.graphics.circle("fill", 1300, 200, 8)
  love.graphics.setColor(1.0, 0.5, 0.0, beaconPulse * 0.3)
  love.graphics.circle("fill", 1300, 200, 20)
end

local function drawNebulaShimmer(time)
  -- Extra shimmer for casino floor atmosphere
  local shimmer = 0.03 + 0.02 * math.sin(time * 1.5)
  love.graphics.setColor(0.4, 0.1, 0.5, shimmer)
  love.graphics.rectangle("fill", 0, 0, 1600, 900)

  -- Sparkle particles
  for i = 1, 5 do
    local sx = (math.sin(time * 0.7 + i * 2.3) * 0.5 + 0.5) * 1600
    local sy = (math.cos(time * 0.5 + i * 1.7) * 0.5 + 0.5) * 900
    local sparkle = math.abs(math.sin(time * 3 + i))
    love.graphics.setColor(0.8, 0.6, 1.0, sparkle * 0.4)
    love.graphics.circle("fill", sx, sy, 2)
  end
end

local function drawShootingStars(time)
  -- Occasional shooting stars across the residential view
  for i = 1, 3 do
    local cycle = (time * 0.3 + i * 7.1) % 12
    if cycle < 0.5 then
      local progress = cycle / 0.5
      local sx = progress * 1600
      local sy = 100 + i * 200 - progress * 80
      local len = 60
      love.graphics.setColor(1.0, 1.0, 1.0, (1 - progress) * 0.8)
      love.graphics.line(sx, sy, sx - len, sy + len * 0.3)
      love.graphics.setColor(0.6, 0.8, 1.0, (1 - progress) * 0.3)
      love.graphics.line(sx - len, sy + len * 0.3, sx - len * 2, sy + len * 0.6)
    end
  end
end

local function drawRunwayLights(time)
  -- Runway guide lights for the flight deck
  for row = 0, 1 do
    for i = 0, 12 do
      local phase = (time * 3 - i * 0.2) % 1
      local alpha = math.max(0, 1 - phase * 2)
      love.graphics.setColor(0.0, 0.8, 1.0, alpha * 0.6)
      love.graphics.circle("fill", 300 + i * 80, 600 + row * 100, 3)
    end
  end

  -- Landing pad glow
  local padPulse = 0.3 + 0.2 * math.sin(time * 2)
  love.graphics.setColor(0.0, 0.6, 1.0, padPulse * 0.15)
  love.graphics.rectangle("fill", 800, 550, 200, 200, 8)
  love.graphics.setColor(0.0, 0.8, 1.0, padPulse * 0.4)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", 800, 550, 200, 200, 8)
  love.graphics.setLineWidth(1)
end

local function drawGalaxySpiral(time)
  -- Faint galaxy spiral for the panoramic lookout
  local cx, cy = 800, 400
  for i = 0, 200 do
    local angle = i * 0.15 + time * 0.1
    local radius = i * 2.5
    local sx = cx + math.cos(angle) * radius
    local sy = cy + math.sin(angle) * radius * 0.4
    local alpha = 0.03 * (1 - i / 200)
    love.graphics.setColor(0.6, 0.5, 0.9, alpha)
    love.graphics.circle("fill", sx, sy, 3 + (200 - i) * 0.02)
  end
end

local function drawCommandHolo(time)
  -- Holographic grid overlay for command bridge
  love.graphics.setColor(0.2, 0.6, 1.0, 0.02)
  for x = 0, 1600, 40 do
    love.graphics.line(x, 0, x, 900)
  end
  for y = 0, 900, 40 do
    love.graphics.line(0, y, 1600, y)
  end

  -- Rotating tactical circle
  local angle = time * 0.3
  love.graphics.setColor(0.3, 0.8, 1.0, 0.06)
  love.graphics.circle("line", 800, 450, 300)
  for i = 0, 3 do
    local a = angle + i * math.pi / 2
    love.graphics.line(800, 450, 800 + math.cos(a) * 300, 450 + math.sin(a) * 300)
  end
end

local specialDrawers = {
  void_pulse = drawVoidPulse,
  docking_lights = drawDockingLights,
  nebula_shimmer = drawNebulaShimmer,
  shooting_stars = drawShootingStars,
  runway_lights = drawRunwayLights,
  galaxy_spiral = drawGalaxySpiral,
  command_holo = drawCommandHolo,
}

-- Draw a window pane at the given screen position
-- windowStyle: string key from floors.lua (void, docking, nebula, etc.)
-- x, y, w, h: screen coordinates of the window
function M.drawWindow(windowStyle, x, y, w, h, time)
  M.init()
  time = time or 0

  local style = windowStyles[windowStyle]
  if not style then style = windowStyles.starfield end

  -- Save current graphics state
  love.graphics.push()
  love.graphics.translate(x, y)

  -- Scale content to window size
  local scaleX = w / 1600
  local scaleY = h / 900
  love.graphics.scale(scaleX, scaleY)

  -- Background
  love.graphics.setColor(style.bgColor[1], style.bgColor[2], style.bgColor[3])
  love.graphics.rectangle("fill", 0, 0, 1600, 900)

  -- Stars
  if style.showStars then
    drawStars(time, style)
  end

  -- Nebula
  if style.showNebula then
    drawNebula(time)
  end

  -- Special effects
  if style.special and specialDrawers[style.special] then
    specialDrawers[style.special](time)
  end

  love.graphics.pop()

  -- Window frame (metallic border)
  love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", x, y, w, h, 2)
  love.graphics.setLineWidth(1)

  -- Inner glow at edges
  love.graphics.setColor(0.3, 0.4, 0.6, 0.1)
  love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4, 1)
end

-- Draw a row of windows along one wall of a floor
-- wallSide: "top", "bottom", "left", or "right"
function M.drawWindowRow(windowStyle, wallSide, floorWidth, floorHeight, gs, time)
  local numWindows = 0
  local winW, winH = 0, 0
  local startX, startY = 0, 0
  local stepX, stepY = 0, 0
  local screenW, screenH = love.graphics.getDimensions()

  if wallSide == "top" then
    numWindows = math.floor(floorWidth / 4)
    winW, winH = gs * 3, gs * 1.5
    startX = gs
    startY = 0
    stepX = gs * 4
    stepY = 0
  elseif wallSide == "bottom" then
    numWindows = math.floor(floorWidth / 4)
    winW, winH = gs * 3, gs * 1.5
    startX = gs
    startY = (floorHeight - 1) * gs - winH + gs
    stepX = gs * 4
    stepY = 0
  elseif wallSide == "left" then
    numWindows = math.floor(floorHeight / 4)
    winW, winH = gs * 1.5, gs * 3
    startX = 0
    startY = gs
    stepX = 0
    stepY = gs * 4
  elseif wallSide == "right" then
    numWindows = math.floor(floorHeight / 4)
    winW, winH = gs * 1.5, gs * 3
    startX = (floorWidth - 1) * gs - winW + gs
    startY = gs
    stepX = 0
    stepY = gs * 4
  end

  for i = 0, numWindows - 1 do
    local wx = startX + i * stepX
    local wy = startY + i * stepY

    M.drawWindow(windowStyle, wx, wy, winW, winH, time + i * 0.5)
  end
end

return M

local M = {}
local constellation = require("asteroids.constellation")

-- Nebula cloud data
local clouds = {}
local stars = {}
local dustLanes = {}
local time = 0

-- Current constellation visuals
local currentBgColor = {0.02, 0.02, 0.05}
local currentConstellationId = "nebula"
local currentTileX, currentTileY = 0, 0

-- Gas pillar data (for Orion)
local gasPillars = {}

-- Gargantua black hole visual data
local blackHole = {
  accretionAngle = 0,
  lensRings = {},
  warpField = {},
}

-- Pleiades bright star cluster data
local pleiadesStars = {}

-- Vela pulsar visual data
local pulsarBeam = {
  angle = 0,
  intensity = 0,
}

function M.init(width, height, tileX, tileY)
  -- Use tile coordinates to generate unique seed per tile
  local seed = (tileX * 1000 + tileY * 100) + 12345
  math.randomseed(seed)
  clouds = {}
  stars = {}
  dustLanes = {}
  gasPillars = {}
  pleiadesStars = {}
  time = 0

  -- Get constellation-specific parameters
  local cData, cId = constellation.getConstellation(tileX, tileY)
  currentConstellationId = cId
  currentBgColor = cData.bgColor
  currentTileX, currentTileY = tileX, tileY

  -- Get the appropriate palette for this tile
  local palette = constellation.getCloudPalette(tileX, tileY)
  local starParams = constellation.getStarParams(tileX, tileY)

  -- Generate background stars
  for i = 1, starParams.count do
    local colorSet = starParams.colors
    local c = colorSet[math.random(#colorSet)]
    table.insert(stars, {
      x = math.random() * width,
      y = math.random() * height,
      size = math.random() * 1.5 + 0.5,
      brightness = math.random() * 0.5 + 0.3,
      twinkleSpeed = math.random() * 2 + 1,
      twinkleOffset = math.random() * math.pi * 2,
      color = {c[1], c[2], c[3]}
    })
  end

  -- Generate bright foreground stars
  for i = 1, starParams.brightCount do
    local colorSet = starParams.colors
    local c = colorSet[math.random(#colorSet)]
    local brightness = math.random() * 0.3 + 0.7
    table.insert(stars, {
      x = math.random() * width,
      y = math.random() * height,
      size = math.random() * 2 + 2,
      brightness = brightness,
      twinkleSpeed = math.random() * 3 + 2,
      twinkleOffset = math.random() * math.pi * 2,
      color = {c[1], c[2], c[3]},
      hasDiffraction = math.random() < 0.3
    })
  end

  -- Generate nebula clouds
  local cloudCount = 15
  if cId == "orion" then cloudCount = 25 end -- More clouds for Orion
  if cId == "oort" then cloudCount = 8 end   -- Fewer clouds for Oort (dark)
  if cId == "outer_space" then cloudCount = 5 end

  for i = 1, cloudCount do
    local colorIdx = math.random(1, #palette)
    local radius = math.random() * 200 + 100
    if cId == "orion" then radius = radius * 1.5 end -- Larger clouds
    table.insert(clouds, {
      x = math.random() * width,
      y = math.random() * height,
      radius = radius,
      color = palette[colorIdx],
      driftX = (math.random() - 0.5) * 5,
      driftY = (math.random() - 0.5) * 5,
      pulseSpeed = math.random() * 0.5 + 0.2,
      pulseOffset = math.random() * math.pi * 2,
      layers = math.random(2, 4)
    })
  end

  -- Generate dust lanes
  local dustCount = 5
  if cId == "oort" then dustCount = 10 end -- More dark lanes in Oort
  if cId == "gargantua" then dustCount = 8 end

  for i = 1, dustCount do
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

  -- ===== CONSTELLATION-SPECIFIC VISUALS =====

  -- Orion: Gas pillars (tall column structures)
  if cId == "orion" and cData.gasPillars then
    for i = 1, 4 do
      local px = math.random() * width * 0.6 + width * 0.2
      local py = math.random() * height * 0.4 + height * 0.4
      table.insert(gasPillars, {
        x = px, y = py,
        width = 40 + math.random() * 60,
        height = 150 + math.random() * 250,
        color = palette[math.random(#palette)],
        sway = math.random() * math.pi * 2,
      })
    end
  end

  -- Pleiades: Extra bright blue stars with halos
  if cId == "pleiades" then
    for i = 1, 12 do
      table.insert(pleiadesStars, {
        x = math.random() * width,
        y = math.random() * height,
        size = 4 + math.random() * 8,
        haloSize = 30 + math.random() * 50,
        brightness = 0.8 + math.random() * 0.2,
        pulseSpeed = 0.5 + math.random() * 1.5,
        pulseOffset = math.random() * math.pi * 2,
      })
    end
  end

  -- Gargantua: Black hole accretion disk rings
  if cId == "gargantua" then
    blackHole.accretionAngle = 0
    blackHole.lensRings = {}
    for i = 1, 6 do
      table.insert(blackHole.lensRings, {
        radius = 60 + i * 25,
        width = 3 + math.random() * 4,
        speed = 0.5 + math.random() * 1.0,
        color = {0.9 + math.random() * 0.1, 0.6 + math.random() * 0.2, 0.1 + math.random() * 0.2},
        offset = math.random() * math.pi * 2,
      })
    end
  end
end

function M.update(dt)
  time = time + dt

  -- Slowly drift clouds
  for _, cloud in ipairs(clouds) do
    cloud.x = cloud.x + cloud.driftX * dt * 0.1
    cloud.y = cloud.y + cloud.driftY * dt * 0.1
  end

  -- Gargantua accretion rotation
  if currentConstellationId == "gargantua" then
    blackHole.accretionAngle = blackHole.accretionAngle + dt * 0.3
  end

  -- Vela pulsar beam rotation
  if currentConstellationId == "vela" then
    pulsarBeam.angle = pulsarBeam.angle + dt * 4
    local state = constellation.getVelaPulsarState(0, 0) -- approximate
    if state and state.isWarning then
      pulsarBeam.intensity = 0.3 + math.sin(time * 4) * 0.2
    elseif state and state.burstActive then
      pulsarBeam.intensity = 1.0
    else
      pulsarBeam.intensity = 0.1
    end
  end
end

function M.draw(width, height)
  -- Dark space background with constellation-specific color
  love.graphics.setColor(currentBgColor[1], currentBgColor[2], currentBgColor[3])
  love.graphics.rectangle("fill", 0, 0, width, height)

  -- Draw dust lanes first (darkening)
  for _, lane in ipairs(dustLanes) do
    love.graphics.setColor(0, 0, 0, lane.opacity * 0.5)
    for i = 1, #lane.points - 1 do
      local p1, p2 = lane.points[i], lane.points[i + 1]
      local dx = p2.x - p1.x
      local dy = p2.y - p1.y
      local len = math.sqrt(dx * dx + dy * dy)
      if len > 0 then
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
  end

  -- Draw Gargantua black hole (behind everything else)
  if currentConstellationId == "gargantua" then
    M.drawBlackHole(width, height)
  end

  -- Draw nebula clouds
  for _, cloud in ipairs(clouds) do
    local pulse = math.sin(time * cloud.pulseSpeed + cloud.pulseOffset) * 0.1 + 1
    local baseRadius = cloud.radius * pulse

    for layer = cloud.layers, 1, -1 do
      local layerRadius = baseRadius * (0.3 + layer * 0.25)
      local layerOpacity = cloud.color[4] * (1 - layer * 0.2)

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

      love.graphics.setColor(cloud.color[1], cloud.color[2], cloud.color[3], layerOpacity * 0.5)
      love.graphics.circle("fill", cloud.x % width, cloud.y % height, layerRadius * 0.5)
    end
  end

  -- Draw Orion gas pillars
  if currentConstellationId == "orion" then
    M.drawGasPillars(width, height)
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
      love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha * 0.2)
      local diagLen = spikeLen * 0.7
      love.graphics.line(star.x - diagLen, star.y - diagLen, star.x + diagLen, star.y + diagLen)
      love.graphics.line(star.x - diagLen, star.y + diagLen, star.x + diagLen, star.y - diagLen)
    end
  end

  -- Draw Pleiades bright blue stars with halos
  if currentConstellationId == "pleiades" then
    M.drawPleiadesStars(width, height)
  end

  -- Draw Vela pulsar beam
  if currentConstellationId == "vela" then
    M.drawPulsarBeam(width, height)
  end

  -- Draw Andromeda spiral structure
  if currentConstellationId == "andromeda" then
    M.drawAndromedaSpiral(width, height)
  end

  -- Draw Pandora hot sector glow (if applicable)
  if currentConstellationId == "pandora" then
    M.drawPandoraHeat(width, height)
  end

  -- Draw Oort Cloud ice particle effect
  if currentConstellationId == "oort" then
    M.drawOortIce(width, height)
  end

  -- Draw Messier dense star field overlay
  if currentConstellationId == "messier" then
    M.drawMessierStars(width, height)
  end
end

-- ===================== CONSTELLATION-SPECIFIC DRAWING =====================

function M.drawBlackHole(width, height)
  -- The black hole graphic spans the full 7x7 constellation.
  -- Calculate the pixel offset from this tile to the constellation center tile.
  local lx, ly = constellation.getLocalTilePos(currentTileX, currentTileY)
  -- Local pos 3,3 is the center tile. Offset in tiles from center:
  local dtx = 3 - lx  -- positive = center is to the right
  local dty = 3 - ly  -- positive = center is below
  -- Convert tile offset to pixel offset (each tile = one screen)
  local cx = width / 2 + dtx * width
  local cy = height / 2 + dty * height

  -- Scale everything by 3.5 to span the 7-tile-wide constellation
  local S = 3.5

  -- Dark void center
  love.graphics.setColor(0, 0, 0, 0.95)
  love.graphics.circle("fill", cx, cy, 50 * S)

  -- Gravitational lensing rings (accretion disk)
  for _, ring in ipairs(blackHole.lensRings) do
    local angle = blackHole.accretionAngle * ring.speed + ring.offset
    love.graphics.setLineWidth(ring.width * S * 0.5)

    -- Draw elliptical accretion disk (tilted view)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle * 0.1)

    -- Top arc (brighter, Doppler shifted)
    love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], 0.7)
    love.graphics.arc("line", "open", 0, 0, ring.radius * S, -math.pi * 0.8, math.pi * 0.8)

    -- Bottom arc (dimmer, behind the hole)
    love.graphics.setColor(ring.color[1] * 0.4, ring.color[2] * 0.4, ring.color[3] * 0.4, 0.4)
    love.graphics.arc("line", "open", 0, 0, ring.radius * S, math.pi * 0.2, math.pi * 1.8)

    love.graphics.pop()
  end

  -- Photon sphere (bright ring at event horizon)
  love.graphics.setLineWidth(2 * S)
  love.graphics.setColor(1, 0.85, 0.4, 0.6 + math.sin(time * 2) * 0.2)
  love.graphics.circle("line", cx, cy, 55 * S)
  love.graphics.setColor(1, 0.9, 0.6, 0.3)
  love.graphics.circle("line", cx, cy, 58 * S)

  -- Gravitational lensing distortion glow
  love.graphics.setColor(0.9, 0.6, 0.15, 0.15)
  love.graphics.circle("fill", cx, cy, 100 * S)
  love.graphics.setColor(0.7, 0.4, 0.1, 0.08)
  love.graphics.circle("fill", cx, cy, 150 * S)

  -- Far-field gravitational haze (visible from distant tiles)
  love.graphics.setColor(0.4, 0.25, 0.05, 0.04)
  love.graphics.circle("fill", cx, cy, 250 * S)

  love.graphics.setLineWidth(1)
end

function M.drawGasPillars(width, height)
  for _, pillar in ipairs(gasPillars) do
    local sway = math.sin(time * 0.3 + pillar.sway) * 10
    local c = pillar.color

    -- Draw pillar as layered trapezoids
    for layer = 3, 1, -1 do
      local w = pillar.width * (0.5 + layer * 0.2)
      local h = pillar.height * (0.7 + layer * 0.1)
      local alpha = c[4] * (0.8 - layer * 0.15)

      love.graphics.setColor(c[1], c[2], c[3], alpha)
      love.graphics.polygon("fill",
        pillar.x - w / 2 + sway, pillar.y,
        pillar.x + w / 2 + sway, pillar.y,
        pillar.x + w / 3 + sway * 0.5, pillar.y - h,
        pillar.x - w / 3 + sway * 0.5, pillar.y - h
      )
    end

    -- Bright tip (star-forming region)
    love.graphics.setColor(1, 0.9, 0.8, 0.3 + math.sin(time + pillar.sway) * 0.1)
    love.graphics.circle("fill", pillar.x + sway * 0.5, pillar.y - pillar.height, 8)
  end
end

function M.drawPleiadesStars(width, height)
  for _, ps in ipairs(pleiadesStars) do
    local pulse = math.sin(time * ps.pulseSpeed + ps.pulseOffset) * 0.2 + 0.8
    local alpha = ps.brightness * pulse

    -- Large outer halo (reflection nebula)
    love.graphics.setColor(0.3, 0.5, 1.0, alpha * 0.08)
    love.graphics.circle("fill", ps.x, ps.y, ps.haloSize)
    love.graphics.setColor(0.4, 0.6, 1.0, alpha * 0.12)
    love.graphics.circle("fill", ps.x, ps.y, ps.haloSize * 0.6)

    -- Inner halo
    love.graphics.setColor(0.5, 0.7, 1.0, alpha * 0.25)
    love.graphics.circle("fill", ps.x, ps.y, ps.size * 2)

    -- Star core
    love.graphics.setColor(0.8, 0.9, 1.0, alpha)
    love.graphics.circle("fill", ps.x, ps.y, ps.size)
    love.graphics.setColor(1, 1, 1, alpha * 0.9)
    love.graphics.circle("fill", ps.x, ps.y, ps.size * 0.5)

    -- Diffraction spikes
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.7, 0.85, 1.0, alpha * 0.5)
    local spikeLen = ps.size * 5
    love.graphics.line(ps.x - spikeLen, ps.y, ps.x + spikeLen, ps.y)
    love.graphics.line(ps.x, ps.y - spikeLen, ps.x, ps.y + spikeLen)
  end
end

function M.drawPulsarBeam(width, height)
  if pulsarBeam.intensity <= 0.05 then return end

  local cx, cy = width * 0.7, height * 0.3 -- Pulsar position
  local beamLen = math.max(width, height) * 1.5

  -- Rotating beam
  love.graphics.push()
  love.graphics.translate(cx, cy)

  local beamAngle = pulsarBeam.angle
  local intensity = pulsarBeam.intensity

  -- Beam cone (narrow)
  for i = 3, 1, -1 do
    local coneWidth = (3 + i * 2) * intensity
    local alpha = intensity * 0.2 * (4 - i) / 3

    love.graphics.setColor(0.6, 0.4, 1.0, alpha)

    local bx1 = math.cos(beamAngle) * beamLen
    local by1 = math.sin(beamAngle) * beamLen
    local perpX = math.cos(beamAngle + math.pi / 2) * coneWidth
    local perpY = math.sin(beamAngle + math.pi / 2) * coneWidth

    love.graphics.polygon("fill",
      -perpX * 0.3, -perpY * 0.3,
      perpX * 0.3, perpY * 0.3,
      bx1 + perpX, by1 + perpY,
      bx1 - perpX, by1 - perpY
    )

    -- Opposite beam
    love.graphics.polygon("fill",
      -perpX * 0.3, -perpY * 0.3,
      perpX * 0.3, perpY * 0.3,
      -bx1 + perpX, -by1 + perpY,
      -bx1 - perpX, -by1 - perpY
    )
  end

  love.graphics.pop()

  -- Pulsar core
  love.graphics.setColor(0.8, 0.6, 1.0, intensity)
  love.graphics.circle("fill", cx, cy, 6 + intensity * 4)
  love.graphics.setColor(1, 1, 1, intensity * 0.8)
  love.graphics.circle("fill", cx, cy, 3)
end

function M.drawAndromedaSpiral(width, height)
  -- The galaxy graphic spans the full 7x7 constellation (top-down view,
  -- re-using the spiral galaxy style from the title screen).
  local lx, ly = constellation.getLocalTilePos(currentTileX, currentTileY)
  local dtx = 3 - lx
  local dty = 3 - ly
  local cx = width / 2 + dtx * width
  local cy = height / 2 + dty * height

  -- Scale so the galaxy fills ~7 tiles worth of space
  local S = 3.5
  local numArms = 4
  local armSpread = 0.4
  local maxRadius = 394 * S * 0.5  -- matches title screen sizing scaled up
  local coreRadius = 56 * S * 0.5

  -- Nebula clouds in spiral arms
  local cloudPalette = {
    {0.4, 0.2, 0.6, 0.04},
    {0.2, 0.3, 0.7, 0.035},
    {0.6, 0.2, 0.4, 0.03},
    {0.3, 0.5, 0.7, 0.035},
    {0.5, 0.3, 0.6, 0.03},
  }
  math.randomseed(9999)  -- Deterministic
  for i = 1, 20 do
    local armIndex = math.random(0, numArms - 1)
    local armAngle = (armIndex / numArms) * math.pi * 2
    local dist = math.random() * maxRadius * 0.85 + coreRadius * 0.5
    local spiralTwist = dist * 0.008
    local angle = armAngle + spiralTwist + (math.random() - 0.5) * 0.5
    local color = cloudPalette[math.random(#cloudPalette)]
    local cloudX = cx + math.cos(angle + time * 0.008) * dist
    local cloudY = cy + math.sin(angle + time * 0.008) * dist  -- Top-down (circular, not elliptical)
    local cloudR = (68 + math.random() * 113) * S * 0.4
    for layer = 3, 1, -1 do
      local lr = cloudR * (0.4 + layer * 0.25)
      local lo = color[4] * (1.2 - layer * 0.3) * 0.6
      love.graphics.setColor(color[1], color[2], color[3], lo)
      love.graphics.circle("fill", cloudX, cloudY, lr)
    end
  end

  -- Galactic core glow
  for i = 8, 1, -1 do
    local glowSize = coreRadius * i * 0.8
    local alpha = 0.03 / (i * 0.5)
    love.graphics.setColor(1, 0.85, 0.6, alpha)
    love.graphics.circle("fill", cx, cy, glowSize)
  end
  for i = 6, 1, -1 do
    local glowSize = coreRadius * i * 0.5
    local alpha = 0.02 / (i * 0.5)
    love.graphics.setColor(0.8, 0.7, 1, alpha)
    love.graphics.circle("fill", cx, cy, glowSize)
  end

  -- Spiral arm stars (top-down, circular like galaxy.lua but rendered at constellation scale)
  math.randomseed(7777)  -- Deterministic
  for i = 1, 400 do
    local armIndex = math.random(0, numArms - 1)
    local armAngle = (armIndex / numArms) * math.pi * 2
    local dist = math.random() ^ 0.5 * maxRadius + coreRadius * 0.3
    local spiralTwist = dist * 0.008
    local angle = armAngle + spiralTwist + (math.random() - 0.5) * armSpread

    local sx = cx + math.cos(angle + time * 0.008) * dist
    local sy = cy + math.sin(angle + time * 0.008) * dist  -- Top-down (circular)

    local brightness = math.random() * 0.5 + 0.2
    local size = math.random() * 1.5 + 0.5
    local colorType = math.random()
    local r, g, b
    if colorType < 0.6 then
      r, g, b = 0.8 + math.random() * 0.2, 0.85 + math.random() * 0.15, 1
    elseif colorType < 0.85 then
      r, g, b = 1, 0.9 + math.random() * 0.1, 0.6 + math.random() * 0.2
    else
      r, g, b = 1, 0.5 + math.random() * 0.3, 0.3 + math.random() * 0.2
    end

    local twinkle = math.sin(time * (1.5 + math.random()) + i) * 0.3 + 0.7
    love.graphics.setColor(r * brightness * twinkle, g * brightness * twinkle, b * brightness * twinkle)
    love.graphics.circle("fill", sx, sy, size)
  end

  -- Core stars (denser, warmer)
  math.randomseed(8888)
  for i = 1, 80 do
    local angle = math.random() * math.pi * 2
    local dist = math.random() ^ 2 * coreRadius
    local sx = cx + math.cos(angle + time * 0.008) * dist
    local sy = cy + math.sin(angle + time * 0.008) * dist
    local brightness = math.random() * 0.3 + 0.6
    love.graphics.setColor(1 * brightness, 0.95 * brightness, 0.8 * brightness)
    love.graphics.circle("fill", sx, sy, math.random() * 2 + 1)
  end

  -- Bright galactic center
  love.graphics.setColor(1, 0.9, 0.7, 0.25)
  love.graphics.circle("fill", cx, cy, 22 * S * 0.3)
  love.graphics.setColor(1, 0.95, 0.8, 0.4)
  love.graphics.circle("fill", cx, cy, 13 * S * 0.3)
  love.graphics.setColor(1, 0.98, 0.9, 0.6)
  love.graphics.circle("fill", cx, cy, 7 * S * 0.3)
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.circle("fill", cx, cy, 3.5 * S * 0.3)

  math.randomseed(os.time())  -- Restore
end

function M.drawPandoraHeat(width, height)
  -- Subtle blue-dominant ambient glow
  love.graphics.setColor(0.1, 0.15, 0.4, 0.05)
  love.graphics.rectangle("fill", 0, 0, width, height)

  -- Scattered blue cluster glow points
  math.randomseed(42) -- Deterministic for this draw
  for i = 1, 8 do
    local gx = math.random() * width
    local gy = math.random() * height
    love.graphics.setColor(0.2, 0.3, 0.9, 0.06 + math.sin(time + i) * 0.02)
    love.graphics.circle("fill", gx, gy, 80 + math.sin(time * 0.5 + i) * 20)
  end
  math.randomseed(os.time()) -- Restore
end

function M.drawOortIce(width, height)
  -- Floating ice particle effect
  math.randomseed(101)
  for i = 1, 40 do
    local ix = (math.random() * width + time * 5 * (math.random() - 0.5)) % width
    local iy = (math.random() * height + time * 3 * (math.random() - 0.5)) % height
    local alpha = 0.15 + math.sin(time * 0.5 + i * 0.7) * 0.08
    -- Neon-tinted ice particles
    local neonChoice = math.random(3)
    if neonChoice == 1 then
      love.graphics.setColor(0, 0.8, 1.0, alpha) -- Cyan
    elseif neonChoice == 2 then
      love.graphics.setColor(0, 1.0, 0.5, alpha) -- Green
    else
      love.graphics.setColor(0.6, 0, 1.0, alpha)  -- Purple
    end
    love.graphics.circle("fill", ix, iy, 1 + math.random() * 2)
  end
  math.randomseed(os.time())
end

function M.drawMessierStars(width, height)
  -- Dense warm star cluster overlay
  math.randomseed(77)
  for i = 1, 100 do
    local mx = math.random() * width
    local my = math.random() * height
    local twinkle = math.sin(time * (1 + math.random()) + i) * 0.3 + 0.7
    local warmth = math.random()
    if warmth < 0.5 then
      love.graphics.setColor(1, 0.95, 0.8, 0.3 * twinkle) -- Cream
    else
      love.graphics.setColor(1, 0.85, 0.5, 0.25 * twinkle) -- Gold
    end
    love.graphics.circle("fill", mx, my, 0.5 + math.random() * 1.5)
  end
  math.randomseed(os.time())
end

-- Regenerate with new palette for tile transitions
function M.changePalette(width, height)
  -- No longer needed, init handles palette per constellation
end

return M

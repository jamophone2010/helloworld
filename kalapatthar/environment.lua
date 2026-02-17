-- kalapatthar/environment.lua
-- Environmental rendering for Kala Patthar — Nepali mountain village
-- All draw functions use WORLD coordinates (drawn inside translate block)
-- Screen-space functions (sky, stars, snow, wind overlay) noted explicitly.

local M = {}

local areas = require("kalapatthar.areas")

-- Wind system
local wind = {
  speed = 0,
  direction = 1,
  gustTimer = 0,
  gustStrength = 0,
  baseSpeed = 15,
}

local flagWave = 0

function M.load()
  areas.initStars()
  areas.initSnow()
  wind.speed = wind.baseSpeed
end

function M.update(dt)
  wind.gustTimer = wind.gustTimer - dt
  if wind.gustTimer <= 0 then
    wind.gustStrength = math.random() * 30 + 10
    wind.gustTimer = math.random() * 4 + 2
    if math.random() < 0.3 then
      wind.direction = -wind.direction
    end
  end
  wind.speed = wind.baseSpeed + wind.gustStrength * math.max(0, 1 - wind.gustTimer)

  flagWave = flagWave + dt * 3

  local snow = areas.getSnow()
  for _, p in ipairs(snow) do
    p.y = p.y + p.speed * dt
    p.x = p.x + (wind.speed * wind.direction * 0.3 + p.drift) * dt
    p.wobble = p.wobble + dt * 1.5
    if p.y > 900 then
      p.y = -10
      p.x = math.random(0, 1400)
    end
    if p.x > 1500 then p.x = -10 end
    if p.x < -10 then p.x = 1500 end
  end
end

function M.getWind() return wind end

-- =============================================
-- SCREEN-SPACE: Sky (drawn before push/translate)
-- =============================================

function M.drawSky(screenW, screenH, time)
  -- Deep space gradient: dark indigo at top, very dark purple at bottom
  for y = 0, screenH, 4 do
    local t = y / screenH
    local r = 0.03 + t * 0.06
    local g = 0.03 + t * 0.04
    local b = 0.10 + t * 0.08
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, y, screenW, 4)
  end
end

-- =============================================
-- SCREEN-SPACE: Stars (drawn before push/translate)
-- =============================================

function M.drawStars(screenW, screenH, time)
  local stars = areas.getStars()
  for _, s in ipairs(stars) do
    local twinkle = math.sin(time * 1.5 + s.twinklePhase) * 0.3 + 0.7
    local bright = s.brightness * twinkle
    if s.color == "warm" then
      love.graphics.setColor(1.0 * bright, 0.85 * bright, 0.6 * bright)
    else
      love.graphics.setColor(0.7 * bright, 0.8 * bright, 1.0 * bright)
    end
    love.graphics.circle("fill", s.x % screenW, s.y % screenH, s.size)
  end
end

-- =============================================
-- SCREEN-SPACE: Mountain range parallax (before push/translate)
-- =============================================

function M.drawMountainRange(screenW, screenH, camY, time)
  local baseY = screenH * 0.55
  local centerX = screenW * 0.5

  -- ═══════════════════════════════════════════════════════════
  -- LAYER 0: Distant Himalayan range (far background)
  -- ═══════════════════════════════════════════════════════════
  local p0 = camY * 0.01
  love.graphics.setColor(0.10, 0.08, 0.16, 0.45)
  local farPeaks = {
    {0, 45}, {70, 25}, {140, 40}, {220, 18}, {310, 55},
    {400, 30}, {500, 50}, {620, 20}, {740, 42}, {860, 15},
    {960, 38}, {1060, 22}, {1160, 48}, {1280, 28}, {1400, 40},
  }
  local vFar = {}
  for _, pk in ipairs(farPeaks) do
    table.insert(vFar, pk[1])
    table.insert(vFar, baseY - 120 - pk[2] + p0)
  end
  table.insert(vFar, screenW)
  table.insert(vFar, baseY - 60 + p0)
  table.insert(vFar, 0)
  table.insert(vFar, baseY - 60 + p0)
  if #vFar >= 6 then love.graphics.polygon("fill", vFar) end

  -- ═══════════════════════════════════════════════════════════
  -- LAYER 1: The Everest Massif — Nuptse, Everest, Lhotse
  -- The iconic view from Kala Patthar:
  --   Nuptse (7861m) on the left — broad, craggy wall
  --   Everest (8849m) center-right — triangular summit, SW face
  --   Lhotse (8516m) to the right — steep south face
  -- ═══════════════════════════════════════════════════════════
  local p1 = camY * 0.02
  local eBaseY = baseY - 30 + p1

  -- === NUPTSE (left massif — long ridge wall) ===
  -- Dark rock face with snow bands
  love.graphics.setColor(0.14, 0.12, 0.18)
  local nuptseVerts = {
    centerX - 380, eBaseY,             -- left base
    centerX - 360, eBaseY - 70,        -- left shoulder
    centerX - 300, eBaseY - 110,       -- west summit
    centerX - 240, eBaseY - 130,       -- main summit (7861m)
    centerX - 180, eBaseY - 125,       -- east summit
    centerX - 120, eBaseY - 100,       -- col toward Everest
    centerX - 80,  eBaseY - 80,        -- South Col approach
    centerX - 80,  eBaseY,             -- right base
  }
  love.graphics.polygon("fill", nuptseVerts)

  -- Nuptse snow bands (horizontal ice terraces on the face)
  love.graphics.setColor(0.75, 0.80, 0.90, 0.25)
  for i = 1, 5 do
    local bandY = eBaseY - 30 - i * 18
    local bandLeft = centerX - 350 + i * 20
    local bandRight = centerX - 100 - i * 5
    if bandLeft < bandRight then
      love.graphics.setLineWidth(2)
      love.graphics.line(bandLeft, bandY, bandRight, bandY + 2)
      love.graphics.setLineWidth(1)
    end
  end

  -- Nuptse snow cap
  love.graphics.setColor(0.85, 0.88, 0.95, 0.5)
  love.graphics.polygon("fill",
    centerX - 280, eBaseY - 115,
    centerX - 240, eBaseY - 130,
    centerX - 200, eBaseY - 122,
    centerX - 230, eBaseY - 112
  )

  -- === EVEREST (center — the great pyramid) ===
  -- Southwest face — massive triangular summit
  love.graphics.setColor(0.16, 0.13, 0.20)
  local everestVerts = {
    centerX - 80,  eBaseY,             -- left base
    centerX - 80,  eBaseY - 80,        -- South Col
    centerX - 40,  eBaseY - 120,       -- South Pillar
    centerX + 10,  eBaseY - 150,       -- shoulder
    centerX + 50,  eBaseY - 190,       -- SUMMIT (8849m)
    centerX + 90,  eBaseY - 155,       -- NE ridge descent
    centerX + 130, eBaseY - 120,       -- col to Lhotse
    centerX + 130, eBaseY,             -- right base
  }
  love.graphics.polygon("fill", everestVerts)

  -- Everest rock bands / Yellow Band
  love.graphics.setColor(0.45, 0.38, 0.22, 0.12)
  love.graphics.polygon("fill",
    centerX - 20, eBaseY - 130,
    centerX + 50, eBaseY - 185,
    centerX + 75, eBaseY - 165,
    centerX + 20, eBaseY - 120
  )

  -- Hillary Step / summit ridge detail
  love.graphics.setColor(0.22, 0.18, 0.25, 0.5)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(centerX + 35, eBaseY - 178, centerX + 50, eBaseY - 190)
  love.graphics.setLineWidth(1)

  -- Everest snow: summit pyramid and upper slopes
  love.graphics.setColor(0.90, 0.92, 0.97, 0.55)
  love.graphics.polygon("fill",
    centerX + 20,  eBaseY - 160,
    centerX + 50,  eBaseY - 190,       -- summit
    centerX + 80,  eBaseY - 162,
    centerX + 55,  eBaseY - 155
  )
  -- Snow plume (wind-blown spindrift off summit)
  local plumeSway = math.sin(time * 0.6) * 15 + 20
  local plumeAlpha = 0.15 + math.sin(time * 0.4) * 0.05
  love.graphics.setColor(0.88, 0.90, 0.95, plumeAlpha)
  love.graphics.polygon("fill",
    centerX + 50, eBaseY - 190,
    centerX + 50 + plumeSway, eBaseY - 192,
    centerX + 50 + plumeSway + 25, eBaseY - 188,
    centerX + 50 + plumeSway * 0.5, eBaseY - 186
  )
  -- Second wisp
  love.graphics.setColor(0.88, 0.90, 0.95, plumeAlpha * 0.6)
  love.graphics.polygon("fill",
    centerX + 50 + plumeSway * 0.5, eBaseY - 188,
    centerX + 50 + plumeSway + 35, eBaseY - 186,
    centerX + 50 + plumeSway + 45, eBaseY - 183
  )

  -- Southwest face couloirs (shadow lines / gullies)
  love.graphics.setColor(0.10, 0.08, 0.14, 0.3)
  love.graphics.line(centerX, eBaseY - 100, centerX + 30, eBaseY - 160)
  love.graphics.line(centerX - 30, eBaseY - 60, centerX + 10, eBaseY - 135)
  love.graphics.line(centerX + 70, eBaseY - 80, centerX + 60, eBaseY - 140)

  -- === LHOTSE (right — steep south face) ===
  love.graphics.setColor(0.15, 0.12, 0.19)
  local lhotseVerts = {
    centerX + 130, eBaseY,             -- left base
    centerX + 130, eBaseY - 120,       -- col from Everest
    centerX + 170, eBaseY - 160,       -- Lhotse Shar
    centerX + 210, eBaseY - 175,       -- SUMMIT (8516m)
    centerX + 250, eBaseY - 140,       -- east descent
    centerX + 310, eBaseY - 90,        -- far ridge
    centerX + 350, eBaseY - 60,        -- trailing ridge
    centerX + 380, eBaseY,             -- right base
  }
  love.graphics.polygon("fill", lhotseVerts)

  -- Lhotse face: steep ice/rock striations
  love.graphics.setColor(0.10, 0.08, 0.14, 0.25)
  for i = 1, 4 do
    local sx = centerX + 140 + i * 25
    love.graphics.line(sx, eBaseY - 40, sx + 15, eBaseY - 140 - i * 5)
  end

  -- Lhotse snow cap
  love.graphics.setColor(0.88, 0.90, 0.96, 0.5)
  love.graphics.polygon("fill",
    centerX + 185, eBaseY - 165,
    centerX + 210, eBaseY - 175,
    centerX + 240, eBaseY - 148,
    centerX + 215, eBaseY - 155
  )

  -- ═══════════════════════════════════════════════════════════
  -- LAYER 2: Foothills / moraine ridge (closer, darker)
  -- ═══════════════════════════════════════════════════════════
  local p2 = camY * 0.04
  love.graphics.setColor(0.12, 0.10, 0.14, 0.8)
  local foothills = {
    {0, 30}, {100, 18}, {200, 35}, {350, 10}, {500, 25},
    {650, 12}, {800, 28}, {950, 8}, {1100, 22}, {1250, 30},
    {1400, 15},
  }
  local vFoot = {}
  for _, pk in ipairs(foothills) do
    table.insert(vFoot, pk[1])
    table.insert(vFoot, baseY + 10 - pk[2] + p2)
  end
  table.insert(vFoot, screenW)
  table.insert(vFoot, baseY + 20 + p2)
  table.insert(vFoot, 0)
  table.insert(vFoot, baseY + 20 + p2)
  if #vFoot >= 6 then love.graphics.polygon("fill", vFoot) end

  -- Moraine snow patches
  love.graphics.setColor(0.80, 0.84, 0.92, 0.15)
  for i = 0, 6 do
    local px = 100 + i * 200 + math.sin(i * 2.3) * 40
    local py = baseY + 5 + p2
    love.graphics.ellipse("fill", px, py, 25, 4)
  end

  -- Glacier glint on Khumbu glacier
  local glintPhase = math.sin(time * 0.3) * 0.15 + 0.15
  love.graphics.setColor(0.6, 0.78, 0.95, glintPhase)
  love.graphics.rectangle("fill", centerX - 60, baseY + 5 + p2, 80, 3, 1, 1)
  love.graphics.rectangle("fill", centerX + 150, baseY + 8 + p2, 50, 2, 1, 1)

  -- ═══════════════════════════════════════════════════════════
  -- Summit labels (subtle, faint white text)
  -- ═══════════════════════════════════════════════════════════
  love.graphics.setColor(0.80, 0.82, 0.90, 0.18 + math.sin(time * 0.5) * 0.04)
  love.graphics.print("Everest", centerX + 20, eBaseY - 200)
  love.graphics.print("Lhotse", centerX + 185, eBaseY - 185)
  love.graphics.print("Nuptse", centerX - 260, eBaseY - 140)
end

-- =============================================
-- WORLD-SPACE: Ground terrain (inside translate block)
-- =============================================

function M.drawGround(time)
  local gs = areas.GRID_SIZE

  -- Draw each zone with its terrain
  for _, zone in ipairs(areas.zones) do
    local zx = zone.x1 * gs
    local zy = zone.y1 * gs
    local zw = (zone.x2 - zone.x1 + 1) * gs
    local zh = (zone.y2 - zone.y1 + 1) * gs

    -- Base terrain color varies by zone
    local r, g, b = 0.25, 0.22, 0.18
    if zone.id == "village_center" then
      r, g, b = 0.30, 0.26, 0.20
    elseif zone.id == "west_ridge" then
      r, g, b = 0.28, 0.24, 0.18
    elseif zone.id == "east_terrace" then
      r, g, b = 0.26, 0.24, 0.20
    elseif zone.id == "meditation_glade" then
      r, g, b = 0.28, 0.25, 0.20
    elseif zone.id == "upper_village" then
      r, g, b = 0.24, 0.22, 0.18
    elseif zone.id == "north_pass" then
      r, g, b = 0.22, 0.20, 0.17
    end

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", zx, zy, zw, zh)

    -- Rocky texture per tile
    for ty = zone.y1, zone.y2 do
      for tx = zone.x1, zone.x2 do
        local hash = (tx * 73 + ty * 137) % 256 / 256
        local shade = 0.92 + hash * 0.16
        love.graphics.setColor(r * shade, g * shade, b * shade)
        love.graphics.rectangle("fill", tx * gs + 1, ty * gs + 1, gs - 2, gs - 2)

        -- Snow dusting on some tiles
        if hash > 0.7 then
          love.graphics.setColor(0.85, 0.88, 0.93, 0.15 + hash * 0.1)
          love.graphics.rectangle("fill", tx * gs + 2, ty * gs + 2, gs - 4, gs - 4)
        end
      end
    end
  end

  -- Draw trails (stone paths)
  M.drawTrails(gs)

  -- Draw gorge areas
  M.drawGorges(gs, time)
end

function M.drawTrails(gs)
  for _, trail in ipairs(areas.trails) do
    for _, seg in ipairs(trail.segments) do
      local minX = math.min(seg.x1, seg.x2)
      local maxX = math.max(seg.x1, seg.x2)
      local minY = math.min(seg.y1, seg.y2)
      local maxY = math.max(seg.y1, seg.y2)
      for ty = minY, maxY do
        for tx = minX, maxX do
          local hash = (tx * 31 + ty * 97) % 256 / 256
          -- Stone path tiles
          love.graphics.setColor(0.42 + hash * 0.06, 0.38 + hash * 0.05, 0.32 + hash * 0.04)
          love.graphics.rectangle("fill", tx * gs + 1, ty * gs + 1, gs - 2, gs - 2, 1, 1)
          -- Stone joints
          love.graphics.setColor(0.30, 0.27, 0.22, 0.3)
          love.graphics.line(tx * gs, ty * gs, tx * gs + gs, ty * gs)
          love.graphics.line(tx * gs, ty * gs, tx * gs, ty * gs + gs)
        end
      end
    end
  end
end

function M.drawGorges(gs, time)
  for _, gorge in ipairs(areas.gorges) do
    -- Dark void with depth
    for ty = gorge.y1, gorge.y2 do
      for tx = gorge.x1, gorge.x2 do
        -- Check if bridge covers this tile
        local onBridge = areas.isOnBridge(tx, ty)
        if not onBridge then
          -- Deep gorge - dark with bluish ice tint
          local depth = gorge.depth / 400
          love.graphics.setColor(0.05 * (1 - depth * 0.5), 0.06 * (1 - depth * 0.3), 0.12 * (1 - depth * 0.2))
          love.graphics.rectangle("fill", tx * gs, ty * gs, gs, gs)

          -- Ice/rock ledges visible in the depths
          local hash = (tx * 47 + ty * 83) % 256 / 256
          if hash > 0.6 then
            love.graphics.setColor(0.15, 0.20, 0.30, 0.3)
            local ledgeW = 8 + hash * 12
            local ledgeY = ty * gs + hash * 20
            love.graphics.rectangle("fill", tx * gs + (gs - ledgeW) / 2, ledgeY, ledgeW, 3)
          end

          -- Glacier shimmer deep in gorge
          if hash > 0.85 then
            local shimmer = math.sin(time * 0.5 + tx + ty) * 0.1 + 0.1
            love.graphics.setColor(0.4, 0.6, 0.85, shimmer)
            love.graphics.circle("fill", tx * gs + gs / 2, ty * gs + gs / 2, 2)
          end
        end
      end
    end

    -- Cliff edges (craggy stone rim around gorge)
    love.graphics.setColor(0.22, 0.20, 0.16)
    love.graphics.setLineWidth(2)
    local gx1 = gorge.x1 * gs
    local gy1 = gorge.y1 * gs
    local gx2 = (gorge.x2 + 1) * gs
    local gy2 = (gorge.y2 + 1) * gs
    love.graphics.rectangle("line", gx1, gy1, gx2 - gx1, gy2 - gy1)
    love.graphics.setLineWidth(1)
  end
end

-- =============================================
-- WORLD-SPACE: Suspension bridges (inside translate block)
-- =============================================

function M.drawBridges(time)
  local gs = areas.GRID_SIZE

  for _, br in ipairs(areas.bridges) do
    local isVertical = (br.x1 == br.x2)

    if isVertical then
      M.drawVerticalBridge(br, gs, time)
    else
      M.drawHorizontalBridge(br, gs, time)
    end
  end
end

function M.drawHorizontalBridge(br, gs, time)
  local startX = math.min(br.x1, br.x2) * gs
  local endX = (math.max(br.x1, br.x2) + 1) * gs
  local topY = br.y1 * gs
  local bridgeW = endX - startX
  local bridgeH = br.width * gs
  local sway = math.sin(time * 0.8) * 2

  -- Rope rails (top and bottom)
  love.graphics.setColor(0.55, 0.42, 0.25)
  love.graphics.setLineWidth(2)
  -- Top rope with catenary sag
  local segments = 12
  for i = 0, segments - 1 do
    local t1 = i / segments
    local t2 = (i + 1) / segments
    local sag1 = math.sin(t1 * math.pi) * 4 + math.sin(time + t1 * 3) * sway * 0.3
    local sag2 = math.sin(t2 * math.pi) * 4 + math.sin(time + t2 * 3) * sway * 0.3
    love.graphics.line(
      startX + bridgeW * t1, topY - 4 + sag1,
      startX + bridgeW * t2, topY - 4 + sag2
    )
    love.graphics.line(
      startX + bridgeW * t1, topY + bridgeH + 4 + sag1,
      startX + bridgeW * t2, topY + bridgeH + 4 + sag2
    )
  end

  -- Wooden planks
  local plankCount = math.floor(bridgeW / 6)
  for i = 0, plankCount do
    local px = startX + i * (bridgeW / plankCount)
    local t = i / plankCount
    local plankSag = math.sin(t * math.pi) * 2 + math.sin(time + t * 3) * sway * 0.2
    local hash = (i * 73) % 256 / 256
    love.graphics.setColor(0.45 + hash * 0.1, 0.32 + hash * 0.08, 0.18 + hash * 0.05)
    love.graphics.rectangle("fill", px, topY + plankSag, 5, bridgeH)
    -- Plank gap
    love.graphics.setColor(0.05, 0.06, 0.12, 0.5)
    love.graphics.line(px + 5, topY + plankSag, px + 5, topY + bridgeH + plankSag)
  end

  -- Vertical rope supports
  love.graphics.setColor(0.50, 0.38, 0.22, 0.6)
  love.graphics.setLineWidth(1)
  for i = 0, 4 do
    local rx = startX + i * (bridgeW / 4)
    local t = i / 4
    local ropeSag = math.sin(t * math.pi) * 4 + math.sin(time + t * 3) * sway * 0.3
    love.graphics.line(rx, topY - 4 + ropeSag, rx, topY + ropeSag)
    love.graphics.line(rx, topY + bridgeH + 4 + ropeSag, rx, topY + bridgeH + ropeSag)
  end

  -- Anchor posts at each end
  love.graphics.setColor(0.35, 0.25, 0.15)
  love.graphics.rectangle("fill", startX - 3, topY - 8, 6, bridgeH + 16)
  love.graphics.rectangle("fill", endX - 3, topY - 8, 6, bridgeH + 16)
end

function M.drawVerticalBridge(br, gs, time)
  local topY = math.min(br.y1, br.y2) * gs
  local botY = (math.max(br.y1, br.y2) + 1) * gs
  local leftX = br.x1 * gs
  local bridgeH = botY - topY
  local bridgeW = br.width * gs
  local sway = math.sin(time * 0.8 + 1.5) * 2

  -- Rope rails (left and right)
  love.graphics.setColor(0.55, 0.42, 0.25)
  love.graphics.setLineWidth(2)
  local segments = 12
  for i = 0, segments - 1 do
    local t1 = i / segments
    local t2 = (i + 1) / segments
    local sag1 = math.sin(t1 * math.pi) * 4 + math.sin(time + t1 * 3) * sway * 0.3
    local sag2 = math.sin(t2 * math.pi) * 4 + math.sin(time + t2 * 3) * sway * 0.3
    love.graphics.line(
      leftX - 4 + sag1, topY + bridgeH * t1,
      leftX - 4 + sag2, topY + bridgeH * t2
    )
    love.graphics.line(
      leftX + bridgeW + 4 + sag1, topY + bridgeH * t1,
      leftX + bridgeW + 4 + sag2, topY + bridgeH * t2
    )
  end

  -- Wooden planks (horizontal, running across vertical bridge)
  local plankCount = math.floor(bridgeH / 6)
  for i = 0, plankCount do
    local py = topY + i * (bridgeH / plankCount)
    local t = i / plankCount
    local plankSag = math.sin(t * math.pi) * 2 + math.sin(time + t * 3) * sway * 0.2
    local hash = (i * 73) % 256 / 256
    love.graphics.setColor(0.45 + hash * 0.1, 0.32 + hash * 0.08, 0.18 + hash * 0.05)
    love.graphics.rectangle("fill", leftX + plankSag, py, bridgeW, 5)
    love.graphics.setColor(0.05, 0.06, 0.12, 0.5)
    love.graphics.line(leftX + plankSag, py + 5, leftX + bridgeW + plankSag, py + 5)
  end

  -- Vertical rope supports
  love.graphics.setColor(0.50, 0.38, 0.22, 0.6)
  love.graphics.setLineWidth(1)
  for i = 0, 4 do
    local ry = topY + i * (bridgeH / 4)
    local t = i / 4
    local ropeSag = math.sin(t * math.pi) * 4 + math.sin(time + t * 3) * sway * 0.3
    love.graphics.line(leftX - 4 + ropeSag, ry, leftX + ropeSag, ry)
    love.graphics.line(leftX + bridgeW + 4 + ropeSag, ry, leftX + bridgeW + ropeSag, ry)
  end

  -- Anchor posts
  love.graphics.setColor(0.35, 0.25, 0.15)
  love.graphics.rectangle("fill", leftX - 8, topY - 3, bridgeW + 16, 6)
  love.graphics.rectangle("fill", leftX - 8, botY - 3, bridgeW + 16, 6)
end

-- =============================================
-- WORLD-SPACE: Prayer flags (inside translate block)
-- =============================================

function M.drawPrayerFlags(time)
  local gs = areas.GRID_SIZE
  local colors = areas.FLAG_COLORS

  for _, d in ipairs(areas.decorations) do
    if d.type == "prayer_flags" then
      local sx = d.x1 * gs + gs / 2
      local sy = d.y1 * gs
      local ex = d.x2 * gs + gs / 2
      local ey = d.y2 * gs
      local span = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)

      -- Main rope
      love.graphics.setColor(0.50, 0.40, 0.28)
      love.graphics.setLineWidth(1)

      -- Catenary with wind
      local segs = 20
      local windOffset = wind.speed * wind.direction * 0.05
      for i = 0, segs - 1 do
        local t1 = i / segs
        local t2 = (i + 1) / segs
        local x1 = sx + (ex - sx) * t1
        local y1 = sy + (ey - sy) * t1 + math.sin(t1 * math.pi) * 8
        local x2 = sx + (ex - sx) * t2
        local y2 = sy + (ey - sy) * t2 + math.sin(t2 * math.pi) * 8
        -- Wind sway
        x1 = x1 + math.sin(time * 2 + t1 * 5) * windOffset
        x2 = x2 + math.sin(time * 2 + t2 * 5) * windOffset
        love.graphics.line(x1, y1, x2, y2)
      end

      -- Flags
      local numFlags = math.floor(span / 12)
      if numFlags < 3 then numFlags = 3 end
      for i = 1, numFlags do
        local t = i / (numFlags + 1)
        local fx = sx + (ex - sx) * t
        local fy = sy + (ey - sy) * t + math.sin(t * math.pi) * 8
        fx = fx + math.sin(time * 2 + t * 5) * windOffset

        local colorIdx = ((i - 1) % 5) + 1
        local c = colors[colorIdx]
        love.graphics.setColor(c[1], c[2], c[3], 0.85)

        -- Flag (small rectangle fluttering)
        local flagW = 8
        local flagH = 12
        local flutter = math.sin(time * 3 + i * 1.7) * 2 + windOffset * 0.5
        love.graphics.polygon("fill",
          fx, fy,
          fx + flagW + flutter, fy + 2,
          fx + flagW + flutter * 0.8, fy + flagH,
          fx, fy + flagH - 1
        )
      end

      -- Poles at endpoints
      love.graphics.setColor(0.40, 0.30, 0.20)
      love.graphics.rectangle("fill", sx - 1, sy - 10, 3, 20)
      love.graphics.rectangle("fill", ex - 1, ey - 10, 3, 20)
    end
  end
end

-- =============================================
-- WORLD-SPACE: Decorations (inside translate block)
-- =============================================

function M.drawDecorations(time)
  local gs = areas.GRID_SIZE

  for _, d in ipairs(areas.decorations) do
    if d.type == "cairn" then
      M.drawCairn(d.x * gs, d.y * gs)
    elseif d.type == "stupa" then
      M.drawStupa(d.x * gs, d.y * gs, time)
    elseif d.type == "campfire" then
      M.drawCampfire(d.x * gs, d.y * gs, time)
    elseif d.type == "mani_wall" then
      M.drawManiWall(d.x1 * gs, d.y1 * gs, d.x2 * gs, d.y2 * gs)
    elseif d.type == "boulder" then
      M.drawBoulder(d.x * gs, d.y * gs)
    elseif d.type == "yak" then
      M.drawYak(d.x * gs, d.y * gs, time)
    elseif d.type == "bench" then
      M.drawBench(d.x * gs, d.y * gs)
    elseif d.type == "supply_crate" then
      M.drawSupplyCrate(d.x * gs, d.y * gs)
    elseif d.type == "firewood" then
      M.drawFirewood(d.x * gs, d.y * gs)
    elseif d.type == "bell" then
      M.drawBell(d.x * gs, d.y * gs, time)
    elseif d.type == "frozen_stream" then
      M.drawFrozenStream(d.x1 * gs, d.y1 * gs, d.x2 * gs, d.y2 * gs, time)
    end
    -- prayer_flags handled separately
  end
end

function M.drawCairn(x, y)
  -- Stack of stones
  love.graphics.setColor(0.45, 0.40, 0.35)
  love.graphics.ellipse("fill", x + 16, y + 28, 10, 5)
  love.graphics.setColor(0.48, 0.43, 0.38)
  love.graphics.ellipse("fill", x + 16, y + 22, 8, 4)
  love.graphics.setColor(0.52, 0.47, 0.40)
  love.graphics.ellipse("fill", x + 16, y + 17, 6, 3)
  love.graphics.setColor(0.55, 0.50, 0.43)
  love.graphics.ellipse("fill", x + 16, y + 13, 4, 2)
  -- Top stone
  love.graphics.setColor(0.58, 0.53, 0.46)
  love.graphics.circle("fill", x + 16, y + 10, 2)
end

function M.drawStupa(x, y, time)
  -- White-washed dome
  love.graphics.setColor(0.88, 0.85, 0.78)
  love.graphics.rectangle("fill", x + 4, y + 16, 24, 14, 3, 3)
  love.graphics.arc("fill", x + 16, y + 16, 12, math.pi, 0)
  -- Golden harmika (box above dome)
  love.graphics.setColor(0.90, 0.75, 0.20)
  love.graphics.rectangle("fill", x + 10, y + 6, 12, 8)
  -- Spire tiers
  for i = 0, 3 do
    local w = 8 - i * 1.5
    love.graphics.rectangle("fill", x + 16 - w / 2, y + 2 + i * 2, w, 2)
  end
  -- Pinnacle
  love.graphics.setColor(1.0, 0.85, 0.30)
  love.graphics.circle("fill", x + 16, y, 2)
  -- Eyes of Buddha (on harmika)
  love.graphics.setColor(0.15, 0.15, 0.40)
  love.graphics.circle("fill", x + 13, y + 9, 1.5)
  love.graphics.circle("fill", x + 19, y + 9, 1.5)
  -- Glow
  local pulse = math.sin(time * 1.5) * 0.05 + 0.1
  love.graphics.setColor(1.0, 0.90, 0.50, pulse)
  love.graphics.circle("fill", x + 16, y + 12, 20)
end

function M.drawCampfire(x, y, time)
  -- Fire glow
  love.graphics.setColor(0.95, 0.60, 0.15, 0.15)
  love.graphics.circle("fill", x + 16, y + 20, 25)
  -- Stone ring
  love.graphics.setColor(0.35, 0.30, 0.25)
  for i = 0, 7 do
    local angle = i * math.pi / 4
    local sx = x + 16 + math.cos(angle) * 8
    local sy = y + 20 + math.sin(angle) * 5
    love.graphics.circle("fill", sx, sy, 3)
  end
  -- Flames
  for i = 1, 4 do
    local flicker = math.sin(time * 5 + i * 1.3) * 3
    local h = 6 + math.sin(time * 4 + i) * 3
    love.graphics.setColor(1.0, 0.7 - i * 0.1, 0.1, 0.8)
    love.graphics.polygon("fill",
      x + 12 + i * 3, y + 20,
      x + 14 + i * 3 + flicker, y + 20 - h,
      x + 16 + i * 3, y + 20
    )
  end
  -- Embers
  love.graphics.setColor(1.0, 0.5, 0.1, 0.4)
  for i = 1, 3 do
    local ex = x + 16 + math.sin(time * 2 + i * 2) * 6
    local ey = y + 14 - math.abs(math.sin(time * 1.5 + i)) * 8
    love.graphics.circle("fill", ex, ey, 1)
  end
end

function M.drawManiWall(x1, y1, x2, y2)
  local gs = areas.GRID_SIZE
  local wallW = x2 - x1 + gs
  -- Stone wall base
  love.graphics.setColor(0.48, 0.43, 0.36)
  love.graphics.rectangle("fill", x1, y1 + 8, wallW, 20, 2, 2)
  -- Individual carved stones
  local stoneW = 14
  local numStones = math.floor(wallW / stoneW)
  for i = 0, numStones - 1 do
    local hash = (i * 47 + math.floor(x1)) % 256 / 256
    love.graphics.setColor(0.50 + hash * 0.08, 0.45 + hash * 0.06, 0.38 + hash * 0.05)
    love.graphics.rectangle("fill", x1 + i * stoneW + 1, y1 + 9, stoneW - 2, 18, 1, 1)
    -- Om mani padme hum carving (tiny decorative marks)
    love.graphics.setColor(0.60, 0.55, 0.45, 0.4)
    love.graphics.line(x1 + i * stoneW + 3, y1 + 15, x1 + i * stoneW + stoneW - 3, y1 + 15)
    love.graphics.line(x1 + i * stoneW + 5, y1 + 19, x1 + i * stoneW + stoneW - 5, y1 + 19)
  end
end

function M.drawBoulder(x, y)
  love.graphics.setColor(0.35, 0.32, 0.28)
  love.graphics.ellipse("fill", x + 16, y + 20, 14, 10)
  love.graphics.setColor(0.38, 0.35, 0.30)
  love.graphics.ellipse("fill", x + 14, y + 18, 10, 7)
  -- Snow on top
  love.graphics.setColor(0.88, 0.90, 0.94, 0.4)
  love.graphics.arc("fill", x + 16, y + 14, 10, math.pi + 0.3, -0.3)
end

function M.drawYak(x, y, time)
  -- Body
  love.graphics.setColor(0.20, 0.15, 0.10)
  love.graphics.ellipse("fill", x + 16, y + 22, 12, 8)
  -- Head
  love.graphics.setColor(0.22, 0.17, 0.12)
  love.graphics.circle("fill", x + 6, y + 18, 5)
  -- Horns
  love.graphics.setColor(0.50, 0.45, 0.35)
  love.graphics.setLineWidth(2)
  love.graphics.arc("line", "open", x + 4, y + 14, 5, math.pi * 0.8, math.pi * 1.5)
  love.graphics.arc("line", "open", x + 8, y + 14, 5, math.pi * 1.5, math.pi * 2.2)
  love.graphics.setLineWidth(1)
  -- Legs
  love.graphics.setColor(0.18, 0.13, 0.08)
  love.graphics.rectangle("fill", x + 8, y + 28, 3, 4)
  love.graphics.rectangle("fill", x + 14, y + 28, 3, 4)
  love.graphics.rectangle("fill", x + 20, y + 28, 3, 4)
  -- Tail swish
  local tailSwish = math.sin(time * 2) * 3
  love.graphics.line(x + 28, y + 20, x + 30 + tailSwish, y + 16)
  -- Eye
  love.graphics.setColor(0.8, 0.7, 0.5)
  love.graphics.circle("fill", x + 4, y + 17, 1)
end

function M.drawBench(x, y)
  -- Seat
  love.graphics.setColor(0.45, 0.32, 0.18)
  love.graphics.rectangle("fill", x + 2, y + 18, 28, 4, 1, 1)
  -- Legs
  love.graphics.setColor(0.38, 0.28, 0.15)
  love.graphics.rectangle("fill", x + 4, y + 22, 3, 8)
  love.graphics.rectangle("fill", x + 25, y + 22, 3, 8)
end

function M.drawSupplyCrate(x, y)
  love.graphics.setColor(0.42, 0.30, 0.18)
  love.graphics.rectangle("fill", x + 4, y + 8, 24, 22, 2, 2)
  -- Bands
  love.graphics.setColor(0.50, 0.38, 0.22)
  love.graphics.rectangle("fill", x + 4, y + 14, 24, 3)
  love.graphics.rectangle("fill", x + 4, y + 22, 24, 3)
  -- Lid
  love.graphics.setColor(0.48, 0.35, 0.20)
  love.graphics.rectangle("fill", x + 3, y + 6, 26, 4, 1, 1)
end

function M.drawFirewood(x, y)
  -- Stack of logs
  for i = 0, 3 do
    local ly = y + 20 - i * 5
    local hash = (i * 47) % 100 / 100
    love.graphics.setColor(0.40 + hash * 0.1, 0.28 + hash * 0.06, 0.15 + hash * 0.04)
    love.graphics.ellipse("fill", x + 16, ly, 10 - i, 3)
  end
  -- Snow on top
  love.graphics.setColor(0.88, 0.90, 0.94, 0.3)
  love.graphics.ellipse("fill", x + 16, y + 4, 8, 2)
end

function M.drawBell(x, y, time)
  -- Chain
  love.graphics.setColor(0.50, 0.42, 0.25)
  love.graphics.line(x + 16, y, x + 16, y + 10)
  -- Bell body
  love.graphics.setColor(0.72, 0.58, 0.20)
  local sway = math.sin(time * 1.2) * 1
  love.graphics.polygon("fill",
    x + 10 + sway, y + 10,
    x + 22 + sway, y + 10,
    x + 24 + sway, y + 22,
    x + 8 + sway, y + 22
  )
  -- Clapper
  love.graphics.setColor(0.60, 0.48, 0.18)
  love.graphics.circle("fill", x + 16 + sway, y + 22, 2)
end

function M.drawFrozenStream(x1, y1, x2, y2, time)
  local gs = areas.GRID_SIZE
  local streamH = y2 - y1 + gs
  -- Ice surface
  love.graphics.setColor(0.65, 0.80, 0.92, 0.5)
  love.graphics.rectangle("fill", x1 + 8, y1, 16, streamH, 3, 3)
  -- Ice cracks
  love.graphics.setColor(0.50, 0.65, 0.80, 0.3)
  love.graphics.setLineWidth(1)
  for i = 0, 4 do
    local cy = y1 + i * streamH / 4
    love.graphics.line(x1 + 10, cy, x1 + 22, cy + 8)
  end
  -- Shimmer
  local shimmer = math.sin(time * 0.8) * 0.1 + 0.15
  love.graphics.setColor(0.80, 0.90, 1.0, shimmer)
  love.graphics.rectangle("fill", x1 + 12, y1 + streamH * 0.3, 8, 4)
end

-- =============================================
-- SCREEN-SPACE: Snow (drawn after pop)
-- =============================================

function M.drawSnow(screenW, screenH)
  local snow = areas.getSnow()
  for _, p in ipairs(snow) do
    local alpha = p.opacity
    local wobble = math.sin(p.wobble) * 2
    local sx = (p.x + wobble) % (screenW + 20) - 10
    local sy = p.y % (screenH + 20) - 10
    love.graphics.setColor(0.92, 0.94, 0.97, alpha)
    love.graphics.circle("fill", sx, sy, p.size)
  end
end

-- =============================================
-- SCREEN-SPACE: Wind overlay (drawn after pop)
-- =============================================

function M.drawWindOverlay(screenW, screenH, time)
  if wind.speed < 20 then return end

  local intensity = (wind.speed - 20) / 40
  intensity = math.min(intensity, 0.5)

  love.graphics.setColor(0.85, 0.88, 0.93, intensity * 0.08)
  -- Streaks
  for i = 1, 8 do
    local y = (i * 97 + time * 50) % screenH
    local x = wind.direction > 0 and 0 or screenW
    local len = 80 + math.sin(time + i) * 40
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y, x + len * wind.direction, y + 2)
  end
end

-- =============================================
-- SCREEN-SPACE: Altitude indicator (drawn after pop)
-- =============================================

function M.drawAltitudeIndicator(playerY)
  local alt = 5500 - (playerY / (areas.WORLD_HEIGHT * areas.GRID_SIZE)) * 1000
  love.graphics.setColor(0.6, 0.8, 1.0, 0.6)
  love.graphics.print(string.format("%.0fm", alt), love.graphics.getWidth() - 100, 35)
end

return M

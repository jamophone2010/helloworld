-- singularity/init.lua
-- Cosmic village hub - Interstellar tesseract inspired
-- Paths floating among stars with black hole in background

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local areas = require("singularity.areas")
local buildings = require("singularity.buildings")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

function M.load()
  gameState.location = "outdoors"
  gameState.interiorId = nil

  -- Initialize background stars
  areas.initStars(300)

  -- Player starts at Event Horizon Plaza
  local startX = areas.spawnPoint.x * 32 + 16
  local startY = areas.spawnPoint.y * 32 + 16
  gameState.player = player.new(startX, startY)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.collisionMap = areas.createCollisionMap()
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.buildingEntryCooldown = 0
  gameState.transition = nil
  gameState.returnLocation = nil
  gameState.returnPosition = nil
  gameState.fadeInFromStarfox = false

  -- Currency
  gameState.credits = 1000000
  gameState.notes = currency.load()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false}
  gameState.paused = false
  gameState.animationTime = 0

  -- Black hole animation
  gameState.blackHoleRotation = 0
  gameState.gravitationalPulse = 0

  M.setupOutdoorNPCs()

  audio.load()
  pauseMenu.load()

  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 0.5,
      callback = nil,
      color = {1, 1, 1}  -- White fade
    }
    gameState.fadeInFromStarfox = false
  end
end

-- ═══════════════════════════════════════
-- GETTERS / SETTERS
-- ═══════════════════════════════════════

function M.getCredits() return gameState.credits end
function M.setCredits(amount) gameState.credits = amount end
function M.getNotes() return gameState.notes end
function M.setNotes(amount) gameState.notes = amount end

function M.addNotes(amount)
  gameState.notes = gameState.notes + amount
  currency.save(gameState.notes)
end

function M.spendNotes(amount)
  if gameState.notes >= amount then
    gameState.notes = gameState.notes - amount
    currency.save(gameState.notes)
    return true
  end
  return false
end

function M.getShopItems() return gameState.shopItems end
function M.clearShopItems() gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false} end
function M.setPaused(paused) gameState.paused = paused end

function M.setFadeInFromStarfox(enable)
  gameState.fadeInFromStarfox = enable
end

-- ═══════════════════════════════════════
-- NPC MANAGEMENT
-- ═══════════════════════════════════════

function M.setupOutdoorNPCs()
  gameState.currentNPCs = {}
  for _, npcData in ipairs(areas.npcs) do
    table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
  end
end

function M.enterBuilding(buildingId)
  local interior = buildings.getInterior(buildingId)
  if not interior then return end

  gameState.interiorId = buildingId
  gameState.location = "interior"
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}

  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * 32 + 16
  gameState.player.y = gameState.player.gridY * 32 + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y

  gameState.collisionMap = buildings.createInteriorCollisionMap(buildingId)
  gameState.currentPortals = interior.portals

  gameState.currentNPCs = {}
  if interior.npcs then
    for _, npcData in ipairs(interior.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
    end
  end
end

function M.exitBuilding()
  gameState.transition = {
    phase = "out",
    timer = 0,
    duration = 0.2,
    callback = function()
      M.doExitBuilding()
    end
  }
end

function M.doExitBuilding()
  gameState.location = "outdoors"
  local buildingId = gameState.interiorId
  gameState.interiorId = nil
  gameState.buildingEntryCooldown = 0.5

  if gameState.returnPosition then
    gameState.player.gridX = gameState.returnPosition.gridX
    gameState.player.gridY = gameState.returnPosition.gridY + 1
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.returnPosition = nil
  else
    for _, b in ipairs(areas.buildings) do
      if b.interior == buildingId then
        gameState.player.gridX = b.doorX
        gameState.player.gridY = b.doorY + 1
        gameState.player.x = gameState.player.gridX * 32 + 16
        gameState.player.y = gameState.player.gridY * 32 + 16
        gameState.player.targetX = gameState.player.x
        gameState.player.targetY = gameState.player.y
        break
      end
    end
  end

  gameState.collisionMap = areas.createCollisionMap()
  gameState.currentPortals = nil
  M.setupOutdoorNPCs()
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  if gameState.paused then
    pauseMenu.update(dt)
    return
  end

  gameState.animationTime = gameState.animationTime + dt
  gameState.blackHoleRotation = gameState.blackHoleRotation + dt * 0.015
  gameState.gravitationalPulse = gameState.gravitationalPulse + dt * 0.5

  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.update(npcObj, dt, gameState.collisionMap, gameState.currentNPCs, gameState.player)
  end

  if love.keyboard.isDown("up") then
    player.tryMove(gameState.player, "up", gameState.collisionMap, gameState.currentNPCs)
  elseif love.keyboard.isDown("down") then
    player.tryMove(gameState.player, "down", gameState.collisionMap, gameState.currentNPCs)
  elseif love.keyboard.isDown("left") then
    player.tryMove(gameState.player, "left", gameState.collisionMap, gameState.currentNPCs)
  elseif love.keyboard.isDown("right") then
    player.tryMove(gameState.player, "right", gameState.collisionMap, gameState.currentNPCs)
  end

  camera.update(gameState.camera, gameState.player.x, gameState.player.y)

  if gameState.transition then
    gameState.transition.timer = gameState.transition.timer + dt
    if gameState.transition.phase == "out" then
      if gameState.transition.timer >= gameState.transition.duration then
        if gameState.transition.callback then
          gameState.transition.callback()
        end
        gameState.transition.phase = "in"
        gameState.transition.timer = 0
      end
    elseif gameState.transition.phase == "in" then
      if gameState.transition.timer >= gameState.transition.duration then
        gameState.transition = nil
      end
    end
    return
  end

  if gameState.buildingEntryCooldown > 0 then
    gameState.buildingEntryCooldown = gameState.buildingEntryCooldown - dt
    if gameState.buildingEntryCooldown < 0 then
      gameState.buildingEntryCooldown = 0
    end
  end

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil

  if gameState.location == "outdoors" then
    if gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(areas.buildings) do
        if gameState.player.gridX == b.doorX and gameState.player.gridY == b.doorY then
          gameState.nearBuildingDoor = b
          local interiorId = b.interior
          gameState.transition = {
            phase = "out",
            timer = 0,
            duration = 0.2,
            callback = function()
              M.enterBuilding(interiorId)
              audio.playPortal()
            end
          }
          break
        end
      end
    end
  else
    if gameState.currentPortals then
      for _, portal in ipairs(gameState.currentPortals) do
        local dx = math.abs(gameState.player.gridX - portal.x)
        local dy = math.abs(gameState.player.gridY - portal.y)
        if dx <= 1 and dy <= 1 then
          gameState.nearbyPortal = portal
          break
        end
      end
    end

    if gameState.interiorId then
      if buildings.isAtExit(gameState.player.gridX, gameState.player.gridY, gameState.interiorId) then
        M.exitBuilding()
      end
    end
  end

  for _, npcObj in ipairs(gameState.currentNPCs) do
    local npcGridX = npcObj.gridX or npcObj.x
    local npcGridY = npcObj.gridY or npcObj.y
    if math.abs(gameState.player.gridX - npcGridX) <= 1 and
       math.abs(gameState.player.gridY - npcGridY) <= 1 then
      gameState.nearbyNPC = npcObj
      break
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════

function M.draw()
  -- Draw void background (always behind everything)
  love.graphics.setColor(areas.COLORS.void[1], areas.COLORS.void[2], areas.COLORS.void[3])
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.push()
  love.graphics.translate(-gameState.camera.x + love.graphics.getWidth() / 2,
                          -gameState.camera.y + love.graphics.getHeight() / 2)

  if gameState.location == "outdoors" then
    M.drawOutdoors()
  else
    M.drawInterior()
  end

  player.draw(gameState.player, gameState.animationTime)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj)
  end

  love.graphics.pop()

  M.drawUI()

  if gameState.paused then
    pauseMenu.draw()
  end

  if gameState.transition then
    local alpha = 0
    if gameState.transition.phase == "out" then
      alpha = gameState.transition.timer / gameState.transition.duration
    elseif gameState.transition.phase == "in" then
      alpha = 1 - gameState.transition.timer / gameState.transition.duration
    end
    alpha = math.max(0, math.min(1, alpha))
    local color = gameState.transition.color or {0, 0, 0}
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  end
end

function M.drawOutdoors()
  -- Draw background stars
  M.drawBackgroundStars()

  -- Draw black hole
  M.drawBlackHole()

  -- Draw star paths (bridges between platforms)
  for _, path in ipairs(areas.starPaths) do
    M.drawStarPath(path)
  end

  -- Draw platforms (zones)
  for name, zone in pairs(areas.zones) do
    if not zone.isVoid and zone.groundColor then
      M.drawPlatform(zone)
    end
  end

  -- Draw buildings
  for _, b in ipairs(areas.buildings) do
    M.drawBuilding(b)
  end
end

function M.drawBackgroundStars()
  for _, star in ipairs(areas.backgroundStars) do
    local twinkle = math.sin(gameState.animationTime * star.twinkleSpeed + star.twinkleOffset) * 0.3 + 0.7
    local brightness = star.brightness * twinkle

    -- Mix white with amber based on warmth
    local r = 1.0 * (1 - star.warmth * 0.3) + areas.COLORS.amber[1] * star.warmth * 0.3
    local g = 1.0 * (1 - star.warmth * 0.5) + areas.COLORS.amber[2] * star.warmth * 0.5
    local b = 1.0 * (1 - star.warmth * 0.7) + areas.COLORS.amber[3] * star.warmth * 0.7

    love.graphics.setColor(r, g, b, brightness)
    love.graphics.circle("fill", star.x, star.y, star.size)
  end
end

function M.drawBlackHole()
  local bhX = areas.blackHolePos.x * 32 + 16
  local bhY = areas.blackHolePos.y * 32 + 16
  local baseRadius = areas.blackHoleRadius

  local pulse = math.sin(gameState.gravitationalPulse) * 0.1 + 0.9

  -- Distant warm glow halo (Interstellar-style diffuse light)
  for i = 20, 1, -1 do
    local glowRadius = baseRadius + i * 25
    local alpha = (21 - i) / 21 * 0.12 * pulse
    love.graphics.setColor(1.0, 0.7, 0.25, alpha)
    love.graphics.circle("fill", bhX, bhY, glowRadius)
  end

  -- Accretion disk - wide, warm, Interstellar-style
  love.graphics.push()
  love.graphics.translate(bhX, bhY)
  love.graphics.rotate(gameState.blackHoleRotation)

  -- Outer diffuse accretion glow
  for i = 12, 1, -1 do
    local diskRadius = baseRadius * 1.8 - i * 8
    local alpha = (13 - i) / 13 * 0.35 * pulse
    love.graphics.setColor(
      1.0 * (1 - i/24) + 0.95 * (i/24),
      0.55 * (1 - i/24) + 0.4 * (i/24),
      0.1 * (1 - i/24) + 0.05 * (i/24),
      alpha
    )
    love.graphics.setLineWidth(6 + i * 2)
    love.graphics.ellipse("line", 0, 0, diskRadius, diskRadius * 0.35)
  end

  -- Bright inner accretion ring
  for i = 6, 1, -1 do
    local innerR = baseRadius * 1.15 + i * 5
    local alpha = (7 - i) / 7 * 0.7 * pulse
    love.graphics.setColor(1.0, 0.85, 0.45, alpha)
    love.graphics.setLineWidth(4 + i)
    love.graphics.ellipse("line", 0, 0, innerR, innerR * 0.35)
  end

  -- Hot white-amber core ring (photon ring)
  love.graphics.setColor(1.0, 0.95, 0.75, 0.85 * pulse)
  love.graphics.setLineWidth(3)
  love.graphics.ellipse("line", 0, 0, baseRadius * 1.05, baseRadius * 1.05 * 0.35)

  love.graphics.pop()

  -- Gravitational lensing ring (Einstein ring - vertical halo behind the hole)
  love.graphics.push()
  love.graphics.translate(bhX, bhY)
  love.graphics.rotate(gameState.blackHoleRotation * 0.3)
  for i = 4, 1, -1 do
    local lensR = baseRadius * 1.15 + i * 3
    love.graphics.setColor(1.0, 0.9, 0.6, (5 - i) / 5 * 0.4 * pulse)
    love.graphics.setLineWidth(2 + i)
    love.graphics.ellipse("line", 0, 0, lensR * 0.4, lensR)
  end
  love.graphics.pop()

  -- Event horizon (pure black center)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.circle("fill", bhX, bhY, baseRadius)

  -- Thin bright photon sphere edge
  love.graphics.setColor(1.0, 0.92, 0.7, 0.55 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", bhX, bhY, baseRadius)

  -- Subtle inner edge highlight (light bending at the horizon)
  love.graphics.setColor(1.0, 0.85, 0.5, 0.2 * pulse)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", bhX, bhY, baseRadius - 3)
end

function M.drawStarPath(path)
  local x1 = path.x1 * 32
  local y1 = path.y1 * 32
  local x2 = (path.x2 + 1) * 32
  local y2 = (path.y2 + 1) * 32

  -- Glowing path
  local pulse = math.sin(gameState.animationTime * 2) * 0.2 + 0.8

  -- Glow underneath
  love.graphics.setColor(path.glow[1], path.glow[2], path.glow[3], 0.3 * pulse)
  love.graphics.rectangle("fill", x1 - 4, y1 - 4, x2 - x1 + 8, y2 - y1 + 8)

  -- Path surface
  love.graphics.setColor(0.1, 0.08, 0.06, 0.9)
  love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)

  -- Edge glow
  love.graphics.setColor(path.glow[1], path.glow[2], path.glow[3], 0.7 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
end

function M.drawPlatform(zone)
  local x = zone.x1 * 32
  local y = zone.y1 * 32
  local w = (zone.x2 - zone.x1 + 1) * 32
  local h = (zone.y2 - zone.y1 + 1) * 32

  local pulse = math.sin(gameState.animationTime * 1.5) * 0.15 + 0.85

  -- Glow underneath platform
  if zone.glowColor then
    love.graphics.setColor(zone.glowColor[1], zone.glowColor[2], zone.glowColor[3], 0.25 * pulse)
    love.graphics.rectangle("fill", x - 8, y - 8, w + 16, h + 16)
  end

  -- Platform surface
  love.graphics.setColor(zone.groundColor[1], zone.groundColor[2], zone.groundColor[3], 0.95)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Grid lines (tesseract effect)
  if zone.glowColor then
    love.graphics.setColor(zone.glowColor[1], zone.glowColor[2], zone.glowColor[3], 0.15)
    love.graphics.setLineWidth(1)
    for gx = x, x + w, 32 do
      love.graphics.line(gx, y, gx, y + h)
    end
    for gy = y, y + h, 32 do
      love.graphics.line(x, gy, x + w, gy)
    end
  end

  -- Edge glow
  if zone.glowColor then
    love.graphics.setColor(zone.glowColor[1], zone.glowColor[2], zone.glowColor[3], 0.6 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
  end
end

function M.drawBuilding(b)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32

  local pulse = math.sin(gameState.animationTime * 2 + x * 0.01) * 0.2 + 0.8

  -- Building glow
  love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.2 * pulse)
  love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8)

  -- Building body
  love.graphics.setColor(b.color[1], b.color[2], b.color[3])
  love.graphics.rectangle("fill", x, y, w, h)

  -- Windows (amber glow)
  love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.7)
  local windowY = y + 8
  for wx = x + 6, x + w - 14, 16 do
    love.graphics.rectangle("fill", wx, windowY, 10, 8)
  end

  -- Door (Interstellar tesseract-style portal)
  local doorPx = b.doorX * 32 + 2
  local doorPy = (b.y + b.h - 1) * 32 + 2
  local doorW = 28
  local doorH = 28

  -- Warm glow emanating from doorway
  for gi = 4, 1, -1 do
    love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.08 * (5 - gi) * pulse)
    love.graphics.rectangle("fill", doorPx - gi * 3, doorPy - gi * 2, doorW + gi * 6, doorH + gi * 4, 2)
  end

  -- Dark doorway interior
  love.graphics.setColor(0.02, 0.01, 0.01)
  love.graphics.rectangle("fill", doorPx, doorPy, doorW, doorH, 2)

  -- Tesseract grid lines inside the doorway (like looking into the tesseract)
  love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.15 * pulse)
  love.graphics.setLineWidth(1)
  for gx = doorPx + 7, doorPx + doorW - 4, 7 do
    love.graphics.line(gx, doorPy + 2, gx, doorPy + doorH - 2)
  end
  for gy = doorPy + 7, doorPy + doorH - 4, 7 do
    love.graphics.line(doorPx + 2, gy, doorPx + doorW - 2, gy)
  end

  -- Bright amber door frame
  love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.8 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", doorPx, doorPy, doorW, doorH, 2)

  -- Top lintel accent
  love.graphics.setColor(b.glowColor[1] * 1.1, b.glowColor[2] * 1.1, b.glowColor[3] * 0.8, 0.9 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.line(doorPx - 2, doorPy, doorPx + doorW + 2, doorPy)

  -- Building edge glow
  love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.5 * pulse)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h)

  -- Building name
  love.graphics.setColor(areas.COLORS.cream[1], areas.COLORS.cream[2], areas.COLORS.cream[3], 0.9)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  love.graphics.print(b.name, x + w/2 - textW/2, y - 16)
end

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Dark floor with grid
  love.graphics.setColor(0.08, 0.06, 0.04)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

  -- Grid lines
  love.graphics.setColor(areas.COLORS.amber[1], areas.COLORS.amber[2], areas.COLORS.amber[3], 0.1)
  love.graphics.setLineWidth(1)
  for x = 0, interior.width * 32, 32 do
    love.graphics.line(x, 0, x, interior.height * 32)
  end
  for y = 0, interior.height * 32, 32 do
    love.graphics.line(0, y, interior.width * 32, y)
  end

  -- Walls (dark with amber glow)
  love.graphics.setColor(0.12, 0.08, 0.05)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
  love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

  -- Exit door
  love.graphics.setColor(areas.COLORS.amber[1], areas.COLORS.amber[2], areas.COLORS.amber[3], 0.4)
  love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)

  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local px = portal.x * 32
      local py = portal.y * 32
      local pulse = math.sin(gameState.animationTime * 3) * 0.2 + 0.8

      -- Portal glow
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.3 * pulse)
      love.graphics.circle("fill", px + 16, py + 16, 28)

      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], pulse)
      love.graphics.circle("fill", px + 16, py + 16, 18)

      love.graphics.setColor(areas.COLORS.cream[1], areas.COLORS.cream[2], areas.COLORS.cream[3])
      local font = love.graphics.getFont()
      local textW = font:getWidth(portal.name)
      love.graphics.print(portal.name, px + 16 - textW/2, py + 40)
    end
  end

  -- Interior name
  love.graphics.setColor(areas.COLORS.gold[1], areas.COLORS.gold[2], areas.COLORS.gold[3])
  love.graphics.print(interior.name, 40, 40)
end

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Zone name
  local zoneName, zone = areas.getZoneAt(gameState.player.gridX, gameState.player.gridY)
  if gameState.location == "outdoors" and zone then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 220, 30, 5, 5)
    love.graphics.setColor(areas.COLORS.gold[1], areas.COLORS.gold[2], areas.COLORS.gold[3])
    love.graphics.print(zone.name or "The Void", 20, 17)
  elseif gameState.location == "interior" then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", 10, 10, 250, 30, 5, 5)
      love.graphics.setColor(areas.COLORS.gold[1], areas.COLORS.gold[2], areas.COLORS.gold[3])
      love.graphics.print(interior.name, 20, 17)
    end
  end

  -- Currency
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", screenW - 160, 10, 150, 30, 5, 5)
  love.graphics.setColor(areas.COLORS.amber[1], areas.COLORS.amber[2], areas.COLORS.amber[3])
  love.graphics.print("Notes: " .. gameState.notes, screenW - 150, 17)

  -- Interaction prompts
  if gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", screenW/2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(areas.COLORS.cream[1], areas.COLORS.cream[2], areas.COLORS.cream[3])
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW/2 - 120, screenH - 50, 240, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", screenW/2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(areas.COLORS.cream[1], areas.COLORS.cream[2], areas.COLORS.cream[3])
    love.graphics.printf("Press E to talk to " .. gameState.nearbyNPC.name, screenW/2 - 120, screenH - 50, 240, "center")
  end

  -- Dialogue box
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(areas.COLORS.amber[1], areas.COLORS.amber[2], areas.COLORS.amber[3], 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(areas.COLORS.gold[1], areas.COLORS.gold[2], areas.COLORS.gold[3])
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 140)
    love.graphics.setColor(areas.COLORS.cream[1], areas.COLORS.cream[2], areas.COLORS.cream[3])
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 115, screenW - 140, "left")
    love.graphics.setColor(0.6, 0.5, 0.4)
    love.graphics.print("Press E to close", 70, screenH - 50)
  end

  -- Return hint
  if gameState.location == "outdoors" then
    local nearEdge = gameState.player.gridX <= 1 or gameState.player.gridX >= areas.WIDTH - 2 or
                     gameState.player.gridY <= 1 or gameState.player.gridY >= areas.HEIGHT - 2
    if nearEdge then
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", screenW/2 - 140, 50, 280, 30, 5, 5)
      love.graphics.setColor(areas.COLORS.cream[1], areas.COLORS.cream[2], areas.COLORS.cream[3])
      love.graphics.printf("Press ESC to pause", screenW/2 - 140, 57, 280, "center")
    end
  end
end

-- ═══════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════

function M.textinput(text)
  if gameState.paused then
    pauseMenu.textinput(text)
  end
end

function M.keypressed(key)
  if gameState.paused then
    pauseMenu.keypressed(key)
    return
  end

  if key == "escape" then
    if gameState.dialogueBox then
      gameState.dialogueBox = nil
    else
      gameState.paused = true
    end
    return
  end

  if gameState.dialogueBox then
    if key == "e" or key == "escape" or key == "return" then
      gameState.dialogueBox = nil
    end
    return
  end

  if key == "e" then
    if gameState.nearbyPortal then
      audio.playPortal()
      gameState.returnLocation = gameState.location
      gameState.returnPosition = {
        gridX = gameState.player.gridX,
        gridY = gameState.player.gridY
      }
      if M.switchToGame then
        M.switchToGame(gameState.nearbyPortal.game)
      end
      return
    end

    if gameState.nearbyNPC then
      gameState.dialogueBox = {
        npc = gameState.nearbyNPC.name,
        text = gameState.nearbyNPC.dialogue
      }
      return
    end
  end
end

-- ═══════════════════════════════════════
-- RETURN FROM GAMES
-- ═══════════════════════════════════════

function M.returnFromGame()
  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 0.5,
      callback = nil
    }
    gameState.fadeInFromStarfox = false
  end

  if gameState.returnLocation and gameState.returnLocation ~= "outdoors" then
    M.enterBuilding(gameState.interiorId or gameState.returnLocation)
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY
      gameState.player.x = gameState.player.gridX * 32 + 16
      gameState.player.y = gameState.player.gridY * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
    end
  else
    gameState.location = "outdoors"
    gameState.collisionMap = areas.createCollisionMap()
    M.setupOutdoorNPCs()
  end
  gameState.returnLocation = nil
  gameState.returnPosition = nil
end

return M

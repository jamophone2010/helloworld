-- chillon/init.lua
-- Chillon: Swiss-French alpine lakeside town (Montreux × Chamonix)
-- Cobblestone promenades, watchmaker ateliers, lakefront jazz stages,
-- alpine chalets, instrument workshops, mountain refuges, and thermal baths
-- Full day/night cycle, falling snow, aurora borealis

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local areas = require("chillon.areas")
local buildings = require("chillon.buildings")
local lighting = require("chillon.lighting")
local environment = require("chillon.environment")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

-- ═══════════════════════════════════════
-- LOAD
-- ═══════════════════════════════════════

function M.load()
  gameState.location = "outdoors"
  gameState.interiorId = nil

  -- Initialize environment systems
  areas.initParticles(100)
  areas.initStars(250)

  -- Player starts at village center
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

  -- Setup outdoor NPCs
  M.setupOutdoorNPCs()

  -- Initialize systems
  audio.load()
  pauseMenu.load()
  lighting.init()
  environment.init()

  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 1.0,
      callback = nil,
      color = {1, 1, 1}
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

  gameState.collisionMap = buildings.createInteriorCollisionMap(interior)
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

  -- Update systems
  lighting.update(dt)
  environment.update(dt)

  -- Update player
  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  -- Collect door positions for NPC pathfinding (prevent blocking doorways)
  local doorPositions = {}
  if gameState.location == "outdoors" then
    for _, b in ipairs(areas.buildings) do
      table.insert(doorPositions, {x = b.doorX, y = b.doorY})
    end
  end

  -- Update NPCs
  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.update(npcObj, dt, gameState.collisionMap, gameState.currentNPCs, gameState.player, doorPositions)
  end

  -- Continuous movement (disabled during dialogue)
  if not gameState.dialogueBox then
    if love.keyboard.isDown("up") then
      player.tryMove(gameState.player, "up", gameState.collisionMap, gameState.currentNPCs)
    elseif love.keyboard.isDown("down") then
      player.tryMove(gameState.player, "down", gameState.collisionMap, gameState.currentNPCs)
    elseif love.keyboard.isDown("left") then
      player.tryMove(gameState.player, "left", gameState.collisionMap, gameState.currentNPCs)
    elseif love.keyboard.isDown("right") then
      player.tryMove(gameState.player, "right", gameState.collisionMap, gameState.currentNPCs)
    end
  end

  camera.update(gameState.camera, gameState.player.x, gameState.player.y)

  -- Handle transitions
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

  -- Cooldowns
  if gameState.buildingEntryCooldown > 0 then
    gameState.buildingEntryCooldown = gameState.buildingEntryCooldown - dt
    if gameState.buildingEntryCooldown < 0 then
      gameState.buildingEntryCooldown = 0
    end
  end

  -- Reset proximity flags
  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil

  if gameState.location == "outdoors" then
    -- Check building doors
    if gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(areas.buildings) do
        if gameState.player.gridX == b.doorX and gameState.player.gridY == b.doorY - 1 then
          if love.keyboard.isDown("up") then
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
    end
  else
    -- Inside a building
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
      local interior = buildings.getInterior(gameState.interiorId)
      if interior and buildings.isAtExit(interior, gameState.player.gridX, gameState.player.gridY) then
        M.exitBuilding()
      end
    end
  end

  -- Check nearby NPCs
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
-- DRAW (layered alpine rendering)
-- ═══════════════════════════════════════

function M.draw()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local _, ambientIntensity = lighting.getAmbientLight()
  local skyColors = {lighting.getSkyColors()}

  if gameState.location == "outdoors" then
    -- Layer 0: Alpine sky gradient
    environment.drawSky(screenW, screenH, skyColors)

    -- Layer 0.5: Stars (night)
    environment.drawStars(screenW, screenH, gameState.animationTime, lighting.isNight())

    -- Layer 1: Moon
    lighting.drawMoonlight(screenW, screenH, gameState.animationTime)

    -- Layer 1.5: Aurora Borealis (night)
    environment.drawAurora(screenW, screenH, gameState.animationTime, lighting.isNight())

    -- Layer 2: Distant mountain range (parallax background)
    environment.drawMountainRange(screenW, screenH, gameState.camera.y, ambientIntensity)

    -- Layer 3: Clouds
    environment.drawClouds(gameState.camera.x, gameState.camera.y, gameState.animationTime, ambientIntensity)
  end

  -- Main world (camera-transformed)
  love.graphics.push()
  love.graphics.translate(math.floor(-gameState.camera.x + screenW / 2),
                          math.floor(-gameState.camera.y + screenH / 2))

  if gameState.location == "outdoors" then
    M.drawOutdoors()
  else
    M.drawInterior()
  end

  -- Draw player shadow
  if gameState.location == "outdoors" then
    lighting.drawPlayerShadow(gameState.player.x, gameState.player.y)
  end

  -- Draw player
  player.draw(gameState.player, gameState.animationTime)

  -- Draw NPCs
  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj)
  end

  love.graphics.pop()

  -- Post-processing overlays
  if gameState.location == "outdoors" then
    -- Falling snow (on top of everything for depth)
    environment.drawSnow(gameState.camera.x, gameState.camera.y, screenW, screenH)

    -- Blizzard overlay (when wind is high)
    environment.drawBlizzardOverlay(screenW, screenH, gameState.animationTime)

    -- Ambient lighting overlay
    lighting.applyAmbientOverlay(screenW, screenH)
  end

  -- UI overlay
  M.drawUI()

  -- Pause menu
  if gameState.paused then
    pauseMenu.draw()
  end

  -- Transition fade
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
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

-- ═══════════════════════════════════════
-- DRAW: OUTDOORS
-- ═══════════════════════════════════════

function M.drawOutdoors()
  local gs = 32
  local _, ambientIntensity = lighting.getAmbientLight()

  -- Draw ground zones with alpine textures
  for name, zone in pairs(areas.zones) do
    if zone.groundColor then
      M.drawGroundZone(name, zone, gs, ambientIntensity)
    end
  end

  -- Draw frozen lake
  environment.drawFrozenLake(gs, gameState.animationTime, ambientIntensity)

  -- Draw gorges (void under bridges)
  environment.drawGorges(gs, gameState.animationTime, ambientIntensity)

  -- Draw mountain trails
  M.drawTrails(gs, ambientIntensity)

  -- Draw building shadows
  for _, b in ipairs(areas.buildings) do
    lighting.drawShadow(b.x, b.y, b.w, b.h, gs)
  end

  -- Draw tree shadows
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "pine_tree" then
      lighting.drawTreeShadow(deco.x, deco.y, gs, "pine_tree")
    end
  end

  -- Draw non-tree decorations
  for _, deco in ipairs(areas.decorations) do
    if deco.type ~= "pine_tree" then
      M.drawDecoration(deco)
    end
  end

  -- Draw buildings (Swiss chalets, pavilions, etc.)
  for _, b in ipairs(areas.buildings) do
    M.drawBuilding(b)
  end

  -- Draw pine trees (on top for depth layering)
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "pine_tree" then
      environment.drawPineTree(deco.x, deco.y, gs, gameState.animationTime, deco.variety, ambientIntensity)
    end
  end

  -- Draw hot spring steam
  environment.drawSteam(gs, gameState.animationTime, ambientIntensity)
end

-- ═══════════════════════════════════════
-- DRAW: GROUND ZONES (alpine terrain textures)
-- ═══════════════════════════════════════

function M.drawGroundZone(name, zone, gs, ambientIntensity)
  local x = zone.x1 * gs
  local y = zone.y1 * gs
  local w = (zone.x2 - zone.x1 + 1) * gs
  local h = (zone.y2 - zone.y1 + 1) * gs
  local gc = zone.groundColor

  -- Base fill
  love.graphics.setColor(gc[1] * ambientIntensity, gc[2] * ambientIntensity, gc[3] * ambientIntensity)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Zone-specific textures
  if name == "village_square" or name == "artisan_quarter" or name == "lakefront" then
    -- Cobblestone with snow in cracks
    for tx = zone.x1, zone.x2 do
      for ty = zone.y1, zone.y2 do
        local shade = 0.95 + math.sin(tx * 4.1 + ty * 5.7) * 0.05
        love.graphics.setColor(gc[1] * ambientIntensity * shade, gc[2] * ambientIntensity * shade, gc[3] * ambientIntensity * shade)
        love.graphics.rectangle("fill", tx * gs + 1, ty * gs + 1, gs - 2, gs - 2, 1, 1)
        -- Snow in cracks
        love.graphics.setColor(0.78 * ambientIntensity, 0.82 * ambientIntensity, 0.88 * ambientIntensity, 0.2)
        love.graphics.line(tx * gs, ty * gs, tx * gs + gs, ty * gs)
        love.graphics.line(tx * gs, ty * gs, tx * gs, ty * gs + gs)
      end
    end

  elseif name == "pine_forest" then
    -- Dark forest floor with needle litter
    local count = math.floor(w * h / 150)
    for i = 1, count do
      local seed = i * 7.31 + zone.x1 * 13.7 + zone.y1 * 17.3
      local gx = x + (math.sin(seed) * 0.5 + 0.5) * w
      local gy = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      local needleLen = 3 + math.sin(seed * 2.91) * 2
      local angle = math.sin(seed * 4.1) * math.pi
      love.graphics.setColor(
        (gc[1] + 0.05) * ambientIntensity,
        (gc[2] + 0.08) * ambientIntensity,
        gc[3] * ambientIntensity,
        0.4
      )
      love.graphics.line(gx, gy, gx + math.cos(angle) * needleLen, gy + math.sin(angle) * needleLen)
    end
    -- Snow patches on forest floor
    environment.drawSnowGround(zone, x, y, w, h, gs, ambientIntensity, gameState.animationTime)

  elseif name == "snowfield" then
    -- Deep snow with wind-sculpted ridges
    for i = 1, 25 do
      local seed = i * 11.3 + zone.x1 * 5.7
      local ridgeX = x + (math.sin(seed) * 0.5 + 0.5) * w
      local ridgeY = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      local ridgeW = 30 + math.sin(seed * 2.1) * 20
      love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.3)
      love.graphics.ellipse("fill", ridgeX, ridgeY, ridgeW, 5)
      love.graphics.setColor(0.65 * ambientIntensity, 0.70 * ambientIntensity, 0.78 * ambientIntensity, 0.15)
      love.graphics.ellipse("fill", ridgeX + 3, ridgeY + 3, ridgeW * 0.9, 4)
    end

  elseif name == "frozen_lake" then
    -- Handled by environment.drawFrozenLake()
    return

  elseif name == "thermal_district" then
    -- Warm flagstone with mineral deposits
    for tx = zone.x1, zone.x2 do
      for ty = zone.y1, zone.y2 do
        local shade = 0.95 + math.sin(tx * 3.3 + ty * 4.1) * 0.05
        love.graphics.setColor(gc[1] * ambientIntensity * shade, gc[2] * ambientIntensity * shade, gc[3] * ambientIntensity * shade)
        love.graphics.rectangle("fill", tx * gs + 1, ty * gs + 1, gs - 2, gs - 2, 1, 1)
      end
    end
    -- Mineral stains (warm orange/ochre)
    for i = 1, 12 do
      local seed = i * 8.3 + zone.x1 * 3.1
      local sx = x + (math.sin(seed) * 0.5 + 0.5) * w
      local sy = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      love.graphics.setColor(0.55 * ambientIntensity, 0.42 * ambientIntensity, 0.25 * ambientIntensity, 0.2)
      love.graphics.circle("fill", sx, sy, 8 + math.sin(seed * 2.1) * 5)
    end

  elseif zone.isMountain then
    -- Rocky mountain terrain
    for i = 1, math.floor(w * h / 400) do
      local seed = i * 13.7 + zone.x1 * 7.1
      local rx = x + (math.sin(seed) * 0.5 + 0.5) * w
      local ry = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      local rockShade = gc[1] * (0.85 + math.sin(seed * 2.91) * 0.15)
      love.graphics.setColor(rockShade * ambientIntensity, rockShade * 0.95 * ambientIntensity, rockShade * 0.90 * ambientIntensity, 0.5)
      love.graphics.rectangle("fill", rx, ry, 8 + math.sin(seed * 3.7) * 4, 6 + math.sin(seed * 4.3) * 3)
    end
    -- Snow on mountain tops
    environment.drawSnowGround(zone, x, y, w, h, gs, ambientIntensity, gameState.animationTime)

  else
    -- Default: add snow patches
    environment.drawSnowGround(zone, x, y, w, h, gs, ambientIntensity, gameState.animationTime)
  end
end

-- ═══════════════════════════════════════
-- DRAW: MOUNTAIN TRAILS
-- ═══════════════════════════════════════

function M.drawTrails(gs, ambientIntensity)
  for _, trail in ipairs(areas.trails) do
    for _, seg in ipairs(trail.segments) do
      local minX = math.min(seg.x1, seg.x2)
      local maxX = math.max(seg.x1, seg.x2)
      local minY = math.min(seg.y1, seg.y2)
      local maxY = math.max(seg.y1, seg.y2)

      for gx = minX, maxX do
        for gy = minY, maxY do
          local px = gx * gs
          local py = gy * gs

          -- Packed earth/gravel trail
          local trailVar = math.sin(gx * 3.7 + gy * 5.3) * 0.03
          love.graphics.setColor(
            (0.45 + trailVar) * ambientIntensity,
            (0.42 + trailVar) * ambientIntensity,
            (0.38 + trailVar) * ambientIntensity
          )
          love.graphics.rectangle("fill", px, py, gs, gs)

          -- Gravel texture
          local gravel = math.sin(gx * 7.1 + gy * 11.3) * 0.05
          love.graphics.setColor(
            (0.48 + gravel) * ambientIntensity,
            (0.45 + gravel) * ambientIntensity,
            (0.40 + gravel) * ambientIntensity,
            0.5
          )
          love.graphics.circle("fill", px + 8, py + 12, 2)
          love.graphics.circle("fill", px + 22, py + 8, 1.5)
          love.graphics.circle("fill", px + 14, py + 24, 2)

          -- Snow dusting on trail edges
          love.graphics.setColor(0.80 * ambientIntensity, 0.83 * ambientIntensity, 0.88 * ambientIntensity, 0.15)
          love.graphics.rectangle("fill", px, py, gs, 3)
          love.graphics.rectangle("fill", px, py + gs - 3, gs, 3)
        end
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: BUILDINGS (Swiss chalet architecture)
-- ═══════════════════════════════════════

function M.drawBuilding(b)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32
  local _, ambientIntensity = lighting.getAmbientLight()
  local tc = b.timberColor or {0.40, 0.32, 0.22}
  local style = b.style or "chalet"

  if style == "pavilion" then
    M.drawPavilion(b, x, y, w, h, ambientIntensity, tc)
    return
  end

  if style == "chapel" then
    M.drawChapel(b, x, y, w, h, ambientIntensity, tc)
    return
  end

  -- ═══ BUILDING BODY (plaster and timber walls) ═══
  love.graphics.setColor(
    b.color[1] * ambientIntensity,
    b.color[2] * ambientIntensity,
    b.color[3] * ambientIntensity
  )
  love.graphics.rectangle("fill", x, y, w, h)

  -- Stone texture (clean-cut alpine masonry)
  for sx = x + 2, x + w - 4, 10 do
    for sy = y + 14, y + h - 2, 8 do
      local blockShade = 0.92 + math.sin(sx * 1.7 + sy * 2.3) * 0.08
      love.graphics.setColor(
        b.color[1] * ambientIntensity * blockShade,
        b.color[2] * ambientIntensity * blockShade,
        b.color[3] * ambientIntensity * blockShade
      )
      love.graphics.rectangle("fill", sx, sy, 8, 6, 1, 1)
      -- Mortar lines
      love.graphics.setColor(b.color[1] * ambientIntensity * 0.80, b.color[2] * ambientIntensity * 0.80, b.color[3] * ambientIntensity * 0.80, 0.15)
      love.graphics.rectangle("line", sx, sy, 8, 6, 1, 1)
    end
  end

  -- ═══ TIMBER FRAME (exposed half-timber, Swiss style) ═══
  love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity)
  -- Vertical beams
  love.graphics.rectangle("fill", x, y + 10, 4, h - 10)
  love.graphics.rectangle("fill", x + w - 4, y + 10, 4, h - 10)
  love.graphics.rectangle("fill", x + w/2 - 2, y + 10, 4, h - 10)
  -- Horizontal beam (lintel)
  love.graphics.rectangle("fill", x, y + 10, w, 3)
  -- Cross-bracing (Swiss chalet pattern)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.9, tc[2] * ambientIntensity * 0.9, tc[3] * ambientIntensity * 0.9)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(x + 4, y + 14, x + w/2 - 2, y + h - 4)
  love.graphics.line(x + w/2 + 2, y + 14, x + w - 4, y + h - 4)
  love.graphics.setLineWidth(1)

  -- Side shading
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.75, b.color[2] * ambientIntensity * 0.75, b.color[3] * ambientIntensity * 0.75)
  love.graphics.rectangle("fill", x + w - 4, y + 4, 4, h - 4)

  -- ═══ ROOF (steep pitched Swiss roof with wide eaves) ═══
  local roofOverhang = 14    -- Wide eaves (Swiss style)
  local roofPeakY = y - 22
  local roofBaseY = y + 2

  -- Main roof (dark slate)
  love.graphics.setColor(
    b.roofColor[1] * ambientIntensity,
    b.roofColor[2] * ambientIntensity,
    b.roofColor[3] * ambientIntensity
  )
  love.graphics.polygon("fill",
    x - roofOverhang, roofBaseY,
    x + w + roofOverhang, roofBaseY,
    x + w/2, roofPeakY
  )

  -- Roof tile texture (horizontal lines for slate tiles)
  for ty = roofPeakY + 4, roofBaseY - 2, 4 do
    local progress = (ty - roofPeakY) / (roofBaseY - roofPeakY)
    local lineW = (w + roofOverhang * 2) * progress
    local lineX = x + w/2 - lineW/2
    local plankShade = 0.90 + math.sin(ty * 0.8) * 0.10
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * plankShade,
      b.roofColor[2] * ambientIntensity * plankShade,
      b.roofColor[3] * ambientIntensity * plankShade
    )
    love.graphics.line(lineX, ty, lineX + lineW, ty)
  end

  -- Snow on roof
  love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.70)
  love.graphics.polygon("fill",
    x + w/2, roofPeakY + 2,
    x - roofOverhang + 5, roofBaseY - 4,
    x + w + roofOverhang - 5, roofBaseY - 4
  )
  -- Icicles on eaves
  love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.5)
  for ex = x - roofOverhang + 3, x + w + roofOverhang - 3, 8 do
    local icicleLen = 4 + math.sin(ex * 1.7) * 3
    love.graphics.polygon("fill",
      ex, roofBaseY,
      ex + 2, roofBaseY,
      ex + 1, roofBaseY + icicleLen
    )
  end

  -- Ridge beam
  love.graphics.setColor(tc[1] * ambientIntensity * 1.1, tc[2] * ambientIntensity * 1.1, tc[3] * ambientIntensity)
  love.graphics.setLineWidth(2)
  love.graphics.line(x - roofOverhang, roofBaseY, x + w/2, roofPeakY)
  love.graphics.line(x + w/2, roofPeakY, x + w + roofOverhang, roofBaseY)
  love.graphics.setLineWidth(1)

  -- ═══ CHIMNEY (stone, with smoke) ═══
  local chimneyX = x + w - 16
  local chimneyY = roofPeakY + 8
  love.graphics.setColor(0.38 * ambientIntensity, 0.35 * ambientIntensity, 0.32 * ambientIntensity)
  love.graphics.rectangle("fill", chimneyX, chimneyY - 20, 10, 20)
  -- Chimney cap
  love.graphics.setColor(0.42 * ambientIntensity, 0.38 * ambientIntensity, 0.35 * ambientIntensity)
  love.graphics.rectangle("fill", chimneyX - 2, chimneyY - 22, 14, 3)
  -- Smoke wisps
  for i = 1, 4 do
    local smokeX = chimneyX + 5 + math.sin(gameState.animationTime * 0.5 + i * 1.7) * 8
    local smokeY = chimneyY - 22 - i * 10
    local smokeAlpha = (0.18 - i * 0.035)
    love.graphics.setColor(0.55, 0.55, 0.58, math.max(0, smokeAlpha))
    love.graphics.circle("fill", smokeX, smokeY, 4 + i * 2)
  end

  -- ═══ FLOWER BOX UNDER WINDOWS (chalet detail) ═══
  if style == "chalet" or style == "greathall" then
    local windowY = y + 22
    -- Flower boxes with geraniums
    for wx = x + 16, x + w - 32, 32 do
      -- Window box
      love.graphics.setColor(tc[1] * ambientIntensity * 0.8, tc[2] * ambientIntensity * 0.8, tc[3] * ambientIntensity * 0.8)
      love.graphics.rectangle("fill", wx - 2, windowY + 12, 18, 5, 1, 1)
      -- Red geraniums (tiny flowers)
      for fi = 0, 3 do
        love.graphics.setColor(0.75 * ambientIntensity, 0.15 * ambientIntensity, 0.15 * ambientIntensity, 0.8)
        love.graphics.circle("fill", wx + 2 + fi * 4, windowY + 10, 2)
        love.graphics.setColor(0.20 * ambientIntensity, 0.40 * ambientIntensity, 0.18 * ambientIntensity, 0.7)
        love.graphics.rectangle("fill", wx + 1 + fi * 4, windowY + 11, 2, 2)
      end
    end
  end

  -- ═══ DOOR (arched wooden door, Swiss style) ═══
  local doorX = b.doorX * 32 + 4
  local doorY = b.doorY * 32 - 24
  local doorW = 24
  local doorH = 24

  -- Door frame
  love.graphics.setColor(tc[1] * 0.8 * ambientIntensity, tc[2] * 0.8 * ambientIntensity, tc[3] * 0.8 * ambientIntensity)
  love.graphics.rectangle("fill", doorX - 2, doorY - 2, doorW + 4, doorH + 4)

  -- Door planks
  love.graphics.setColor(0.38 * ambientIntensity, 0.30 * ambientIntensity, 0.20 * ambientIntensity)
  love.graphics.rectangle("fill", doorX, doorY, doorW, doorH, 2, 2)
  -- Plank lines
  love.graphics.setColor(0.32 * ambientIntensity, 0.26 * ambientIntensity, 0.16 * ambientIntensity, 0.5)
  for px = doorX + 6, doorX + doorW - 4, 6 do
    love.graphics.line(px, doorY + 2, px, doorY + doorH - 2)
  end
  -- Brass handle (Swiss style)
  love.graphics.setColor(0.70 * ambientIntensity, 0.58 * ambientIntensity, 0.30 * ambientIntensity)
  love.graphics.circle("fill", doorX + doorW - 8, doorY + doorH / 2, 2.5)

  -- ═══ WINDOWS (shuttered, with alpine charm) ═══
  local windowY = y + 22
  for wx = x + 16, x + w - 32, 32 do
    -- Window recess
    love.graphics.setColor(b.color[1] * ambientIntensity * 0.60, b.color[2] * ambientIntensity * 0.60, b.color[3] * ambientIntensity * 0.60)
    love.graphics.rectangle("fill", wx, windowY, 14, 10)

    if lighting.lampsOn() then
      -- Warm amber glow through windows
      love.graphics.setColor(0.95, 0.80, 0.45, 0.7)
      love.graphics.rectangle("fill", wx + 1, windowY + 1, 12, 8)
      -- Glow halo
      love.graphics.setColor(0.95, 0.80, 0.45, 0.10)
      love.graphics.circle("fill", wx + 7, windowY + 5, 22)
    else
      -- Daytime: frost-covered glass
      love.graphics.setColor(0.55 * ambientIntensity, 0.65 * ambientIntensity, 0.75 * ambientIntensity)
      love.graphics.rectangle("fill", wx + 1, windowY + 1, 12, 8)
      -- Cross mullion
      love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity, 0.5)
      love.graphics.line(wx + 7, windowY + 1, wx + 7, windowY + 9)
      love.graphics.line(wx + 1, windowY + 5, wx + 13, windowY + 5)
    end

    -- Wooden shutters (painted)
    love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity)
    love.graphics.rectangle("fill", wx - 2, windowY, 3, 10)
    love.graphics.rectangle("fill", wx + 13, windowY, 3, 10)
    -- Snow on sill
    love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.6)
    love.graphics.rectangle("fill", wx - 2, windowY + 10, 18, 3, 1, 1)
  end

  -- ═══ BUILDING NAME (carved wooden sign) ═══
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  local signX = x + w/2 - textW/2 - 8
  local signY = roofBaseY - 4

  -- Wooden sign plank
  love.graphics.setColor(0.30 * ambientIntensity, 0.24 * ambientIntensity, 0.16 * ambientIntensity, 0.75)
  love.graphics.rectangle("fill", signX, signY, textW + 16, 14, 2, 2)
  love.graphics.setColor(0.40 * ambientIntensity, 0.38 * ambientIntensity, 0.35 * ambientIntensity, 0.5)
  love.graphics.rectangle("line", signX, signY, textW + 16, 14, 2, 2)
  -- Text (warm cream)
  love.graphics.setColor(0.92 * ambientIntensity, 0.88 * ambientIntensity, 0.75 * ambientIntensity)
  love.graphics.print(b.name, signX + 8, signY + 1)

  -- ═══ GREAT HALL / HÔTEL DE VILLE SPECIAL FEATURES ═══
  if style == "greathall" then
    -- Torch brackets on walls
    for i = 0, 1 do
      local torchX = i == 0 and (x - 4) or (x + w + 1)
      local torchY = y + h/2
      love.graphics.setColor(0.40 * ambientIntensity, 0.38 * ambientIntensity, 0.35 * ambientIntensity)
      love.graphics.rectangle("fill", torchX, torchY, 4, 12)
      if lighting.lampsOn() then
        love.graphics.setColor(1.0, 0.85, 0.35, 0.85)
        local flicker = math.sin(gameState.animationTime * 8 + torchX) * 2
        love.graphics.circle("fill", torchX + 2 + flicker * 0.3, torchY - 2, 4)
        love.graphics.setColor(1.0, 0.65, 0.20, 0.5)
        love.graphics.circle("fill", torchX + 2 + flicker * 0.3, torchY - 5, 3)
        love.graphics.setColor(1.0, 0.80, 0.35, 0.08)
        love.graphics.circle("fill", torchX + 2, torchY, 40)
      end
    end
  end

  -- ═══ TOWER SPECIAL (Observatory) ═══
  if style == "tower" then
    -- Copper dome on top
    local domeX = x + w/2
    local domeY = roofPeakY - 18
    -- Dome body (oxidized copper green)
    love.graphics.setColor(0.35 * ambientIntensity, 0.55 * ambientIntensity, 0.45 * ambientIntensity)
    love.graphics.arc("fill", domeX, roofPeakY - 4, w * 0.3, math.pi, 0)
    -- Dome ribs
    love.graphics.setColor(0.30 * ambientIntensity, 0.48 * ambientIntensity, 0.40 * ambientIntensity, 0.5)
    for ri = 1, 4 do
      local angle = math.pi + (ri / 5) * math.pi
      love.graphics.line(domeX, domeY, domeX + math.cos(angle) * w * 0.3, roofPeakY - 4)
    end
    -- Finial
    love.graphics.setColor(0.65 * ambientIntensity, 0.58 * ambientIntensity, 0.30 * ambientIntensity)
    love.graphics.circle("fill", domeX, domeY - 2, 3)
    -- Snow on dome
    love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.5)
    love.graphics.arc("fill", domeX, roofPeakY - 4, w * 0.25, math.pi + 0.3, -0.3)

    -- Telescope slit
    love.graphics.setColor(0.08, 0.06, 0.10, 0.8)
    love.graphics.rectangle("fill", domeX - 2, domeY - 5, 4, 8)

    -- Star glow from telescope (night only)
    if lighting.isNight() then
      love.graphics.setColor(0.50, 0.60, 0.90, 0.08)
      love.graphics.circle("fill", domeX, domeY, 50)
    end
  end

  -- ═══ CABIN SPECIAL (rustic, smaller) ═══
  if style == "cabin" then
    -- Log ends visible on walls
    for cy = y + 14, y + h - 6, 8 do
      love.graphics.setColor(tc[1] * ambientIntensity * 0.85, tc[2] * ambientIntensity * 0.85, tc[3] * ambientIntensity * 0.85)
      love.graphics.circle("fill", x - 2, cy, 3)
      love.graphics.circle("fill", x + w + 2, cy, 3)
    end
  end
end

-- ═══ JAZZ PAVILION (open-air stage) ═══
function M.drawPavilion(b, x, y, w, h, ambientIntensity, tc)
  -- Open structure with support pillars
  -- Floor platform (raised wooden stage)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.9, tc[2] * ambientIntensity * 0.9, tc[3] * ambientIntensity * 0.9)
  love.graphics.rectangle("fill", x - 4, y + h - 6, w + 8, 8, 2, 2)

  -- Stage floor
  love.graphics.setColor(0.35 * ambientIntensity, 0.28 * ambientIntensity, 0.20 * ambientIntensity)
  love.graphics.rectangle("fill", x, y + 4, w, h - 8)
  -- Floor boards
  love.graphics.setColor(0.30 * ambientIntensity, 0.24 * ambientIntensity, 0.16 * ambientIntensity, 0.3)
  for px = x + 4, x + w - 4, 6 do
    love.graphics.line(px, y + 6, px, y + h - 6)
  end

  -- Back wall (partial)
  love.graphics.setColor(b.color[1] * ambientIntensity, b.color[2] * ambientIntensity, b.color[3] * ambientIntensity)
  love.graphics.rectangle("fill", x, y, w, 8)

  -- Support pillars
  for px = 0, 1 do
    local pillarX = px == 0 and x or (x + w - 5)
    love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity)
    love.graphics.rectangle("fill", pillarX, y - 10, 5, h + 12)
  end

  -- Roof (flat with slight slant)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.polygon("fill",
    x - 8, y - 8,
    x + w + 8, y - 8,
    x + w + 8, y - 14,
    x - 8, y - 10
  )
  -- Snow on roof
  love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.5)
  love.graphics.rectangle("fill", x - 6, y - 16, w + 12, 4, 1, 1)

  -- Stage lights (colored)
  if lighting.lampsOn() then
    local colors = {{0.20, 0.40, 0.90}, {0.90, 0.30, 0.20}, {0.20, 0.80, 0.40}, {0.90, 0.70, 0.15}}
    for i = 1, 4 do
      local lx = x + (i - 0.5) * (w / 4)
      local c = colors[i]
      love.graphics.setColor(c[1], c[2], c[3], 0.6)
      love.graphics.circle("fill", lx, y - 5, 3)
      -- Light cone
      love.graphics.setColor(c[1], c[2], c[3], 0.04)
      love.graphics.polygon("fill",
        lx - 2, y - 4,
        lx + 2, y - 4,
        lx + 15, y + h - 8,
        lx - 15, y + h - 8
      )
    end
  end

  -- Name sign
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  love.graphics.setColor(0.15, 0.12, 0.10, 0.8)
  love.graphics.rectangle("fill", x + w/2 - textW/2 - 6, y - 26, textW + 12, 14, 2, 2)
  love.graphics.setColor(0.95 * ambientIntensity, 0.85 * ambientIntensity, 0.55 * ambientIntensity)
  love.graphics.print(b.name, x + w/2 - textW/2, y - 25)
end

-- ═══ CHAPEL (stone with bell tower) ═══
function M.drawChapel(b, x, y, w, h, ambientIntensity, tc)
  -- Stone body
  love.graphics.setColor(b.color[1] * ambientIntensity, b.color[2] * ambientIntensity, b.color[3] * ambientIntensity)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Stone texture
  for sx = x + 2, x + w - 4, 12 do
    for sy = y + 4, y + h - 2, 8 do
      local shade = 0.94 + math.sin(sx * 1.3 + sy * 2.7) * 0.06
      love.graphics.setColor(
        b.color[1] * ambientIntensity * shade,
        b.color[2] * ambientIntensity * shade,
        b.color[3] * ambientIntensity * shade
      )
      love.graphics.rectangle("fill", sx, sy, 10, 6, 1, 1)
    end
  end

  -- Steep roof
  local roofOverhang = 10
  local roofPeakY = y - 24
  local roofBaseY = y + 2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.polygon("fill",
    x - roofOverhang, roofBaseY,
    x + w + roofOverhang, roofBaseY,
    x + w/2, roofPeakY
  )
  -- Snow on roof
  love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.65)
  love.graphics.polygon("fill",
    x + w/2, roofPeakY + 3,
    x - roofOverhang + 5, roofBaseY - 3,
    x + w + roofOverhang - 5, roofBaseY - 3
  )

  -- Bell tower (rising from one side)
  local towerX = x + w - 20
  local towerW = 16
  local towerTop = roofPeakY - 30

  -- Tower body
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.95, b.color[2] * ambientIntensity * 0.95, b.color[3] * ambientIntensity * 0.95)
  love.graphics.rectangle("fill", towerX, towerTop + 10, towerW, roofPeakY - towerTop)

  -- Bell opening (arched)
  love.graphics.setColor(0.15, 0.12, 0.10, 0.8)
  love.graphics.rectangle("fill", towerX + 3, towerTop + 14, 10, 12, 2, 2)
  love.graphics.arc("fill", towerX + 8, towerTop + 14, 5, math.pi, 0)

  -- Bell
  love.graphics.setColor(0.65 * ambientIntensity, 0.55 * ambientIntensity, 0.25 * ambientIntensity)
  love.graphics.polygon("fill",
    towerX + 6, towerTop + 18,
    towerX + 10, towerTop + 18,
    towerX + 11, towerTop + 24,
    towerX + 5, towerTop + 24
  )

  -- Tower cap (pointed spire)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.polygon("fill",
    towerX - 2, towerTop + 10,
    towerX + towerW + 2, towerTop + 10,
    towerX + towerW/2, towerTop
  )

  -- Cross at top
  love.graphics.setColor(0.65 * ambientIntensity, 0.55 * ambientIntensity, 0.30 * ambientIntensity)
  love.graphics.rectangle("fill", towerX + towerW/2 - 1, towerTop - 10, 2, 10)
  love.graphics.rectangle("fill", towerX + towerW/2 - 4, towerTop - 8, 8, 2)

  -- Snow on tower
  love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.5)
  love.graphics.rectangle("fill", towerX - 1, towerTop + 9, towerW + 2, 3, 1, 1)

  -- Stained glass window (round)
  local glassX = x + 12
  local glassY = y + h/2
  love.graphics.setColor(0.25, 0.35, 0.65, 0.7 * ambientIntensity)
  love.graphics.circle("fill", glassX, glassY, 6)
  if lighting.lampsOn() then
    -- Glow through stained glass
    love.graphics.setColor(0.40, 0.50, 0.80, 0.15)
    love.graphics.circle("fill", glassX, glassY, 20)
  end

  -- Door
  local doorX = b.doorX * 32 + 4
  local doorY = b.doorY * 32 - 24
  love.graphics.setColor(0.35 * ambientIntensity, 0.28 * ambientIntensity, 0.20 * ambientIntensity)
  love.graphics.rectangle("fill", doorX, doorY, 24, 24, 3, 3)
  love.graphics.arc("fill", doorX + 12, doorY, 12, math.pi, 0)
  -- Iron hinges
  love.graphics.setColor(0.30 * ambientIntensity, 0.28 * ambientIntensity, 0.26 * ambientIntensity)
  love.graphics.rectangle("fill", doorX, doorY + 4, 24, 2)
  love.graphics.rectangle("fill", doorX, doorY + 16, 24, 2)

  -- Name
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  love.graphics.setColor(0.20, 0.18, 0.15, 0.7)
  love.graphics.rectangle("fill", x + w/2 - textW/2 - 6, y - 28, textW + 12, 14, 2, 2)
  love.graphics.setColor(0.92 * ambientIntensity, 0.88 * ambientIntensity, 0.75 * ambientIntensity)
  love.graphics.print(b.name, x + w/2 - textW/2, y - 27)
end

-- ═══════════════════════════════════════
-- DRAW: DECORATIONS
-- ═══════════════════════════════════════

function M.drawDecoration(deco)
  local x = deco.x * 32
  local y = deco.y * 32
  local _, ambientIntensity = lighting.getAmbientLight()

  if deco.type == "street_lamp" then
    -- Belle Époque wrought-iron lamp post
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)

    -- Iron post
    love.graphics.setColor(0.25 * ambientIntensity, 0.23 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y + 8, 4, 24)
    -- Decorative scroll at top
    love.graphics.setColor(0.28 * ambientIntensity, 0.26 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.arc("line", x + 16, y + 8, 6, math.pi, 0)
    -- Lamp housing
    love.graphics.setColor(0.30 * ambientIntensity, 0.28 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.polygon("fill",
      x + 10, y + 8,
      x + 22, y + 8,
      x + 20, y + 2,
      x + 12, y + 2
    )
    -- Lamp top (cap)
    love.graphics.setColor(0.28 * ambientIntensity, 0.26 * ambientIntensity, 0.24 * ambientIntensity)
    love.graphics.polygon("fill",
      x + 11, y + 2,
      x + 21, y + 2,
      x + 16, y - 3
    )

    if lighting.lampsOn() then
      -- Warm gas lamp glow
      love.graphics.setColor(1.0, 0.88, 0.50, 0.85)
      love.graphics.circle("fill", x + 16, y + 5, 5)
      love.graphics.setColor(1.0, 0.85, 0.45, 0.12)
      love.graphics.circle("fill", x + 16, y + 5, 45)
      love.graphics.setColor(1.0, 0.90, 0.55, 0.25)
      love.graphics.circle("fill", x + 16, y + 5, 20)
    end

  elseif deco.type == "clocktower" then
    lighting.drawShadow(deco.x, deco.y, 1, 2, 32)

    -- Tower body
    love.graphics.setColor(0.58 * ambientIntensity, 0.54 * ambientIntensity, 0.48 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y - 32, 24, 64)

    -- Clock face (white circle)
    love.graphics.setColor(0.90 * ambientIntensity, 0.88 * ambientIntensity, 0.85 * ambientIntensity)
    love.graphics.circle("fill", x + 16, y - 10, 10)
    -- Clock border
    love.graphics.setColor(0.40 * ambientIntensity, 0.35 * ambientIntensity, 0.30 * ambientIntensity)
    love.graphics.circle("line", x + 16, y - 10, 10)

    -- Clock hands (animate with game time)
    local hour = lighting.getHour()
    local hourAngle = (hour / 12) * math.pi * 2 - math.pi / 2
    local minAngle = (gameState.animationTime * 0.1) * math.pi * 2 - math.pi / 2
    -- Hour hand
    love.graphics.setColor(0.15 * ambientIntensity, 0.12 * ambientIntensity, 0.10 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 16, y - 10, x + 16 + math.cos(hourAngle) * 6, y - 10 + math.sin(hourAngle) * 6)
    -- Minute hand
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 16, y - 10, x + 16 + math.cos(minAngle) * 8, y - 10 + math.sin(minAngle) * 8)

    -- Hour markers
    for i = 0, 11 do
      local a = (i / 12) * math.pi * 2 - math.pi / 2
      love.graphics.setColor(0.20 * ambientIntensity, 0.18 * ambientIntensity, 0.16 * ambientIntensity)
      love.graphics.circle("fill", x + 16 + math.cos(a) * 8, y - 10 + math.sin(a) * 8, 1)
    end

    -- Spire
    love.graphics.setColor(0.45 * ambientIntensity, 0.42 * ambientIntensity, 0.38 * ambientIntensity)
    love.graphics.polygon("fill",
      x + 6, y - 30,
      x + 26, y - 30,
      x + 16, y - 48
    )
    -- Snow on spire
    love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.6)
    love.graphics.polygon("fill",
      x + 16, y - 46,
      x + 8, y - 32,
      x + 24, y - 32
    )

    -- Clock glow at night
    if lighting.lampsOn() then
      love.graphics.setColor(0.95, 0.90, 0.65, 0.15)
      love.graphics.circle("fill", x + 16, y - 10, 18)
    end

  elseif deco.type == "fountain" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)

    -- Stone basin (circular)
    love.graphics.setColor(0.50 * ambientIntensity, 0.48 * ambientIntensity, 0.45 * ambientIntensity)
    love.graphics.circle("fill", x + 16, y + 20, 14)
    love.graphics.circle("line", x + 16, y + 20, 14)
    -- Inner basin
    love.graphics.setColor(0.30, 0.50, 0.60, 0.6)
    love.graphics.circle("fill", x + 16, y + 20, 10)
    -- Central column
    love.graphics.setColor(0.55 * ambientIntensity, 0.52 * ambientIntensity, 0.48 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y + 6, 4, 14)
    -- Water spray (animated)
    local sprayH = 6 + math.sin(gameState.animationTime * 3) * 2
    love.graphics.setColor(0.50, 0.70, 0.85, 0.5)
    love.graphics.polygon("fill",
      x + 14, y + 6,
      x + 18, y + 6,
      x + 16, y + 6 - sprayH
    )
    -- Droplets
    for i = 1, 4 do
      local dropX = x + 16 + math.sin(gameState.animationTime * 2 + i * 1.5) * 8
      local dropY = y + 10 + math.abs(math.sin(gameState.animationTime * 2.5 + i * 2.3)) * 8
      love.graphics.setColor(0.55, 0.75, 0.90, 0.4)
      love.graphics.circle("fill", dropX, dropY, 1.5)
    end

  elseif deco.type == "jazz_stage" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    lighting.drawShadow(deco.x, deco.y, deco.w or 1, deco.h or 1, 32)

    -- Raised wooden platform
    love.graphics.setColor(0.32 * ambientIntensity, 0.26 * ambientIntensity, 0.18 * ambientIntensity)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    -- Stage floor boards
    love.graphics.setColor(0.28 * ambientIntensity, 0.22 * ambientIntensity, 0.14 * ambientIntensity, 0.3)
    for px = x + 4, x + w - 4, 6 do
      love.graphics.line(px, y + 2, px, y + h - 2)
    end
    -- Stage edge
    love.graphics.setColor(0.38 * ambientIntensity, 0.32 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.rectangle("fill", x, y + h - 4, w, 4, 1, 1)

  elseif deco.type == "string_lights" then
    local w = (deco.w or 1) * 32
    -- Catenary wire
    love.graphics.setColor(0.30 * ambientIntensity, 0.28 * ambientIntensity, 0.26 * ambientIntensity, 0.6)
    local segments = math.floor(w / 8)
    for i = 0, segments - 1 do
      local lx1 = x + (i / segments) * w
      local lx2 = x + ((i + 1) / segments) * w
      local sag = math.sin((i + 0.5) / segments * math.pi) * 4
      love.graphics.line(lx1, y + sag, lx2, y + sag)
    end

    -- Bulbs (warm color if lamps on)
    for i = 0, segments - 1, 2 do
      local bx = x + (i + 0.5) / segments * w
      local sag = math.sin((i + 0.5) / segments * math.pi) * 4
      if lighting.lampsOn() then
        local colors = {{1.0, 0.85, 0.30}, {0.90, 0.30, 0.20}, {0.30, 0.80, 0.40}, {0.30, 0.50, 0.90}}
        local c = colors[(i % #colors) + 1]
        love.graphics.setColor(c[1], c[2], c[3], 0.9)
        love.graphics.circle("fill", bx, y + sag + 2, 2.5)
        love.graphics.setColor(c[1], c[2], c[3], 0.08)
        love.graphics.circle("fill", bx, y + sag + 2, 15)
      else
        love.graphics.setColor(0.40 * ambientIntensity, 0.38 * ambientIntensity, 0.35 * ambientIntensity, 0.5)
        love.graphics.circle("fill", bx, y + sag + 2, 2)
      end
    end

  elseif deco.type == "festival_banner" then
    local bannerSway = math.sin(gameState.animationTime * 1.2 + x * 0.3) * 4
    -- Pole
    love.graphics.setColor(0.30 * ambientIntensity, 0.28 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y, 4, 32)
    -- Banner (triangular pennant)
    local colors = {{0.80, 0.20, 0.20}, {0.20, 0.40, 0.80}, {0.80, 0.65, 0.15}, {0.20, 0.70, 0.35}}
    local c = colors[((deco.x + deco.y) % #colors) + 1]
    love.graphics.setColor(c[1] * ambientIntensity, c[2] * ambientIntensity, c[3] * ambientIntensity, 0.8)
    love.graphics.polygon("fill",
      x + 18, y + 4,
      x + 18, y + 18,
      x + 30 + bannerSway, y + 11
    )

  elseif deco.type == "flower_box" then
    -- Wooden planter
    love.graphics.setColor(0.42 * ambientIntensity, 0.35 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 20, 24, 10, 1, 1)
    -- Soil
    love.graphics.setColor(0.30 * ambientIntensity, 0.25 * ambientIntensity, 0.18 * ambientIntensity)
    love.graphics.rectangle("fill", x + 6, y + 18, 20, 4, 1, 1)
    -- Flowers (small clusters — alpine geraniums)
    local flowerColors = {{0.80, 0.15, 0.15}, {0.85, 0.45, 0.15}, {0.75, 0.20, 0.55}, {0.85, 0.80, 0.20}}
    for fi = 1, 5 do
      local fc = flowerColors[(fi % #flowerColors) + 1]
      local fx = x + 6 + fi * 4
      love.graphics.setColor(0.20 * ambientIntensity, 0.45 * ambientIntensity, 0.20 * ambientIntensity)
      love.graphics.line(fx, y + 18, fx, y + 12)
      love.graphics.setColor(fc[1] * ambientIntensity, fc[2] * ambientIntensity, fc[3] * ambientIntensity, 0.8)
      love.graphics.circle("fill", fx, y + 12, 2.5)
    end

  elseif deco.type == "watch_display" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Glass display case
    love.graphics.setColor(0.38 * ambientIntensity, 0.35 * ambientIntensity, 0.32 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 10, 24, 20, 2, 2)
    -- Glass top
    love.graphics.setColor(0.55, 0.65, 0.75, 0.3 * ambientIntensity)
    love.graphics.rectangle("fill", x + 6, y + 12, 20, 8, 1, 1)
    -- Watch faces (tiny)
    for i = 1, 3 do
      love.graphics.setColor(0.85 * ambientIntensity, 0.82 * ambientIntensity, 0.75 * ambientIntensity)
      love.graphics.circle("fill", x + 8 + i * 5, y + 16, 3)
      love.graphics.setColor(0.25 * ambientIntensity, 0.22 * ambientIntensity, 0.20 * ambientIntensity)
      love.graphics.circle("line", x + 8 + i * 5, y + 16, 3)
    end

  elseif deco.type == "boulder" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    love.graphics.setColor(0.38 * ambientIntensity, 0.36 * ambientIntensity, 0.34 * ambientIntensity)
    love.graphics.ellipse("fill", x + 16, y + 20, 14, 10)
    -- Lichen patches
    love.graphics.setColor(0.35 * ambientIntensity, 0.42 * ambientIntensity, 0.30 * ambientIntensity, 0.3)
    love.graphics.circle("fill", x + 12, y + 18, 4)
    -- Snow on top
    love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.5)
    love.graphics.ellipse("fill", x + 16, y + 14, 10, 5)

  elseif deco.type == "snowdrift" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    love.graphics.setColor(0.85 * ambientIntensity, 0.88 * ambientIntensity, 0.93 * ambientIntensity, 0.8)
    love.graphics.ellipse("fill", x + w/2, y + h/2, w * 0.45, h * 0.4)
    love.graphics.setColor(0.70 * ambientIntensity, 0.75 * ambientIntensity, 0.82 * ambientIntensity, 0.3)
    love.graphics.ellipse("fill", x + w/2 + 4, y + h/2 + 3, w * 0.40, h * 0.35)

  elseif deco.type == "frozen_waterfall" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    love.graphics.setColor(0.60 * ambientIntensity, 0.72 * ambientIntensity, 0.82 * ambientIntensity, 0.7)
    love.graphics.rectangle("fill", x + w/2 - 8, y, 16, h)
    for i = 1, 6 do
      local icicleX = x + w/2 - 12 + i * 4
      local icicleLen = 8 + math.sin(i * 2.7) * 5
      love.graphics.setColor(0.65 * ambientIntensity, 0.78 * ambientIntensity, 0.88 * ambientIntensity, 0.6)
      love.graphics.polygon("fill", icicleX, y + 5, icicleX + 2, y + 5, icicleX + 1, y + 5 + icicleLen)
    end
    local shimmer = math.sin(gameState.animationTime * 2) * 0.15 + 0.5
    love.graphics.setColor(0.85, 0.92, 1.0, shimmer * 0.3 * ambientIntensity)
    love.graphics.circle("fill", x + w/2, y + h/2, 8)

  elseif deco.type == "hot_spring_pool" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    -- Mineral-stained rock border
    love.graphics.setColor(0.42 * ambientIntensity, 0.38 * ambientIntensity, 0.32 * ambientIntensity)
    love.graphics.ellipse("fill", x + w/2, y + h/2, w * 0.5 + 4, h * 0.5 + 4)
    -- Turquoise water
    love.graphics.setColor(0.20, 0.55, 0.65, 0.8)
    love.graphics.ellipse("fill", x + w/2, y + h/2, w * 0.45, h * 0.45)
    local sparkle = math.sin(gameState.animationTime * 2.5) * 0.2 + 0.6
    love.graphics.setColor(0.40, 0.75, 0.85, sparkle * 0.4)
    love.graphics.circle("fill", x + w/2, y + h/2, w * 0.15)
    -- Warm glow
    love.graphics.setColor(1.0, 0.60, 0.30, 0.05)
    love.graphics.circle("fill", x + w/2, y + h/2, w * 0.6)

  elseif deco.type == "wooden_bridge" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    love.graphics.setColor(0.38 * ambientIntensity, 0.30 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.32 * ambientIntensity, 0.25 * ambientIntensity, 0.16 * ambientIntensity, 0.5)
    for px = x + 4, x + w - 4, 6 do
      love.graphics.line(px, y + 2, px, y + h - 2)
    end
    -- Rope railing
    love.graphics.setColor(0.45 * ambientIntensity, 0.38 * ambientIntensity, 0.28 * ambientIntensity)
    love.graphics.line(x, y, x + w, y)
    love.graphics.line(x, y + h, x + w, y + h)

  elseif deco.type == "bench" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    love.graphics.setColor(0.38 * ambientIntensity, 0.30 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.rectangle("fill", x, y + 16, 32, 6, 1, 1)
    love.graphics.rectangle("fill", x + 4, y + 22, 3, 10)
    love.graphics.rectangle("fill", x + 25, y + 22, 3, 10)
    love.graphics.rectangle("fill", x + 2, y + 8, 28, 3)
    love.graphics.rectangle("fill", x + 4, y + 8, 3, 8)
    love.graphics.rectangle("fill", x + 25, y + 8, 3, 8)
    -- Snow on seat
    love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.4)
    love.graphics.rectangle("fill", x + 2, y + 14, 28, 3, 1, 1)

  elseif deco.type == "supply_crate" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    love.graphics.setColor(0.42 * ambientIntensity, 0.35 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 10, 24, 20, 2, 2)
    love.graphics.setColor(0.35 * ambientIntensity, 0.28 * ambientIntensity, 0.18 * ambientIntensity, 0.4)
    love.graphics.line(x + 16, y + 12, x + 16, y + 28)
    love.graphics.setColor(0.45 * ambientIntensity, 0.42 * ambientIntensity, 0.40 * ambientIntensity, 0.5)
    love.graphics.rectangle("fill", x + 4, y + 15, 24, 2)
    love.graphics.rectangle("fill", x + 4, y + 24, 24, 2)

  elseif deco.type == "barrel" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    love.graphics.setColor(0.40 * ambientIntensity, 0.32 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.ellipse("fill", x + 16, y + 20, 10, 12)
    love.graphics.setColor(0.45 * ambientIntensity, 0.42 * ambientIntensity, 0.40 * ambientIntensity, 0.6)
    love.graphics.ellipse("line", x + 16, y + 14, 9, 2)
    love.graphics.ellipse("line", x + 16, y + 26, 9, 2)
    -- Snow on top
    love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.4)
    love.graphics.ellipse("fill", x + 16, y + 10, 8, 3)

  elseif deco.type == "ice_pillar" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    love.graphics.setColor(0.55 * ambientIntensity, 0.68 * ambientIntensity, 0.80 * ambientIntensity, 0.7)
    love.graphics.polygon("fill",
      x + 8, y + 30,
      x + 24, y + 30,
      x + 20, y + 4,
      x + 16, y,
      x + 12, y + 4
    )
    love.graphics.setColor(0.65, 0.80, 0.95, 0.15 * ambientIntensity)
    love.graphics.polygon("fill",
      x + 12, y + 26,
      x + 20, y + 26,
      x + 18, y + 8,
      x + 16, y + 4,
      x + 14, y + 8
    )
    local sparkle = math.sin(gameState.animationTime * 3 + x * 0.1) * 0.3 + 0.7
    love.graphics.setColor(0.90, 0.95, 1.0, sparkle * 0.4 * ambientIntensity)
    love.graphics.circle("fill", x + 16, y + 12, 3)
  end
end

-- ═══════════════════════════════════════
-- DRAW: INTERIOR
-- ═══════════════════════════════════════

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Swiss chalet interior (warm wood floors, plaster walls)
  local fc = interior.floorColor or {0.42, 0.38, 0.34}
  local wc = interior.wallColor or {0.58, 0.52, 0.45}

  for fy = 0, interior.height - 1 do
    for fx = 0, interior.width - 1 do
      local shade = 0.95 + math.sin(fx * 2.7 + fy * 3.9) * 0.05
      love.graphics.setColor(fc[1] * shade, fc[2] * shade, fc[3] * shade)
      love.graphics.rectangle("fill", fx * 32, fy * 32, 32, 32)
      -- Wood plank joints
      love.graphics.setColor(fc[1] * shade * 0.85, fc[2] * shade * 0.85, fc[3] * shade * 0.85, 0.15)
      love.graphics.line(fx * 32, fy * 32, fx * 32 + 32, fy * 32)
    end
  end

  -- Walls (plaster with timber trim)
  love.graphics.setColor(wc[1], wc[2], wc[3])
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
  love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

  -- Decorative timber beams on walls
  love.graphics.setColor(wc[1] * 0.7, wc[2] * 0.65, wc[3] * 0.6, 0.4)
  for wx = 2, interior.width - 3, 3 do
    love.graphics.rectangle("fill", wx * 32, 0, 4, 32)
  end

  -- Warm ambient glow
  love.graphics.setColor(0.95, 0.85, 0.55, 0.04)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

  -- Exit doorway
  love.graphics.setColor(0.55, 0.52, 0.48)
  love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)

  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local px = portal.x * 32
      local py = portal.y * 32
      local pulse = math.sin(gameState.animationTime * 3) * 0.2 + 0.8

      -- Default portal colors (golden for time/shop, blue for games)
      local portalColor = {0.45, 0.55, 0.85}
      if portal.game == "shop" then
        portalColor = {0.80, 0.65, 0.25}
      elseif portal.game == "hangar" then
        portalColor = {0.40, 0.70, 0.50}
      elseif portal.game == "casino_exchange" then
        portalColor = {0.70, 0.50, 0.80}
      end

      love.graphics.setColor(portalColor[1] * pulse, portalColor[2] * pulse, portalColor[3] * pulse)
      love.graphics.circle("fill", px + 16, py + 16, 20)
      love.graphics.setColor(portalColor[1], portalColor[2], portalColor[3], 0.15)
      love.graphics.circle("fill", px + 16, py + 16, 35)

      -- Label
      love.graphics.setColor(1, 1, 1)
      local font = love.graphics.getFont()
      local labelText = portal.label or portal.name
      local textW = font:getWidth(labelText)
      love.graphics.print(labelText, px + 16 - textW/2, py + 40)
    end
  end

  -- Interior name
  love.graphics.setColor(0.88, 0.83, 0.72)
  love.graphics.print(interior.name, 40, 40)
end

-- ═══════════════════════════════════════
-- DRAW: UI
-- ═══════════════════════════════════════

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Zone name display (elegant Swiss style)
  local zoneName, zone = areas.getZoneAt(gameState.player.gridX, gameState.player.gridY)
  if gameState.location == "outdoors" and zone then
    love.graphics.setColor(0.10, 0.08, 0.06, 0.75)
    love.graphics.rectangle("fill", 10, 10, 250, 30, 4, 4)
    love.graphics.setColor(0.50, 0.45, 0.35, 0.5)
    love.graphics.rectangle("line", 10, 10, 250, 30, 4, 4)
    love.graphics.setColor(0.92, 0.88, 0.78)
    love.graphics.print(zone.name, 20, 17)
  elseif gameState.location == "interior" then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.setColor(0.10, 0.08, 0.06, 0.75)
      love.graphics.rectangle("fill", 10, 10, 280, 30, 4, 4)
      love.graphics.setColor(0.50, 0.45, 0.35, 0.5)
      love.graphics.rectangle("line", 10, 10, 280, 30, 4, 4)
      love.graphics.setColor(0.92, 0.88, 0.78)
      love.graphics.print(interior.name, 20, 17)
    end
  end

  -- Currency display
  love.graphics.setColor(0.10, 0.08, 0.06, 0.75)
  love.graphics.rectangle("fill", screenW - 170, 10, 160, 30, 4, 4)
  love.graphics.setColor(0.50, 0.45, 0.35, 0.5)
  love.graphics.rectangle("line", screenW - 170, 10, 160, 30, 4, 4)
  love.graphics.setColor(1, 0.85, 0.35)
  love.graphics.print("Notes: " .. gameState.notes, screenW - 160, 17)

  -- Time of day (with clock icon)
  if gameState.location == "outdoors" then
    love.graphics.setColor(0.10, 0.08, 0.06, 0.75)
    love.graphics.rectangle("fill", screenW - 110, 45, 100, 25, 4, 4)
    love.graphics.setColor(0.50, 0.45, 0.35, 0.5)
    love.graphics.rectangle("line", screenW - 110, 45, 100, 25, 4, 4)
    love.graphics.setColor(0.92, 0.88, 0.78)
    love.graphics.print("⏰ " .. lighting.getTimeString(), screenW - 105, 50)

    -- Temperature indicator
    local hour = lighting.getHour()
    local temp
    if hour >= 10 and hour <= 14 then
      temp = "-8°C"     -- Warmer (Swiss alpine, not arctic)
    elseif (hour >= 7 and hour < 10) or (hour > 14 and hour <= 17) then
      temp = "-14°C"
    else
      temp = "-22°C"
    end
    love.graphics.setColor(0.10, 0.08, 0.06, 0.75)
    love.graphics.rectangle("fill", screenW - 110, 73, 100, 25, 4, 4)
    love.graphics.setColor(0.55, 0.70, 0.90)
    love.graphics.print(temp, screenW - 100, 78)
  end

  -- Interaction prompts
  if gameState.nearbyPortal then
    love.graphics.setColor(0.08, 0.06, 0.04, 0.82)
    love.graphics.rectangle("fill", screenW/2 - 180, screenH - 60, 360, 40, 6, 6)
    love.graphics.setColor(0.55, 0.48, 0.35, 0.6)
    love.graphics.rectangle("line", screenW/2 - 180, screenH - 60, 360, 40, 6, 6)
    love.graphics.setColor(0.92, 0.88, 0.78)
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW/2 - 170, screenH - 50, 340, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0.08, 0.06, 0.04, 0.82)
    love.graphics.rectangle("fill", screenW/2 - 180, screenH - 60, 360, 40, 6, 6)
    love.graphics.setColor(0.55, 0.48, 0.35, 0.6)
    love.graphics.rectangle("line", screenW/2 - 180, screenH - 60, 360, 40, 6, 6)
    love.graphics.setColor(0.92, 0.88, 0.78)
    love.graphics.printf("Press E to speak with " .. gameState.nearbyNPC.name, screenW/2 - 170, screenH - 50, 340, "center")
  end

  -- Dialogue box (parchment style)
  if gameState.dialogueBox then
    love.graphics.setColor(0.08, 0.06, 0.04, 0.92)
    love.graphics.rectangle("fill", 50, screenH - 155, screenW - 100, 125, 8, 8)
    -- Gilt border
    love.graphics.setColor(0.55, 0.48, 0.30, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 50, screenH - 155, screenW - 100, 125, 8, 8)
    love.graphics.setColor(0.45, 0.40, 0.28, 0.3)
    love.graphics.rectangle("line", 54, screenH - 151, screenW - 108, 117, 6, 6)
    love.graphics.setLineWidth(1)
    -- Speaker name
    love.graphics.setColor(0.95, 0.82, 0.42)
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 143)
    -- Dialogue text
    love.graphics.setColor(0.90, 0.86, 0.76)
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 118, screenW - 140, "left")
    -- Dismiss hint
    love.graphics.setColor(0.55, 0.50, 0.42)
    love.graphics.print("Press E to close", 70, screenH - 50)
  end

  -- Edge hint
  if gameState.location == "outdoors" then
    local nearEdge = gameState.player.gridX <= 1 or gameState.player.gridX >= areas.WIDTH - 2 or
                     gameState.player.gridY <= 1 or gameState.player.gridY >= areas.HEIGHT - 2
    if nearEdge then
      love.graphics.setColor(0.10, 0.08, 0.05, 0.7)
      love.graphics.rectangle("fill", screenW/2 - 120, 50, 240, 30, 5, 5)
      love.graphics.setColor(0.92, 0.88, 0.78)
      love.graphics.printf("Press ESC to pause", screenW/2 - 120, 57, 240, "center")
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
    -- Portal interaction
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

    -- NPC dialogue
    if gameState.nearbyNPC then
      -- Make NPC turn to face the player
      local npcGridX = gameState.nearbyNPC.gridX or gameState.nearbyNPC.x
      local npcGridY = gameState.nearbyNPC.gridY or gameState.nearbyNPC.y
      local dx = gameState.player.gridX - npcGridX
      local dy = gameState.player.gridY - npcGridY
      if math.abs(dx) > math.abs(dy) then
        gameState.nearbyNPC.direction = dx > 0 and "right" or "left"
      else
        gameState.nearbyNPC.direction = dy > 0 and "down" or "up"
      end

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
      duration = 1.0,
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

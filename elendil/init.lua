-- elendil/init.lua
-- HD-2D fantasy village hub (Octopath Traveler inspired)
-- Timber-frame village with tilt-shift depth-of-field, volumetric lighting,
-- water reflections, particle effects, and painterly environment art

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local areas = require("elendil.areas")
local buildings = require("elendil.buildings")
local lighting = require("elendil.lighting")
local environment = require("elendil.environment")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

function M.load()
  gameState.location = "outdoors"
  gameState.interiorId = nil

  -- Initialize environment systems
  areas.initParticles(80)
  areas.initStars(200)

  -- Player starts at village square
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

  -- Currency (shared system)
  gameState.credits = 1000000
  gameState.notes = currency.load()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false}
  gameState.paused = false
  gameState.animationTime = 0

  -- Setup outdoor NPCs
  M.setupOutdoorNPCs()

  audio.load()
  pauseMenu.load()

  -- Initialize HD-2D systems
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

  -- Update HD-2D systems
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
      if buildings.isAtExit(gameState.player.gridX, gameState.player.gridY, gameState.interiorId) then
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
-- DRAW (HD-2D layered rendering)
-- ═══════════════════════════════════════

function M.draw()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  if gameState.location == "outdoors" then
    -- Layer 0: Sky gradient
    environment.drawSky(screenW, screenH)

    -- Layer 0.5: Stars (night only)
    environment.drawStars(screenW, screenH, gameState.animationTime)

    -- Layer 1: Moon (night only)
    lighting.drawMoonlight(screenW, screenH, gameState.animationTime)

    -- Layer 1.5: Distant valley cliffs with waterfalls
    environment.drawValleyCliffs(screenW, screenH, gameState.camera.y)

    -- Layer 1.6: Cascading waterfalls
    environment.drawWaterfalls(screenW, screenH, gameState.camera.y, gameState.animationTime)

    -- Layer 2: Clouds (parallax)
    environment.drawClouds(gameState.camera.x, gameState.camera.y, gameState.animationTime)

    -- Layer 2.5: God rays (volumetric light)
    lighting.drawGodRays(screenW, screenH, gameState.camera.x, gameState.camera.y, gameState.animationTime)
  end

  -- Main world (camera-transformed)
  -- Round to whole pixels to prevent sub-pixel shimmer on building tile patterns
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

  -- Post-processing overlays (after camera transform)
  if gameState.location == "outdoors" then
    -- Fireflies (night particles)
    environment.drawFireflies(gameState.camera.x, gameState.camera.y, screenW, screenH)

    -- Dust motes (day particles)
    environment.drawDustMotes(gameState.camera.x, gameState.camera.y, screenW, screenH)

    -- HD-2D ambient overlay (tilt-shift + color grading + bloom)
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
-- DRAW: OUTDOORS (HD-2D village)
-- ═══════════════════════════════════════

function M.drawOutdoors()
  local gs = 32
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  -- Default ground fill (eliminates void areas)
  -- Fill entire world with base terrain so no untextured tiles exist
  local defaultGround = {0.09, 0.18, 0.26}
  for ty = 0, areas.HEIGHT - 1 do
    for tx = 0, areas.WIDTH - 1 do
      local shade = 0.97 + math.sin(tx * 2.3 + ty * 3.1) * 0.03
      love.graphics.setColor(
        defaultGround[1] * ambientIntensity * shade,
        defaultGround[2] * ambientIntensity * shade,
        defaultGround[3] * ambientIntensity * shade
      )
      love.graphics.rectangle("fill", tx * gs, ty * gs, gs, gs)
      -- Subtle grass texture on default ground
      local grassSeed = tx * 7.3 + ty * 11.7
      if math.sin(grassSeed) > 0.3 then
        love.graphics.setColor(
          0.07 * ambientIntensity,
          0.22 * ambientIntensity,
          0.28 * ambientIntensity,
          0.4
        )
        local bladeH = 3 + math.sin(grassSeed * 2.1) * 2
        local bladeX = tx * gs + (math.sin(grassSeed * 1.7) * 0.5 + 0.5) * gs
        local bladeY = ty * gs + (math.sin(grassSeed * 3.1) * 0.5 + 0.5) * gs
        love.graphics.line(bladeX, bladeY, bladeX + environment.getWindSway(bladeX, gameState.animationTime, 0.5), bladeY - bladeH)
      end
    end
  end

  -- Draw ground zones with HD-2D texture (overlay on default fill)
  for name, zone in pairs(areas.zones) do
    if zone.groundColor and name ~= "stone_bridge" then
      M.drawGroundZone(name, zone, gs, ambientIntensity)
    end
  end

  -- Draw stone bridge
  M.drawStoneBridge(gs, ambientIntensity)

  -- Draw river (with HD-2D reflections)
  environment.drawRiver(gs, gameState.animationTime, gameState.camera.x, gameState.camera.y)

  -- Draw cobblestone paths connecting areas
  M.drawVillagePaths(gs, ambientIntensity)

  -- Draw building shadows
  for _, b in ipairs(areas.buildings) do
    lighting.drawShadow(b.x, b.y, b.w, b.h, gs)
  end

  -- Draw tree shadows
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "oak_tree" or deco.type == "pine_tree" or deco.type == "willow_tree" then
      lighting.drawTreeShadow(deco.x, deco.y, gs, deco.type)
    end
  end

  -- Draw non-tree decorations
  for _, deco in ipairs(areas.decorations) do
    if deco.type ~= "oak_tree" and deco.type ~= "pine_tree" and deco.type ~= "willow_tree" then
      M.drawDecoration(deco)
    end
  end

  -- Draw buildings (HD-2D timber-frame style)
  for _, b in ipairs(areas.buildings) do
    M.drawBuilding(b)
  end

  -- Draw trees (on top of buildings for depth layering)
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "oak_tree" then
      environment.drawOakTree(deco.x, deco.y, gs, gameState.animationTime, deco.variety)
    elseif deco.type == "pine_tree" then
      environment.drawPineTree(deco.x, deco.y, gs, gameState.animationTime, deco.variety)
    elseif deco.type == "willow_tree" then
      environment.drawWillowTree(deco.x, deco.y, gs, gameState.animationTime, deco.variety)
    end
  end
end

-- Draw ground zone with HD-2D texture
function M.drawGroundZone(name, zone, gs, ambientIntensity)
  local x = zone.x1 * gs
  local y = zone.y1 * gs
  local w = (zone.x2 - zone.x1 + 1) * gs
  local h = (zone.y2 - zone.y1 + 1) * gs
  local gc = zone.groundColor

  -- Base fill
  love.graphics.setColor(gc[1] * ambientIntensity, gc[2] * ambientIntensity, gc[3] * ambientIntensity)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Texture detail per zone type
  if name == "village_square" or name == "castle_grounds" then
    -- Zanaris paving: holographic tile pattern with subtle neon variation
    for tx = zone.x1, zone.x2 do
      for ty = zone.y1, zone.y2 do
        local shade = 0.97 + math.sin(tx * 3.7 + ty * 5.3) * 0.03
        love.graphics.setColor(gc[1] * ambientIntensity * shade, gc[2] * ambientIntensity * shade, gc[3] * ambientIntensity * shade)
        love.graphics.rectangle("fill", tx * gs + 1, ty * gs + 1, gs - 2, gs - 2, 2, 2)
        -- Neon cyan inlay pattern between tiles
        love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.75 * ambientIntensity, 0.08)
        love.graphics.rectangle("line", tx * gs + 1, ty * gs + 1, gs - 2, gs - 2, 2, 2)
      end
    end
  elseif name == "orchard" or name == "residential" or name == "windmill_hill" then
    -- Lush grass with wildflowers (Rivendell meadow feel)
    local count = math.floor(w * h / 200)
    for i = 1, count do
      local seed = i * 7.31 + zone.x1 * 13.7 + zone.y1 * 17.3
      local gx = x + (math.sin(seed) * 0.5 + 0.5) * w
      local gy = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      local grassSway = environment.getWindSway(gx, gameState.animationTime, 1)
      local blade = (math.sin(seed * 2.91) * 0.5 + 0.5) * 0.15
      love.graphics.setColor(
        (gc[1] + blade * 0.3) * ambientIntensity,
        (gc[2] + blade) * ambientIntensity,
        (gc[3] - blade * 0.2) * ambientIntensity,
        0.6
      )
      local bladeH = 4 + (math.sin(seed * 3.47) * 0.5 + 0.5) * 3
      love.graphics.line(gx, gy, gx + grassSway, gy - bladeH)
    end
    -- Bioluminescent micro-flora (tiny neon dots)
    for i = 1, math.floor(count * 0.15) do
      local seed = i * 19.7 + zone.x1 * 3.1 + zone.y1 * 7.9
      local fx = x + (math.sin(seed) * 0.5 + 0.5) * w
      local fy = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      local flowerType = math.floor((math.sin(seed * 2.1) * 0.5 + 0.5) * 3)
      if flowerType == 0 then
        love.graphics.setColor(0.15 * ambientIntensity, 0.70 * ambientIntensity, 0.85 * ambientIntensity, 0.5)
      elseif flowerType == 1 then
        love.graphics.setColor(0.55 * ambientIntensity, 0.30 * ambientIntensity, 0.80 * ambientIntensity, 0.5)
      else
        love.graphics.setColor(0.20 * ambientIntensity, 0.85 * ambientIntensity, 0.55 * ambientIntensity, 0.5)
      end
      love.graphics.circle("fill", fx, fy, 1.5)
    end
  elseif name == "market_row" then
    -- Smooth packed earth with mosaic tile accents
    for i = 1, 15 do
      local seed = i * 11.3 + zone.x1 * 5.7
      local tileX = x + (math.sin(seed) * 0.5 + 0.5) * w
      local tileY = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      -- Neon lichen at foundation
      love.graphics.setColor(0.10 * ambientIntensity, 0.45 * ambientIntensity, 0.60 * ambientIntensity, 0.35)
      love.graphics.rectangle("fill", tileX, tileY, 6, 6, 1, 1)
    end
  elseif name == "river_bank" then
    -- Mossy bank with ferns
    for i = 1, 30 do
      local seed = i * 9.7 + zone.x1 * 3.1
      local rx = x + (math.sin(seed) * 0.5 + 0.5) * w
      local ry = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
      local fernSway = environment.getWindSway(rx, gameState.animationTime, 2)
      local fernH = 6 + (math.sin(seed * 2.91) * 0.5 + 0.5) * 4
      -- Silver-green ferns
      love.graphics.setColor(0.28 * ambientIntensity, 0.52 * ambientIntensity, 0.32 * ambientIntensity, 0.6)
      love.graphics.line(rx, ry, rx + fernSway, ry - fernH)
      -- Frond leaves
      love.graphics.setColor(0.32 * ambientIntensity, 0.55 * ambientIntensity, 0.35 * ambientIntensity, 0.4)
      love.graphics.line(rx + fernSway * 0.5, ry - fernH * 0.5, rx + fernSway + 3, ry - fernH * 0.6)
      love.graphics.line(rx + fernSway * 0.5, ry - fernH * 0.5, rx + fernSway - 3, ry - fernH * 0.6)
    end
  end
end

-- Draw the indigo stone bridge (neon-traced railings)
function M.drawStoneBridge(gs, ambientIntensity)
  local bridge = areas.zones.stone_bridge
  local bx = bridge.x1 * gs
  local bw = (bridge.x2 - bridge.x1 + 1) * gs

  -- Deep blue stone surface
  for y = bridge.y1, bridge.y2 do
    for x = bridge.x1, bridge.x2 do
      local shade = 0.97 + math.sin(x * 2.1 + y * 3.7) * 0.03
      love.graphics.setColor(0.18 * shade * ambientIntensity, 0.22 * shade * ambientIntensity, 0.40 * shade * ambientIntensity)
      love.graphics.rectangle("fill", x * gs, y * gs, gs, gs)

      -- Surface detail (neon tile lines)
      love.graphics.setColor(0.12 * ambientIntensity, 0.40 * ambientIntensity, 0.60 * ambientIntensity, 0.3)
      love.graphics.line(x * gs + 3, y * gs + 16, x * gs + 29, y * gs + 14)
    end
  end

  -- Graceful curved railings (Elven filigree arches)
  local railY1 = bridge.y1 * gs
  local railY2 = bridge.y2 * gs + gs

  -- Left railing (dark blue stone with neon trace)
  love.graphics.setColor(0.14 * ambientIntensity, 0.18 * ambientIntensity, 0.35 * ambientIntensity)
  love.graphics.rectangle("fill", bx - 3, railY1, 4, railY2 - railY1)
  -- Right railing
  love.graphics.rectangle("fill", bx + bw - 1, railY1, 4, railY2 - railY1)

  -- Neon-lit arch posts with crystal finials
  for y = bridge.y1, bridge.y2, 2 do
    love.graphics.setColor(0.20 * ambientIntensity, 0.55 * ambientIntensity, 0.75 * ambientIntensity)
    love.graphics.rectangle("fill", bx - 5, y * gs, 8, 4)
    love.graphics.rectangle("fill", bx + bw - 3, y * gs, 8, 4)
    -- Crystal finials
    love.graphics.setColor(0.10 * ambientIntensity, 0.60 * ambientIntensity, 0.80 * ambientIntensity, 0.5)
    love.graphics.circle("fill", bx - 1, y * gs - 1, 2.5)
    love.graphics.circle("fill", bx + bw + 1, y * gs - 1, 2.5)
  end

  -- Neon trace along railings
  local sway = environment.getWindSway(bx, gameState.animationTime, 1)
  for i = 1, 6 do
    local seed = i * 5.73
    local vy = railY1 + (math.sin(seed) * 0.5 + 0.5) * (railY2 - railY1)
    love.graphics.setColor(0.10 * ambientIntensity, 0.60 * ambientIntensity, 0.80 * ambientIntensity, 0.5)
    -- Left vine
    love.graphics.line(bx - 1, vy, bx + 5 + sway, vy + 4)
    -- Right vine
    love.graphics.line(bx + bw + 1, vy, bx + bw - 5 + sway, vy + 4)
  end

  -- Cyan inlay center line
  love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.75 * ambientIntensity, 0.15)
  love.graphics.line(bx + bw / 2, railY1 + 4, bx + bw / 2, railY2 - 4)
end

-- ═══ DARK BLUE-STONE PATHS (with neon trace inlay) ═══
-- Paths connecting zones AND building front doors
function M.drawVillagePaths(gs, ambientIntensity)
  -- Zone-to-zone path strips
  local pathStrips = {
    -- Market row to village square (horizontal)
    {x1 = 15, y = 16, x2 = 17, depth = 1},
    -- Residential to village square (vertical)
    {x1 = 20, y = 13, x2 = 21, depth = 1},
    {x1 = 28, y = 13, x2 = 29, depth = 1},
    -- Residential to windmill hill
    {x1 = 33, y = 6, x2 = 38, depth = 1},
    -- Village square to castle grounds
    {x1 = 30, y = 17, x2 = 35, depth = 1},
    -- Village square to bridge/river
    {x1 = 22, y = 22, x2 = 25, depth = 5},
    -- Castle grounds to river
    {x1 = 40, y = 25, x2 = 41, depth = 3},
    -- Orchard to market row
    {x1 = 6, y = 6, x2 = 7, depth = 7},
    -- Main east-west corridor across market + square
    {x1 = 3, y = 16, x2 = 30, depth = 1},
    -- Main corridor in residential area
    {x1 = 20, y = 5, x2 = 29, depth = 1},
  }

  -- Door-connecting path segments (connects each building door to nearest main path)
  local doorPaths = {}
  for _, b in ipairs(areas.buildings) do
    local dX = b.doorX
    local dY = b.doorY
    -- Connect door tile downward to next row (threshold connector)
    table.insert(doorPaths, {x = dX, y1 = dY, y2 = dY + 1})
    -- For buildings with doors on row 16, connect to main corridor
    if dY == 16 then
      -- Already on main corridor, add a short approach
      table.insert(doorPaths, {x = dX, y1 = dY, y2 = dY + 1})
    elseif dY == 22 then
      -- Connect to main corridor (row 16) with vertical path
      table.insert(doorPaths, {x = dX, y1 = 17, y2 = dY})
    elseif dY == 5 then
      -- Connect to residential corridor
      table.insert(doorPaths, {x = dX, y1 = dY, y2 = 6})
    elseif dY == 6 then
      table.insert(doorPaths, {x = dX, y1 = dY, y2 = 7})
    elseif dY == 19 then
      table.insert(doorPaths, {x = dX, y1 = dY, y2 = 20})
    elseif dY == 25 then
      table.insert(doorPaths, {x = dX, y1 = dY, y2 = 26})
    elseif dY == 26 then
      table.insert(doorPaths, {x = dX, y1 = dY, y2 = 27})
    end
  end

  -- Draw horizontal path strips
  for _, strip in ipairs(pathStrips) do
    for dy = 0, strip.depth - 1 do
      for gx = strip.x1, strip.x2 do
        M.drawPathTile(gx, strip.y + dy, gs, ambientIntensity)
      end
    end
  end

  -- Draw vertical door-connection paths
  for _, dp in ipairs(doorPaths) do
    for gy = dp.y1, dp.y2 do
      M.drawPathTile(dp.x, gy, gs, ambientIntensity)
    end
  end
end

-- Helper: draw a single path tile
function M.drawPathTile(gx, gy, gs, ambientIntensity)
  local px = gx * gs
  local py = gy * gs

  -- Dark blue stone
  local stoneVar = math.sin(gx * 3.7 + gy * 5.3) * 0.02
  love.graphics.setColor(
    (0.16 + stoneVar) * ambientIntensity,
    (0.20 + stoneVar) * ambientIntensity,
    (0.38 + stoneVar) * ambientIntensity
  )
  love.graphics.rectangle("fill", px, py, gs, gs)

  -- Polished crystal paving tiles
  local shade = 0.98 + math.sin(gx * 4.1 + gy * 3.3) * 0.02
  love.graphics.setColor(
    0.20 * shade * ambientIntensity,
    0.25 * shade * ambientIntensity,
    0.45 * shade * ambientIntensity
  )
  love.graphics.rectangle("fill", px + 1, py + 1, gs - 2, gs - 2, 2, 2)

  -- Neon-traced border between tiles
  love.graphics.setColor(0.12 * ambientIntensity, 0.45 * ambientIntensity, 0.65 * ambientIntensity, 0.35)
  love.graphics.rectangle("line", px + 1, py + 1, gs - 2, gs - 2, 2, 2)

  -- Neon trace inlay (glowing rune in some tiles)
  local leafChance = math.sin(gx * 7.3 + gy * 11.7)
  if leafChance > 0.5 then
    love.graphics.setColor(0.18 * ambientIntensity, 0.60 * ambientIntensity, 0.82 * ambientIntensity, 0.12)
    love.graphics.ellipse("fill", px + 16, py + 16, 5, 3, math.sin(gx) * 0.5)
    love.graphics.setColor(0.25 * ambientIntensity, 0.75 * ambientIntensity, 0.95 * ambientIntensity, 0.2)
    love.graphics.circle("fill", px + 16, py + 16, 1.5)
  end
end

-- ═══════════════════════════════════════
-- DRAW: BUILDINGS (Unique architecture per building)
-- Each building inspired by a specific Antoni Gaudí work:
-- Tavern→Casa Batlló, General Store→Casa Vicens, Town Hall→Sagrada Família,
-- Blacksmith→Palau Güell, Apothecary→Park Güell, Bakery→El Capricho,
-- Weaver→Casa Milà, Elder House→Episcopal Palace Astorga,
-- Cottage→Casa Calvet, Farmstead→Casa Botines, Windmill→Bellesguard,
-- Castle→Hotel Attraction, Wayfarer's Rest→Colònia Güell, Fisherman→SF Schools
-- ═══════════════════════════════════════

-- Shared helpers for building rendering
function M.drawBuildingBase(b, x, y, w, h, ambientIntensity)
  -- Foundation
  love.graphics.setColor(
    b.color[1] * ambientIntensity * 0.5,
    b.color[2] * ambientIntensity * 0.5,
    b.color[3] * ambientIntensity * 0.6
  )
  love.graphics.rectangle("fill", x, y, w, h)
end

function M.drawBuildingDoor(b, ambientIntensity)
  local tc = b.timberColor or {0.50, 0.45, 0.38}
  local doorX = b.doorX * 32 + 2
  local doorBaseY = b.doorY * 32
  local doorW = 28
  local doorH = 36

  -- Door recess
  love.graphics.setColor(0.03 * ambientIntensity, 0.05 * ambientIntensity, 0.12 * ambientIntensity)
  love.graphics.rectangle("fill", doorX - 1, doorBaseY - doorH + 10, doorW + 2, doorH - 8)

  -- Door body
  love.graphics.setColor(0.08 * ambientIntensity, 0.14 * ambientIntensity, 0.30 * ambientIntensity)
  love.graphics.rectangle("fill", doorX, doorBaseY - doorH + 10, doorW, doorH - 10)

  -- Pointed arch top
  love.graphics.arc("fill", doorX + doorW/2, doorBaseY - doorH + 10, doorW/2, math.pi, 0)

  -- Door panel detail
  love.graphics.setColor(0.05 * ambientIntensity, 0.10 * ambientIntensity, 0.22 * ambientIntensity, 0.6)
  love.graphics.line(doorX + doorW/2, doorBaseY - doorH + 14, doorX + doorW/2, doorBaseY)

  -- Door handle
  love.graphics.setColor(0.20 * ambientIntensity, 0.70 * ambientIntensity, 0.90 * ambientIntensity, 0.8)
  love.graphics.circle("fill", doorX + doorW/2 + 5, doorBaseY - 10, 1.5)

  -- Threshold
  love.graphics.setColor(0.12 * ambientIntensity, 0.20 * ambientIntensity, 0.38 * ambientIntensity)
  love.graphics.rectangle("fill", doorX - 2, doorBaseY - 2, doorW + 4, 4)

  -- Door frame
  love.graphics.setColor(tc[1] * ambientIntensity * 1.2, tc[2] * ambientIntensity * 1.2, tc[3] * ambientIntensity * 1.1)
  love.graphics.setLineWidth(2.5)
  love.graphics.arc("line", doorX + doorW/2, doorBaseY - doorH + 10, doorW/2 + 2, math.pi, 0)
  love.graphics.line(doorX - 2, doorBaseY - doorH + 10, doorX - 2, doorBaseY)
  love.graphics.line(doorX + doorW + 2, doorBaseY - doorH + 10, doorX + doorW + 2, doorBaseY)
  love.graphics.setLineWidth(1)

  -- Interior glow
  if lighting.lampsOn() then
    love.graphics.setColor(0.15, 0.55, 0.85, 0.10)
    love.graphics.rectangle("fill", doorX + 2, doorBaseY - doorH + 14, doorW - 4, doorH - 16)
  end
end

function M.drawBuildingSign(b, x, y, w, roofBaseY, ambientIntensity)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  local signX = x + w/2 - textW/2 - 6
  local signY = roofBaseY - 6

  love.graphics.setColor(0.05, 0.08, 0.18, 0.55)
  love.graphics.rectangle("fill", signX, signY, textW + 12, 14, 3, 3)
  love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.75 * ambientIntensity, 0.5)
  love.graphics.rectangle("line", signX, signY, textW + 12, 14, 3, 3)
  love.graphics.setColor(0.70 * ambientIntensity, 0.88 * ambientIntensity, 0.95 * ambientIntensity)
  love.graphics.print(b.name, signX + 6, signY + 1)
end

function M.drawBuilding(b)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32
  local _, ambientIntensity = lighting.getAmbientLight()
  local tc = b.timberColor or {0.50, 0.45, 0.38}
  local interior = b.interior

  if interior == "tavern" then
    M.drawTavern(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "general_store" then
    M.drawGeneralStore(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "town_hall" then
    M.drawTownHall(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "blacksmith" then
    M.drawBlacksmith(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "apothecary" then
    M.drawApothecary(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "bakery" then
    M.drawBakery(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "weaver" then
    M.drawWeaver(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "elder_house" then
    M.drawElderHouse(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "cottage" then
    M.drawCottage(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "farmstead" then
    M.drawFarmstead(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "windmill" then
    M.drawWindmill(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "castle" then
    M.drawCastle(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "wayfarers_rest" then
    M.drawWayfarersRest(b, x, y, w, h, ambientIntensity, tc)
  elseif interior == "fisherman_hut" then
    M.drawFishermanHut(b, x, y, w, h, ambientIntensity, tc)
  end
end

-- ═══ TAVERN: Casa Batlló — skeletal bone facade, dragon-spine roof, skull balconies ═══
-- "House of Bones": organic skeletal columns, iridescent trencadís dragon-scale roof,
-- oval skull-mask windows, undulating facade with no straight lines
function M.drawTavern(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Undulating facade surface (no straight lines, Casa Batlló hallmark)
  for sy = y + 8, y + h - 2, 4 do
    local undulation = math.sin(sy * 0.18 + x * 0.05) * 3
    love.graphics.setColor(
      (b.color[1] + math.sin(sy * 0.3) * 0.04) * ambientIntensity,
      (b.color[2] + math.sin(sy * 0.25) * 0.03) * ambientIntensity,
      (b.color[3] + math.sin(sy * 0.2) * 0.02) * ambientIntensity
    )
    love.graphics.rectangle("fill", x + 1 + undulation, sy, w - 2, 3.5, 1, 1)
  end

  -- Bone-like columns (skeletal pillars flanking facade)
  for _, cx in ipairs({x + 3, x + w - 6}) do
    love.graphics.setColor(
      (b.color[1] + 0.08) * ambientIntensity,
      (b.color[2] + 0.06) * ambientIntensity,
      (b.color[3] + 0.04) * ambientIntensity
    )
    -- Organic bone column with joint bulges
    for cy = y + 10, y + h - 2, 4 do
      local boneWidth = 3 + math.sin(cy * 0.25) * 1.5  -- joint swelling
      love.graphics.ellipse("fill", cx + 1.5, cy + 2, boneWidth / 2, 2.5)
    end
  end

  -- Dragon-spine roof (arched like a reptile's back, iridescent scales)
  local roofBaseY = y + 4
  local spinePoints = {}
  for rx = x - 8, x + w + 8, 2 do
    local progress = (rx - (x - 8)) / (w + 16)
    -- Asymmetric dragon back: higher on left (head), slopes right (tail)
    local spineHeight = math.sin(progress * math.pi) * 18 + math.sin(progress * math.pi * 2) * 4
    table.insert(spinePoints, rx)
    table.insert(spinePoints, roofBaseY - spineHeight)
  end
  table.insert(spinePoints, x + w + 8)
  table.insert(spinePoints, roofBaseY + 2)
  table.insert(spinePoints, x - 8)
  table.insert(spinePoints, roofBaseY + 2)
  if #spinePoints >= 6 then
    love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
    love.graphics.polygon("fill", spinePoints)
  end
  -- Iridescent dragon scales (trencadís ceramic tiles shifting green→blue→violet)
  for rx = x - 6, x + w + 6, 4 do
    local progress = (rx - (x - 6)) / (w + 12)
    local spineH = math.sin(progress * math.pi) * 18 + math.sin(progress * math.pi * 2) * 4
    -- Color shifts: green on right (head) → blue center → violet left (tail)
    local scaleR = (0.10 + progress * 0.20) * ambientIntensity
    local scaleG = (0.35 + math.sin(progress * math.pi) * 0.25) * ambientIntensity
    local scaleB = (0.55 + (1 - progress) * 0.20) * ambientIntensity
    love.graphics.setColor(scaleR, scaleG, scaleB, 0.7)
    love.graphics.ellipse("fill", rx + 2, roofBaseY - spineH + 3, 2.5, 2)
  end

  -- Dragon's eye (small triangular window on right side, looking toward Sagrada Família)
  love.graphics.setColor(0.20 * ambientIntensity, 0.70 * ambientIntensity, 0.90 * ambientIntensity, 0.8)
  love.graphics.polygon("fill", x + w - 2, roofBaseY - 8, x + w + 4, roofBaseY - 5, x + w, roofBaseY - 2)

  -- Tower with cross (Saint George's lance piercing the dragon)
  local lanceX = x + 6
  local lanceTopY = roofBaseY - 28
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.7, b.color[2] * ambientIntensity * 0.7, b.color[3] * ambientIntensity * 0.8)
  love.graphics.rectangle("fill", lanceX, lanceTopY, 4, 28)
  -- Bulbous plant-like finial (thalamus flower)
  love.graphics.setColor(0.12 * ambientIntensity, 0.50 * ambientIntensity, 0.70 * ambientIntensity)
  love.graphics.ellipse("fill", lanceX + 2, lanceTopY - 3, 4, 5)
  -- Four-arm cross
  love.graphics.setColor(0.20 * ambientIntensity, 0.75 * ambientIntensity, 0.95 * ambientIntensity)
  local pulse = math.sin(gameState.animationTime * 2) * 0.2 + 0.8
  love.graphics.rectangle("fill", lanceX - 1, lanceTopY - 10, 8, 2)
  love.graphics.rectangle("fill", lanceX + 1, lanceTopY - 14, 2, 10)
  love.graphics.setColor(0.15 * pulse, 0.55 * pulse, 0.85 * pulse, 0.08)
  love.graphics.circle("fill", lanceX + 2, lanceTopY - 10, 14)

  -- Skull-mask oval windows (Casa dels Ossos / House of Bones style)
  for wx = x + 10, x + w - 18, 20 do
    local winY = y + 20
    -- Oval organic window opening (no straight lines)
    love.graphics.setColor(0.04 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.ellipse("fill", wx + 6, winY + 6, 7, 8)
    -- Bone-like surround (organic sculpted stone frame)
    love.graphics.setColor(
      (b.color[1] + 0.10) * ambientIntensity,
      (b.color[2] + 0.08) * ambientIntensity,
      (b.color[3] + 0.05) * ambientIntensity
    )
    love.graphics.setLineWidth(2.5)
    love.graphics.ellipse("line", wx + 6, winY + 6, 8, 9)
    love.graphics.setLineWidth(1)
    -- Warm amber glow at night
    if lighting.lampsOn() then
      love.graphics.setColor(0.85, 0.55, 0.20, 0.55)
      love.graphics.ellipse("fill", wx + 6, winY + 6, 5.5, 6.5)
      love.graphics.setColor(0.90, 0.60, 0.25, 0.06)
      love.graphics.circle("fill", wx + 6, winY + 6, 24)
    else
      love.graphics.setColor(0.25 * ambientIntensity, 0.40 * ambientIntensity, 0.60 * ambientIntensity, 0.4)
      love.graphics.ellipse("fill", wx + 6, winY + 6, 5.5, 6.5)
    end
  end

  -- Wrought-iron seaweed balcony rails (under windows)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.7, tc[2] * ambientIntensity * 0.7, tc[3] * ambientIntensity * 0.8)
  for bx = x + 8, x + w - 16, 20 do
    love.graphics.setLineWidth(1.5)
    -- Organic seaweed-like ironwork
    for i = 0, 4 do
      local ironX = bx + i * 3
      local sway = math.sin(ironX * 0.5 + y * 0.3) * 2
      love.graphics.line(ironX, y + 34, ironX + sway, y + 38)
    end
    love.graphics.line(bx, y + 34, bx + 12, y + 34)
    love.graphics.setLineWidth(1)
  end

  -- Multicolored trencadís band along lower facade
  for mx = x + 1, x + w - 3, 3 do
    local tileHue = math.sin(mx * 0.9) * 0.5 + 0.5
    love.graphics.setColor(
      (0.12 + tileHue * 0.12) * ambientIntensity,
      (0.35 + tileHue * 0.15) * ambientIntensity,
      (0.55 + (1 - tileHue) * 0.15) * ambientIntensity, 0.6
    )
    love.graphics.rectangle("fill", mx, y + h - 6, 2.5, 4, 0.5, 0.5)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, roofBaseY - 2, ambientIntensity)
end

-- ═══ GENERAL STORE: Casa Vicens — checkered ceramic tiles, Moorish turrets, oriental lattice ═══
-- Gaudí's first major work: straight-line orientalist structure, green+white check tiles,
-- fan palm iron gates, mitred arch galleries, corner turret with cupola
function M.drawGeneralStore(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Checkered ceramic tile facade (Casa Vicens signature: alternating masonry + tiles)
  for sy = y + 6, y + h - 2, 4 do
    for sx = x + 1, x + w - 3, 4 do
      local isCheck = (math.floor((sx - x) / 4) + math.floor((sy - y) / 4)) % 2 == 0
      if isCheck then
        -- Green/teal tile
        love.graphics.setColor(
          0.10 * ambientIntensity,
          (0.35 + math.sin(sx * 0.5) * 0.05) * ambientIntensity,
          (0.45 + math.sin(sy * 0.3) * 0.05) * ambientIntensity
        )
      else
        -- Cream/stone masonry
        love.graphics.setColor(
          (b.color[1] + 0.06) * ambientIntensity,
          (b.color[2] + 0.04) * ambientIntensity,
          (b.color[3] + 0.02) * ambientIntensity
        )
      end
      love.graphics.rectangle("fill", sx, sy, 3.5, 3.5)
    end
  end

  -- Corner turret with cupola (Casa Vicens pavilion)
  local turretX = x + w - 8
  local turretTopY = y - 22
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.8, b.color[2] * ambientIntensity * 0.85, b.color[3] * ambientIntensity * 0.9)
  love.graphics.rectangle("fill", turretX, turretTopY + 8, 10, y - turretTopY - 6)
  -- Cupola dome (hemispherical with ceramic tiles)
  love.graphics.setColor(0.10 * ambientIntensity, 0.40 * ambientIntensity, 0.55 * ambientIntensity)
  love.graphics.arc("fill", turretX + 5, turretTopY + 8, 7, math.pi, 0)
  -- Bronze flame finial
  local flamePulse = math.sin(gameState.animationTime * 3) * 0.2 + 0.8
  love.graphics.setColor(0.65 * flamePulse * ambientIntensity, 0.40 * flamePulse * ambientIntensity, 0.12 * flamePulse * ambientIntensity)
  love.graphics.polygon("fill", turretX + 5, turretTopY - 2, turretX + 3, turretTopY + 4, turretX + 7, turretTopY + 4)
  -- Turret checkered tiles
  for ty = turretTopY + 10, y, 4 do
    local isCheck = (math.floor(ty / 4)) % 2 == 0
    love.graphics.setColor(
      (isCheck and 0.10 or 0.18) * ambientIntensity,
      (isCheck and 0.38 or 0.28) * ambientIntensity,
      (isCheck and 0.50 or 0.42) * ambientIntensity, 0.7
    )
    love.graphics.rectangle("fill", turretX + 1, ty, 8, 3.5)
  end

  -- Mitred arch gallery (continuous arcade along upper floor, oriental style)
  love.graphics.setColor(tc[1] * ambientIntensity * 1.1, tc[2] * ambientIntensity * 1.1, tc[3] * ambientIntensity * 1.1)
  local galleryY = y + 8
  for gx = x + 3, x + w - 10, 10 do
    -- Pointed mitred arch
    love.graphics.setLineWidth(1.5)
    love.graphics.line(gx, galleryY + 10, gx + 5, galleryY, gx + 10, galleryY + 10)
    love.graphics.setLineWidth(1)
    -- Oriental lattice fill
    love.graphics.setColor(tc[1] * ambientIntensity * 0.6, tc[2] * ambientIntensity * 0.6, tc[3] * ambientIntensity * 0.7, 0.4)
    love.graphics.line(gx + 2, galleryY + 3, gx + 8, galleryY + 9)
    love.graphics.line(gx + 8, galleryY + 3, gx + 2, galleryY + 9)
  end

  -- Pitched roof with Arabic tiles (stepped roofline)
  local roofY = y - 2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  -- Stepped crenellation roofline (semi-elliptical battlements)
  for rx = x - 4, x + w + 2, 8 do
    love.graphics.rectangle("fill", rx, roofY - 4, 7, 6)
    -- Decorative battlement cap
    love.graphics.arc("fill", rx + 3.5, roofY - 4, 3.5, math.pi, 0)
  end
  love.graphics.rectangle("fill", x - 6, roofY + 2, w + 12, 4)
  -- Carnation tile trim along roof (the flower motif Gaudí found on site)
  for rx = x - 4, x + w + 4, 5 do
    local flowerHue = math.sin(rx * 0.8) * 0.5 + 0.5
    love.graphics.setColor(
      (0.60 + flowerHue * 0.20) * ambientIntensity,
      (0.35 + flowerHue * 0.10) * ambientIntensity,
      (0.12 + flowerHue * 0.08) * ambientIntensity, 0.6
    )
    love.graphics.circle("fill", rx + 2, roofY + 1, 2)
  end

  -- Display windows with teardrop sculptural drops
  for wx = x + 4, x + w - 20, 18 do
    love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.rectangle("fill", wx, y + 22, 12, 10)
    if lighting.lampsOn() then
      love.graphics.setColor(0.20, 0.70, 0.95, 0.55)
      love.graphics.rectangle("fill", wx + 1, y + 23, 10, 8)
    else
      love.graphics.setColor(0.25 * ambientIntensity, 0.45 * ambientIntensity, 0.65 * ambientIntensity, 0.4)
      love.graphics.rectangle("fill", wx + 1, y + 23, 10, 8)
    end
    -- Teardrop ornaments hanging from top
    love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity, 0.7)
    for tx = wx + 2, wx + 10, 4 do
      love.graphics.polygon("fill", tx, y + 22, tx + 2, y + 22, tx + 1, y + 19)
    end
  end

  -- Fan palm iron gate motif at entrance (wrought iron with palm leaves)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.6, tc[2] * ambientIntensity * 0.6, tc[3] * ambientIntensity * 0.7)
  local gateX = b.doorX * 32 + 16
  for i = -2, 2 do
    local palmAngle = math.pi/2 + i * 0.3
    love.graphics.line(gateX, y + h - 2, gateX + math.cos(palmAngle) * 8, y + h - 14 + math.abs(i) * 2)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, roofY - 4, ambientIntensity)
end

-- ═══ TOWN HALL: Sagrada Família — soaring organic spires, tree-branch columns, rose window ═══
-- Gaudí's masterwork: four tapering spires with geometric tops, nature-inspired branching
-- columns, three-facade symbolism, hyperboloid crossing, extensive sculptural detail
function M.drawTownHall(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Richly sculpted facade (deep relief stonework, naturalistic forms)
  for sy = y + 6, y + h - 2, 4 do
    for sx = x + 2, x + w - 4, 5 do
      local relief = math.sin(sx * 2.1 + sy * 1.7) * 0.08
      love.graphics.setColor(
        (b.color[1] + relief) * ambientIntensity,
        (b.color[2] + relief * 0.7) * ambientIntensity,
        (b.color[3] + relief * 0.5) * ambientIntensity
      )
      love.graphics.rectangle("fill", sx, sy, 4.5, 3.5, 0.5, 0.5)
    end
  end

  -- Tree-branch columns (Gaudí's interior columns that branch like trees)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.85, tc[2] * ambientIntensity * 0.85, tc[3] * ambientIntensity * 0.95)
  for _, cx in ipairs({x + 6, x + w - 8}) do
    -- Trunk
    love.graphics.rectangle("fill", cx, y + 12, 3, h - 14)
    -- Branches splitting upward
    love.graphics.line(cx + 1.5, y + 12, cx - 3, y + 4)
    love.graphics.line(cx + 1.5, y + 12, cx + 5, y + 4)
    love.graphics.line(cx + 1.5, y + 18, cx - 5, y + 10)
    love.graphics.line(cx + 1.5, y + 18, cx + 7, y + 10)
  end

  -- Four tapering spires (Sagrada Família's iconic openwork towers)
  local spirePositions = {
    {x + 2, 45},    -- leftmost, shorter
    {x + w/3 - 2, 55},  -- inner left, taller
    {x + w*2/3 - 2, 55}, -- inner right, taller
    {x + w - 6, 45}  -- rightmost, shorter
  }
  for _, sp in ipairs(spirePositions) do
    local sx, spH = sp[1], sp[2]
    local spTopY = y - spH
    -- Tapering tower body (narrows toward top)
    love.graphics.setColor(b.color[1] * ambientIntensity * 0.75, b.color[2] * ambientIntensity * 0.80, b.color[3] * ambientIntensity * 0.90)
    love.graphics.polygon("fill",
      sx, y + 2, sx + 6, y + 2,
      sx + 5, spTopY + 10,
      sx + 1, spTopY + 10
    )
    -- Openwork perforations (circular holes in spire)
    love.graphics.setColor(0.04 * ambientIntensity, 0.07 * ambientIntensity, 0.15 * ambientIntensity, 0.6)
    for hy = spTopY + 14, y - 2, 8 do
      love.graphics.circle("fill", sx + 3, hy, 1.5)
    end
    -- Geometric Cubist crown (inspired by the pinnacle decorations)
    love.graphics.setColor(0.12 * ambientIntensity, 0.50 * ambientIntensity, 0.70 * ambientIntensity)
    love.graphics.polygon("fill", sx + 1, spTopY + 10, sx + 5, spTopY + 10, sx + 3, spTopY)
    -- Orb finial
    local pulse = math.sin(gameState.animationTime * 2.2 + sx * 0.1) * 0.25 + 0.75
    love.graphics.setColor(0.20 * pulse, 0.75 * pulse, 0.95 * pulse, 0.9)
    love.graphics.circle("fill", sx + 3, spTopY - 2, 2)
    love.graphics.setColor(0.15, 0.55, 0.85, 0.06 * pulse)
    love.graphics.circle("fill", sx + 3, spTopY - 2, 12)
  end

  -- Central crossing tower (tallest, Jesus tower - hyperboloid shape)
  local centralX = x + w/2 - 3
  local centralTopY = y - 65
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.7, b.color[2] * ambientIntensity * 0.75, b.color[3] * ambientIntensity * 0.85)
  -- Hyperboloid: wider at middle, narrow at top and base
  for hy = y, centralTopY, -2 do
    local progress = (y - hy) / (y - centralTopY)
    local hyperWidth = 3 + math.sin(progress * math.pi) * 4
    love.graphics.rectangle("fill", centralX + 3 - hyperWidth/2, hy, hyperWidth, 2.5)
  end
  -- Star of Bethlehem cross at apex
  love.graphics.setColor(0.25 * ambientIntensity, 0.85 * ambientIntensity, 0.95 * ambientIntensity)
  local starCX = centralX + 3
  local starCY = centralTopY - 4
  for i = 0, 11 do
    local sa = i * math.pi / 6
    local len = (i % 2 == 0) and 5 or 3
    love.graphics.line(starCX, starCY, starCX + math.cos(sa) * len, starCY + math.sin(sa) * len)
  end
  love.graphics.circle("fill", starCX, starCY, 2)
  love.graphics.setColor(0.15, 0.60, 0.90, 0.10)
  love.graphics.circle("fill", starCX, starCY, 20)

  -- Main facade roof (stepped, between the spires)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.rectangle("fill", x - 4, y, w + 8, 4)
  love.graphics.polygon("fill", x, y, x + w, y, x + w/2, y - 12)

  -- Rose window (Gaudí's grand stained glass, multicolored radiating)
  local roseX = x + w/2
  local roseY = y + 18
  love.graphics.setColor(0.04 * ambientIntensity, 0.07 * ambientIntensity, 0.18 * ambientIntensity)
  love.graphics.circle("fill", roseX, roseY, 10)
  if lighting.lampsOn() then
    -- Radiating colored segments (warm rainbow stained glass)
    for i = 0, 11 do
      local angle = i * math.pi / 6 + gameState.animationTime * 0.2
      local colors = {
        {0.85, 0.35, 0.25}, {0.90, 0.55, 0.20}, {0.85, 0.75, 0.25},
        {0.30, 0.75, 0.40}, {0.25, 0.60, 0.90}, {0.55, 0.30, 0.85},
        {0.85, 0.35, 0.25}, {0.90, 0.55, 0.20}, {0.85, 0.75, 0.25},
        {0.30, 0.75, 0.40}, {0.25, 0.60, 0.90}, {0.55, 0.30, 0.85}
      }
      local c = colors[i + 1]
      love.graphics.setColor(c[1], c[2], c[3], 0.5)
      love.graphics.arc("fill", roseX, roseY, 8, angle, angle + math.pi/6)
    end
    love.graphics.setColor(0.85, 0.75, 0.55, 0.06)
    love.graphics.circle("fill", roseX, roseY, 32)
  else
    love.graphics.setColor(0.20 * ambientIntensity, 0.40 * ambientIntensity, 0.60 * ambientIntensity, 0.5)
    love.graphics.circle("fill", roseX, roseY, 8)
  end
  -- Tracery (delicate stone spokes)
  love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity, 0.6)
  for i = 0, 11 do
    local angle = i * math.pi / 6
    love.graphics.line(roseX, roseY, roseX + math.cos(angle) * 9, roseY + math.sin(angle) * 9)
  end
  love.graphics.circle("line", roseX, roseY, 10)
  love.graphics.circle("line", roseX, roseY, 6)

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, y - 12, ambientIntensity)
end

-- ═══ BLACKSMITH: Palau Güell — parabolic entrance arches, iron gates, ornate chimney forest ═══
-- Gaudí's palace for Güell: twin parabolic arch entrance, forged ironwork gates,
-- tall central dome with starlight holes, rooftop forest of mosaic-clad chimneys
function M.drawBlacksmith(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Austere limestone facade (Palau Güell's restrained street front)
  for sy = y + 6, y + h - 2, 5 do
    for sx = x + 1, x + w - 3, 7 do
      local shade = 0.92 + math.sin(sx * 1.9 + sy * 2.3) * 0.08
      love.graphics.setColor(
        b.color[1] * ambientIntensity * shade * 0.9,
        b.color[2] * ambientIntensity * shade * 0.88,
        b.color[3] * ambientIntensity * shade * 0.95
      )
      love.graphics.rectangle("fill", sx, sy, 6, 4, 0.5, 0.5)
    end
  end

  -- Twin parabolic entrance arches (Palau Güell's iconic front)
  love.graphics.setColor(tc[1] * ambientIntensity * 1.1, tc[2] * ambientIntensity * 1.1, tc[3] * ambientIntensity * 1.2)
  love.graphics.setLineWidth(2.5)
  for _, archOff in ipairs({w/4, w*3/4}) do
    local archCX = x + archOff
    for i = -1, 1, 0.04 do
      local ax = archCX + i * 8
      local ay = y + h - 2 - (1 - i*i) * 14
      love.graphics.circle("fill", ax, ay, 1.2)
    end
  end
  love.graphics.setLineWidth(1)

  -- Forged iron spiderweb gate between arches (wrought iron patterns)
  local gateX = x + w/2 - 6
  love.graphics.setColor(tc[1] * ambientIntensity * 0.5, tc[2] * ambientIntensity * 0.5, tc[3] * ambientIntensity * 0.6, 0.7)
  -- Spiderweb radial pattern
  local webCX = x + w/2
  local webCY = y + h - 14
  for i = 0, 7 do
    local wa = i * math.pi / 4
    love.graphics.line(webCX, webCY, webCX + math.cos(wa) * 8, webCY + math.sin(wa) * 8)
  end
  for r = 3, 8, 2.5 do
    love.graphics.circle("line", webCX, webCY, r)
  end

  -- Phoenix emblem between arches (Güell's mythical symbol)
  love.graphics.setColor(0.65 * ambientIntensity, 0.40 * ambientIntensity, 0.12 * ambientIntensity, 0.7)
  love.graphics.polygon("fill", webCX, y + h - 28, webCX - 4, y + h - 22, webCX + 4, y + h - 22)
  love.graphics.polygon("fill", webCX - 3, y + h - 24, webCX - 8, y + h - 20, webCX - 2, y + h - 22)
  love.graphics.polygon("fill", webCX + 3, y + h - 24, webCX + 8, y + h - 20, webCX + 2, y + h - 22)

  -- Central dome (tall parabolic dome rising above, with starlight holes)
  local domeCX = x + w/2
  local domeBaseY = y + 2
  local domeTopY = y - 30
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 0.9, b.roofColor[2] * ambientIntensity * 0.9, b.roofColor[3] * ambientIntensity)
  love.graphics.polygon("fill",
    x - 2, domeBaseY, x + w + 2, domeBaseY,
    x + w - 4, domeBaseY - 8, domeCX + 4, domeTopY + 6,
    domeCX, domeTopY, domeCX - 4, domeTopY + 6,
    x + 4, domeBaseY - 8
  )
  -- Starlight holes in dome (Palau Güell's ceiling with lantern-lit holes)
  if lighting.lampsOn() then
    for i = 1, 8 do
      local starX = domeCX + math.sin(i * 1.7) * (w/3)
      local starY = domeBaseY - 6 - i * 2.5
      local twinkle = math.sin(gameState.animationTime * 3 + i * 1.3) * 0.3 + 0.7
      love.graphics.setColor(0.85 * twinkle, 0.75 * twinkle, 0.45 * twinkle, 0.6)
      love.graphics.circle("fill", starX, starY, 1)
      love.graphics.setColor(0.85, 0.75, 0.45, 0.03 * twinkle)
      love.graphics.circle("fill", starX, starY, 6)
    end
  end

  -- Forest of ornate chimneys on rooftop (espanta bruixes / witch scarers)
  for i = 0, 4 do
    local chimX = x + 3 + i * (w / 5)
    local chimH = 12 + math.sin(i * 2.1) * 5
    local chimTopY = domeTopY + 2 - chimH
    love.graphics.setColor(b.color[1] * ambientIntensity * 0.65, b.color[2] * ambientIntensity * 0.6, b.color[3] * ambientIntensity * 0.75)
    love.graphics.rectangle("fill", chimX, chimTopY, 4, chimH)
    -- Mosaic cap (each chimney unique trencadís color)
    local capColors = {
      {0.65, 0.25, 0.15}, {0.15, 0.55, 0.35}, {0.55, 0.40, 0.70},
      {0.70, 0.55, 0.15}, {0.20, 0.50, 0.70}
    }
    local cc = capColors[i + 1]
    love.graphics.setColor(cc[1] * ambientIntensity, cc[2] * ambientIntensity, cc[3] * ambientIntensity, 0.8)
    love.graphics.polygon("fill", chimX - 1, chimTopY, chimX + 5, chimTopY, chimX + 2, chimTopY - 5)
  end

  -- Forge glow from within (warm fire through the arches)
  if lighting.lampsOn() then
    local flicker = math.sin(gameState.animationTime * 5.5) * 0.12 + 0.88
    love.graphics.setColor(0.90 * flicker, 0.45 * flicker, 0.12 * flicker, 0.08)
    love.graphics.circle("fill", x + w/4, y + h - 8, 18)
    love.graphics.circle("fill", x + w*3/4, y + h - 8, 18)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, domeTopY, ambientIntensity)
end

-- ═══ APOTHECARY: Park Güell — mosaic gatehouse, Doric columns, serpentine bench, salamander ═══
-- Gaudí's garden city: whimsical gingerbread pavilion roof, multicolored trencadís,
-- Doric column hypostyle hall, organic serpentine bench, El Drac salamander fountain
function M.drawApothecary(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Multicolored trencadís mosaic walls (Park Güell's signature patchwork)
  for sx = x + 2, x + w - 4, 4 do
    for sy = y + 8, y + h - 2, 4 do
      local hue1 = math.sin(sx * 1.3 + sy * 0.7) * 0.5 + 0.5
      local hue2 = math.cos(sx * 0.9 + sy * 1.1) * 0.5 + 0.5
      love.graphics.setColor(
        (0.12 + hue1 * 0.18) * ambientIntensity,
        (0.30 + hue2 * 0.25) * ambientIntensity,
        (0.45 + hue1 * 0.20) * ambientIntensity, 0.8
      )
      -- Irregular mosaic tile shapes
      love.graphics.rectangle("fill", sx + math.sin(sy * 0.5) * 0.5, sy, 3.5, 3.5, 0.5, 0.5)
    end
  end

  -- Doric columns (hypostyle hall supporting the terrace above)
  love.graphics.setColor(
    (b.color[1] + 0.08) * ambientIntensity,
    (b.color[2] + 0.06) * ambientIntensity,
    (b.color[3] + 0.04) * ambientIntensity
  )
  for cx = x + 5, x + w - 6, 8 do
    -- Fluted Doric column
    love.graphics.rectangle("fill", cx, y + 14, 4, h - 16)
    -- Column capital
    love.graphics.rectangle("fill", cx - 1, y + 12, 6, 3)
    -- Fluting detail
    love.graphics.setColor(b.color[1] * ambientIntensity * 0.7, b.color[2] * ambientIntensity * 0.7, b.color[3] * ambientIntensity * 0.8, 0.3)
    love.graphics.line(cx + 2, y + 14, cx + 2, y + h - 2)
    love.graphics.setColor(
      (b.color[1] + 0.08) * ambientIntensity,
      (b.color[2] + 0.06) * ambientIntensity,
      (b.color[3] + 0.04) * ambientIntensity
    )
  end

  -- Gingerbread gatehouse roof (whimsical bulbous form with mushroom cap)
  local roofCX = x + w/2
  local roofBaseY = y + 4
  -- Main mushroom-cap dome
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 1.1, b.roofColor[2] * ambientIntensity * 1.2, b.roofColor[3] * ambientIntensity * 1.1)
  local domePoints = {}
  for angle = math.pi, 0, -0.08 do
    local r = (w/2 + 6) * (1 + 0.12 * math.cos(angle * 4))
    table.insert(domePoints, roofCX + math.cos(angle) * r)
    table.insert(domePoints, roofBaseY - math.sin(angle) * r * 0.45)
  end
  table.insert(domePoints, roofCX + w/2 + 6)
  table.insert(domePoints, roofBaseY)
  table.insert(domePoints, roofCX - w/2 - 6)
  table.insert(domePoints, roofBaseY)
  if #domePoints >= 6 then
    love.graphics.polygon("fill", domePoints)
  end
  -- Polychrome ceramic dots on dome (scattered trencadís)
  for i = 1, 12 do
    local dotAngle = math.pi * i / 13
    local dotR = (w/2 + 2) * (1 + 0.12 * math.cos(dotAngle * 4))
    local dotX = roofCX + math.cos(dotAngle) * dotR * 0.7
    local dotY = roofBaseY - math.sin(dotAngle) * dotR * 0.35
    local dotHue = math.sin(i * 1.7) * 0.5 + 0.5
    love.graphics.setColor(
      (0.15 + dotHue * 0.20) * ambientIntensity,
      (0.40 + dotHue * 0.15) * ambientIntensity,
      (0.55 + (1 - dotHue) * 0.15) * ambientIntensity, 0.6
    )
    love.graphics.circle("fill", dotX, dotY, 2)
  end

  -- Spired pinnacle with Gaudí cross
  local spireTopY = roofBaseY - (w/2 + 6) * 0.45 - 8
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 0.8, b.roofColor[2] * ambientIntensity * 0.85, b.roofColor[3] * ambientIntensity * 0.9)
  love.graphics.polygon("fill", roofCX - 3, roofBaseY - 20, roofCX + 3, roofBaseY - 20, roofCX, spireTopY)
  -- Four-arm cross
  love.graphics.setColor(0.20 * ambientIntensity, 0.75 * ambientIntensity, 0.90 * ambientIntensity)
  love.graphics.rectangle("fill", roofCX - 3, spireTopY - 6, 6, 1.5)
  love.graphics.rectangle("fill", roofCX - 0.75, spireTopY - 9, 1.5, 8)

  -- El Drac salamander/dragon (mosaic fountain at base)
  local salamX = x + 4
  local salamY = y + h - 2
  love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.40 * ambientIntensity, 0.8)
  -- Body
  love.graphics.ellipse("fill", salamX + 6, salamY - 3, 6, 3)
  -- Head
  love.graphics.ellipse("fill", salamX + 13, salamY - 3, 3, 2.5)
  -- Mosaic spots
  love.graphics.setColor(0.60 * ambientIntensity, 0.45 * ambientIntensity, 0.15 * ambientIntensity, 0.6)
  love.graphics.circle("fill", salamX + 4, salamY - 3, 1)
  love.graphics.circle("fill", salamX + 8, salamY - 4, 1)
  love.graphics.setColor(0.20 * ambientIntensity, 0.65 * ambientIntensity, 0.85 * ambientIntensity, 0.6)
  love.graphics.circle("fill", salamX + 6, salamY - 2, 1)

  -- Serpentine bench fragment along roofline (undulating sea-serpent bench)
  love.graphics.setColor(0.12 * ambientIntensity, 0.45 * ambientIntensity, 0.65 * ambientIntensity, 0.5)
  love.graphics.setLineWidth(2)
  for bx = x - 4, x + w + 4, 2 do
    local benchWave = math.sin((bx - x) * 0.15) * 3
    love.graphics.circle("fill", bx, roofBaseY + benchWave, 1)
  end
  love.graphics.setLineWidth(1)

  -- Herb planters integrated as grotesque ceiling mosaic motifs
  for px = x + 4, x + w - 10, 14 do
    love.graphics.setColor(0.10 * ambientIntensity, 0.18 * ambientIntensity, 0.30 * ambientIntensity)
    love.graphics.rectangle("fill", px, y + h - 5, 10, 5, 1, 1)
    for hx = px + 1, px + 8, 3 do
      local herbSway = environment.getWindSway(hx, gameState.animationTime, 1)
      love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.35 * ambientIntensity, 0.8)
      love.graphics.line(hx + 1, y + h - 5, hx + 1 + herbSway * 0.5, y + h - 9)
    end
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, spireTopY - 2, ambientIntensity)
end

-- ═══ BAKERY: El Capricho — sunflower ceramic tower, playful color bands, Moorish minaret ═══
-- Gaudí's playful villa: cylindrical tower/minaret with sunflower tiles,
-- horizontal bands of alternating green/yellow ceramic, iron sunflower balcony
function M.drawBakery(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Horizontal alternating color bands (green & warm yellow ceramic strips)
  for sy = y + 6, y + h - 2, 4 do
    local band = math.floor((sy - y) / 4) % 2
    if band == 0 then
      love.graphics.setColor(
        0.22 * ambientIntensity, 0.42 * ambientIntensity, 0.28 * ambientIntensity
      )
    else
      love.graphics.setColor(
        0.50 * ambientIntensity, 0.42 * ambientIntensity, 0.18 * ambientIntensity
      )
    end
    love.graphics.rectangle("fill", x + 1, sy, w - 2, 3.5)
  end

  -- Cylindrical minaret tower (right side, El Capricho's signature)
  local towerCX = x + w - 2
  local towerW = 12
  local towerTopY = y - 35
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.9, b.color[2] * ambientIntensity * 0.92, b.color[3] * ambientIntensity)
  love.graphics.rectangle("fill", towerCX - towerW/2, towerTopY, towerW, y + h - towerTopY)
  -- Rounded sides
  love.graphics.arc("fill", towerCX, towerTopY + (y + h - towerTopY) / 2, towerW / 2, -math.pi/2, math.pi/2)

  -- Sunflower tile pattern on tower (ceramic sunflower medallions)
  for ty = towerTopY + 4, y + h - 8, 10 do
    -- Sunflower center
    love.graphics.setColor(0.55 * ambientIntensity, 0.38 * ambientIntensity, 0.12 * ambientIntensity)
    love.graphics.circle("fill", towerCX, ty, 3)
    -- Petals
    for p = 0, 5 do
      local pAngle = p * math.pi / 3
      love.graphics.setColor(0.60 * ambientIntensity, 0.50 * ambientIntensity, 0.12 * ambientIntensity, 0.7)
      love.graphics.ellipse("fill", towerCX + math.cos(pAngle) * 4, ty + math.sin(pAngle) * 4, 2, 1.2, pAngle)
    end
  end

  -- Minaret cupola (bulbous onion dome top)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 1.1, b.roofColor[2] * ambientIntensity * 1.2, b.roofColor[3] * ambientIntensity * 1.1)
  love.graphics.ellipse("fill", towerCX, towerTopY - 2, towerW / 2 + 2, 8)
  -- Dome pinnacle
  love.graphics.setColor(0.55 * ambientIntensity, 0.42 * ambientIntensity, 0.15 * ambientIntensity)
  love.graphics.polygon("fill", towerCX - 2, towerTopY - 9, towerCX + 2, towerTopY - 9, towerCX, towerTopY - 18)
  -- Iron weathervane on top
  love.graphics.setColor(0.15 * ambientIntensity, 0.50 * ambientIntensity, 0.70 * ambientIntensity)
  love.graphics.line(towerCX, towerTopY - 18, towerCX, towerTopY - 22)
  love.graphics.circle("fill", towerCX, towerTopY - 22, 2)

  -- Main building roof: playful undulating terracotta ridge
  local roofY = y - 2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  local roofPts = {}
  for rx = x - 6, x + w - 10, 2 do
    local ridge = math.sin((rx - x) * 0.2) * 4
    table.insert(roofPts, rx)
    table.insert(roofPts, roofY - 6 + ridge)
  end
  table.insert(roofPts, x + w - 10)
  table.insert(roofPts, roofY + 4)
  table.insert(roofPts, x - 6)
  table.insert(roofPts, roofY + 4)
  if #roofPts >= 6 then
    love.graphics.polygon("fill", roofPts)
  end

  -- Iron sunflower railing on balcony
  love.graphics.setColor(tc[1] * ambientIntensity * 0.7, tc[2] * ambientIntensity * 0.7, tc[3] * ambientIntensity * 0.8)
  love.graphics.rectangle("fill", x - 4, y + h / 2, w - 6, 2)
  for rx = x, x + w - 14, 10 do
    -- Tiny sunflower ornaments on railing
    love.graphics.setColor(0.55 * ambientIntensity, 0.45 * ambientIntensity, 0.15 * ambientIntensity, 0.6)
    love.graphics.circle("fill", rx + 3, y + h / 2 - 2, 2)
  end

  -- Bakery oven window (warm glow from inside)
  local ovenWinX = x + 4
  local ovenWinY = y + 18
  love.graphics.setColor(0.06 * ambientIntensity, 0.10 * ambientIntensity, 0.22 * ambientIntensity)
  love.graphics.rectangle("fill", ovenWinX, ovenWinY, 12, 10, 2, 2)
  if lighting.lampsOn() then
    local flicker = math.sin(gameState.animationTime * 4.5) * 0.1 + 0.9
    love.graphics.setColor(0.90 * flicker, 0.50 * flicker, 0.12 * flicker, 0.4)
    love.graphics.rectangle("fill", ovenWinX + 1, ovenWinY + 1, 10, 8, 1, 1)
    love.graphics.setColor(0.90 * flicker, 0.50 * flicker, 0.12 * flicker, 0.06)
    love.graphics.circle("fill", ovenWinX + 6, ovenWinY + 5, 20)
  end

  -- Chimney smoke
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.6, b.color[2] * ambientIntensity * 0.6, b.color[3] * ambientIntensity * 0.7)
  love.graphics.rectangle("fill", x + 8, roofY - 10, 5, 10)
  for i = 1, 2 do
    local sT = gameState.animationTime + i * 2.3
    local sAlpha = math.max(0, 0.2 - (sT % 2.5) * 0.08)
    love.graphics.setColor(0.35 * ambientIntensity, 0.40 * ambientIntensity, 0.50 * ambientIntensity, sAlpha)
    love.graphics.circle("fill", x + 10 + math.sin(sT) * 3, roofY - 12 - (sT % 2.5) * 5, 2)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, towerTopY - 22, ambientIntensity)
end

-- ═══ WEAVER: Casa Milà (La Pedrera) — undulating stone facade, seaweed balconies, warrior chimneys ═══
-- Gaudí's stone quarry: NO straight lines anywhere, self-supporting rippling facade,
-- wrought-iron kelp/seaweed balcony rails, espanta bruixes warrior-helmet chimney sentinels
function M.drawWeaver(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Undulating stone facade (no straight lines — organic wave surface)
  for sy = y + 6, y + h - 2, 3 do
    local waveOff = math.sin(sy * 0.18 + 1.5) * 3
    local shade = 0.92 + math.sin(sy * 0.35) * 0.08
    love.graphics.setColor(
      (b.color[1] + 0.03) * ambientIntensity * shade,
      (b.color[2] + 0.02) * ambientIntensity * shade,
      b.color[3] * ambientIntensity * shade
    )
    -- Each row is slightly offset to create rippling effect
    love.graphics.rectangle("fill", x + 1 + waveOff, sy, w - 2, 2.5, 0.5, 0.5)
  end

  -- Undulating roofline (organic flowing terrace edge)
  local roofBaseY = y + 2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 1.05, b.roofColor[2] * ambientIntensity * 1.1, b.roofColor[3] * ambientIntensity * 1.05)
  local roofPts = {}
  for rx = x - 6, x + w + 6, 2 do
    local wave = math.sin((rx - x) * 0.1) * 6 + math.sin((rx - x) * 0.22) * 3
    table.insert(roofPts, rx)
    table.insert(roofPts, roofBaseY - 8 + wave)
  end
  table.insert(roofPts, x + w + 6)
  table.insert(roofPts, roofBaseY + 4)
  table.insert(roofPts, x - 6)
  table.insert(roofPts, roofBaseY + 4)
  if #roofPts >= 6 then
    love.graphics.polygon("fill", roofPts)
  end

  -- Espanta bruixes (warrior-helmet chimney sentinels on rooftop)
  local chimneyPositions = {x + 4, x + w/3, x + w*2/3 - 2, x + w - 8}
  for ci, cx in ipairs(chimneyPositions) do
    local chimneyH = 14 + ci * 3
    local chimneyTopY = roofBaseY - 8 - chimneyH
    -- Chimney body (twisted organic form)
    love.graphics.setColor(
      (b.color[1] - 0.02) * ambientIntensity * 0.85,
      (b.color[2] + 0.01) * ambientIntensity * 0.85,
      b.color[3] * ambientIntensity * 0.9
    )
    love.graphics.polygon("fill",
      cx, roofBaseY - 6,
      cx + 6, roofBaseY - 6,
      cx + 5, chimneyTopY + 4,
      cx + 1, chimneyTopY + 4
    )
    -- Warrior helmet head (visor slit face)
    love.graphics.setColor(b.roofColor[1] * ambientIntensity * 0.8, b.roofColor[2] * ambientIntensity * 0.8, b.roofColor[3] * ambientIntensity * 0.85)
    love.graphics.ellipse("fill", cx + 3, chimneyTopY + 2, 5, 4)
    -- Visor slit (dark eye)
    love.graphics.setColor(0.04 * ambientIntensity, 0.06 * ambientIntensity, 0.12 * ambientIntensity)
    love.graphics.rectangle("fill", cx + 1, chimneyTopY + 1, 4, 1.5)
  end

  -- Wrought-iron seaweed/kelp balcony railings
  for bx = x + 2, x + w - 10, 12 do
    local balcY = y + 18 + math.sin(bx * 0.3) * 4
    -- Balcony shelf
    love.graphics.setColor(tc[1] * ambientIntensity * 0.7, tc[2] * ambientIntensity * 0.7, tc[3] * ambientIntensity * 0.8)
    love.graphics.rectangle("fill", bx, balcY, 10, 2)
    -- Kelp/seaweed iron railing tendrils
    love.graphics.setColor(tc[1] * ambientIntensity * 0.5, tc[2] * ambientIntensity * 0.5, tc[3] * ambientIntensity * 0.6, 0.6)
    for t = 0, 3 do
      local tX = bx + 1 + t * 2.5
      local curl = math.sin(tX * 0.8 + gameState.animationTime * 0.3) * 1.5
      love.graphics.line(tX, balcY, tX + curl, balcY + 6)
      love.graphics.circle("fill", tX + curl, balcY + 6, 1)
    end
  end

  -- Oval/organic windows (irregular shapes, no rectangles)
  for wx = x + 6, x + w - 14, 16 do
    local winY = y + 12 + math.sin(wx * 0.4) * 3
    love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.ellipse("fill", wx + 5, winY + 5, 5, 7)
    if lighting.lampsOn() then
      love.graphics.setColor(0.60, 0.35, 0.85, 0.5)
      love.graphics.ellipse("fill", wx + 5, winY + 5, 4, 6)
    end
    -- Organic stone surround
    love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity, 0.5)
    love.graphics.ellipse("line", wx + 5, winY + 5, 5.5, 7.5)
  end

  -- Parabolic arch attic (270 catenary vaults suggested by lines)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.6, tc[2] * ambientIntensity * 0.6, tc[3] * ambientIntensity * 0.7, 0.3)
  for ax = x + 2, x + w - 6, 6 do
    love.graphics.arc("line", ax + 3, roofBaseY, 3, math.pi, 0)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, roofBaseY - 8 - 26, ambientIntensity)
end

-- ═══ ELDER HOUSE: Episcopal Palace of Astorga — neo-Gothic granite castle, cylindrical towers ═══
-- Gaudí's gray granite fortress: four corner cylindrical towers with pointed caps,
-- buttressed entrance arches, moat/ditch surround, Gothic pointed windows
function M.drawElderHouse(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Ashlar granite block walls (rough-cut gray stone)
  for sy = y + 6, y + h - 2, 5 do
    for sx = x + 1, x + w - 3, 7 do
      local shade = 0.88 + math.sin(sx * 2.3 + sy * 1.7) * 0.12
      love.graphics.setColor(
        (b.color[1] - 0.02) * ambientIntensity * shade,
        (b.color[2] - 0.01) * ambientIntensity * shade,
        b.color[3] * ambientIntensity * shade
      )
      love.graphics.rectangle("fill", sx, sy, 6, 4)
    end
  end

  -- Four cylindrical corner towers
  local towerR = 6
  local towerH = 40
  local towerPositions = {
    {x - 2, y + h},
    {x + w + 2, y + h},
    {x - 2, y + h},
    {x + w + 2, y + h}
  }
  local towerXs = {x - 2, x + w + 2, x + w/3, x + w*2/3}
  for ti, tx in ipairs(towerXs) do
    local towerTopY = y - towerH + (ti > 2 and 10 or 0)
    local tH = y + h - towerTopY
    -- Cylindrical tower body
    love.graphics.setColor(
      (b.color[1] - 0.04) * ambientIntensity * 0.85,
      (b.color[2] - 0.03) * ambientIntensity * 0.85,
      b.color[3] * ambientIntensity * 0.9
    )
    love.graphics.rectangle("fill", tx - towerR, towerTopY, towerR * 2, tH)
    love.graphics.arc("fill", tx, towerTopY + tH / 2, towerR, -math.pi/2, math.pi/2)

    -- Conical pointed turret cap
    love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
    love.graphics.polygon("fill",
      tx - towerR - 1, towerTopY,
      tx + towerR + 1, towerTopY,
      tx, towerTopY - 16
    )

    -- Arrow slit windows on towers
    love.graphics.setColor(0.04 * ambientIntensity, 0.06 * ambientIntensity, 0.14 * ambientIntensity)
    for wy = towerTopY + 8, towerTopY + tH - 10, 14 do
      love.graphics.rectangle("fill", tx - 1, wy, 2, 8)
    end
    if lighting.lampsOn() then
      for wy = towerTopY + 8, towerTopY + tH - 10, 14 do
        love.graphics.setColor(0.18, 0.60, 0.90, 0.4)
        love.graphics.rectangle("fill", tx - 1, wy, 2, 8)
      end
    end
  end

  -- Buttressed Gothic entrance arch (large pointed arch)
  local archCX = x + w/2
  local archBaseY = y + h - 2
  love.graphics.setColor(
    (b.color[1] - 0.04) * ambientIntensity * 0.8,
    (b.color[2] - 0.03) * ambientIntensity * 0.8,
    b.color[3] * ambientIntensity * 0.85
  )
  -- Buttresses
  love.graphics.polygon("fill", archCX - 16, archBaseY, archCX - 12, archBaseY, archCX - 14, y + 6, archCX - 18, y + 10)
  love.graphics.polygon("fill", archCX + 12, archBaseY, archCX + 16, archBaseY, archCX + 18, y + 10, archCX + 14, y + 6)

  -- Main steep roof (Gothic pitched)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.polygon("fill",
    x - 4, y + 2,
    x + w + 4, y + 2,
    x + w/2, y - 20
  )
  -- Roof tile rows
  love.graphics.setColor(tc[1] * ambientIntensity * 0.5, tc[2] * ambientIntensity * 0.5, tc[3] * ambientIntensity * 0.6, 0.3)
  for ty = y - 18, y, 4 do
    local progress = (ty - (y - 20)) / 22
    local lineW = (w + 8) * progress
    love.graphics.line(x + w/2 - lineW/2, ty, x + w/2 + lineW/2, ty)
  end

  -- Gothic pointed-arch window (tall and narrow)
  local gwX = x + w/2 - 6
  local gwY = y + 14
  love.graphics.setColor(0.04 * ambientIntensity, 0.07 * ambientIntensity, 0.18 * ambientIntensity)
  love.graphics.rectangle("fill", gwX, gwY, 12, 18)
  -- Pointed arch top
  love.graphics.polygon("fill", gwX, gwY, gwX + 12, gwY, gwX + 6, gwY - 8)
  if lighting.lampsOn() then
    love.graphics.setColor(0.18, 0.55, 0.85, 0.5)
    love.graphics.rectangle("fill", gwX + 1, gwY + 1, 10, 16)
    love.graphics.polygon("fill", gwX + 1, gwY, gwX + 11, gwY, gwX + 6, gwY - 6)
    -- Stained glass tracery
    love.graphics.setColor(0.60, 0.30, 0.90, 0.3)
    love.graphics.line(gwX + 6, gwY - 6, gwX + 6, gwY + 17)
    love.graphics.arc("line", gwX + 6, gwY + 4, 4, math.pi, 0)
  end

  -- Moat/ditch at foundation
  love.graphics.setColor(0.06 * ambientIntensity, 0.12 * ambientIntensity, 0.28 * ambientIntensity, 0.4)
  love.graphics.rectangle("fill", x - 6, y + h, w + 12, 3, 1, 1)

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, y - 20, ambientIntensity)
end

-- ═══ COTTAGE: Casa Calvet — baroque symmetrical facade, mushroom ornaments, bobbin columns ═══
-- Gaudí's most conventional work: symmetrical facade with double gable,
-- mushroom/fungus ornaments, bobbin-shaped entrance columns, bulging iron balconies
function M.drawCottage(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Symmetrical ashlar facade (regular dressed stone — most conventional Gaudí)
  for sy = y + 6, y + h - 2, 4 do
    local row = math.floor((sy - y) / 4)
    local offset = (row % 2 == 0) and 0 or 3
    for sx = x + 1 + offset, x + w - 3, 7 do
      local shade = 0.95 + math.sin(sx * 0.8 + sy * 0.6) * 0.05
      love.graphics.setColor(
        (b.color[1] + 0.02) * ambientIntensity * shade,
        (b.color[2] + 0.01) * ambientIntensity * shade,
        b.color[3] * ambientIntensity * shade
      )
      love.graphics.rectangle("fill", sx, sy, 6, 3.5)
    end
  end

  -- Double gable top (symmetrical baroque crown — Casa Calvet's signature)
  local roofY = y - 2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  -- Left gable
  love.graphics.polygon("fill",
    x - 4, roofY + 3,
    x + w/2 + 2, roofY + 3,
    x + w/4, roofY - 14
  )
  -- Right gable
  love.graphics.polygon("fill",
    x + w/2 - 2, roofY + 3,
    x + w + 4, roofY + 3,
    x + w * 3/4, roofY - 14
  )
  -- Central ornamental pediment
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 1.15, b.roofColor[2] * ambientIntensity * 1.2, b.roofColor[3] * ambientIntensity * 1.15)
  love.graphics.polygon("fill",
    x + w/2 - 8, roofY + 3,
    x + w/2 + 8, roofY + 3,
    x + w/2, roofY - 18
  )

  -- Mushroom/fungus ornaments along gable ridge
  for mi = 0, 3 do
    local mushX = x + w/4 + mi * w/6
    local mushY = roofY - 12 + math.abs(mi - 1.5) * 3
    -- Mushroom cap
    love.graphics.setColor(0.45 * ambientIntensity, 0.28 * ambientIntensity, 0.15 * ambientIntensity, 0.7)
    love.graphics.ellipse("fill", mushX, mushY, 4, 2.5)
    -- Stem
    love.graphics.setColor(0.50 * ambientIntensity, 0.42 * ambientIntensity, 0.28 * ambientIntensity, 0.6)
    love.graphics.rectangle("fill", mushX - 1, mushY, 2, 4)
  end

  -- Bobbin-shaped entrance columns (flanking door)
  local doorCX = b.doorX * 32 + 16
  for side = -1, 1, 2 do
    local colX = doorCX + side * 12
    love.graphics.setColor(
      (b.color[1] + 0.04) * ambientIntensity * 0.9,
      (b.color[2] + 0.03) * ambientIntensity * 0.9,
      b.color[3] * ambientIntensity * 0.95
    )
    -- Bobbin shape: bulge-narrow-bulge
    love.graphics.ellipse("fill", colX, y + h - 4, 3, 4)
    love.graphics.rectangle("fill", colX - 1.5, y + h - 12, 3, 8)
    love.graphics.ellipse("fill", colX, y + h - 14, 3, 3)
    love.graphics.rectangle("fill", colX - 1.5, y + h - 20, 3, 6)
    love.graphics.ellipse("fill", colX, y + h - 22, 3.5, 3)
  end

  -- Bulging wrought-iron balconies
  for bx = x + 6, x + w - 14, 14 do
    local balcY = y + 20
    love.graphics.setColor(tc[1] * ambientIntensity * 0.6, tc[2] * ambientIntensity * 0.6, tc[3] * ambientIntensity * 0.7)
    -- Curved belly of balcony
    love.graphics.arc("fill", bx + 5, balcY + 2, 6, 0, math.pi)
    -- Railing top
    love.graphics.rectangle("fill", bx - 1, balcY, 12, 1.5)
    -- Window above balcony
    love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.rectangle("fill", bx, balcY - 10, 10, 10, 1, 1)
    if lighting.lampsOn() then
      love.graphics.setColor(0.85, 0.65, 0.30, 0.45)
      love.graphics.rectangle("fill", bx + 1, balcY - 9, 8, 8, 1, 1)
    end
  end

  -- Cypress knocker ornament on pediment
  love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.35 * ambientIntensity, 0.6)
  love.graphics.ellipse("fill", x + w/2, roofY - 12, 2, 5)

  -- Flower box at base
  for fx = x + 3, x + w - 8, 12 do
    love.graphics.setColor(0.10 * ambientIntensity, 0.16 * ambientIntensity, 0.28 * ambientIntensity)
    love.graphics.rectangle("fill", fx, y + h - 4, 8, 4, 1, 1)
    for hx = fx + 1, fx + 6, 3 do
      local sway = environment.getWindSway(hx, gameState.animationTime, 1)
      love.graphics.setColor(0.70 * ambientIntensity, 0.30 * ambientIntensity, 0.85 * ambientIntensity, 0.6)
      love.graphics.circle("fill", hx + sway * 0.5, y + h - 6, 2)
    end
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, roofY - 18, ambientIntensity)
end

-- ═══ FARMSTEAD: Casa Botines — medieval neo-Gothic, corner towers, inclined roof, dragon sculpture ═══
-- Gaudí's Gothic castle in León: corner turrets, steeply inclined roof with dormers,
-- moat around facades, Saint George slaying dragon sculpture above entrance
function M.drawFarmstead(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Rusticated stone blocks (rough medieval masonry)
  for sy = y + 6, y + h - 2, 5 do
    for sx = x + 1, x + w - 3, 8 do
      local rng = math.sin(sx * 3.1 + sy * 1.7)
      local shade = 0.85 + rng * 0.15
      love.graphics.setColor(
        (b.color[1] - 0.03) * ambientIntensity * shade,
        (b.color[2] - 0.02) * ambientIntensity * shade,
        b.color[3] * ambientIntensity * shade
      )
      love.graphics.rectangle("fill", sx, sy, 7, 4)
    end
  end

  -- Four corner turrets (smaller medieval round towers)
  local turretR = 5
  local turretXs = {x - 2, x + w + 2}
  for _, tx in ipairs(turretXs) do
    local turretTopY = y - 25
    love.graphics.setColor(
      (b.color[1] - 0.04) * ambientIntensity * 0.8,
      (b.color[2] - 0.03) * ambientIntensity * 0.8,
      b.color[3] * ambientIntensity * 0.85
    )
    love.graphics.rectangle("fill", tx - turretR, turretTopY, turretR * 2, y + h - turretTopY)
    -- Conical turret cap
    love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
    love.graphics.polygon("fill",
      tx - turretR - 1, turretTopY,
      tx + turretR + 1, turretTopY,
      tx, turretTopY - 14
    )
    -- Crenellation ring
    for c = tx - turretR, tx + turretR - 2, 3 do
      love.graphics.setColor(
        (b.color[1] - 0.04) * ambientIntensity * 0.75,
        (b.color[2] - 0.03) * ambientIntensity * 0.75,
        b.color[3] * ambientIntensity * 0.8
      )
      love.graphics.rectangle("fill", c, turretTopY - 1, 2, 3)
    end
  end

  -- Steeply inclined roof with dormer skylights
  local roofPeakY = y - 20
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 1.05, b.roofColor[2] * ambientIntensity * 1.1, b.roofColor[3] * ambientIntensity * 1.05)
  love.graphics.polygon("fill",
    x - 4, y + 2,
    x + w + 4, y + 2,
    x + w/2, roofPeakY
  )
  -- Dormer skylights
  for dx = x + 6, x + w - 12, 14 do
    local dormerProg = (dx - x) / w
    local dormerY = y + 2 - (y + 2 - roofPeakY) * (0.3 + 0.1 * math.sin(dormerProg * 6))
    love.graphics.setColor(b.roofColor[1] * ambientIntensity * 0.85, b.roofColor[2] * ambientIntensity * 0.9, b.roofColor[3] * ambientIntensity * 0.85)
    love.graphics.polygon("fill", dx, dormerY + 6, dx + 8, dormerY + 6, dx + 4, dormerY)
    love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.18 * ambientIntensity)
    love.graphics.rectangle("fill", dx + 2, dormerY + 2, 4, 4)
    if lighting.lampsOn() then
      love.graphics.setColor(0.20, 0.65, 0.90, 0.4)
      love.graphics.rectangle("fill", dx + 2, dormerY + 2, 4, 4)
    end
  end

  -- Saint George slaying dragon sculpture above entrance
  local sgX = x + w/2
  local sgY = y + 8
  -- Dragon body
  love.graphics.setColor(0.18 * ambientIntensity, 0.40 * ambientIntensity, 0.25 * ambientIntensity, 0.7)
  love.graphics.ellipse("fill", sgX - 4, sgY + 2, 5, 3)
  -- Saint George with lance
  love.graphics.setColor(0.50 * ambientIntensity, 0.40 * ambientIntensity, 0.25 * ambientIntensity, 0.7)
  love.graphics.ellipse("fill", sgX + 4, sgY, 3, 4)
  -- Lance
  love.graphics.setColor(tc[1] * ambientIntensity * 0.8, tc[2] * ambientIntensity * 0.8, tc[3] * ambientIntensity * 0.9)
  love.graphics.line(sgX + 4, sgY - 3, sgX - 6, sgY + 3)

  -- Gothic windows
  for wx = x + 6, x + w - 14, 16 do
    love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.rectangle("fill", wx, y + 18, 8, 14)
    love.graphics.polygon("fill", wx, y + 18, wx + 8, y + 18, wx + 4, y + 12)
    if lighting.lampsOn() then
      love.graphics.setColor(0.20, 0.65, 0.90, 0.5)
      love.graphics.rectangle("fill", wx + 1, y + 19, 6, 12)
    end
  end

  -- Moat around foundation
  love.graphics.setColor(0.06 * ambientIntensity, 0.14 * ambientIntensity, 0.30 * ambientIntensity, 0.4)
  love.graphics.rectangle("fill", x - 8, y + h, w + 16, 3, 1, 1)

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, roofPeakY, ambientIntensity)
end

-- ═══ WINDMILL: Bellesguard — square medieval tower, 4-arm cross, Catalan flag mosaic ═══
-- Gaudí's medieval homage: square-base tower (unusual straight lines for Gaudí),
-- 4-arm cross with red/yellow Catalan senyera mosaic, stained-glass 8-pointed star,
-- dragon gargoyle on terrace, crenellated parapet
function M.drawWindmill(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Square tower body (straight lines — unusual for Gaudí, medieval tribute)
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.88, b.color[2] * ambientIntensity * 0.90, b.color[3] * ambientIntensity * 0.95)
  love.graphics.rectangle("fill", x + 2, y, w - 4, h)

  -- Stone coursework on tower
  for sy = y + 2, y + h - 2, 5 do
    local row = math.floor((sy - y) / 5)
    local offset = (row % 2 == 0) and 0 or 4
    for sx = x + 3 + offset, x + w - 5, 9 do
      love.graphics.setColor(
        b.color[1] * ambientIntensity * (0.82 + math.sin(sx + sy * 1.3) * 0.08),
        b.color[2] * ambientIntensity * (0.84 + math.sin(sx * 1.1 + sy) * 0.06),
        b.color[3] * ambientIntensity * 0.9
      )
      love.graphics.rectangle("fill", sx, sy, 8, 4)
    end
  end

  -- Crenellated parapet at top
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.75, b.color[2] * ambientIntensity * 0.78, b.color[3] * ambientIntensity * 0.85)
  for cx = x + 2, x + w - 6, 6 do
    love.graphics.rectangle("fill", cx, y - 4, 4, 6)
  end

  -- Tall conical spire rising from center
  local spirePeakY = y - 45
  local towerCX = x + w/2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.polygon("fill",
    x - 2, y,
    x + w + 2, y,
    towerCX, spirePeakY
  )

  -- 4-arm Gaudí cross at apex with Catalan flag colors
  local crossY = spirePeakY - 2
  -- Vertical arm
  love.graphics.setColor(0.55 * ambientIntensity, 0.15 * ambientIntensity, 0.15 * ambientIntensity)
  love.graphics.rectangle("fill", towerCX - 1.5, crossY - 10, 3, 12)
  -- Horizontal arm
  love.graphics.rectangle("fill", towerCX - 5, crossY - 5, 10, 2)
  -- Red and yellow Catalan senyera mosaic on cross
  love.graphics.setColor(0.65 * ambientIntensity, 0.50 * ambientIntensity, 0.10 * ambientIntensity, 0.8)
  love.graphics.rectangle("fill", towerCX - 1, crossY - 8, 2, 3)
  love.graphics.rectangle("fill", towerCX - 1, crossY - 3, 2, 3)

  -- 8-pointed Star of Venus stained glass window
  local starCX = towerCX
  local starCY = y + 14
  love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
  love.graphics.circle("fill", starCX, starCY, 7)
  if lighting.lampsOn() then
    love.graphics.setColor(0.25, 0.70, 0.90, 0.6)
    love.graphics.circle("fill", starCX, starCY, 6)
  end
  -- 8-pointed star rays
  love.graphics.setColor(0.20 * ambientIntensity, 0.65 * ambientIntensity, 0.85 * ambientIntensity, 0.7)
  for si = 0, 7 do
    local sa = si * math.pi / 4
    love.graphics.line(starCX, starCY, starCX + math.cos(sa) * 7, starCY + math.sin(sa) * 7)
  end

  -- Dragon gargoyle on terrace edge
  local dragX = x + w + 2
  local dragY = y + 4
  love.graphics.setColor(0.15 * ambientIntensity, 0.42 * ambientIntensity, 0.30 * ambientIntensity, 0.7)
  love.graphics.ellipse("fill", dragX + 3, dragY, 4, 2.5)
  -- Dragon head
  love.graphics.polygon("fill", dragX + 6, dragY - 1, dragX + 10, dragY - 2, dragX + 8, dragY + 1)

  -- Signal blades (windmill function — energy collector)
  local bladeX = towerCX
  local bladeY = spirePeakY + 8
  local bladeLen = 30
  local rotation = gameState.animationTime * 0.8 * environment.getWindStrength()
  for i = 0, 3 do
    local angle = rotation + i * math.pi / 2
    local bx2 = bladeX + math.cos(angle) * bladeLen
    local by2 = bladeY + math.sin(angle) * bladeLen
    love.graphics.setColor(0.15 * ambientIntensity, 0.45 * ambientIntensity, 0.65 * ambientIntensity, 0.5)
    local perpX = -math.sin(angle) * 5
    local perpY = math.cos(angle) * 5
    love.graphics.polygon("fill",
      bladeX, bladeY, bx2, by2,
      bx2 + perpX, by2 + perpY,
      bladeX + perpX * 0.2, bladeY + perpY * 0.2
    )
  end
  love.graphics.setColor(0.12 * ambientIntensity, 0.40 * ambientIntensity, 0.60 * ambientIntensity)
  love.graphics.circle("fill", bladeX, bladeY, 4)

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, spirePeakY - 12, ambientIntensity)
end

-- ═══ CASTLE: Hotel Attraction — monumental paraboloid tower, tallest/most dramatic shape ═══
-- Gaudí's unbuilt Manhattan skyscraper concept: massive central paraboloid hyperboloid
-- tower with stacked elliptical floors tapering upward, star-burst crown, observation galleries
function M.drawCastle(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Base structure (wide pedestal platform)
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.85, b.color[2] * ambientIntensity * 0.88, b.color[3] * ambientIntensity * 0.92)
  love.graphics.rectangle("fill", x - 4, y + h/2, w + 8, h/2)

  -- Central paraboloid tower (massive, tallest structure in the hub)
  local towerCX = x + w/2
  local towerPeakY = y - 75
  local towerBaseW = w * 0.8
  -- Draw tower as stack of tapering elliptical floors
  for flr = 0, 18 do
    local t = flr / 18
    local floorY = y + h/2 - t * (y + h/2 - towerPeakY)
    -- Parabolic taper: wide at base, narrow at top
    local floorW = towerBaseW * (1 - t * t) * 0.5 + 4
    local shade = 0.80 + t * 0.20
    love.graphics.setColor(
      b.color[1] * ambientIntensity * shade,
      b.color[2] * ambientIntensity * shade * 1.02,
      b.color[3] * ambientIntensity * shade * 1.05
    )
    love.graphics.ellipse("fill", towerCX, floorY, floorW, 3)
    -- Floor ledge lines
    love.graphics.setColor(tc[1] * ambientIntensity * 0.5, tc[2] * ambientIntensity * 0.5, tc[3] * ambientIntensity * 0.6, 0.3)
    love.graphics.ellipse("line", towerCX, floorY, floorW, 3)
  end

  -- Central spine (structural core)
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.7, b.color[2] * ambientIntensity * 0.72, b.color[3] * ambientIntensity * 0.8)
  love.graphics.rectangle("fill", towerCX - 3, towerPeakY, 6, y + h/2 - towerPeakY)

  -- Star-burst crown at apex (Hotel Attraction's visionary crown)
  love.graphics.setColor(0.20 * ambientIntensity, 0.70 * ambientIntensity, 0.90 * ambientIntensity)
  for si = 0, 11 do
    local sa = si * math.pi / 6
    local sLen = 8 + (si % 2) * 5
    love.graphics.line(towerCX, towerPeakY, towerCX + math.cos(sa) * sLen, towerPeakY + math.sin(sa) * sLen)
  end
  love.graphics.circle("fill", towerCX, towerPeakY, 4)
  -- Glowing beacon
  love.graphics.setColor(0.25, 0.80, 0.95, 0.6)
  love.graphics.circle("fill", towerCX, towerPeakY, 3)
  love.graphics.setColor(0.15, 0.60, 0.85, 0.06)
  love.graphics.circle("fill", towerCX, towerPeakY, 25)

  -- Observation gallery rings (protruding balconies at intervals)
  for gi = 1, 3 do
    local gt = gi * 0.22
    local galleryY = y + h/2 - gt * (y + h/2 - towerPeakY)
    local galleryW = towerBaseW * (1 - gt * gt) * 0.5 + 8
    love.graphics.setColor(
      (b.color[1] + 0.03) * ambientIntensity * 0.85,
      (b.color[2] + 0.02) * ambientIntensity * 0.85,
      b.color[3] * ambientIntensity * 0.9
    )
    love.graphics.ellipse("fill", towerCX, galleryY, galleryW + 4, 2)
    -- Gallery windows
    for gw = -2, 2 do
      local gwX = towerCX + gw * (galleryW / 3)
      love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.20 * ambientIntensity)
      love.graphics.rectangle("fill", gwX - 2, galleryY - 5, 4, 5)
      if lighting.lampsOn() then
        love.graphics.setColor(0.20, 0.65, 0.90, 0.4)
        love.graphics.rectangle("fill", gwX - 1.5, galleryY - 4.5, 3, 4)
      end
    end
  end

  -- Grand entrance arch (hyperboloid-shaped portal)
  love.graphics.setColor(
    (b.color[1] - 0.03) * ambientIntensity * 0.8,
    (b.color[2] - 0.02) * ambientIntensity * 0.8,
    b.color[3] * ambientIntensity * 0.85
  )
  love.graphics.arc("fill", towerCX, y + h - 2, 12, math.pi, 0)

  -- Banner on spire
  local flagY = towerPeakY + 5
  local flagSway = math.sin(gameState.animationTime * 2.5) * 4
  love.graphics.setColor(0.08 * ambientIntensity, 0.30 * ambientIntensity, 0.55 * ambientIntensity)
  love.graphics.polygon("fill",
    towerCX + 4, flagY,
    towerCX + 14 + flagSway, flagY + 3,
    towerCX + 12 + flagSway, flagY + 8,
    towerCX + 4, flagY + 6
  )
  love.graphics.setColor(0.20 * ambientIntensity, 0.75 * ambientIntensity, 0.95 * ambientIntensity)
  love.graphics.circle("fill", towerCX + 9 + flagSway * 0.5, flagY + 4, 2)

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, towerPeakY + 15, ambientIntensity)
end

-- ═══ WAYFARER'S REST: Colònia Güell church — inclined basalt columns, catenary crypt vault ═══
-- Gaudí's masterwork crypt: tilted basalt columns at organic angles (like leaning trees),
-- inverted catenary arch vaults, stained glass petal windows, rough stone organic walls
function M.drawWayfarersRest(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Rough basalt stone walls (dark, irregular volcanic stone)
  for sy = y + 6, y + h - 2, 5 do
    for sx = x + 1, x + w - 3, 6 do
      local shade = 0.82 + math.sin(sx * 2.7 + sy * 1.9) * 0.12
      love.graphics.setColor(
        (b.color[1] - 0.04) * ambientIntensity * shade,
        (b.color[2] - 0.03) * ambientIntensity * shade,
        b.color[3] * ambientIntensity * shade
      )
      -- Irregular polygonal basalt shapes
      love.graphics.polygon("fill",
        sx + math.sin(sy) * 0.5, sy,
        sx + 5, sy + math.cos(sx) * 0.3,
        sx + 5.5, sy + 4,
        sx - 0.5, sy + 4
      )
    end
  end

  -- Inclined basalt columns (leaning at organic angles — Gaudí's structural innovation)
  local columnAngles = {-0.18, -0.08, 0.05, 0.12, -0.14}
  for ci, angle in ipairs(columnAngles) do
    local colBaseX = x + 2 + (ci - 1) * (w / 5)
    local colTopX = colBaseX + math.sin(angle) * 30
    local colTopY = y - 5
    love.graphics.setColor(
      (b.color[1] - 0.06) * ambientIntensity * 0.75,
      (b.color[2] - 0.04) * ambientIntensity * 0.75,
      b.color[3] * ambientIntensity * 0.8
    )
    love.graphics.setLineWidth(3)
    love.graphics.line(colBaseX + 2, y + h - 2, colTopX + 2, colTopY)
    love.graphics.setLineWidth(1)
    -- Column capital (rough stone)
    love.graphics.setColor(
      (b.color[1] - 0.04) * ambientIntensity * 0.8,
      (b.color[2] - 0.03) * ambientIntensity * 0.8,
      b.color[3] * ambientIntensity * 0.85
    )
    love.graphics.circle("fill", colTopX + 2, colTopY, 3)
  end

  -- Catenary arch crypt vault (inverted hanging chain curves for roof)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  local vaultPts = {}
  for vx = x - 6, x + w + 6, 2 do
    -- Catenary curve: a * cosh((x-c)/a) inverted
    local t = (vx - x) / w - 0.5
    local catenary = -12 * (math.exp(t * 2) + math.exp(-t * 2)) / 2 + 18
    table.insert(vaultPts, vx)
    table.insert(vaultPts, y - 4 + catenary)
  end
  table.insert(vaultPts, x + w + 6)
  table.insert(vaultPts, y + 4)
  table.insert(vaultPts, x - 6)
  table.insert(vaultPts, y + 4)
  if #vaultPts >= 6 then
    love.graphics.polygon("fill", vaultPts)
  end

  -- Vault rib structure (organic branching)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.6, tc[2] * ambientIntensity * 0.6, tc[3] * ambientIntensity * 0.7, 0.4)
  for ri = 1, 4 do
    local ribX = x + ri * w / 5
    local ribT = (ribX - x) / w - 0.5
    local ribY = y - 4 + (-12 * (math.exp(ribT * 2) + math.exp(-ribT * 2)) / 2 + 18)
    love.graphics.line(ribX, y + 4, ribX, ribY)
  end

  -- Stained glass petal windows (flower-shaped, organic Gaudí)
  for wx = x + 8, x + w - 14, 16 do
    local winCX = wx + 5
    local winCY = y + 20
    -- Center
    love.graphics.setColor(0.05 * ambientIntensity, 0.08 * ambientIntensity, 0.18 * ambientIntensity)
    love.graphics.circle("fill", winCX, winCY, 6)
    if lighting.lampsOn() then
      -- Petal-shaped colored glass segments
      for p = 0, 4 do
        local pAngle = p * math.pi * 2 / 5
        local petalColors = {
          {0.85, 0.35, 0.20}, {0.25, 0.75, 0.40}, {0.30, 0.50, 0.90},
          {0.80, 0.65, 0.15}, {0.65, 0.25, 0.80}
        }
        love.graphics.setColor(petalColors[p+1][1], petalColors[p+1][2], petalColors[p+1][3], 0.5)
        love.graphics.ellipse("fill", winCX + math.cos(pAngle) * 3, winCY + math.sin(pAngle) * 3, 2.5, 1.5, pAngle)
      end
      love.graphics.setColor(0.80, 0.70, 0.40, 0.05)
      love.graphics.circle("fill", winCX, winCY, 18)
    end
    -- Organic stone frame
    love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity, 0.5)
    love.graphics.circle("line", winCX, winCY, 6)
  end

  -- Wanderer's lantern (hanging from inclined column)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.7, tc[2] * ambientIntensity * 0.7, tc[3] * ambientIntensity * 0.8)
  love.graphics.line(x + w - 2, y + 8, x + w + 6, y + 4)
  if lighting.lampsOn() then
    love.graphics.setColor(0.25, 0.75, 0.95, 0.4)
    love.graphics.circle("fill", x + w + 6, y + 7, 4)
    love.graphics.setColor(0.15, 0.55, 0.85, 0.06)
    love.graphics.circle("fill", x + w + 6, y + 7, 18)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, y - 4 + 18 - 14, ambientIntensity)
end

-- ═══ FISHERMAN HUT: Sagrada Família Schools — ruled-surface conoid roof & walls ═══
-- Gaudí's simple but revolutionary structure: undulating conoid (ruled-surface) roof
-- and walls made from straight lines forming curves, no load-bearing walls,
-- minimal but structurally ingenious form
function M.drawFishermanHut(b, x, y, w, h, ambientIntensity, tc)
  M.drawBuildingBase(b, x, y, w, h, ambientIntensity)

  -- Undulating conoid walls (ruled-surface: straight planks creating curved form)
  for sy = y + 4, y + h - 2, 3 do
    -- Each plank row is offset by a sine wave — the ruled-surface trick
    local waveOff = math.sin((sy - y) * 0.12) * 5
    local shade = 0.88 + math.cos(sy * 0.3) * 0.08
    love.graphics.setColor(
      (b.color[1] + 0.02) * ambientIntensity * shade,
      (b.color[2] + 0.01) * ambientIntensity * shade,
      b.color[3] * ambientIntensity * shade * 0.95
    )
    love.graphics.rectangle("fill", x + waveOff, sy, w - 1, 2.5)
  end
  -- Vertical ruled-surface lines (straight lines that define the curved surface)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.5, tc[2] * ambientIntensity * 0.5, tc[3] * ambientIntensity * 0.6, 0.25)
  for vx = x + 4, x + w - 4, 6 do
    love.graphics.line(vx, y + 4, vx + math.sin(y * 0.12) * 5, y + h - 2)
  end

  -- Undulating conoid roof (the signature: a sinusoidal ridge with perpendicular slope)
  local roofBaseY = y + 2
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 1.1, b.roofColor[2] * ambientIntensity * 1.15, b.roofColor[3] * ambientIntensity * 1.1)
  -- Build the roof as a polygon tracing the conoid wave
  local roofPts = {}
  for rx = x - 8, x + w + 8, 1.5 do
    -- Primary undulation (large wave) + secondary ripple
    local wave1 = math.sin((rx - x) * 0.10) * 8
    local wave2 = math.sin((rx - x) * 0.25) * 2
    table.insert(roofPts, rx)
    table.insert(roofPts, roofBaseY - 12 + wave1 + wave2)
  end
  table.insert(roofPts, x + w + 8)
  table.insert(roofPts, roofBaseY + 4)
  table.insert(roofPts, x - 8)
  table.insert(roofPts, roofBaseY + 4)
  if #roofPts >= 6 then
    love.graphics.polygon("fill", roofPts)
  end

  -- Roof ridge highlight (shows the ruled-surface curvature)
  love.graphics.setColor(b.roofColor[1] * ambientIntensity * 0.8, b.roofColor[2] * ambientIntensity * 0.85, b.roofColor[3] * ambientIntensity * 0.9, 0.5)
  for rx = x - 6, x + w + 6, 2 do
    local wave1 = math.sin((rx - x) * 0.10) * 8
    local wave2 = math.sin((rx - x) * 0.25) * 2
    love.graphics.circle("fill", rx, roofBaseY - 12 + wave1 + wave2, 0.8)
  end

  -- Ruled-surface structural ribs on roof (straight lines fanning to create curve)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.6, tc[2] * ambientIntensity * 0.6, tc[3] * ambientIntensity * 0.7, 0.3)
  for ri = 0, 6 do
    local ribBaseX = x + ri * (w / 6)
    local ribTopX = ribBaseX + 4
    local ribWave = math.sin((ribBaseX - x) * 0.10) * 8
    love.graphics.line(ribBaseX, roofBaseY + 3, ribTopX, roofBaseY - 12 + ribWave)
  end

  -- Simple rectangular windows (School building simplicity)
  for wx = x + 4, x + w - 12, 14 do
    local waveAdj = math.sin((wx - x) * 0.12) * 2
    love.graphics.setColor(0.05 * ambientIntensity, 0.10 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.rectangle("fill", wx + waveAdj, y + 12, 8, 10, 1, 1)
    if lighting.lampsOn() then
      love.graphics.setColor(0.20, 0.60, 0.85, 0.5)
      love.graphics.rectangle("fill", wx + waveAdj + 1, y + 13, 6, 8, 1, 1)
    end
    -- Simple cross mullion
    love.graphics.setColor(tc[1] * ambientIntensity, tc[2] * ambientIntensity, tc[3] * ambientIntensity, 0.4)
    love.graphics.line(wx + waveAdj + 4, y + 12, wx + waveAdj + 4, y + 22)
    love.graphics.line(wx + waveAdj, y + 17, wx + waveAdj + 8, y + 17)
  end

  -- Fishing net draped on wall (nautical character)
  love.graphics.setColor(tc[1] * ambientIntensity * 0.5, tc[2] * ambientIntensity * 0.5, tc[3] * ambientIntensity * 0.6, 0.3)
  for nx = x + w - 12, x + w - 2, 4 do
    for ny = y + 8, y + h - 6, 4 do
      love.graphics.line(nx, ny, nx + 3, ny + 3)
      love.graphics.line(nx + 3, ny, nx, ny + 3)
    end
  end

  -- Drying rack with data-fish
  love.graphics.setColor(tc[1] * ambientIntensity * 0.7, tc[2] * ambientIntensity * 0.7, tc[3] * ambientIntensity * 0.8)
  love.graphics.line(x - 5, y + 8, x - 5, y + h)
  love.graphics.line(x - 5, y + 8, x + 2, y + 6)
  for i = 0, 2 do
    local hangY = y + 10 + i * 6
    local sway = math.sin(gameState.animationTime * 1.5 + i) * 2
    love.graphics.setColor(0.15 * ambientIntensity, 0.45 * ambientIntensity, 0.65 * ambientIntensity, 0.5)
    love.graphics.line(x - 5, hangY, x - 5 + sway - 4, hangY + 3)
  end

  M.drawBuildingDoor(b, ambientIntensity)
  M.drawBuildingSign(b, x, y, w, roofBaseY - 20, ambientIntensity)
end

-- ═══════════════════════════════════════
-- DRAW: DECORATIONS
-- ═══════════════════════════════════════

function M.drawDecoration(deco)
  local x = deco.x * 32
  local y = deco.y * 32
  local _, ambientIntensity = lighting.getAmbientLight()

  if deco.type == "fountain" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    lighting.drawShadow(deco.x, deco.y, deco.w or 1, deco.h or 1, 32)

    -- Crystal basin (dark blue stone)
    love.graphics.setColor(0.12 * ambientIntensity, 0.18 * ambientIntensity, 0.38 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 4, w - 8, h - 8, 3, 3)
    -- Basin rim (neon edge)
    love.graphics.setColor(0.15 * ambientIntensity, 0.50 * ambientIntensity, 0.70 * ambientIntensity, 0.4)
    love.graphics.rectangle("line", x + 4, y + 4, w - 8, h - 8, 3, 3)
    -- Glowing water
    love.graphics.setColor(0.10, 0.35, 0.65, 0.7)
    love.graphics.rectangle("fill", x + 8, y + 8, w - 16, h - 16, 2, 2)
    -- Neon water sparkle
    local sparkle = math.sin(gameState.animationTime * 3) * 0.3 + 0.5
    love.graphics.setColor(0.25, 0.75, 0.95, sparkle * 0.6)
    love.graphics.circle("fill", x + w/2, y + h/2, 5)
    -- Neon glow halo on water
    love.graphics.setColor(0.15, 0.55, 0.85, sparkle * 0.15)
    love.graphics.circle("fill", x + w/2, y + h/2, 20)
    -- Spout (holographic beam)
    local sprayH = 14 + math.sin(gameState.animationTime * 4) * 5
    love.graphics.setColor(0.20, 0.70, 0.95, 0.7)
    love.graphics.circle("fill", x + w/2, y + h/2 - sprayH, 3.5)
    -- Spout beam line
    love.graphics.setColor(0.15, 0.55, 0.85, 0.3)
    love.graphics.line(x + w/2, y + h/2, x + w/2, y + h/2 - sprayH)
    -- Neon droplets
    for i = 1, 6 do
      local dropAngle = gameState.animationTime * 2.5 + i * math.pi / 3
      local dropR = 7 + math.sin(gameState.animationTime * 3 + i) * 3
      love.graphics.setColor(0.20, 0.65, 0.95, 0.5)
      love.graphics.circle("fill",
        x + w/2 + math.cos(dropAngle) * dropR,
        y + h/2 - sprayH + math.sin(dropAngle) * dropR + 3,
        2
      )
    end

  elseif deco.type == "well" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Crystal well base
    love.graphics.setColor(0.15 * ambientIntensity, 0.22 * ambientIntensity, 0.42 * ambientIntensity)
    love.graphics.circle("fill", x + 16, y + 20, 14)
    love.graphics.setColor(0.10 * ambientIntensity, 0.18 * ambientIntensity, 0.35 * ambientIntensity)
    love.graphics.circle("line", x + 16, y + 20, 14)
    -- Deep data-pool inside
    love.graphics.setColor(0.05, 0.10, 0.30, 0.8)
    love.graphics.circle("fill", x + 16, y + 20, 8)
    -- Frame posts
    love.graphics.setColor(0.12 * ambientIntensity, 0.18 * ambientIntensity, 0.35 * ambientIntensity)
    love.graphics.rectangle("fill", x + 6, y + 2, 3, 20)
    love.graphics.rectangle("fill", x + 23, y + 2, 3, 20)
    -- Canopy
    love.graphics.setColor(0.10 * ambientIntensity, 0.25 * ambientIntensity, 0.45 * ambientIntensity)
    love.graphics.polygon("fill", x + 3, y + 4, x + 29, y + 4, x + 16, y - 5)
    -- Cable and probe
    love.graphics.setColor(0.18 * ambientIntensity, 0.40 * ambientIntensity, 0.60 * ambientIntensity)
    love.graphics.line(x + 16, y + 3, x + 16, y + 12)

  elseif deco.type == "flowers" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    local color = deco.color or {1, 0.5, 0.5}
    local sway = environment.getWindSway(x, gameState.animationTime, 1.5)

    for fy = y, y + h - 6, 8 do
      for fx = x, x + w - 6, 8 do
        local flowerSway = sway + math.sin(fx * 0.12 + gameState.animationTime * 0.8) * 1.5
        -- Stem
        love.graphics.setColor(0.10 * ambientIntensity, 0.35 * ambientIntensity, 0.45 * ambientIntensity, 0.7)
        love.graphics.line(fx + 4, fy + 8, fx + 4 + flowerSway * 0.5, fy + 2)
        -- Flower head
        love.graphics.setColor(color[1] * ambientIntensity, color[2] * ambientIntensity, color[3] * ambientIntensity, 0.85)
        love.graphics.circle("fill", fx + 4 + flowerSway * 0.5, fy + 1, 3)
        -- Petal highlight
        love.graphics.setColor(1, 1, 1, 0.2 * ambientIntensity)
        love.graphics.circle("fill", fx + 3 + flowerSway * 0.5, fy, 1.5)
      end
    end

  elseif deco.type == "bench" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Crystal bench
    love.graphics.setColor(0.14 * ambientIntensity, 0.20 * ambientIntensity, 0.38 * ambientIntensity)
    love.graphics.rectangle("fill", x, y + 16, 32, 6, 1, 1)
    -- Legs
    love.graphics.setColor(0.10 * ambientIntensity, 0.16 * ambientIntensity, 0.32 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 22, 3, 10)
    love.graphics.rectangle("fill", x + 25, y + 22, 3, 10)
    -- Back rest
    love.graphics.rectangle("fill", x + 2, y + 8, 28, 3)
    love.graphics.rectangle("fill", x + 4, y + 8, 3, 8)
    love.graphics.rectangle("fill", x + 25, y + 8, 3, 8)

  elseif deco.type == "lantern" then
    -- Dark crystal post
    love.graphics.setColor(0.10 * ambientIntensity, 0.15 * ambientIntensity, 0.30 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y + 8, 4, 24)
    -- Decorative scroll at top
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", x + 16, y + 6, 4, math.pi, 0)
    love.graphics.setLineWidth(1)

    -- Lantern housing
    love.graphics.setColor(0.12 * ambientIntensity, 0.18 * ambientIntensity, 0.32 * ambientIntensity)
    love.graphics.rectangle("fill", x + 10, y, 12, 10)

    if lighting.lampsOn() then
      -- Neon lantern glow (bioluminescent data-light)
      love.graphics.setColor(0.10, 0.50, 0.80, 0.12)
      love.graphics.circle("fill", x + 16, y + 5, 55)
      love.graphics.setColor(0.15, 0.60, 0.90, 0.25)
      love.graphics.circle("fill", x + 16, y + 5, 30)
      love.graphics.setColor(0.25, 0.75, 0.95, 0.6)
      love.graphics.circle("fill", x + 16, y + 5, 12)
      -- Neon core
      love.graphics.setColor(0.40, 0.90, 1.0, 0.9)
      local flicker = math.sin(gameState.animationTime * 8 + x) * 1.5
      love.graphics.circle("fill", x + 16 + flicker * 0.3, y + 5, 4)
    else
      -- Daytime crystal
      love.graphics.setColor(0.25 * ambientIntensity, 0.45 * ambientIntensity, 0.65 * ambientIntensity, 0.4)
      love.graphics.circle("fill", x + 16, y + 5, 5)
    end

  elseif deco.type == "elven_urn" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Dark crystal urn with circuit trace motif
    love.graphics.setColor(0.14 * ambientIntensity, 0.20 * ambientIntensity, 0.40 * ambientIntensity)
    -- Body (elegant amphora shape)
    love.graphics.ellipse("fill", x + 16, y + 22, 10, 8)
    -- Neck
    love.graphics.setColor(0.12 * ambientIntensity, 0.18 * ambientIntensity, 0.38 * ambientIntensity)
    love.graphics.rectangle("fill", x + 12, y + 10, 8, 12)
    -- Lip
    love.graphics.ellipse("fill", x + 16, y + 10, 9, 3)
    -- Circuit trace inlay (neon cyan)
    love.graphics.setColor(0.15 * ambientIntensity, 0.60 * ambientIntensity, 0.80 * ambientIntensity, 0.6)
    love.graphics.arc("line", x + 16, y + 20, 7, 0, math.pi)
    love.graphics.arc("line", x + 16, y + 24, 7, math.pi, math.pi * 2)
    -- Neon filaments from top
    local sway = environment.getWindSway(x, gameState.animationTime, 1.5)
    love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.75 * ambientIntensity, 0.8)
    love.graphics.line(x + 16, y + 8, x + 12 + sway, y + 2)
    love.graphics.line(x + 16, y + 8, x + 20 + sway, y + 3)
    love.graphics.circle("fill", x + 12 + sway, y + 2, 2)
    love.graphics.circle("fill", x + 20 + sway, y + 3, 2)

  elseif deco.type == "elven_pedestal" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Dark crystal pedestal with pulsing data-orb
    love.graphics.setColor(0.12 * ambientIntensity, 0.18 * ambientIntensity, 0.38 * ambientIntensity)
    -- Base (wide)
    love.graphics.rectangle("fill", x + 6, y + 24, 20, 6, 1, 1)
    -- Column (narrow, tapered)
    love.graphics.polygon("fill", x + 10, y + 24, x + 22, y + 24, x + 20, y + 10, x + 12, y + 10)
    -- Capital (flared top)
    love.graphics.setColor(0.14 * ambientIntensity, 0.20 * ambientIntensity, 0.40 * ambientIntensity)
    love.graphics.rectangle("fill", x + 8, y + 8, 16, 4, 1, 1)
    -- Neon data-orb on top
    local pulse = math.sin(gameState.animationTime * 2 + x * 0.1) * 0.15 + 0.85
    love.graphics.setColor(0.15 * pulse * ambientIntensity, 0.60 * pulse * ambientIntensity, 0.85 * pulse * ambientIntensity, 0.8)
    love.graphics.circle("fill", x + 16, y + 5, 5)
    -- Orb glow
    love.graphics.setColor(0.15, 0.55, 0.85, 0.12 * pulse)
    love.graphics.circle("fill", x + 16, y + 5, 18)
    -- Highlight sparkle
    love.graphics.setColor(0.50, 0.90, 1.0, 0.4 * pulse)
    love.graphics.circle("fill", x + 14, y + 3, 1.5)

  elseif deco.type == "elven_statue" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Cartographer figure statue (dark blue-crystal)
    love.graphics.setColor(0.18 * ambientIntensity, 0.25 * ambientIntensity, 0.45 * ambientIntensity)
    -- Plinth
    love.graphics.rectangle("fill", x + 6, y + 26, 20, 4, 1, 1)
    -- Body (flowing robes)
    love.graphics.polygon("fill",
      x + 12, y + 26, x + 20, y + 26,
      x + 18, y + 14, x + 14, y + 14
    )
    -- Torso
    love.graphics.setColor(0.20 * ambientIntensity, 0.28 * ambientIntensity, 0.48 * ambientIntensity)
    love.graphics.rectangle("fill", x + 13, y + 10, 6, 6)
    -- Head
    love.graphics.circle("fill", x + 16, y + 8, 3.5)
    -- Raised arm holding star
    love.graphics.setColor(0.16 * ambientIntensity, 0.22 * ambientIntensity, 0.42 * ambientIntensity)
    love.graphics.line(x + 18, y + 12, x + 22, y + 6)
    -- Neon star-map in hand
    local twinkle = math.sin(gameState.animationTime * 3 + x) * 0.3 + 0.7
    love.graphics.setColor(0.20 * twinkle, 0.70 * twinkle, 0.95 * twinkle, 0.9)
    love.graphics.circle("fill", x + 22, y + 5, 2)
    love.graphics.setColor(0.15, 0.60, 0.90, 0.15 * twinkle)
    love.graphics.circle("fill", x + 22, y + 5, 10)

  elseif deco.type == "elven_pillar" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Data column with circuit trace inscription bands
    love.graphics.setColor(0.14 * ambientIntensity, 0.20 * ambientIntensity, 0.40 * ambientIntensity)
    -- Column shaft
    love.graphics.rectangle("fill", x + 11, y + 6, 10, 24, 2, 2)
    -- Base
    love.graphics.setColor(0.10 * ambientIntensity, 0.16 * ambientIntensity, 0.35 * ambientIntensity)
    love.graphics.rectangle("fill", x + 8, y + 28, 16, 3, 1, 1)
    -- Crystal capital
    love.graphics.setColor(0.16 * ambientIntensity, 0.22 * ambientIntensity, 0.42 * ambientIntensity)
    love.graphics.polygon("fill", x + 8, y + 6, x + 24, y + 6, x + 21, y + 2, x + 11, y + 2)
    -- Neon circuit bands (cyan inlay)
    love.graphics.setColor(0.15 * ambientIntensity, 0.55 * ambientIntensity, 0.75 * ambientIntensity, 0.5)
    love.graphics.rectangle("fill", x + 12, y + 12, 8, 2)
    love.graphics.rectangle("fill", x + 12, y + 18, 8, 2)
    love.graphics.rectangle("fill", x + 12, y + 24, 8, 2)
    -- Small data-dots in bands
    love.graphics.setColor(0.20 * ambientIntensity, 0.65 * ambientIntensity, 0.85 * ambientIntensity, 0.3)
    for i = 0, 3 do
      love.graphics.circle("fill", x + 13 + i * 2, y + 13, 0.5)
      love.graphics.circle("fill", x + 14 + i * 2, y + 19, 0.5)
    end

  elseif deco.type == "stepping_stone" then
    love.graphics.setColor(0.14 * ambientIntensity, 0.20 * ambientIntensity, 0.38 * ambientIntensity, 0.7)
    love.graphics.ellipse("fill", x + 16, y + 16, 10, 6)
  end
end

-- ═══════════════════════════════════════
-- DRAW: INTERIOR (Data hall — crystal floors, arched walls)
-- ═══════════════════════════════════════

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Dark crystal floor (deep blue with faint circuit veining)
  for fy = 0, interior.height - 1 do
    for fx = 0, interior.width - 1 do
      local shade = 0.97 + math.sin(fx * 2.3 + fy * 3.1) * 0.03
      love.graphics.setColor(0.10 * shade, 0.14 * shade, 0.30 * shade)
      love.graphics.rectangle("fill", fx * 32, fy * 32, 32, 32)
      -- Subtle circuit veining
      love.graphics.setColor(0.12 * shade, 0.35 * shade, 0.55 * shade, 0.12)
      love.graphics.line(fx * 32 + 3, fy * 32 + 16, fx * 32 + 29, fy * 32 + 14)
    end
  end

  -- Data-crystal walls (deep indigo with arched motifs)
  love.graphics.setColor(0.12, 0.18, 0.35)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
  love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

  -- Wall arch motifs along top
  for wx = 1, interior.width - 2 do
    love.graphics.setColor(0.15, 0.40, 0.60, 0.4)
    love.graphics.arc("line", wx * 32 + 16, 32, 14, math.pi, 0)
  end

  -- Neon trim lines at wall base
  love.graphics.setColor(0.15, 0.55, 0.75, 0.15)
  love.graphics.line(32, (interior.height - 1) * 32, (interior.width - 1) * 32, (interior.height - 1) * 32)
  love.graphics.line(32, 32, (interior.width - 1) * 32, 32)

  -- Soft ambient glow (neon data-light feel)
  love.graphics.setColor(0.10, 0.40, 0.65, 0.04)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

  -- Exit doorway (arched)
  love.graphics.setColor(0.10, 0.16, 0.32)
  love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)
  love.graphics.setColor(0.14, 0.22, 0.40)
  love.graphics.arc("fill", interior.exitX * 32 + 16, interior.exitY * 32, 16, math.pi, 0)

  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local px = portal.x * 32
      local py = portal.y * 32
      local pulse = math.sin(gameState.animationTime * 3) * 0.2 + 0.8
      love.graphics.setColor(portal.color[1] * pulse, portal.color[2] * pulse, portal.color[3] * pulse)
      love.graphics.circle("fill", px + 16, py + 16, 20)
      -- Glow halo
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.15)
      love.graphics.circle("fill", px + 16, py + 16, 35)
      love.graphics.setColor(1, 1, 1)
      local font = love.graphics.getFont()
      local textW = font:getWidth(portal.name)
      love.graphics.print(portal.name, px + 16 - textW/2, py + 40)
    end
  end

  -- Interior name (data label)
  love.graphics.setColor(0.40, 0.75, 0.90)
  love.graphics.print(interior.name, 40, 40)
end

-- ═══════════════════════════════════════
-- DRAW: UI (minimal HUD)
-- ═══════════════════════════════════════

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Zone name display (parchment style)
  local zoneName, zone = areas.getZoneAt(gameState.player.gridX, gameState.player.gridY)
  if gameState.location == "outdoors" and zone then
    -- Holographic banner
    love.graphics.setColor(0.04, 0.07, 0.18, 0.6)
    love.graphics.rectangle("fill", 10, 10, 220, 30, 4, 4)
    love.graphics.setColor(0.12, 0.50, 0.72, 0.5)
    love.graphics.rectangle("line", 10, 10, 220, 30, 4, 4)
    love.graphics.setColor(0.65, 0.88, 0.95)
    love.graphics.print(zone.name, 20, 17)
  elseif gameState.location == "interior" then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.setColor(0.04, 0.07, 0.18, 0.6)
      love.graphics.rectangle("fill", 10, 10, 260, 30, 4, 4)
      love.graphics.setColor(0.12, 0.50, 0.72, 0.5)
      love.graphics.rectangle("line", 10, 10, 260, 30, 4, 4)
      love.graphics.setColor(0.65, 0.88, 0.95)
      love.graphics.print(interior.name, 20, 17)
    end
  end

  -- Currency display (data-wallet style)
  love.graphics.setColor(0.04, 0.07, 0.18, 0.6)
  love.graphics.rectangle("fill", screenW - 170, 10, 160, 30, 4, 4)
  love.graphics.setColor(0.12, 0.50, 0.72, 0.5)
  love.graphics.rectangle("line", screenW - 170, 10, 160, 30, 4, 4)
  love.graphics.setColor(0.30, 0.80, 0.95)
  love.graphics.print("Notes: " .. gameState.notes, screenW - 160, 17)

  -- Time of day display
  if gameState.location == "outdoors" then
    love.graphics.setColor(0.04, 0.07, 0.18, 0.6)
    love.graphics.rectangle("fill", screenW - 110, 45, 100, 25, 4, 4)
    love.graphics.setColor(0.12, 0.50, 0.72, 0.5)
    love.graphics.rectangle("line", screenW - 110, 45, 100, 25, 4, 4)
    love.graphics.setColor(0.65, 0.88, 0.95)
    love.graphics.print(lighting.getTimeString(), screenW - 100, 50)
  end

  -- Interaction prompts (ornate style)
  if gameState.nearbyPortal then
    love.graphics.setColor(0.04, 0.06, 0.16, 0.75)
    love.graphics.rectangle("fill", screenW/2 - 110, screenH - 60, 220, 40, 6, 6)
    love.graphics.setColor(0.12, 0.50, 0.72, 0.6)
    love.graphics.rectangle("line", screenW/2 - 110, screenH - 60, 220, 40, 6, 6)
    love.graphics.setColor(0.65, 0.88, 0.95)
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW/2 - 110, screenH - 50, 220, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0.04, 0.06, 0.16, 0.75)
    love.graphics.rectangle("fill", screenW/2 - 110, screenH - 60, 220, 40, 6, 6)
    love.graphics.setColor(0.12, 0.50, 0.72, 0.6)
    love.graphics.rectangle("line", screenW/2 - 110, screenH - 60, 220, 40, 6, 6)
    love.graphics.setColor(0.65, 0.88, 0.95)
    love.graphics.printf("Press E to speak with " .. gameState.nearbyNPC.name, screenW/2 - 110, screenH - 50, 220, "center")
  end

  -- Dialogue box (parchment scroll style)
  if gameState.dialogueBox then
    -- Data-terminal background
    love.graphics.setColor(0.04, 0.06, 0.16, 0.88)
    love.graphics.rectangle("fill", 50, screenH - 155, screenW - 100, 125, 8, 8)
    -- Neon border
    love.graphics.setColor(0.12, 0.50, 0.72, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 50, screenH - 155, screenW - 100, 125, 8, 8)
    -- Inner border
    love.graphics.setColor(0.10, 0.40, 0.60, 0.4)
    love.graphics.rectangle("line", 54, screenH - 151, screenW - 108, 117, 6, 6)
    love.graphics.setLineWidth(1)
    -- Speaker name
    love.graphics.setColor(0.30, 0.80, 0.95)
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 143)
    -- Dialogue text
    love.graphics.setColor(0.65, 0.85, 0.92)
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 118, screenW - 140, "left")
    -- Dismiss hint
    love.graphics.setColor(0.35, 0.60, 0.75)
    love.graphics.print("Press E to close", 70, screenH - 50)
  end

  -- Edge hint
  if gameState.location == "outdoors" then
    local nearEdge = gameState.player.gridX <= 1 or gameState.player.gridX >= areas.WIDTH - 2 or
                     gameState.player.gridY <= 1 or gameState.player.gridY >= areas.HEIGHT - 2
    if nearEdge then
      love.graphics.setColor(0.04, 0.06, 0.16, 0.7)
      love.graphics.rectangle("fill", screenW/2 - 120, 50, 240, 30, 5, 5)
      love.graphics.setColor(0.65, 0.88, 0.95)
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

-- cereus/init.lua
-- Desert botanical garden hub world — Cereus
-- Inspired by Arizona's Boyce Thompson Arboretum (est. 1924)
-- Outdoor exploration with saguaros, canyons, Ayer Lake, and mountain vistas

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local areas = require("cereus.areas")
local buildings = require("cereus.buildings")
local lighting = require("cereus.lighting")
local environment = require("cereus.environment")

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

  -- Player starts at Visitor Center entrance
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

  -- Shared currency with main hub
  gameState.credits = 1000000
  gameState.notes = currency.load()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false}
  gameState.paused = false
  gameState.animationTime = 0

  -- Setup outdoor NPCs
  M.setupOutdoorNPCs()

  audio.load()
  pauseMenu.load()

  -- Initialize desert lighting and environment
  lighting.init()
  environment.init()

  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 1.0,
      callback = nil,
      color = {1, 1, 1}  -- White fade (bright desert light)
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

  -- Store door position for exit
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}

  -- Position player at exit (they entered from outside)
  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * 32 + 16
  gameState.player.y = gameState.player.gridY * 32 + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y

  gameState.collisionMap = buildings.createInteriorCollisionMap(buildingId)
  gameState.currentPortals = interior.portals

  -- Setup interior NPCs
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

  -- Regenerate desert wildlife when re-entering outdoors
  environment.regenerateWildlife()

  -- Return to outdoor position
  if gameState.returnPosition then
    gameState.player.gridX = gameState.returnPosition.gridX
    gameState.player.gridY = gameState.returnPosition.gridY + 1
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.returnPosition = nil
  else
    -- Fallback: find building door
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

  -- Update desert dynamic systems
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

  -- Update cooldowns
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

    -- Check building exit
    if gameState.interiorId then
      if buildings.isAtExit(gameState.player.gridX, gameState.player.gridY, gameState.interiorId) then
        M.exitBuilding()
      end
    end
  end

  -- Check nearby NPCs (both outdoors and indoors)
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
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  if gameState.location == "outdoors" then
    -- Draw desert sky gradient
    environment.drawSky(screenW, screenH)

    -- Draw sun (tracks across sky east→west, with glow and animated rays)
    environment.drawSun(screenW, screenH, gameState.animationTime)

    -- Draw distant mountain layers (parallax background)
    environment.drawDistantMountains(screenW, screenH, gameState.camera.x, gameState.camera.y)

    -- Draw clouds (with parallax, before main world)
    environment.drawClouds(gameState.camera.x, gameState.camera.y, gameState.animationTime)
  end

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

  -- Apply ambient lighting overlay
  if gameState.location == "outdoors" then
    lighting.applyAmbientOverlay(screenW, screenH)
  end

  -- Draw UI overlay
  M.drawUI()

  -- Draw pause menu
  if gameState.paused then
    pauseMenu.draw()
  end

  -- Draw transition fade
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
-- DRAW OUTDOORS
-- ═══════════════════════════════════════

function M.drawOutdoors()
  local gs = 32
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  -- Draw zones (ground tiles) with HD-2D layered desert textures
  for name, zone in pairs(areas.zones) do
    if zone.groundColor and not zone.isWater then
      M.drawGroundZone(name, zone, gs, ambientIntensity)
    end
  end

  -- Draw Ayer Lake (water body)
  environment.drawAyerLake(gs, gameState.animationTime, areas.zones.ayer_lake)

  -- Draw wildflower ground cover (before trails so they peek through)
  environment.drawWildflowers(gs, gameState.animationTime)

  -- Draw trail paths (packed earth walkways)
  M.drawTrails(gs, ambientIntensity)

  -- Draw mountain ranges (in-world)
  for _, mtn in ipairs(areas.mountains) do
    environment.drawMountain(mtn, gs, gameState.animationTime)
  end

  -- Draw building shadows first (behind buildings)
  for _, b in ipairs(areas.buildings) do
    lighting.drawShadow(b.x, b.y, b.w, b.h, gs)
  end

  -- Draw Berber Suspension Bridge
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "suspension_bridge" then
      environment.drawSuspensionBridge(deco.x, deco.y, gs, deco.w, gameState.animationTime)
    end
  end

  -- Draw non-tree, non-bridge decorations
  for _, deco in ipairs(areas.decorations) do
    if deco.type ~= "saguaro" and deco.type ~= "barrel_cactus" and
       deco.type ~= "prickly_pear" and deco.type ~= "ocotillo" and
       deco.type ~= "desert_tree" and deco.type ~= "eucalyptus" and
       deco.type ~= "boojum" and deco.type ~= "suspension_bridge" and
       deco.type ~= "cattails" then
      M.drawDecoration(deco)
    end
  end

  -- Draw buildings
  for _, b in ipairs(areas.buildings) do
    M.drawBuilding(b)
  end

  -- Draw desert flora shadows
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "saguaro" then
      lighting.drawSaguaroShadow(deco.x, deco.y, gs, deco.arms, deco.height)
    elseif deco.type == "desert_tree" then
      lighting.drawDesertTreeShadow(deco.x, deco.y, gs)
    elseif deco.type == "eucalyptus" then
      lighting.drawEucalyptusShadow(deco.x, deco.y, gs)
    elseif deco.type == "fancy_tree" then
      lighting.drawFancyTreeShadow(deco.x, deco.y, gs, deco.species)
    end
  end

  -- Draw desert flora (trees, cacti)
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "saguaro" then
      environment.drawSaguaro(deco.x, deco.y, gs, gameState.animationTime, deco.arms, deco.height)
    elseif deco.type == "barrel_cactus" then
      environment.drawBarrelCactus(deco.x, deco.y, gs, gameState.animationTime)
    elseif deco.type == "prickly_pear" then
      environment.drawPricklyPear(deco.x, deco.y, gs, gameState.animationTime, deco.w, deco.h)
    elseif deco.type == "ocotillo" then
      environment.drawOcotillo(deco.x, deco.y, gs, gameState.animationTime)
    elseif deco.type == "desert_tree" then
      environment.drawDesertTree(deco.x, deco.y, gs, gameState.animationTime, deco.variety)
    elseif deco.type == "eucalyptus" then
      environment.drawEucalyptus(deco.x, deco.y, gs, gameState.animationTime)
    elseif deco.type == "boojum" then
      environment.drawBoojum(deco.x, deco.y, gs, gameState.animationTime)
    elseif deco.type == "cattails" then
      environment.drawCattails(deco.x, deco.y, gs, gameState.animationTime)
    elseif deco.type == "fancy_tree" then
      environment.drawFancyTree(deco.x, deco.y, gs, gameState.animationTime, deco.species)
    end
  end

  -- Draw agave and yucca
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "agave" then
      environment.drawAgave(deco.x, deco.y, gs, gameState.animationTime)
    elseif deco.type == "yucca" then
      environment.drawYucca(deco.x, deco.y, gs, gameState.animationTime)
    end
  end

  -- Draw desert wildlife (roadrunners, lizards)
  environment.drawRoadrunners()
  environment.drawLizards()

  -- Draw coatimundi troop (foraging with tails up!)
  environment.drawCoatimundis()

  -- Draw shade dappling under tree canopies
  environment.drawShadeDapple(gs, gameState.animationTime, areas.decorations)

  -- Draw floating pollen motes / cottonwood fluff / dust sparkles
  environment.drawPollenMotes(gameState.animationTime)

  -- Draw falling leaves (from eucalyptus & palo verde)
  environment.drawFallingLeaves(gameState.animationTime)

  -- Draw butterflies (painted ladies, monarchs, swallowtails...)
  environment.drawButterflies()

  -- Draw hummingbirds (Costa's & Anna's at flowers)
  environment.drawHummingbirds()

  -- Draw heat shimmer effect (midday desert mirage)
  environment.drawHeatShimmer(gs, gameState.animationTime, gameState.camera.x, gameState.camera.y)

  -- Draw dust devils
  environment.drawDustDevils(gameState.animationTime)

  -- Draw fireflies (dusk & nighttime bioluminescence)
  environment.drawFireflies(gameState.animationTime)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HD-2D DESERT GROUND RENDERING (per-tile layered textures, Octopath-style)
-- Each tile gets: base color → shade variation → texture layer → scatter
-- ═══════════════════════════════════════════════════════════════════════════

function M.drawGroundZone(zoneName, zone, gs, ambientIntensity)
  local r = zone.groundColor[1]
  local g = zone.groundColor[2]
  local b = zone.groundColor[3]
  local time = gameState.animationTime

  for ty = zone.y1, zone.y2 do
    for tx = zone.x1, zone.x2 do
      local px = tx * gs
      local py = ty * gs

      -- ═══ DETERMINISTIC PER-TILE HASH (no randomness, stable across frames) ═══
      local hash = ((tx * 73 + ty * 137 + tx * ty * 31) % 256) / 256
      local hash2 = ((tx * 127 + ty * 89 + tx * 17) % 256) / 256
      local hash3 = ((tx * 199 + ty * 43 + ty * ty * 7) % 256) / 256

      -- ═══ LAYER 1: BASE TILE with shade variation ═══
      local shade = 0.92 + hash * 0.16  -- 0.92–1.08 range
      local tileR = r * shade * ambientIntensity
      local tileG = g * shade * ambientIntensity
      local tileB = b * shade * ambientIntensity
      love.graphics.setColor(tileR, tileG, tileB)
      love.graphics.rectangle("fill", px, py, gs, gs)

      -- ═══ LAYER 2: TILE EDGE JOINTS (subtle grout lines between tiles) ═══
      local jointAlpha = 0.06 + hash2 * 0.04
      love.graphics.setColor(r * 0.6 * ambientIntensity, g * 0.55 * ambientIntensity, b * 0.5 * ambientIntensity, jointAlpha)
      love.graphics.rectangle("line", px + 0.5, py + 0.5, gs - 1, gs - 1)

      -- ═══ LAYER 3: ZONE-SPECIFIC TEXTURE ═══
      if zoneName == "visitor_center" then
        -- Flagstone pavement — cut stone tiles with mortar
        local stoneShade = 0.95 + math.sin(tx * 4.3 + ty * 3.7) * 0.05
        love.graphics.setColor(
          r * stoneShade * ambientIntensity * 1.02,
          g * stoneShade * ambientIntensity * 1.01,
          b * stoneShade * ambientIntensity * 0.98
        )
        love.graphics.rectangle("fill", px + 1, py + 1, gs - 2, gs - 2, 1, 1)
        -- Mortar joints (warm gray)
        love.graphics.setColor(0.55 * ambientIntensity, 0.50 * ambientIntensity, 0.42 * ambientIntensity, 0.12)
        love.graphics.rectangle("line", px + 1, py + 1, gs - 2, gs - 2, 1, 1)
        -- Wear marks on high-traffic stones
        if hash > 0.7 then
          love.graphics.setColor(tileR * 0.90, tileG * 0.88, tileB * 0.85, 0.15)
          love.graphics.ellipse("fill", px + gs / 2, py + gs / 2, 8 + hash2 * 4, 5 + hash3 * 3)
        end

      elseif zoneName == "eucalyptus_forest" then
        -- Leaf litter floor (dark with scattered bark and leaves)
        -- Bark chip scatter
        local numChips = 3
        for i = 1, numChips do
          local ci = ((tx * 41 + ty * 67 + i * 29) % 256) / 256
          local cx = px + ci * (gs - 6) + 3
          local cy = py + ((tx * 53 + ty * 97 + i * 43) % 256) / 256 * (gs - 6) + 3
          -- Orange/tan peeling bark
          love.graphics.setColor(0.62 * ambientIntensity, 0.48 * ambientIntensity, 0.30 * ambientIntensity, 0.2 + ci * 0.15)
          love.graphics.ellipse("fill", cx, cy, 3 + ci * 2, 1.5 + ci)
        end
        -- Fallen sickle-leaves
        if hash > 0.3 then
          local lx = px + hash2 * 20 + 6
          local ly = py + hash3 * 20 + 6
          love.graphics.setColor(0.38 * ambientIntensity, 0.45 * ambientIntensity, 0.28 * ambientIntensity, 0.25)
          love.graphics.push()
          love.graphics.translate(lx, ly)
          love.graphics.rotate(hash * math.pi * 2)
          love.graphics.ellipse("fill", 0, 0, 1.5, 5)
          love.graphics.pop()
        end
        -- Dappled shade (darker patches under canopy)
        love.graphics.setColor(0, 0, 0, 0.04 + hash * 0.04)
        love.graphics.ellipse("fill", px + gs / 2 + hash2 * 6 - 3, py + gs / 2 + hash3 * 6 - 3, 10 + hash * 5, 8 + hash2 * 4)

      elseif zoneName == "queen_creek" then
        -- Rocky canyon floor — exposed bedrock, gravel, dry wash stones
        -- Exposed rock strata (angled lines)
        if hash > 0.4 then
          love.graphics.setColor(r * 0.75 * ambientIntensity, g * 0.70 * ambientIntensity, b * 0.65 * ambientIntensity, 0.18)
          local strataY = py + hash2 * gs
          love.graphics.setLineWidth(1.5)
          love.graphics.line(px, strataY, px + gs, strataY + (hash3 - 0.5) * 6)
          love.graphics.setLineWidth(1)
        end
        -- Embedded river stones (smooth, rounded, from water action)
        if hash2 > 0.5 then
          local stoneColor = 0.50 + hash3 * 0.15
          love.graphics.setColor(stoneColor * ambientIntensity, (stoneColor - 0.05) * ambientIntensity, (stoneColor - 0.12) * ambientIntensity, 0.3)
          love.graphics.ellipse("fill", px + hash * 24 + 4, py + hash3 * 24 + 4, 4 + hash2 * 3, 3 + hash * 2)
          -- Stone highlight
          love.graphics.setColor(stoneColor * 1.15 * ambientIntensity, (stoneColor + 0.05) * ambientIntensity, (stoneColor - 0.05) * ambientIntensity, 0.12)
          love.graphics.ellipse("fill", px + hash * 24 + 3, py + hash3 * 24 + 2, 3 + hash2 * 2, 2 + hash)
        end
        -- Dry wash gravel bands
        if math.sin(ty * 0.8 + tx * 0.2) > 0.3 then
          love.graphics.setColor(0.60 * ambientIntensity, 0.52 * ambientIntensity, 0.42 * ambientIntensity, 0.08)
          love.graphics.rectangle("fill", px, py + gs / 3, gs, gs / 3)
        end

      elseif zoneName == "cactus_garden" then
        -- Red Sonoran Desert earth — iron-rich soil with caliche patches
        -- Iron oxide stain patches (reddish)
        if hash > 0.3 then
          love.graphics.setColor(0.75 * ambientIntensity, 0.45 * ambientIntensity, 0.25 * ambientIntensity, 0.08 + hash2 * 0.06)
          love.graphics.ellipse("fill", px + hash2 * 20 + 6, py + hash3 * 20 + 6, 8 + hash * 5, 6 + hash2 * 4)
        end
        -- Caliche (calcium carbonate crust — white/pale patches)
        if hash2 > 0.75 then
          love.graphics.setColor(0.88 * ambientIntensity, 0.85 * ambientIntensity, 0.78 * ambientIntensity, 0.10)
          love.graphics.ellipse("fill", px + hash3 * 18 + 7, py + hash * 18 + 7, 6 + hash2 * 4, 4 + hash3 * 3)
        end
        -- Cracked earth (radiating crack lines)
        if hash3 > 0.5 then
          love.graphics.setColor(r * 0.65 * ambientIntensity, g * 0.60 * ambientIntensity, b * 0.55 * ambientIntensity, 0.10)
          local crackX = px + gs / 2 + (hash - 0.5) * 10
          local crackY = py + gs / 2 + (hash2 - 0.5) * 10
          love.graphics.setLineWidth(0.8)
          for ci = 1, 4 do
            local ca = ((ci + tx + ty * 3) % 6) / 6 * math.pi * 2
            local cl = 5 + hash * 6
            love.graphics.line(crackX, crackY, crackX + math.cos(ca) * cl, crackY + math.sin(ca) * cl)
          end
          love.graphics.setLineWidth(1)
        end

      elseif zoneName == "wallace_garden" or zoneName == "south_american" then
        -- Cultivated arid garden beds — decomposed granite mulch
        -- DG granules (tiny uniform particles)
        local numGranules = 5
        for i = 1, numGranules do
          local gi = ((tx * 59 + ty * 83 + i * 37) % 256) / 256
          local gx = px + gi * (gs - 4) + 2
          local gy = py + ((tx * 71 + ty * 109 + i * 53) % 256) / 256 * (gs - 4) + 2
          local gShade = 0.72 + gi * 0.18
          love.graphics.setColor(gShade * ambientIntensity, (gShade - 0.08) * ambientIntensity, (gShade - 0.18) * ambientIntensity, 0.18)
          love.graphics.circle("fill", gx, gy, 1 + gi * 1.2)
        end
        -- Decorative bed borders (subtle raised edges where plants are)
        if hash > 0.8 then
          love.graphics.setColor(0.55 * ambientIntensity, 0.48 * ambientIntensity, 0.38 * ambientIntensity, 0.10)
          love.graphics.rectangle("fill", px + 2, py + 2, gs - 4, 2)
        end

      elseif zoneName == "main_loop" then
        -- Sandy desert soil — the largest zone, varied terrain
        -- Sand ripple patterns (wind-sculpted micro-dunes)
        if hash > 0.25 then
          local rippleAlpha = 0.04 + hash2 * 0.04
          love.graphics.setColor(r * 1.06 * ambientIntensity, g * 1.04 * ambientIntensity, b * 0.98 * ambientIntensity, rippleAlpha)
          local rippleAngle = math.sin(tx * 0.5 + ty * 0.3) * 0.3  -- wind direction
          love.graphics.push()
          love.graphics.translate(px + gs / 2, py + gs / 2)
          love.graphics.rotate(rippleAngle)
          for ri = -2, 2 do
            love.graphics.ellipse("fill", ri * 6, 0, 4, 1.5 + math.abs(ri) * 0.3)
          end
          love.graphics.pop()
        end
        -- Embedded pebbles (various sizes, warm tones)
        if hash2 > 0.55 then
          local pebbleShade = 0.50 + hash3 * 0.25
          love.graphics.setColor(pebbleShade * ambientIntensity, (pebbleShade - 0.05) * ambientIntensity, (pebbleShade - 0.15) * ambientIntensity, 0.22)
          love.graphics.ellipse("fill", px + hash * 22 + 5, py + hash3 * 22 + 5, 2.5 + hash2 * 2, 2 + hash * 1.5)
        end
        -- Scattered mica flakes (glinting in sun)
        if hash3 > 0.85 and ambientIntensity > 0.5 then
          local micaGlint = math.sin(time * 3 + tx * 2.7 + ty * 1.9)
          if micaGlint > 0.4 then
            love.graphics.setColor(1, 0.98, 0.88, (micaGlint - 0.4) * 0.3 * ambientIntensity)
            love.graphics.circle("fill", px + hash * 28 + 2, py + hash2 * 28 + 2, 1)
          end
        end
        -- Cracked earth patches (dry desert surface)
        if hash > 0.65 then
          love.graphics.setColor(r * 0.70 * ambientIntensity, g * 0.65 * ambientIntensity, b * 0.58 * ambientIntensity, 0.07)
          local crackX = px + hash2 * 16 + 8
          local crackY = py + hash3 * 16 + 8
          love.graphics.setLineWidth(0.6)
          for ci = 1, 3 do
            local ca = ((ci * 73 + tx * 11 + ty * 23) % 360) / 360 * math.pi * 2
            local cl = 4 + hash * 5
            love.graphics.line(crackX, crackY, crackX + math.cos(ca) * cl, crackY + math.sin(ca) * cl)
          end
          love.graphics.setLineWidth(1)
        end

      elseif zoneName == "picketpost" or zoneName == "east_mountains" or zoneName == "west_cliffs" then
        -- Volcanic/igneous rock — dark, angular, fractured
        -- Angular rock slab texture
        local slabShade = 0.88 + hash * 0.24
        love.graphics.setColor(r * slabShade * ambientIntensity, g * slabShade * ambientIntensity, b * slabShade * ambientIntensity)
        love.graphics.rectangle("fill", px + 1, py + 1, gs - 2, gs - 2)
        -- Fracture lines (sharp, angular)
        if hash > 0.3 then
          love.graphics.setColor(r * 0.5 * ambientIntensity, g * 0.45 * ambientIntensity, b * 0.4 * ambientIntensity, 0.12)
          love.graphics.setLineWidth(0.8)
          local fx = px + hash2 * gs
          local fy = py + hash3 * gs
          love.graphics.line(fx, fy, fx + (hash - 0.5) * 18, fy + (hash2 - 0.5) * 18)
          -- Branch fracture
          if hash3 > 0.5 then
            love.graphics.line(fx + (hash - 0.5) * 9, fy + (hash2 - 0.5) * 9,
              fx + (hash - 0.5) * 9 + (hash3 - 0.5) * 12, fy + (hash2 - 0.5) * 9 + (hash - 0.5) * 10)
          end
          love.graphics.setLineWidth(1)
        end
        -- Mineral vein (rare, reddish-copper glint)
        if hash2 > 0.9 then
          love.graphics.setColor(0.65 * ambientIntensity, 0.35 * ambientIntensity, 0.22 * ambientIntensity, 0.12)
          love.graphics.setLineWidth(1.2)
          love.graphics.line(px + hash * 20 + 6, py + 2, px + hash3 * 20 + 6, py + gs - 2)
          love.graphics.setLineWidth(1)
        end

      elseif zoneName == "south_foothills" then
        -- Transition zone — sandy to rocky, scattered larger stones
        -- Larger embedded desert rocks
        if hash > 0.4 then
          local rockShade = 0.55 + hash2 * 0.20
          love.graphics.setColor(rockShade * ambientIntensity, (rockShade - 0.06) * ambientIntensity, (rockShade - 0.14) * ambientIntensity, 0.20)
          love.graphics.ellipse("fill", px + hash * 18 + 7, py + hash3 * 18 + 7, 4 + hash2 * 4, 3 + hash * 3)
          -- Rock highlight
          love.graphics.setColor((rockShade + 0.12) * ambientIntensity, (rockShade + 0.06) * ambientIntensity, (rockShade - 0.04) * ambientIntensity, 0.08)
          love.graphics.ellipse("fill", px + hash * 18 + 5, py + hash3 * 18 + 5, 3 + hash2 * 2, 2 + hash)
        end
        -- Sparse bunch-grass tufts
        if hash2 > 0.65 then
          local gx2 = px + hash3 * 22 + 5
          local gy2 = py + hash * 20 + 8
          love.graphics.setColor(0.50 * ambientIntensity, 0.52 * ambientIntensity, 0.32 * ambientIntensity, 0.20)
          for bi = 1, 4 do
            local ba = ((bi * 50 + tx * 13) % 360) / 360 * math.pi * 2
            local bl = 3 + hash * 3
            love.graphics.line(gx2, gy2, gx2 + math.cos(ba) * bl, gy2 - bl)
          end
        end
      end

      -- ═══ LAYER 4: UNIVERSAL SCATTER (all desert zones) ═══
      -- Small gravel particles (2-4 per tile, deterministic positions)
      local numGravel = 2 + math.floor(hash * 2.5)
      for gi = 1, numGravel do
        local gHash = ((tx * 37 + ty * 91 + gi * 67) % 256) / 256
        local gHash2 = ((tx * 53 + ty * 113 + gi * 43) % 256) / 256
        local gx3 = px + gHash * (gs - 4) + 2
        local gy3 = py + gHash2 * (gs - 4) + 2
        local gravelShade = 0.55 + gHash * 0.25
        love.graphics.setColor(
          gravelShade * ambientIntensity,
          (gravelShade - 0.04) * ambientIntensity,
          (gravelShade - 0.12) * ambientIntensity,
          0.12 + gHash2 * 0.08
        )
        love.graphics.circle("fill", gx3, gy3, 0.8 + gHash * 1.2)
      end

      -- ═══ LAYER 5: SUBTLE DEPTH SHADOW (bottom-right corner shading per tile) ═══
      love.graphics.setColor(0, 0, 0, 0.015 + hash * 0.01)
      love.graphics.rectangle("fill", px + gs - 3, py + gs - 3, 3, 3)
    end
  end
end

-- ═══════════════════════════════════════
-- TRAIL RENDERING (packed desert earth paths)
-- ═══════════════════════════════════════

function M.drawTrails(gs, ambientIntensity)
  for _, trail in ipairs(areas.trails) do
    for si, seg in ipairs(trail.segments) do
      local x = seg.x1 * gs
      local y = seg.y1 * gs
      local w = (seg.x2 - seg.x1 + 1) * gs
      local h = (seg.y2 - seg.y1 + 1) * gs
      local segSeed = seg.x1 * 73 + seg.y1 * 137 + si * 31

      -- Packed earth trail base (darker compacted dirt)
      love.graphics.setColor(0.58 * ambientIntensity, 0.48 * ambientIntensity, 0.35 * ambientIntensity, 0.55)
      love.graphics.rectangle("fill", x, y, w, h)

      -- Worn center rut (even darker, well-trodden earth)
      love.graphics.setColor(0.50 * ambientIntensity, 0.40 * ambientIntensity, 0.30 * ambientIntensity, 0.35)
      if w > h then
        love.graphics.rectangle("fill", x + 4, y + h / 2 - 6, w - 8, 12)
      else
        love.graphics.rectangle("fill", x + w / 2 - 6, y + 4, 12, h - 8)
      end

      -- Trail edge border (compacted edges — slightly visible)
      love.graphics.setColor(0.48 * ambientIntensity, 0.38 * ambientIntensity, 0.28 * ambientIntensity, 0.3)
      love.graphics.setLineWidth(1.5)
      love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4)
      love.graphics.setLineWidth(1)

      -- ═══ SMALL BORDER STONES along path edges (deterministic) ═══
      local stoneCount = math.floor(math.max(w, h) / 14)
      for i = 1, stoneCount do
        local hash1 = ((segSeed + i * 71) % 256) / 256
        local hash2 = ((segSeed + i * 43 + 99) % 256) / 256
        local hash3 = ((segSeed + i * 113 + 57) % 256) / 256
        local stoneSize = 2.5 + hash3 * 2.5
        local shade = 0.52 + hash2 * 0.12

        love.graphics.setColor(shade * ambientIntensity, (shade - 0.06) * ambientIntensity, (shade - 0.14) * ambientIntensity, 0.65)

        if w > h then
          -- Horizontal path: stones along top and bottom edges
          local sx = x + 6 + hash1 * (w - 12)
          love.graphics.ellipse("fill", sx, y + 3, stoneSize, stoneSize * 0.65)
          -- Mirror on bottom edge
          local hash4 = ((segSeed + i * 89 + 33) % 256) / 256
          if hash4 > 0.35 then
            love.graphics.ellipse("fill", sx + 4, y + h - 3, stoneSize * 0.9, stoneSize * 0.6)
          end
        else
          -- Vertical path: stones along left and right edges
          local sy = y + 6 + hash1 * (h - 12)
          love.graphics.ellipse("fill", x + 3, sy, stoneSize * 0.65, stoneSize)
          local hash4 = ((segSeed + i * 89 + 33) % 256) / 256
          if hash4 > 0.35 then
            love.graphics.ellipse("fill", x + w - 3, sy + 4, stoneSize * 0.6, stoneSize * 0.9)
          end
        end
      end

      -- ═══ SCATTERED GRAVEL on path surface (deterministic) ═══
      for i = 1, 12 do
        local hash1 = ((segSeed + i * 53 + 7) % 256) / 256
        local hash2 = ((segSeed + i * 97 + 19) % 256) / 256
        local hash3 = ((segSeed + i * 37 + 41) % 256) / 256
        local gx = x + 6 + hash1 * (w - 12)
        local gy = y + 6 + hash2 * (h - 12)
        love.graphics.setColor(0.55 * ambientIntensity, 0.47 * ambientIntensity, 0.36 * ambientIntensity, 0.3)
        love.graphics.circle("fill", gx, gy, 1 + hash3 * 1.5)
      end

      -- ═══ FLAT STONES embedded in path (deterministic) ═══
      for i = 1, 3 do
        local hash1 = ((segSeed + i * 67 + 200) % 256) / 256
        local hash2 = ((segSeed + i * 109 + 150) % 256) / 256
        local hash3 = ((segSeed + i * 83 + 77) % 256) / 256
        local hash4 = ((segSeed + i * 47 + 130) % 256) / 256
        local sx = x + 10 + hash1 * (w - 20)
        local sy = y + 10 + hash2 * (h - 20)
        love.graphics.setColor(0.54 * ambientIntensity, 0.48 * ambientIntensity, 0.40 * ambientIntensity, 0.2)
        love.graphics.ellipse("fill", sx, sy, 4 + hash3 * 3, 3 + hash4 * 2)
      end

      -- ═══ TRAIL-EDGE WILDFLOWERS (deterministic positions) ═══
      local time = gameState.animationTime
      for i = 1, 6 do
        local side = (i % 2 == 0) and -1 or 1
        local hash1 = ((segSeed + i * 61 + 300) % 256) / 256
        local fx, fy
        if w > h then
          fx = x + 8 + hash1 * (w - 16)
          fy = (side > 0) and (y + 1) or (y + h - 3)
        else
          fx = (side > 0) and (x + 1) or (x + w - 3)
          fy = y + 8 + hash1 * (h - 16)
        end
        local sway = math.sin(time * 1.5 + fx * 0.1 + i) * 1.5

        -- Tiny stem
        love.graphics.setColor(0.25 * ambientIntensity, 0.42 * ambientIntensity, 0.18 * ambientIntensity, 0.6)
        love.graphics.line(fx, fy + 4, fx + sway * 0.3, fy)

        -- Tiny bloom
        local colorIndex = (i + math.floor(fx * 0.1)) % 3
        if colorIndex == 0 then
          love.graphics.setColor(0.95 * ambientIntensity, 0.78 * ambientIntensity, 0.12 * ambientIntensity, 0.7)
        elseif colorIndex == 1 then
          love.graphics.setColor(0.88 * ambientIntensity, 0.42 * ambientIntensity, 0.12 * ambientIntensity, 0.7)
        else
          love.graphics.setColor(0.50 * ambientIntensity, 0.22 * ambientIntensity, 0.60 * ambientIntensity, 0.7)
        end
        love.graphics.circle("fill", fx + sway * 0.3, fy - 1, 1.5)
      end
    end
  end
end

-- ═══════════════════════════════════════
-- BUILDING RENDERING (Arizona architecture styles)
-- ═══════════════════════════════════════

function M.drawBuilding(b)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local style = b.style or "adobe"

  -- ═══ BUILDING BODY ═══
  love.graphics.setColor(b.color[1] * ambientIntensity, b.color[2] * ambientIntensity, b.color[3] * ambientIntensity)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Texture varies by style
  if style == "historic_stone" or style == "stone" then
    -- Rough-cut stone texture (Smith Building, Bridge House)
    for sx = x + 2, x + w - 6, 12 do
      for sy = y + 16, y + h - 4, 10 do
        local shade = 0.92 + math.sin(sx * 2.3 + sy * 3.1) * 0.08
        love.graphics.setColor(
          (b.color[1] * shade - 0.02) * ambientIntensity,
          (b.color[2] * shade - 0.03) * ambientIntensity,
          (b.color[3] * shade - 0.02) * ambientIntensity
        )
        local stoneW = 10 + math.sin(sx * 0.7 + sy) * 2
        local stoneH = 8 + math.sin(sx + sy * 0.5) * 2
        love.graphics.rectangle("fill", sx, sy, stoneW, stoneH, 1, 1)
        -- Mortar lines
        love.graphics.setColor(b.color[1] * 0.6 * ambientIntensity, b.color[2] * 0.6 * ambientIntensity, b.color[3] * 0.6 * ambientIntensity, 0.4)
        love.graphics.rectangle("line", sx, sy, stoneW, stoneH, 1, 1)
      end
    end
  elseif style == "adobe" then
    -- Smooth stucco with subtle variation
    for sx = x + 2, x + w - 2, 8 do
      for sy = y + 16, y + h - 2, 8 do
        local speckle = math.sin(sx * 3.1 + sy * 2.7) * 0.02
        love.graphics.setColor(
          (b.color[1] + speckle) * ambientIntensity,
          (b.color[2] + speckle) * ambientIntensity,
          (b.color[3] + speckle) * ambientIntensity
        )
        love.graphics.rectangle("fill", sx, sy, 6, 6)
      end
    end
  elseif style == "greenhouse" then
    -- Glass panels
    for gx = x + 4, x + w - 8, 16 do
      love.graphics.setColor(0.55 * ambientIntensity, 0.75 * ambientIntensity, 0.60 * ambientIntensity, 0.4)
      love.graphics.rectangle("fill", gx, y + 8, 14, h - 12)
      -- Glass frame
      love.graphics.setColor(0.40 * ambientIntensity, 0.55 * ambientIntensity, 0.40 * ambientIntensity)
      love.graphics.rectangle("line", gx, y + 8, 14, h - 12)
      -- Horizontal mullion
      love.graphics.line(gx, y + h / 2, gx + 14, y + h / 2)
    end
  end

  -- Side shading for depth
  love.graphics.setColor(b.color[1] * ambientIntensity * 0.7, b.color[2] * ambientIntensity * 0.7, b.color[3] * ambientIntensity * 0.7)
  love.graphics.rectangle("fill", x + w - 5, y + 4, 5, h - 4)

  -- ═══ ROOF ═══
  love.graphics.setColor(b.roofColor[1] * ambientIntensity, b.roofColor[2] * ambientIntensity, b.roofColor[3] * ambientIntensity)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, 18)

  if style == "castle" then
    -- Crenellations (Picket Post House — "Castle on the Rock")
    for cx = x - 2, x + w, 10 do
      love.graphics.setColor(b.roofColor[1] * 0.85 * ambientIntensity, b.roofColor[2] * 0.85 * ambientIntensity, b.roofColor[3] * 0.85 * ambientIntensity)
      love.graphics.rectangle("fill", cx, y - 8, 6, 6)
    end
  elseif style == "greenhouse" then
    -- Peaked glass roof
    love.graphics.setColor(0.50 * ambientIntensity, 0.68 * ambientIntensity, 0.52 * ambientIntensity)
    love.graphics.polygon("fill", x - 2, y + 2, x + w / 2, y - 10, x + w + 2, y + 2)
  else
    -- Terracotta tile pattern (traditional AZ/Southwest)
    for tx = x - 2, x + w, 8 do
      love.graphics.setColor(
        b.roofColor[1] * ambientIntensity * 1.1,
        b.roofColor[2] * ambientIntensity * 0.9,
        b.roofColor[3] * ambientIntensity * 0.8
      )
      love.graphics.arc("fill", tx + 4, y + 2, 5, math.pi, 0)
      love.graphics.setColor(
        b.roofColor[1] * ambientIntensity * 0.9,
        b.roofColor[2] * ambientIntensity * 0.8,
        b.roofColor[3] * ambientIntensity * 0.7
      )
      love.graphics.arc("fill", tx + 8, y + 8, 5, math.pi, 0)
    end
  end

  -- Roof edge shadow
  love.graphics.setColor(0, 0, 0, 0.15 * ambientIntensity)
  love.graphics.rectangle("fill", x - 2, y + 14, w + 4, 3)

  -- ═══ DOOR ═══
  local doorX = b.doorX * 32 + 4
  local doorY = b.doorY * 32 - 24
  local doorW = 24
  local doorH = 24

  -- Arched doorway (Southwest style)
  love.graphics.setColor(0.35 * ambientIntensity, 0.22 * ambientIntensity, 0.12 * ambientIntensity)
  love.graphics.rectangle("fill", doorX, doorY + 8, doorW, doorH - 8)
  love.graphics.arc("fill", doorX + doorW / 2, doorY + 8, doorW / 2, math.pi, 0)
  -- Door frame
  love.graphics.setColor(0.28 * ambientIntensity, 0.18 * ambientIntensity, 0.10 * ambientIntensity)
  love.graphics.setLineWidth(2)
  love.graphics.arc("line", doorX + doorW / 2, doorY + 8, doorW / 2, math.pi, 0)
  love.graphics.line(doorX, doorY + 8, doorX, doorY + doorH)
  love.graphics.line(doorX + doorW, doorY + 8, doorX + doorW, doorY + doorH)
  love.graphics.setLineWidth(1)

  -- Door handle
  love.graphics.setColor(0.75, 0.70, 0.35, ambientIntensity)
  love.graphics.circle("fill", doorX + doorW - 4, doorY + doorH / 2, 2)

  -- ═══ WINDOWS ═══
  local windowY = y + 24
  for wx = x + 8, x + w - 24, 24 do
    -- Window glass
    love.graphics.setColor(0.55 * ambientIntensity, 0.72 * ambientIntensity, 0.85 * ambientIntensity)
    love.graphics.rectangle("fill", wx, windowY, 16, 12)
    -- Frame
    love.graphics.setColor(0.35 * ambientIntensity, 0.30 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", wx, windowY, 16, 12)
    love.graphics.line(wx + 8, windowY, wx + 8, windowY + 12)
    love.graphics.setLineWidth(1)
    -- Window sill
    love.graphics.setColor(0.60 * ambientIntensity, 0.55 * ambientIntensity, 0.48 * ambientIntensity)
    love.graphics.rectangle("fill", wx - 2, windowY + 12, 20, 3)
    -- Day reflection
    if not lighting.isNight() then
      love.graphics.setColor(1, 1, 0.95, 0.25 * ambientIntensity)
      love.graphics.rectangle("fill", wx + 2, windowY + 1, 5, 3)
    end
  end

  -- ═══ BUILDING NAME SIGN ═══
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  local signX = x + w / 2 - textW / 2 - 6
  local signY = y - 22

  -- Sign board (rustic wood for desert aesthetic)
  love.graphics.setColor(0.22, 0.16, 0.10, 0.8)
  love.graphics.rectangle("fill", signX, signY, textW + 12, 18, 3, 3)
  love.graphics.setColor(0.45 * ambientIntensity, 0.38 * ambientIntensity, 0.28 * ambientIntensity)
  love.graphics.rectangle("line", signX, signY, textW + 12, 18, 3, 3)

  -- Sign text
  love.graphics.setColor(0.95 * ambientIntensity, 0.92 * ambientIntensity, 0.82 * ambientIntensity)
  love.graphics.print(b.name, signX + 6, signY + 2)

  -- Year marker for historic buildings
  if b.year then
    local yearStr = tostring(b.year)
    local yearW = font:getWidth(yearStr)
    love.graphics.setColor(0.80 * ambientIntensity, 0.75 * ambientIntensity, 0.60 * ambientIntensity, 0.7)
    love.graphics.print(yearStr, x + w / 2 - yearW / 2, y + h - 14)
  end
end

-- ═══════════════════════════════════════
-- DECORATION RENDERING
-- ═══════════════════════════════════════

function M.drawDecoration(deco)
  local x = deco.x * 32
  local y = deco.y * 32
  local _, ambientIntensity = lighting.getAmbientLight()

  if deco.type == "bench" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    -- Rustic wooden bench
    love.graphics.setColor(0.50 * ambientIntensity, 0.38 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.rectangle("fill", x, y + 16, 32, 8)
    love.graphics.rectangle("fill", x + 4, y + 24, 4, 8)
    love.graphics.rectangle("fill", x + 24, y + 24, 4, 8)
    -- Back support
    love.graphics.setColor(0.45 * ambientIntensity, 0.35 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.rectangle("fill", x + 2, y + 8, 28, 3)

  elseif deco.type == "trail_sign" then
    environment.drawTrailSign(deco.x, deco.y, 32, deco.text)

  elseif deco.type == "lamp" then
    -- Desert lamp post (wrought iron style)
    love.graphics.setColor(0.30 * ambientIntensity, 0.28 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y + 8, 4, 24)
    -- Cross arm
    love.graphics.rectangle("fill", x + 8, y + 6, 16, 3)

    if lighting.lampsOn() then
      -- Warm amber desert glow
      love.graphics.setColor(1, 0.85, 0.5, 0.25)
      love.graphics.circle("fill", x + 16, y + 4, 35)
      love.graphics.setColor(1, 0.90, 0.6, 0.55)
      love.graphics.circle("fill", x + 16, y + 4, 18)
      love.graphics.setColor(1, 0.95, 0.8, 0.85)
      love.graphics.circle("fill", x + 16, y + 4, 7)
    else
      love.graphics.setColor(0.8 * ambientIntensity, 0.78 * ambientIntensity, 0.72 * ambientIntensity, 0.5)
      love.graphics.circle("fill", x + 16, y + 4, 6)
    end

  elseif deco.type == "boulder" then
    environment.drawBoulder(deco.x, deco.y, 32, deco.size)

  elseif deco.type == "creek" then
    -- Queen Creek Wash (seasonal stream bed)
    local x1 = deco.x * 32
    local y1 = deco.y * 32
    local x2 = deco.x2 * 32
    local creekW = x2 - x1
    love.graphics.setColor(0.35 * ambientIntensity, 0.50 * ambientIntensity, 0.55 * ambientIntensity, 0.5)
    love.graphics.rectangle("fill", x1, y1, creekW, 32)
    -- Creek stones (deterministic positioning)
    local creekSeed = deco.x * 73 + deco.y * 137
    for i = 1, 12 do
      local h1 = ((creekSeed + i * 53) % 256) / 256
      local h2 = ((creekSeed + i * 97) % 256) / 256
      local h3 = ((creekSeed + i * 37) % 256) / 256
      local cx = x1 + h1 * creekW
      local cy = y1 + 4 + h2 * 24
      love.graphics.setColor(0.50 * ambientIntensity, 0.45 * ambientIntensity, 0.38 * ambientIntensity, 0.4)
      love.graphics.circle("fill", cx, cy, 3 + h3 * 3)
    end

  elseif deco.type == "ramada" then
    environment.drawRamada(deco.x, deco.y, 32)

  elseif deco.type == "fountain" then
    environment.drawDrinkingFountain(deco.x, deco.y, 32, gameState.animationTime)

  elseif deco.type == "interp_sign" then
    environment.drawInterpretiveSign(deco.x, deco.y, 32, deco.text)

  elseif deco.type == "flower_bed" then
    -- Cultivated flower display bed (raised stone border with blooms)
    local fbx = deco.x * 32
    local fby = deco.y * 32
    -- Stone border
    love.graphics.setColor(0.55 * ambientIntensity, 0.50 * ambientIntensity, 0.42 * ambientIntensity)
    love.graphics.rectangle("line", fbx, fby, 32, 32, 3, 3)
    -- Rich soil
    love.graphics.setColor(0.42 * ambientIntensity, 0.32 * ambientIntensity, 0.22 * ambientIntensity, 0.5)
    love.graphics.rectangle("fill", fbx + 2, fby + 2, 28, 28, 2, 2)
    -- Flowers (color by species)
    local fr, fg, fb
    if deco.species == "poppy" then fr, fg, fb = 0.95, 0.72, 0.10
    elseif deco.species == "penstemon" then fr, fg, fb = 0.85, 0.12, 0.18
    elseif deco.species == "globe_mallow" then fr, fg, fb = 0.92, 0.45, 0.12
    elseif deco.species == "lupine" then fr, fg, fb = 0.45, 0.20, 0.65
    elseif deco.species == "brittlebush" then fr, fg, fb = 0.95, 0.88, 0.20
    else fr, fg, fb = 0.90, 0.75, 0.15
    end
    local fbSeed = deco.x * 71 + deco.y * 113
    for i = 1, 6 do
      local fh1 = ((fbSeed + i * 47) % 256) / 256
      local fh2 = ((fbSeed + i * 83) % 256) / 256
      local fh3 = ((fbSeed + i * 61) % 256) / 256
      local fx2 = fbx + 5 + fh1 * 22
      local fy2 = fby + 5 + fh2 * 22
      love.graphics.setColor(fr * ambientIntensity, fg * ambientIntensity, fb * ambientIntensity)
      love.graphics.circle("fill", fx2, fy2, 2.5 + fh3 * 1.5)
    end

  elseif deco.type == "stepping_stones" then
    -- Decorative stepping stones across path intersections
    local ssx = deco.x * 32
    local ssy = deco.y * 32
    love.graphics.setColor(0.58 * ambientIntensity, 0.52 * ambientIntensity, 0.45 * ambientIntensity)
    if deco.direction == "horizontal" then
      for i = 0, 3 do
        love.graphics.ellipse("fill", ssx + 4 + i * 8, ssy + 16, 4, 3)
      end
    else
      for i = 0, 3 do
        love.graphics.ellipse("fill", ssx + 16, ssy + 4 + i * 8, 3, 4)
      end
    end
  end
end

-- ═══════════════════════════════════════
-- INTERIOR RENDERING
-- ═══════════════════════════════════════

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Floor
  local floorColor = interior.floorColor or {0.7, 0.65, 0.55}
  love.graphics.setColor(floorColor[1], floorColor[2], floorColor[3])
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

  -- Floor texture (flagstone pattern for stone buildings)
  if interior.floorType == "flagstone" then
    for fx = 0, interior.width * 32, 24 do
      for fy = 0, interior.height * 32, 20 do
        local shade = 0.95 + math.sin(fx * 0.3 + fy * 0.5) * 0.05
        love.graphics.setColor(
          floorColor[1] * shade,
          floorColor[2] * shade,
          floorColor[3] * shade
        )
        love.graphics.rectangle("fill", fx + 1, fy + 1, 22, 18)
        love.graphics.setColor(floorColor[1] * 0.7, floorColor[2] * 0.7, floorColor[3] * 0.7, 0.3)
        love.graphics.rectangle("line", fx + 1, fy + 1, 22, 18)
      end
    end
  end

  -- Walls
  local wallColor = interior.wallColor or {0.5, 0.45, 0.4}
  love.graphics.setColor(wallColor[1], wallColor[2], wallColor[3])
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
  love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

  -- Exit door
  love.graphics.setColor(0.4, 0.25, 0.15)
  love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)

  -- Interior features (display cases, furniture, etc.)
  if interior.features then
    for _, feat in ipairs(interior.features) do
      M.drawInteriorFeature(feat)
    end
  end

  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local px = portal.x * 32
      local py = portal.y * 32
      local pulse = math.sin(gameState.animationTime * 3) * 0.2 + 0.8
      love.graphics.setColor(portal.color[1] * pulse, portal.color[2] * pulse, portal.color[3] * pulse)
      love.graphics.circle("fill", px + 16, py + 16, 20)
      love.graphics.setColor(1, 1, 1)
      local font = love.graphics.getFont()
      local textW = font:getWidth(portal.name)
      love.graphics.print(portal.name, px + 16 - textW / 2, py + 40)
    end
  end

  -- Interior name
  love.graphics.setColor(0.2, 0.15, 0.1)
  love.graphics.print(interior.name, 40, 40)
end

function M.drawInteriorFeature(feat)
  local x = feat.x * 32
  local y = feat.y * 32

  if feat.type == "display_case" then
    love.graphics.setColor(0.55, 0.50, 0.42)
    love.graphics.rectangle("fill", x, y, (feat.w or 1) * 32, (feat.h or 1) * 32)
    love.graphics.setColor(0.45, 0.60, 0.55, 0.5)
    love.graphics.rectangle("fill", x + 4, y + 4, (feat.w or 1) * 32 - 8, (feat.h or 1) * 32 - 8)
  elseif feat.type == "desk" then
    love.graphics.setColor(0.50, 0.40, 0.28)
    love.graphics.rectangle("fill", x, y, (feat.w or 2) * 32, 32)
  elseif feat.type == "fireplace" then
    love.graphics.setColor(0.45, 0.38, 0.30)
    love.graphics.rectangle("fill", x, y, (feat.w or 2) * 32, 32)
    -- Fire glow
    love.graphics.setColor(0.95, 0.55, 0.15, 0.6)
    love.graphics.circle("fill", x + 16, y + 12, 10)
  elseif feat.type == "telescope" then
    love.graphics.setColor(0.35, 0.35, 0.40)
    love.graphics.rectangle("fill", x + 12, y, 8, 32)
    love.graphics.line(x + 16, y, x + 28, y - 16)
  elseif feat.type == "window_wall" then
    love.graphics.setColor(0.50, 0.68, 0.78, 0.5)
    love.graphics.rectangle("fill", x, y, (feat.w or 3) * 32, 32)
  end
end

-- ═══════════════════════════════════════
-- UI OVERLAY
-- ═══════════════════════════════════════

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Zone name display
  local zoneName, zone = areas.getZoneAt(gameState.player.gridX, gameState.player.gridY)
  if gameState.location == "outdoors" and zone then
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 10, 10, 200, 30, 5, 5)
    love.graphics.setColor(1, 0.95, 0.8)  -- Warm desert text tint
    love.graphics.print(zone.name, 20, 17)
  elseif gameState.location == "interior" then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.setColor(0, 0, 0, 0.5)
      love.graphics.rectangle("fill", 10, 10, 250, 30, 5, 5)
      love.graphics.setColor(1, 1, 1)
      love.graphics.print(interior.name, 20, 17)
    end
  end

  -- Currency display
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", screenW - 160, 10, 150, 30, 5, 5)
  love.graphics.setColor(1, 0.85, 0.3)
  love.graphics.print("Notes: " .. gameState.notes, screenW - 150, 17)

  -- Time of day display (outdoors only)
  if gameState.location == "outdoors" then
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", screenW - 100, 45, 90, 25, 5, 5)
    love.graphics.setColor(1, 1, 0.9)
    love.graphics.print(lighting.getTimeString(), screenW - 90, 50)

    -- Temperature indicator (desert heat!)
    local hour = lighting.getHour()
    local temp
    if hour >= 11 and hour <= 16 then temp = "105°F"
    elseif hour >= 8 and hour <= 18 then temp = "95°F"
    elseif hour >= 6 and hour <= 20 then temp = "82°F"
    else temp = "68°F"
    end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", screenW - 100, 72, 90, 20, 5, 5)
    love.graphics.setColor(1, 0.7, 0.4)
    love.graphics.print(temp, screenW - 90, 75)
  end

  -- Interaction prompts
  if gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW / 2 - 100, screenH - 60, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW / 2 - 100, screenH - 50, 200, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW / 2 - 100, screenH - 60, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to talk to " .. gameState.nearbyNPC.name, screenW / 2 - 100, screenH - 50, 200, "center")
  end

  -- Dialogue box
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.8, 0.6, 0.3)  -- Desert gold border
    love.graphics.rectangle("line", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.95, 0.82, 0.5)  -- Warm name color
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 140)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 115, screenW - 140, "left")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press E to close", 70, screenH - 50)
  end

  -- Edge hint
  if gameState.location == "outdoors" then
    local nearEdge = gameState.player.gridX <= 1 or gameState.player.gridX >= areas.WIDTH - 2 or
                     gameState.player.gridY <= 1 or gameState.player.gridY >= areas.HEIGHT - 2
    if nearEdge then
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", screenW / 2 - 120, 50, 240, 30, 5, 5)
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf("Press ESC to pause", screenW / 2 - 120, 57, 240, "center")
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
    -- Was inside a building
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
    -- Was outdoors
    gameState.location = "outdoors"
    gameState.collisionMap = areas.createCollisionMap()
    M.setupOutdoorNPCs()
  end
  gameState.returnLocation = nil
  gameState.returnPosition = nil
end

return M

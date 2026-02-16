-- leucadia/init.lua
-- Beach town hub - Cianwood City style outdoor exploration
-- Unlike the space station hub, this is a single large outdoor area

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local areas = require("leucadia.areas")
local buildings = require("leucadia.buildings")
local lighting = require("leucadia.lighting")
local environment = require("leucadia.environment")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

function M.load()
  gameState.location = "outdoors"  -- "outdoors" or building interior id
  gameState.interiorId = nil

  -- Player starts at town square spawn point
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

  -- Initialize dynamic lighting and environment
  lighting.init()
  environment.init()

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

  -- Regenerate tides and beach life when exiting buildings
  environment.regenerateTide()

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

  -- Update dynamic systems
  lighting.update(dt)
  environment.update(dt)

  -- Update player
  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  -- Update NPCs
  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.update(npcObj, dt, gameState.collisionMap, gameState.currentNPCs, gameState.player)
  end

  -- Continuous movement
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
        -- Check if player is on tile below door and pressing up to enter
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
    -- Draw horizon and sky gradient (before camera transform)
    environment.drawHorizon(screenW, screenH, gameState.camera.y)
    environment.drawSky(screenW, screenH)

    -- Draw clouds (with parallax, before main world)
    environment.drawClouds(gameState.camera.x, gameState.camera.y, gameState.animationTime)
  end

  love.graphics.push()
  love.graphics.translate(-gameState.camera.x + screenW / 2,
                          -gameState.camera.y + screenH / 2)

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

function M.drawOutdoors()
  local gs = 32
  local tideLevel = environment.getTideLevel()

  -- Draw zones (ground) with lighting adjustment
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  for name, zone in pairs(areas.zones) do
    if zone.groundColor then
      local r = zone.groundColor[1] * ambientIntensity
      local g = zone.groundColor[2] * ambientIntensity
      local b = zone.groundColor[3] * ambientIntensity
      love.graphics.setColor(r, g, b)
      local x = zone.x1 * gs
      local y = zone.y1 * gs
      local w = (zone.x2 - zone.x1 + 1) * gs
      local h = (zone.y2 - zone.y1 + 1) * gs
      love.graphics.rectangle("fill", x, y, w, h)
      
      -- Add sand texture shimmer to beach
      if name == "beach" then
        for i = 1, 50 do
          local sx = x + math.random(0, w)
          local sy = y + math.random(0, h)
          local shimmer = 0.5 + math.sin(gameState.animationTime * 2 + sx * 0.1) * 0.5
          love.graphics.setColor(1, 1, 0.9, 0.15 * shimmer * ambientIntensity)
          love.graphics.circle("fill", sx, sy, 1.5)
        end
      end
    end
  end

  -- Draw pier planks with enhanced wood texture
  for y = 30, 34 do
    for x = 31, 49 do
      -- Base plank color with variation
      local colorVar = 0.95 + math.sin(x * 1.3 + y * 2.1) * 0.05
      love.graphics.setColor(0.52 * ambientIntensity * colorVar, 0.42 * ambientIntensity * colorVar, 0.32 * ambientIntensity * colorVar)
      love.graphics.rectangle("fill", x * gs, y * gs, gs, gs)
      
      -- Plank separations (darker)
      love.graphics.setColor(0.30 * ambientIntensity, 0.22 * ambientIntensity, 0.14 * ambientIntensity)
      love.graphics.setLineWidth(2)
      love.graphics.line(x * gs, y * gs, x * gs + gs, y * gs)
      love.graphics.line(x * gs + gs, y * gs, x * gs + gs, y * gs + gs)
      
      -- Wood grain texture
      love.graphics.setColor(0.45 * ambientIntensity, 0.35 * ambientIntensity, 0.25 * ambientIntensity, 0.3)
      love.graphics.setLineWidth(1)
      for i = 1, 2 do
        love.graphics.line(x * gs + 5, y * gs + i * 10, x * gs + gs - 5, y * gs + i * 10)
      end
      
      -- Nail heads
      love.graphics.setColor(0.25 * ambientIntensity, 0.25 * ambientIntensity, 0.28 * ambientIntensity)
      love.graphics.circle("fill", x * gs + 6, y * gs + 6, 1.5)
      love.graphics.circle("fill", x * gs + gs - 6, y * gs + 6, 1.5)
      love.graphics.setLineWidth(1)
    end
  end

  -- Draw ocean with tide-affected color and depth
  local oceanZone = areas.zones.ocean
  local oceanDepth = 0.6 + tideLevel * 0.2
  
  -- Draw ocean in layers for depth effect
  for y = oceanZone.y1, oceanZone.y2 do
    for x = oceanZone.x1, oceanZone.x2 do
      -- Base ocean color with depth gradient
      local depthFactor = 1 + (y - oceanZone.y1) * 0.05
      love.graphics.setColor(
        0.2 * oceanDepth * depthFactor, 
        0.5 * oceanDepth * depthFactor, 
        0.75 * oceanDepth * depthFactor
      )
      love.graphics.rectangle("fill", x * gs, y * gs, gs, gs)
    end
  end
  
  -- Ocean sparkles (sunlight on water)
  if not lighting.isNight() then
    for i = 1, 25 do
      local sparkleX = (oceanZone.x1 + (i * 53 + gameState.animationTime * 3.75) % (oceanZone.x2 - oceanZone.x1)) * gs
      local sparkleY = (oceanZone.y1 + (i * 37) % (oceanZone.y2 - oceanZone.y1)) * gs
      local sparklePhase = math.sin(gameState.animationTime * 4 + i * 1.5)
      if sparklePhase > 0.6 then
        local brightness = (sparklePhase - 0.6) * 2.5
        love.graphics.setColor(1, 1, 0.9, 0.5 * brightness * ambientIntensity)
        love.graphics.circle("fill", sparkleX, sparkleY, 3 + brightness * 2)
      end
    end
  end

  -- Draw waves at high tide or foam at shoreline
  environment.drawWaves(gs, gameState.animationTime)

  -- Draw crabs at low tide
  environment.drawCrabs()

  -- Draw cobblestone sidewalks connecting building fronts
  M.drawCobbleSidewalks(gs, ambientIntensity)

  -- Draw building shadows first (behind buildings)
  for _, b in ipairs(areas.buildings) do
    lighting.drawShadow(b.x, b.y, b.w, b.h, gs)
  end

  -- Draw decorations (non-palm trees first for layering)
  for _, deco in ipairs(areas.decorations) do
    if deco.type ~= "palm_tree" then
      M.drawDecoration(deco)
    end
  end

  -- Draw buildings
  for _, b in ipairs(areas.buildings) do
    M.drawBuilding(b)
  end

  -- Draw palm tree shadows (before trees for correct layering)
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "palm_tree" then
      lighting.drawPalmTreeShadow(deco.x, deco.y, gs, deco.variety)
    end
  end

  -- Draw palm trees with wind animation (after buildings and shadows)
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "palm_tree" then
      environment.drawPalmTree(deco.x, deco.y, gs, gameState.animationTime, deco.variety)
    end
  end
end

function M.drawCobbleSidewalks(gs, ambientIntensity)
  -- Group buildings by zone to create continuous sidewalk strips
  local sidewalkStrips = {}

  -- Coast Highway sidewalk: continuous strip along front of shops (moved up to y=17 and y=22-23)
  table.insert(sidewalkStrips, {x1 = 2, y = 17, x2 = 16, depth = 1})  -- Upper row shops
  table.insert(sidewalkStrips, {x1 = 2, y = 22, x2 = 13, depth = 2})  -- Lower row shops

  -- Connector from Coast Highway to Town Square
  table.insert(sidewalkStrips, {x1 = 14, y = 17, x2 = 18, depth = 1})
  table.insert(sidewalkStrips, {x1 = 16, y = 18, x2 = 18, depth = 3})

  -- Town Square walkways
  table.insert(sidewalkStrips, {x1 = 17, y = 20, x2 = 31, depth = 1})  -- North shops
  table.insert(sidewalkStrips, {x1 = 20, y = 25, x2 = 28, depth = 1})  -- Town Hall front

  -- Connector from Town Square to Mission District
  table.insert(sidewalkStrips, {x1 = 31, y = 20, x2 = 36, depth = 1})
  table.insert(sidewalkStrips, {x1 = 33, y = 21, x2 = 36, depth = 2})

  -- Mission District walkways
  table.insert(sidewalkStrips, {x1 = 35, y = 22, x2 = 49, depth = 1})  -- Upper buildings
  table.insert(sidewalkStrips, {x1 = 35, y = 27, x2 = 49, depth = 1})  -- Lower buildings

  -- Residential walkway
  table.insert(sidewalkStrips, {x1 = 2, y = 7, x2 = 23, depth = 1})

  -- Connector from Residential to Flower Fields
  table.insert(sidewalkStrips, {x1 = 23, y = 7, x2 = 30, depth = 1})
  table.insert(sidewalkStrips, {x1 = 28, y = 8, x2 = 30, depth = 2})

  -- Flower fields path
  table.insert(sidewalkStrips, {x1 = 29, y = 9, x2 = 48, depth = 1})

  for _, strip in ipairs(sidewalkStrips) do
    for dy = 0, strip.depth - 1 do
      for gx = strip.x1, strip.x2 do
        local px = gx * gs
        local py = (strip.y + dy) * gs

        -- Base cobblestone color (warm gray)
        local stoneVar = math.sin(gx * 3.7 + (strip.y + dy) * 5.3) * 0.04
        love.graphics.setColor(
          (0.62 + stoneVar) * ambientIntensity,
          (0.58 + stoneVar) * ambientIntensity,
          (0.50 + stoneVar) * ambientIntensity
        )
        love.graphics.rectangle("fill", px, py, gs, gs)

        -- Draw individual cobblestones (2x3 grid per tile)
        for cx = 0, 1 do
          for cy = 0, 2 do
            local stoneX = px + cx * 16 + 1
            local stoneY = py + cy * 11 + 1
            local sw = 14
            local sh = 9

            -- Offset alternate rows for brick pattern
            local rowOffset = (cy % 2 == 1) and 8 or 0
            stoneX = stoneX + rowOffset

            -- Individual stone color variation
            local shade = 0.95 + math.sin((gx * 2 + cx) * 4.1 + (strip.y + dy + cy) * 3.3) * 0.05
            love.graphics.setColor(
              0.58 * shade * ambientIntensity,
              0.54 * shade * ambientIntensity,
              0.46 * shade * ambientIntensity
            )
            love.graphics.rectangle("fill", stoneX, stoneY, sw, sh, 2, 2)

            -- Stone border / mortar lines
            love.graphics.setColor(0.42 * ambientIntensity, 0.38 * ambientIntensity, 0.32 * ambientIntensity, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", stoneX, stoneY, sw, sh, 2, 2)

            -- Subtle highlight on top edge
            love.graphics.setColor(0.72 * ambientIntensity, 0.68 * ambientIntensity, 0.60 * ambientIntensity, 0.3)
            love.graphics.line(stoneX + 2, stoneY + 1, stoneX + sw - 2, stoneY + 1)
          end
        end
      end
    end
  end
end

function M.drawBuilding(b)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local nameLower = b.name:lower()

  -- Determine building style
  local isShop = string.match(nameLower, "shop") or string.match(nameLower, "cafe") or
                 string.match(nameLower, "grill") or string.match(nameLower, "boutique") or
                 string.match(nameLower, "stand") or string.match(nameLower, "tackle")
  local isHouse = string.match(nameLower, "house")
  local isCivic = string.match(nameLower, "hall") or string.match(nameLower, "bank") or
                  string.match(nameLower, "mission") or string.match(nameLower, "control")
  local isMilitary = string.match(nameLower, "hangar") or string.match(nameLower, "depot") or
                     string.match(nameLower, "lounge")

  -- ═══ BUILDING BODY (stucco texture) ═══
  love.graphics.setColor(
    b.color[1] * ambientIntensity, 
    b.color[2] * ambientIntensity, 
    b.color[3] * ambientIntensity
  )
  love.graphics.rectangle("fill", x, y, w, h)

  -- Stucco texture (tiny speckles for Mediterranean feel)
  for sx = x + 2, x + w - 2, 6 do
    for sy = y + 18, y + h - 2, 6 do
      local speckle = math.sin(sx * 3.1 + sy * 2.7) * 0.03
      love.graphics.setColor(
        (b.color[1] + speckle) * ambientIntensity,
        (b.color[2] + speckle) * ambientIntensity,
        (b.color[3] + speckle) * ambientIntensity
      )
      love.graphics.rectangle("fill", sx, sy, 4, 4)
    end
  end

  -- Side shading for depth
  love.graphics.setColor(
    b.color[1] * ambientIntensity * 0.7,
    b.color[2] * ambientIntensity * 0.7,
    b.color[3] * ambientIntensity * 0.7
  )
  love.graphics.rectangle("fill", x + w - 5, y + 4, 5, h - 4)

  -- Bottom shadow strip (ground contact)
  love.graphics.setColor(
    b.color[1] * ambientIntensity * 0.6,
    b.color[2] * ambientIntensity * 0.6,
    b.color[3] * ambientIntensity * 0.6
  )
  love.graphics.rectangle("fill", x, y + h - 3, w, 3)

  -- ═══ SPANISH TILE ROOF ═══
  -- Roof base
  love.graphics.setColor(
    b.roofColor[1] * ambientIntensity, 
    b.roofColor[2] * ambientIntensity, 
    b.roofColor[3] * ambientIntensity
  )
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, 18)

  -- Scalloped tile pattern (terracotta barrel tiles)
  for tx = x - 2, x + w, 8 do
    -- Upper row of tiles
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 1.1,
      b.roofColor[2] * ambientIntensity * 0.9,
      b.roofColor[3] * ambientIntensity * 0.8
    )
    love.graphics.arc("fill", tx + 4, y + 2, 5, math.pi, 0)
    -- Lower row offset
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.9,
      b.roofColor[2] * ambientIntensity * 0.8,
      b.roofColor[3] * ambientIntensity * 0.7
    )
    love.graphics.arc("fill", tx + 8, y + 8, 5, math.pi, 0)
  end

  -- Roof edge overhang shadow
  love.graphics.setColor(0, 0, 0, 0.15 * ambientIntensity)
  love.graphics.rectangle("fill", x - 2, y + 14, w + 4, 3)

  -- Roof trim line (decorative molding)
  love.graphics.setColor(
    b.roofColor[1] * ambientIntensity * 1.3,
    b.roofColor[2] * ambientIntensity * 1.2,
    b.roofColor[3] * ambientIntensity * 1.1
  )
  love.graphics.setLineWidth(2)
  love.graphics.line(x - 2, y + 16, x + w + 2, y + 16)
  love.graphics.setLineWidth(1)

  -- ═══ DOOR (arched for shops/civic, square for others) ═══
  local doorX = b.doorX * 32 + 4
  local doorY = b.doorY * 32 - 24
  local doorW = 24
  local doorH = 24

  if isShop or isCivic then
    -- Arched doorway (Carlsbad Mediterranean style)
    love.graphics.setColor(0.35 * ambientIntensity, 0.22 * ambientIntensity, 0.12 * ambientIntensity)
    love.graphics.rectangle("fill", doorX, doorY + 8, doorW, doorH - 8)
    love.graphics.arc("fill", doorX + doorW/2, doorY + 8, doorW/2, math.pi, 0)
    -- Arch frame
    love.graphics.setColor(0.28 * ambientIntensity, 0.18 * ambientIntensity, 0.10 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", doorX + doorW/2, doorY + 8, doorW/2, math.pi, 0)
    love.graphics.line(doorX, doorY + 8, doorX, doorY + doorH)
    love.graphics.line(doorX + doorW, doorY + 8, doorX + doorW, doorY + doorH)
    love.graphics.setLineWidth(1)
    -- Decorative keystone at arch top
    love.graphics.setColor(0.55 * ambientIntensity, 0.50 * ambientIntensity, 0.42 * ambientIntensity)
    love.graphics.polygon("fill",
      doorX + doorW/2 - 3, doorY - 3,
      doorX + doorW/2 + 3, doorY - 3,
      doorX + doorW/2 + 2, doorY + 2,
      doorX + doorW/2 - 2, doorY + 2
    )
  else
    -- Standard door
    love.graphics.setColor(0.4 * ambientIntensity, 0.25 * ambientIntensity, 0.15 * ambientIntensity)
    love.graphics.rectangle("fill", doorX, doorY, doorW, doorH)
    -- Door frame
    love.graphics.setColor(0.3 * ambientIntensity, 0.2 * ambientIntensity, 0.12 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", doorX, doorY, doorW, doorH)
    love.graphics.setLineWidth(1)
  end

  -- Door handle
  love.graphics.setColor(0.75, 0.70, 0.35, ambientIntensity)
  love.graphics.circle("fill", doorX + doorW - 4, doorY + doorH/2, 2)

  -- Door panel lines
  love.graphics.setColor(0.32 * ambientIntensity, 0.20 * ambientIntensity, 0.12 * ambientIntensity, 0.4)
  love.graphics.line(doorX + doorW/2, doorY + 6, doorX + doorW/2, doorY + doorH)

  -- ═══ AWNING (shops and cafes) ═══
  if isShop then
    -- Striped canvas awning
    local awningX = b.doorX * 32 - 4
    local awningY = doorY - 4
    local awningW = 40
    local awningH = 8
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.85,
      b.roofColor[2] * ambientIntensity * 0.85,
      b.roofColor[3] * ambientIntensity * 0.85
    )
    love.graphics.polygon("fill",
      awningX, awningY,
      awningX + awningW, awningY,
      awningX + awningW + 3, awningY + awningH,
      awningX - 3, awningY + awningH
    )
    -- Awning stripes
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.6,
      b.roofColor[2] * ambientIntensity * 0.6,
      b.roofColor[3] * ambientIntensity * 0.6
    )
    for stripe = 0, 4 do
      love.graphics.rectangle("fill", awningX + stripe * 8, awningY, 4, awningH)
    end
    -- Awning scalloped bottom edge
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.75,
      b.roofColor[2] * ambientIntensity * 0.75,
      b.roofColor[3] * ambientIntensity * 0.75
    )
    for scallop = 0, 4 do
      love.graphics.arc("fill", awningX + scallop * 8 + 4, awningY + awningH, 4, 0, math.pi)
    end
  end

  -- ═══ WINDOWS ═══
  local windowY = y + 24
  for wx = x + 8, x + w - 24, 24 do
    -- Window shutters (wooden, Carlsbad style)
    love.graphics.setColor(
      b.color[1] * ambientIntensity * 0.65,
      b.color[2] * ambientIntensity * 0.65,
      b.color[3] * ambientIntensity * 0.65
    )
    love.graphics.rectangle("fill", wx - 4, windowY - 1, 4, 14)
    love.graphics.rectangle("fill", wx + 16, windowY - 1, 4, 14)
    -- Shutter slats
    love.graphics.setColor(
      b.color[1] * ambientIntensity * 0.5,
      b.color[2] * ambientIntensity * 0.5,
      b.color[3] * ambientIntensity * 0.5
    )
    for slat = 0, 2 do
      love.graphics.line(wx - 3, windowY + slat * 4, wx, windowY + slat * 4)
      love.graphics.line(wx + 17, windowY + slat * 4, wx + 20, windowY + slat * 4)
    end

    -- Window glass
    love.graphics.setColor(0.55 * ambientIntensity, 0.72 * ambientIntensity, 0.85 * ambientIntensity)
    love.graphics.rectangle("fill", wx, windowY, 16, 12)

    -- Sky reflection
    love.graphics.setColor(0.70 * ambientIntensity, 0.85 * ambientIntensity, 0.95 * ambientIntensity, 0.3)
    love.graphics.rectangle("fill", wx, windowY, 16, 4)

    -- Window frame (thicker, more ornate)
    love.graphics.setColor(0.35 * ambientIntensity, 0.30 * ambientIntensity, 0.25 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", wx, windowY, 16, 12)
    love.graphics.line(wx + 8, windowY, wx + 8, windowY + 12)
    love.graphics.line(wx, windowY + 6, wx + 16, windowY + 6)
    love.graphics.setLineWidth(1)

    -- Window sill (stone ledge)
    love.graphics.setColor(0.60 * ambientIntensity, 0.55 * ambientIntensity, 0.48 * ambientIntensity)
    love.graphics.rectangle("fill", wx - 2, windowY + 12, 20, 3)

    -- Window flower box (alternating windows)
    if math.floor(wx / 24) % 2 == 0 then
      love.graphics.setColor(0.45 * ambientIntensity, 0.30 * ambientIntensity, 0.20 * ambientIntensity)
      love.graphics.rectangle("fill", wx - 1, windowY + 15, 18, 4)
      -- Colorful flowers (varied colors per building)
      local flowerSeed = b.x * 3 + b.y * 7
      for f = 0, 4 do
        local fColor = (flowerSeed + f) % 3
        if fColor == 0 then
          love.graphics.setColor(0.9 * ambientIntensity, 0.3 * ambientIntensity, 0.4 * ambientIntensity)
        elseif fColor == 1 then
          love.graphics.setColor(0.95 * ambientIntensity, 0.75 * ambientIntensity, 0.2 * ambientIntensity)
        else
          love.graphics.setColor(0.7 * ambientIntensity, 0.3 * ambientIntensity, 0.8 * ambientIntensity)
        end
        love.graphics.circle("fill", wx + 1 + f * 3.5, windowY + 15, 2)
      end
      -- Green leaves
      love.graphics.setColor(0.3 * ambientIntensity, 0.55 * ambientIntensity, 0.25 * ambientIntensity)
      for f = 0, 3 do
        love.graphics.circle("fill", wx + 2 + f * 4, windowY + 17, 1.5)
      end
    end

    -- Day reflection sparkle
    if not lighting.isNight() then
      love.graphics.setColor(1, 1, 0.95, 0.25 * ambientIntensity)
      love.graphics.rectangle("fill", wx + 2, windowY + 1, 5, 3)
    end
  end

  -- ═══ DECORATIVE TILE ACCENT (below windows, Carlsbad style) ═══
  if isShop or isCivic then
    local accentY = windowY + 20
    for tx = x + 4, x + w - 8, 12 do
      local tileShade = 0.9 + math.sin(tx * 0.5) * 0.1
      love.graphics.setColor(
        0.15 * tileShade * ambientIntensity,
        0.35 * tileShade * ambientIntensity,
        0.55 * tileShade * ambientIntensity
      )
      love.graphics.rectangle("fill", tx, accentY, 10, 5, 1, 1)
      love.graphics.setColor(
        0.65 * tileShade * ambientIntensity,
        0.55 * tileShade * ambientIntensity,
        0.20 * tileShade * ambientIntensity
      )
      love.graphics.rectangle("fill", tx + 5, accentY, 5, 5, 1, 1)
    end
  end

  -- ═══ OUTDOOR PLANTERS (at building base) ═══
  if isShop or isCivic then
    -- Terracotta planters on each side of door
    for _, planterSide in ipairs({-1, 1}) do
      local planterX = b.doorX * 32 + (planterSide > 0 and 30 or -10)
      local planterY = b.doorY * 32 - 10
      -- Pot
      love.graphics.setColor(0.65 * ambientIntensity, 0.38 * ambientIntensity, 0.22 * ambientIntensity)
      love.graphics.polygon("fill",
        planterX, planterY,
        planterX + 10, planterY,
        planterX + 8, planterY + 10,
        planterX + 2, planterY + 10
      )
      -- Pot rim
      love.graphics.setColor(0.58 * ambientIntensity, 0.34 * ambientIntensity, 0.20 * ambientIntensity)
      love.graphics.rectangle("fill", planterX - 1, planterY - 2, 12, 3)
      -- Plant
      love.graphics.setColor(0.30 * ambientIntensity, 0.55 * ambientIntensity, 0.25 * ambientIntensity)
      love.graphics.circle("fill", planterX + 5, planterY - 5, 6)
      love.graphics.setColor(0.35 * ambientIntensity, 0.60 * ambientIntensity, 0.30 * ambientIntensity)
      love.graphics.circle("fill", planterX + 3, planterY - 7, 4)
    end
  end

  -- ═══ BUILDING NAME SIGN ═══
  -- Hanging sign with bracket (Carlsbad style)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  local signX = x + w/2 - textW/2 - 6
  local signY = y - 22

  -- Sign bracket
  love.graphics.setColor(0.25 * ambientIntensity, 0.25 * ambientIntensity, 0.28 * ambientIntensity)
  love.graphics.setLineWidth(2)
  love.graphics.line(signX + 4, y, signX + 4, signY + 2)
  love.graphics.line(signX + textW + 8, y, signX + textW + 8, signY + 2)
  love.graphics.setLineWidth(1)

  -- Sign board
  love.graphics.setColor(0.18, 0.14, 0.10, 0.75)
  love.graphics.rectangle("fill", signX, signY, textW + 12, 18, 3, 3)
  -- Sign border
  love.graphics.setColor(0.45 * ambientIntensity, 0.38 * ambientIntensity, 0.28 * ambientIntensity)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", signX, signY, textW + 12, 18, 3, 3)

  -- Sign text
  love.graphics.setColor(0.95 * ambientIntensity, 0.92 * ambientIntensity, 0.82 * ambientIntensity)
  love.graphics.print(b.name, signX + 6, signY + 2)

  -- ═══ CHIMNEY (houses and grill) ═══
  if isHouse or string.match(nameLower, "grill") then
    local chimneyX = x + w - 16
    local chimneyY = y - 10
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.55,
      b.roofColor[2] * ambientIntensity * 0.55,
      b.roofColor[3] * ambientIntensity * 0.55
    )
    love.graphics.rectangle("fill", chimneyX, chimneyY, 8, 26)
    -- Chimney cap
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.45,
      b.roofColor[2] * ambientIntensity * 0.45,
      b.roofColor[3] * ambientIntensity * 0.45
    )
    love.graphics.rectangle("fill", chimneyX - 2, chimneyY - 2, 12, 3)
    -- Brick detail
    love.graphics.setColor(
      b.roofColor[1] * ambientIntensity * 0.4,
      b.roofColor[2] * ambientIntensity * 0.4,
      b.roofColor[3] * ambientIntensity * 0.4
    )
    for brickY = chimneyY + 4, chimneyY + 20, 6 do
      love.graphics.line(chimneyX, brickY, chimneyX + 8, brickY)
    end
  end

  -- ═══ CORNER COLUMNS (civic buildings) ═══
  if isCivic then
    love.graphics.setColor(
      b.color[1] * ambientIntensity * 1.15,
      b.color[2] * ambientIntensity * 1.15,
      b.color[3] * ambientIntensity * 1.15
    )
    -- Left column
    love.graphics.rectangle("fill", x + 2, y + 16, 5, h - 16)
    -- Right column
    love.graphics.rectangle("fill", x + w - 7, y + 16, 5, h - 16)
    -- Column capitals
    love.graphics.setColor(
      b.color[1] * ambientIntensity * 1.25,
      b.color[2] * ambientIntensity * 1.25,
      b.color[3] * ambientIntensity * 1.25
    )
    love.graphics.rectangle("fill", x + 1, y + 16, 7, 3)
    love.graphics.rectangle("fill", x + w - 8, y + 16, 7, 3)
    -- Column bases
    love.graphics.rectangle("fill", x + 1, y + h - 3, 7, 3)
    love.graphics.rectangle("fill", x + w - 8, y + h - 3, 7, 3)
  end

  -- ═══ WROUGHT IRON BALCONY (some residential/cafe buildings) ═══
  if isHouse or string.match(nameLower, "cafe") or string.match(nameLower, "lounge") then
    local balconyY = y + 20
    -- Balcony base
    love.graphics.setColor(0.25 * ambientIntensity, 0.25 * ambientIntensity, 0.28 * ambientIntensity)
    love.graphics.rectangle("fill", x + 6, balconyY, w - 12, 2)
    -- Iron railing
    love.graphics.setLineWidth(1.5)
    for rx = x + 8, x + w - 12, 6 do
      love.graphics.line(rx, balconyY - 8, rx, balconyY)
    end
    -- Top rail
    love.graphics.line(x + 6, balconyY - 8, x + w - 6, balconyY - 8)
    -- Decorative scroll at center
    love.graphics.arc("line", x + w/2, balconyY - 4, 3, 0, math.pi)
    love.graphics.setLineWidth(1)
  end

end

function M.drawDecoration(deco)
  local x = deco.x * 32
  local y = deco.y * 32
  local _, ambientIntensity = lighting.getAmbientLight()

  -- Palm trees are now drawn by environment module with wind animation
  if deco.type == "palm_tree" then
    return  -- Handled separately

  elseif deco.type == "umbrella" then
    local color = deco.color or {0.9, 0.2, 0.2}
    love.graphics.setColor(color[1] * ambientIntensity, color[2] * ambientIntensity, color[3] * ambientIntensity)
    love.graphics.circle("fill", x + 16, y + 8, 18)
    love.graphics.setColor(0.4 * ambientIntensity, 0.3 * ambientIntensity, 0.2 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y + 8, 4, 20)
    -- Umbrella shadow
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)

  elseif deco.type == "fountain" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    -- Shadow
    lighting.drawShadow(deco.x, deco.y, deco.w or 1, deco.h or 1, 32)
    -- Basin
    love.graphics.setColor(0.5 * ambientIntensity, 0.5 * ambientIntensity, 0.55 * ambientIntensity)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.3, 0.55, 0.7)
    love.graphics.rectangle("fill", x + 8, y + 8, w - 16, h - 16)
    -- Water spray
    love.graphics.setColor(0.6, 0.8, 0.95, 0.7)
    local sprayHeight = 15 + math.sin(gameState.animationTime * 5) * 5
    love.graphics.circle("fill", x + w/2, y + h/2 - sprayHeight, 4)

  elseif deco.type == "flowers" then
    local w = (deco.w or 1) * 32
    local h = (deco.h or 1) * 32
    local color = deco.color or {1, 0.5, 0.5}
    -- Flowers sway slightly in the wind
    local sway = environment.getWindSway(x, gameState.animationTime, 2)
    for fy = y, y + h - 8, 10 do
      for fx = x, x + w - 8, 10 do
        local flowerSway = sway + math.sin(fx * 0.1 + gameState.animationTime) * 1
        love.graphics.setColor(color[1] * ambientIntensity, color[2] * ambientIntensity, color[3] * ambientIntensity, 0.9)
        love.graphics.circle("fill", fx + flowerSway, fy, 4)
      end
    end

  elseif deco.type == "bench" then
    lighting.drawShadow(deco.x, deco.y, 1, 1, 32)
    love.graphics.setColor(0.5 * ambientIntensity, 0.35 * ambientIntensity, 0.2 * ambientIntensity)
    love.graphics.rectangle("fill", x, y + 16, 32, 8)
    love.graphics.rectangle("fill", x + 4, y + 24, 4, 8)
    love.graphics.rectangle("fill", x + 24, y + 24, 4, 8)

  elseif deco.type == "lamp" then
    -- Lamp post
    love.graphics.setColor(0.3 * ambientIntensity, 0.3 * ambientIntensity, 0.35 * ambientIntensity)
    love.graphics.rectangle("fill", x + 14, y + 8, 4, 24)

    -- Lamp glow (brighter at night)
    if lighting.lampsOn() then
      -- Warm glow circle
      love.graphics.setColor(1, 0.9, 0.6, 0.3)
      love.graphics.circle("fill", x + 16, y + 4, 40)
      love.graphics.setColor(1, 0.95, 0.7, 0.6)
      love.graphics.circle("fill", x + 16, y + 4, 20)
      love.graphics.setColor(1, 0.98, 0.9, 0.9)
      love.graphics.circle("fill", x + 16, y + 4, 8)
    else
      -- Daytime lamp (just glass)
      love.graphics.setColor(0.8 * ambientIntensity, 0.85 * ambientIntensity, 0.9 * ambientIntensity, 0.5)
      love.graphics.circle("fill", x + 16, y + 4, 8)
    end
    
  elseif deco.type == "towel" then
    -- Beach towel laid out on sand
    local color = deco.color or {1, 0.5, 0.5}
    love.graphics.setColor(color[1] * ambientIntensity, color[2] * ambientIntensity, color[3] * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 8, 24, 18)
    -- Towel stripes
    love.graphics.setColor(color[1] * 0.7 * ambientIntensity, color[2] * 0.7 * ambientIntensity, color[3] * 0.7 * ambientIntensity)
    love.graphics.rectangle("fill", x + 4, y + 12, 24, 3)
    love.graphics.rectangle("fill", x + 4, y + 19, 24, 3)
    
  elseif deco.type == "surfboard" then
    -- Surfboard stuck in sand
    local color = deco.color or {0.2, 0.8, 0.9}
    lighting.drawShadow(deco.x, deco.y, 0.3, 2, 32)
    love.graphics.setColor(color[1] * ambientIntensity, color[2] * ambientIntensity, color[3] * ambientIntensity)
    -- Board shape (pointed oval)
    for i = 0, 8 do
      local t = i / 8
      local w = math.sin(t * math.pi) * 6
      love.graphics.ellipse("fill", x + 16, y + 8 + t * 40, w, 3)
    end
    -- Fin
    love.graphics.setColor(color[1] * 0.7 * ambientIntensity, color[2] * 0.7 * ambientIntensity, color[3] * 0.7 * ambientIntensity)
    love.graphics.polygon("fill", x + 16, y + 42, x + 16 - 3, y + 50, x + 16 + 3, y + 50)
    -- Wax shine
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.ellipse("fill", x + 16, y + 20, 4, 10)
    
  elseif deco.type == "piling" then
    -- Pier support piling
    love.graphics.setColor(0.35 * ambientIntensity, 0.25 * ambientIntensity, 0.15 * ambientIntensity)
    love.graphics.rectangle("fill", x + 12, y, 8, 64)
    -- Wood texture lines
    love.graphics.setColor(0.25 * ambientIntensity, 0.18 * ambientIntensity, 0.10 * ambientIntensity)
    for i = 0, 3 do
      love.graphics.line(x + 12, y + i * 16, x + 20, y + i * 16)
    end
    -- Barnacles and wear
    love.graphics.setColor(0.6, 0.6, 0.65, 0.4)
    for i = 1, 4 do
      love.graphics.circle("fill", x + 12 + math.random(0, 8), y + 32 + math.random(0, 20), 2)
    end
    
  elseif deco.type == "pier_rope" then
    -- Rope tied to pier
    love.graphics.setColor(0.7 * ambientIntensity, 0.6 * ambientIntensity, 0.4 * ambientIntensity)
    love.graphics.setLineWidth(3)
    local ropeY = y + 16
    for i = 0, 5 do
      local segX = x + i * 8
      local segY = ropeY + math.sin(i * 0.8 + gameState.animationTime) * 3
      if i > 0 then
        love.graphics.line(x + (i-1) * 8, ropeY + math.sin((i-1) * 0.8 + gameState.animationTime) * 3, segX, segY)
      end
    end
    love.graphics.setLineWidth(1)
  end
end

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Floor
  love.graphics.setColor(0.7, 0.65, 0.55)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

  -- Walls
  love.graphics.setColor(0.5, 0.45, 0.4)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
  love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

  -- Exit door
  love.graphics.setColor(0.4, 0.25, 0.15)
  love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)

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
      love.graphics.print(portal.name, px + 16 - textW/2, py + 40)
    end
  end

  -- Interior name
  love.graphics.setColor(0.2, 0.15, 0.1)
  love.graphics.print(interior.name, 40, 40)
end

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Zone name display
  local zoneName, zone = areas.getZoneAt(gameState.player.gridX, gameState.player.gridY)
  if gameState.location == "outdoors" and zone then
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 10, 10, 200, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
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

    -- Tide indicator
    environment.drawTideIndicator(screenW - 100, 75)
  end

  -- Interaction prompts
  if gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 100, screenH - 60, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW/2 - 100, screenH - 50, 200, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 100, screenH - 60, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to talk to " .. gameState.nearbyNPC.name, screenW/2 - 100, screenH - 50, 200, "center")
  end

  -- Dialogue box
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.3, 0.6, 0.8)
    love.graphics.rectangle("line", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.3, 0.8, 1)
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 140)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 115, screenW - 140, "left")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press E to close", 70, screenH - 50)
  end

  -- Back to asteroids hint (when outdoors near edge)
  if gameState.location == "outdoors" then
    local nearEdge = gameState.player.gridX <= 1 or gameState.player.gridX >= areas.WIDTH - 2 or
                     gameState.player.gridY <= 1 or gameState.player.gridY >= areas.HEIGHT - 2
    if nearEdge then
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", screenW/2 - 120, 50, 240, 30, 5, 5)
      love.graphics.setColor(1, 1, 1)
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

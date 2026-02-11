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
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false}
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
      callback = nil
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
function M.clearShopItems() gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false} end
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
    table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue))
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
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue))
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
  if gameState.paused then return end

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
    -- Draw sky gradient (before camera transform)
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
  player.draw(gameState.player)

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
    love.graphics.setColor(0, 0, 0, alpha)
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
    end
  end

  -- Draw pier planks
  love.graphics.setColor(0.5 * ambientIntensity, 0.4 * ambientIntensity, 0.3 * ambientIntensity)
  for y = 30, 34 do
    for x = 31, 49 do
      love.graphics.rectangle("fill", x * gs, y * gs, gs, gs)
      love.graphics.setColor(0.35 * ambientIntensity, 0.25 * ambientIntensity, 0.15 * ambientIntensity)
      love.graphics.line(x * gs, y * gs, x * gs + gs, y * gs)
      love.graphics.setColor(0.5 * ambientIntensity, 0.4 * ambientIntensity, 0.3 * ambientIntensity)
    end
  end

  -- Draw ocean with tide-affected color
  local oceanZone = areas.zones.ocean
  local oceanDepth = 0.6 + tideLevel * 0.2
  love.graphics.setColor(0.2 * oceanDepth, 0.5 * oceanDepth, 0.75 * oceanDepth)
  for y = oceanZone.y1, oceanZone.y2 do
    for x = oceanZone.x1, oceanZone.x2 do
      love.graphics.rectangle("fill", x * gs, y * gs, gs, gs)
    end
  end

  -- Draw waves at high tide or foam at shoreline
  environment.drawWaves(gs, gameState.animationTime)

  -- Draw crabs at low tide
  environment.drawCrabs()

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

  -- Draw palm trees with wind animation (after buildings for correct layering)
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "palm_tree" then
      environment.drawPalmTree(deco.x, deco.y, gs, gameState.animationTime)
    end
  end
end

function M.drawBuilding(b)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32

  -- Building body
  love.graphics.setColor(b.color[1], b.color[2], b.color[3])
  love.graphics.rectangle("fill", x, y, w, h)

  -- Roof (top portion)
  love.graphics.setColor(b.roofColor[1], b.roofColor[2], b.roofColor[3])
  love.graphics.rectangle("fill", x, y, w, 16)

  -- Door
  love.graphics.setColor(0.4, 0.25, 0.15)
  love.graphics.rectangle("fill", b.doorX * 32 + 4, b.doorY * 32 - 24, 24, 24)

  -- Windows
  love.graphics.setColor(0.7, 0.85, 0.95)
  local windowY = y + 24
  for wx = x + 8, x + w - 24, 24 do
    love.graphics.rectangle("fill", wx, windowY, 16, 12)
  end

  -- Building name sign
  love.graphics.setColor(0.9, 0.85, 0.75)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  love.graphics.print(b.name, x + w/2 - textW/2, y - 18)
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

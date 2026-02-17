-- kalapatthar/init.lua
-- Kala Patthar — Nepali mountain village in Deep Space
-- Uses love.graphics.push/translate/pop for correct camera handling.
-- All world-space objects (ground, buildings, bridges, decorations,
-- player, NPCs) are drawn inside the translate block.

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local areas = require("kalapatthar.areas")
local buildings = require("kalapatthar.buildings")
local environment = require("kalapatthar.environment")
local lighting = require("kalapatthar.lighting")
local pauseMenu = require("hub.pause_menu")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

-- =============================================
-- LOAD
-- =============================================

function M.load()
  gameState.location = "outdoors"
  gameState.interiorId = nil

  gameState.player = player.new(areas.spawnX * areas.GRID_SIZE + 16, areas.spawnY * areas.GRID_SIZE + 16)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.collisionMap = areas.createCollisionMap()
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.lastKeyPress = 0
  gameState.buildingEntryCooldown = 0
  gameState.transition = nil
  gameState.returnPosition = nil
  gameState.paused = false
  gameState.animationTime = 0

  M.setupOutdoorNPCs()

  environment.load()
  lighting.load()
  audio.load()
  pauseMenu.load()

  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in", timer = 0, duration = 1.0,
      callback = nil, color = {0, 0, 0}
    }
    gameState.fadeInFromStarfox = false
  end
end

function M.setFadeInFromStarfox(enable)
  gameState.fadeInFromStarfox = enable
end

function M.setPaused(paused)
  gameState.paused = paused
end

function M.setupOutdoorNPCs()
  gameState.currentNPCs = {}
  for _, npcData in ipairs(areas.npcs) do
    table.insert(gameState.currentNPCs, npc.new(
      npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData
    ))
  end
end

-- =============================================
-- BUILDING ENTER / EXIT
-- =============================================

function M.enterBuilding(buildingId)
  local interior = buildings.getInterior(buildingId)
  if not interior then return end

  gameState.interiorId = buildingId
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}
  gameState.location = "interior"

  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * areas.GRID_SIZE + 16
  gameState.player.y = gameState.player.gridY * areas.GRID_SIZE + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y

  gameState.collisionMap = buildings.createInteriorCollisionMap(buildingId)
  gameState.currentPortals = interior.portals

  gameState.currentNPCs = {}
  if interior.npcs then
    for _, npcData in ipairs(interior.npcs) do
      table.insert(gameState.currentNPCs, npc.new(
        npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData
      ))
    end
  end
end

function M.exitBuilding()
  gameState.transition = {
    phase = "out", timer = 0, duration = 0.2,
    callback = function() M.doExitBuilding() end
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
    gameState.player.x = gameState.player.gridX * areas.GRID_SIZE + 16
    gameState.player.y = gameState.player.gridY * areas.GRID_SIZE + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.returnPosition = nil
  else
    for _, b in ipairs(areas.buildings) do
      if b.interior == buildingId then
        gameState.player.gridX = b.doorX
        gameState.player.gridY = b.doorY + 1
        gameState.player.x = gameState.player.gridX * areas.GRID_SIZE + 16
        gameState.player.y = gameState.player.gridY * areas.GRID_SIZE + 16
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

function M.returnFromGame()
  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in", timer = 0, duration = 1.0,
      callback = nil, color = {0, 0, 0}
    }
    gameState.fadeInFromStarfox = false
  end

  if gameState.returnPosition and gameState.location == "interior" then
    M.enterBuilding(gameState.interiorId)
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY
      gameState.player.x = gameState.player.gridX * areas.GRID_SIZE + 16
      gameState.player.y = gameState.player.gridY * areas.GRID_SIZE + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
    end
  else
    gameState.location = "outdoors"
    gameState.collisionMap = areas.createCollisionMap()
    M.setupOutdoorNPCs()
  end
end

-- =============================================
-- UPDATE
-- =============================================

function M.update(dt)
  if gameState.paused then
    pauseMenu.update(dt)
    return
  end

  gameState.animationTime = gameState.animationTime + dt

  environment.update(dt)
  lighting.update(dt)

  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  -- Collect door positions for NPC pathfinding (prevent blocking doorways)
  local doorPositions = {}
  if gameState.location == "outdoors" and areas and areas.buildings then
    for _, b in ipairs(areas.buildings) do
      table.insert(doorPositions, {x = b.doorX, y = b.doorY})
    end
  end

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

  -- Transition
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

  -- Cooldown
  if gameState.buildingEntryCooldown > 0 then
    gameState.buildingEntryCooldown = gameState.buildingEntryCooldown - dt
    if gameState.buildingEntryCooldown < 0 then gameState.buildingEntryCooldown = 0 end
  end

  -- Reset proximity
  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil

  if gameState.location == "outdoors" then
    if gameState.buildingEntryCooldown <= 0 then
      for _, b in ipairs(areas.buildings) do
        if gameState.player.gridX == b.doorX and gameState.player.gridY == b.doorY - 1 then
          gameState.nearBuildingDoor = b
          break
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
  else
    -- Interior
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

    for _, npcObj in ipairs(gameState.currentNPCs) do
      local npcGridX = npcObj.gridX or npcObj.x
      local npcGridY = npcObj.gridY or npcObj.y
      if math.abs(gameState.player.gridX - npcGridX) <= 1 and
         math.abs(gameState.player.gridY - npcGridY) <= 1 then
        gameState.nearbyNPC = npcObj
        break
      end
    end

    if gameState.interiorId then
      if buildings.isAtExit(gameState.player.gridX, gameState.player.gridY, gameState.interiorId) then
        M.exitBuilding()
      end
    end
  end
end

-- =============================================
-- DRAW  (camera translate pattern — like chillon)
-- =============================================

function M.draw()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local time = gameState.animationTime

  if gameState.location == "outdoors" then
    -- === SCREEN-SPACE: Sky, stars, aurora, mountains ===
    environment.drawSky(screenW, screenH, time)
    environment.drawStars(screenW, screenH, time)
    lighting.drawCosmicAurora(screenW, screenH, time)
    environment.drawMountainRange(screenW, screenH, gameState.camera.y, time)
  end

  -- === CAMERA-SPACE: push/translate ===
  love.graphics.push()
  love.graphics.translate(
    math.floor(-gameState.camera.x + screenW / 2),
    math.floor(-gameState.camera.y + screenH / 2)
  )

  if gameState.location == "outdoors" then
    M.drawOutdoors(time)
  else
    M.drawInterior(time)
  end

  -- Player shadow (world-space)
  if gameState.location == "outdoors" then
    lighting.drawPlayerShadow(gameState.player.x, gameState.player.y)
  end

  -- Player (world-space — no manual camX/camY subtraction)
  player.draw(gameState.player, time)

  -- NPCs (world-space — no manual camX/camY subtraction)
  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj, time)
  end

  love.graphics.pop()
  -- === END CAMERA-SPACE ===

  -- === SCREEN-SPACE overlays ===
  if gameState.location == "outdoors" then
    environment.drawSnow(screenW, screenH)
    environment.drawWindOverlay(screenW, screenH, time)
    lighting.drawAmbientOverlay(screenW, screenH)
    M.drawHUD(time)
  end

  -- Dialogue
  if gameState.dialogueBox then
    M.drawDialogueBox()
  end

  -- Proximity prompts
  if not gameState.dialogueBox then
    if gameState.nearBuildingDoor then
      love.graphics.setColor(0.9, 0.85, 0.7, 0.9)
      love.graphics.printf("\xe2\x86\x91 Enter " .. gameState.nearBuildingDoor.name, 0, screenH - 60, screenW, "center")
    end
    if gameState.nearbyNPC then
      love.graphics.setColor(0.9, 0.85, 0.7, 0.9)
      love.graphics.printf("E: Talk to " .. gameState.nearbyNPC.name, 0, screenH - 40, screenW, "center")
    end
    if gameState.nearbyPortal then
      love.graphics.setColor(0.9, 0.85, 0.7, 0.9)
      love.graphics.printf("E: " .. (gameState.nearbyPortal.label or "Enter"), 0, screenH - 40, screenW, "center")
    end
  end

  -- Pause
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

-- =============================================
-- DRAW: OUTDOORS (inside translate block — world coordinates)
-- =============================================

function M.drawOutdoors(time)
  local gs = areas.GRID_SIZE

  -- Ground terrain
  environment.drawGround(time)

  -- Prayer flags (behind buildings for depth)
  environment.drawPrayerFlags(time)

  -- Building shadows
  for _, b in ipairs(areas.buildings) do
    lighting.drawBuildingShadow(
      b.x * gs, b.y * gs, b.width * gs, b.height * gs
    )
  end

  -- Suspension bridges
  environment.drawBridges(time)

  -- Buildings (Nepali stone lodges)
  for _, b in ipairs(areas.buildings) do
    local bx = b.x * gs
    local by = b.y * gs
    local bw = b.width * gs
    local bh = b.height * gs

    -- Warm glow
    lighting.drawBuildingGlow(bx, by, bw, bh, b.windowColor)

    -- Draw building by style
    if b.style == "lodge" then
      M.drawLodge(bx, by, bw, bh, b, time)
    elseif b.style == "temple" then
      M.drawTemple(bx, by, bw, bh, b, time)
    elseif b.style == "dome" then
      M.drawDome(bx, by, bw, bh, b, time)
    else
      M.drawGenericBuilding(bx, by, bw, bh, b)
    end

    -- Door (Nepali style — thick timber frame, wooden planks, brass handle)
    M.drawBuildingDoor(b, gs, time)

    -- Building name
    love.graphics.setColor(0.9, 0.85, 0.75, 0.8)
    local nameW = love.graphics.getFont():getWidth(b.name)
    love.graphics.print(b.name, bx + bw / 2 - nameW / 2, by - 14)
  end

  -- Decorations
  environment.drawDecorations(time)
end

-- =============================================
-- NEPALI DOOR (thick timber frame, carved planks, brass hardware)
-- =============================================

function M.drawBuildingDoor(b, gs, time)
  local doorX = b.doorX * gs + 2
  local doorBaseY = b.doorY * gs
  local doorW = 28
  local doorH = 32

  -- Stone step / threshold
  love.graphics.setColor(0.50, 0.45, 0.38)
  love.graphics.rectangle("fill", doorX - 4, doorBaseY - 2, doorW + 8, 6, 1, 1)
  -- Step highlight
  love.graphics.setColor(0.58, 0.53, 0.44, 0.5)
  love.graphics.rectangle("fill", doorX - 2, doorBaseY - 2, doorW + 4, 2)

  -- Door recess (dark interior visible behind door)
  love.graphics.setColor(0.06, 0.05, 0.04)
  love.graphics.rectangle("fill", doorX - 1, doorBaseY - doorH + 4, doorW + 2, doorH - 2)

  -- Door body (dark wood planks)
  love.graphics.setColor(0.32, 0.22, 0.12)
  love.graphics.rectangle("fill", doorX, doorBaseY - doorH + 4, doorW, doorH - 6, 2, 2)

  -- Vertical plank lines
  love.graphics.setColor(0.26, 0.18, 0.09, 0.5)
  for px = doorX + 7, doorX + doorW - 4, 7 do
    love.graphics.line(px, doorBaseY - doorH + 6, px, doorBaseY - 4)
  end

  -- Horizontal cross beams (two iron bands)
  love.graphics.setColor(0.28, 0.24, 0.20, 0.6)
  local bandY1 = doorBaseY - doorH * 0.65
  local bandY2 = doorBaseY - doorH * 0.3
  love.graphics.rectangle("fill", doorX + 1, bandY1, doorW - 2, 3)
  love.graphics.rectangle("fill", doorX + 1, bandY2, doorW - 2, 3)

  -- Timber door frame (thick, Nepali-style carved wood)
  love.graphics.setColor(0.40, 0.28, 0.14)
  love.graphics.setLineWidth(3)
  -- Left jamb
  love.graphics.rectangle("fill", doorX - 4, doorBaseY - doorH + 2, 5, doorH)
  -- Right jamb
  love.graphics.rectangle("fill", doorX + doorW - 1, doorBaseY - doorH + 2, 5, doorH)
  -- Lintel (top beam)
  love.graphics.rectangle("fill", doorX - 4, doorBaseY - doorH, doorW + 8, 6, 1, 1)
  love.graphics.setLineWidth(1)

  -- Carved lintel detail (decorative notches)
  love.graphics.setColor(0.35, 0.24, 0.12, 0.5)
  for i = 0, 4 do
    local notchX = doorX + i * (doorW / 4)
    love.graphics.rectangle("fill", notchX, doorBaseY - doorH + 1, 3, 3)
  end

  -- Brass door handle (round ring pull — Nepali style)
  love.graphics.setColor(0.72, 0.58, 0.20)
  local handleX = doorX + doorW - 9
  local handleY = doorBaseY - doorH * 0.45
  love.graphics.circle("fill", handleX, handleY, 3.5)
  love.graphics.setColor(0.60, 0.48, 0.15)
  love.graphics.circle("line", handleX, handleY, 3.5)
  -- Handle mount plate
  love.graphics.setColor(0.65, 0.52, 0.18)
  love.graphics.rectangle("fill", handleX - 2, handleY - 5, 4, 4, 1, 1)

  -- Warm interior glow spilling out
  love.graphics.setColor(0.95, 0.70, 0.25, 0.08 + math.sin((time or 0) * 1.5) * 0.03)
  love.graphics.rectangle("fill", doorX + 2, doorBaseY - doorH + 8, doorW - 4, doorH - 12)

  -- Light spill on ground in front of door
  love.graphics.setColor(0.90, 0.65, 0.20, 0.06)
  love.graphics.ellipse("fill", doorX + doorW / 2, doorBaseY + 6, doorW * 0.6, 8)
end

-- =============================================
-- NEPALI LODGE (stone walls, painted metal roof, small windows)
-- =============================================

function M.drawLodge(bx, by, bw, bh, b, time)
  local color = b.color or {0.45, 0.40, 0.35}
  local roofColor = b.roofColor or {0.72, 0.18, 0.12}
  local stories = b.stories or 1
  local roofH = bh * 0.3
  local wallH = bh - roofH

  -- Stone wall base
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.rectangle("fill", bx, by + roofH, bw, wallH, 2, 2)

  -- Stone texture (horizontal mortar lines)
  love.graphics.setColor(color[1] - 0.06, color[2] - 0.06, color[3] - 0.06, 0.5)
  local rowH = wallH / (stories * 3)
  for i = 1, stories * 3 - 1 do
    local yy = by + roofH + i * rowH
    love.graphics.line(bx + 1, yy, bx + bw - 1, yy)
  end
  -- Vertical joints (offset per row)
  for i = 0, stories * 3 - 1 do
    local yy = by + roofH + i * rowH
    local offset = (i % 2 == 0) and 0 or (bw / 6)
    for j = 1, 5 do
      local xx = bx + j * (bw / 6) + offset
      if xx > bx and xx < bx + bw then
        love.graphics.line(xx, yy, xx, yy + rowH)
      end
    end
  end

  -- Painted metal roof (corrugated look)
  love.graphics.setColor(roofColor[1], roofColor[2], roofColor[3])
  love.graphics.polygon("fill",
    bx - 4, by + roofH,
    bx + bw + 4, by + roofH,
    bx + bw / 2, by
  )
  -- Corrugation lines
  love.graphics.setColor(roofColor[1] + 0.08, roofColor[2] + 0.08, roofColor[3] + 0.08, 0.4)
  for i = 1, 5 do
    local t = i / 6
    local lx = bx - 4 + (bw + 8) * t
    local ly = by + roofH - roofH * (0.5 - math.abs(t - 0.5)) * 2
    love.graphics.line(lx, by + roofH, bx + bw / 2, by)
  end

  -- Snow on roof
  love.graphics.setColor(0.90, 0.92, 0.96, 0.5)
  love.graphics.polygon("fill",
    bx + 6, by + roofH,
    bx + bw - 6, by + roofH,
    bx + bw / 2, by + 6
  )

  -- Windows with warm glow
  local winColor = b.windowColor or {0.90, 0.70, 0.30}
  if stories >= 2 then
    -- Two rows of windows
    M.drawWindows(bx, by + roofH + wallH * 0.1, bw, wallH * 0.35, winColor)
    M.drawWindows(bx, by + roofH + wallH * 0.55, bw, wallH * 0.35, winColor)
  else
    M.drawWindows(bx, by + roofH + wallH * 0.15, bw, wallH * 0.5, winColor)
  end

  -- Chimney with smoke
  love.graphics.setColor(0.35, 0.30, 0.25)
  love.graphics.rectangle("fill", bx + bw * 0.7, by + 4, 6, roofH - 4)
  love.graphics.setColor(0.7, 0.7, 0.7, 0.15)
  for i = 1, 3 do
    local sx = bx + bw * 0.7 + 3 + math.sin((time or 0) * 0.8 + i) * 4
    local sy = by + 4 - i * 6
    love.graphics.circle("fill", sx, sy, 3 + i)
  end
end

function M.drawWindows(bx, by, bw, wh, winColor)
  local numWins = math.max(1, math.floor(bw / 40))
  local winW = 10
  local winH = math.min(wh * 0.7, 10)
  local spacing = bw / (numWins + 1)
  for i = 1, numWins do
    local wx = bx + spacing * i - winW / 2
    local wy = by + (wh - winH) / 2
    -- Warm glow
    love.graphics.setColor(winColor[1], winColor[2], winColor[3], 0.5)
    love.graphics.rectangle("fill", wx, wy, winW, winH, 1, 1)
    -- Window frame
    love.graphics.setColor(0.35, 0.25, 0.15)
    love.graphics.rectangle("line", wx, wy, winW, winH, 1, 1)
    -- Cross bar
    love.graphics.line(wx + winW / 2, wy, wx + winW / 2, wy + winH)
    love.graphics.line(wx, wy + winH / 2, wx + winW, wy + winH / 2)
  end
end

-- =============================================
-- NEPALI TEMPLE (white-washed, golden roof, prayer items)
-- =============================================

function M.drawTemple(bx, by, bw, bh, b, time)
  local color = b.color or {0.88, 0.82, 0.68}
  local roofColor = b.roofColor or {0.90, 0.75, 0.20}

  -- White-washed stone walls
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.rectangle("fill", bx + 2, by + bh * 0.35, bw - 4, bh * 0.65, 2, 2)

  -- Tiered golden roof
  love.graphics.setColor(roofColor[1], roofColor[2], roofColor[3])
  -- Lower roof tier
  love.graphics.polygon("fill",
    bx - 6, by + bh * 0.35,
    bx + bw + 6, by + bh * 0.35,
    bx + bw - 2, by + bh * 0.2,
    bx + 2, by + bh * 0.2
  )
  -- Upper roof tier
  love.graphics.polygon("fill",
    bx + 4, by + bh * 0.2,
    bx + bw - 4, by + bh * 0.2,
    bx + bw / 2, by + 4
  )

  -- Golden pinnacle
  love.graphics.setColor(1.0, 0.85, 0.30)
  love.graphics.circle("fill", bx + bw / 2, by + 2, 3)

  -- Eyes of Buddha
  love.graphics.setColor(0.15, 0.15, 0.40)
  love.graphics.circle("fill", bx + bw / 2 - 4, by + bh * 0.25, 2)
  love.graphics.circle("fill", bx + bw / 2 + 4, by + bh * 0.25, 2)

  -- Ornamental border
  love.graphics.setColor(roofColor[1], roofColor[2], roofColor[3], 0.6)
  love.graphics.rectangle("line", bx + 2, by + bh * 0.35, bw - 4, bh * 0.65, 2, 2)

  -- Windows
  local winColor = b.windowColor or {1.0, 0.90, 0.50}
  love.graphics.setColor(winColor[1], winColor[2], winColor[3], 0.6)
  love.graphics.rectangle("fill", bx + bw * 0.3, by + bh * 0.5, 8, 10, 1, 1)
  love.graphics.rectangle("fill", bx + bw * 0.6, by + bh * 0.5, 8, 10, 1, 1)

  -- Golden glow
  local pulse = math.sin((time or 0) * 1.5) * 0.03 + 0.06
  love.graphics.setColor(1.0, 0.90, 0.40, pulse)
  love.graphics.circle("fill", bx + bw / 2, by + bh * 0.5, bw * 0.8)
end

-- =============================================
-- OBSERVATORY DOME
-- =============================================

function M.drawDome(bx, by, bw, bh, b, time)
  local color = b.color or {0.35, 0.38, 0.45}

  -- Base structure
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.rectangle("fill", bx, by + bh * 0.5, bw, bh * 0.5, 2, 2)

  -- Dome
  love.graphics.setColor(color[1] + 0.1, color[2] + 0.1, color[3] + 0.1)
  love.graphics.arc("fill", bx + bw / 2, by + bh * 0.5, bw / 2, math.pi, 0)

  -- Slit
  love.graphics.setColor(0.05, 0.05, 0.15)
  love.graphics.rectangle("fill", bx + bw / 2 - 2, by + bh * 0.15, 4, bh * 0.35)

  -- Star reflection
  local glow = math.sin((time or 0) * 0.8) * 0.15 + 0.25
  love.graphics.setColor(0.60, 0.75, 1.0, glow)
  love.graphics.circle("fill", bx + bw / 2, by + bh * 0.3, 3)

  -- Snow on dome
  love.graphics.setColor(0.90, 0.92, 0.96, 0.3)
  love.graphics.arc("fill", bx + bw / 2, by + bh * 0.5, bw / 2 - 2, math.pi + 0.4, -0.4)
end

-- =============================================
-- GENERIC BUILDING FALLBACK
-- =============================================

function M.drawGenericBuilding(bx, by, bw, bh, b)
  local color = b.color or {0.40, 0.35, 0.30}
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.rectangle("fill", bx, by, bw, bh, 2, 2)
  love.graphics.setColor(color[1] + 0.1, color[2] + 0.1, color[3] + 0.1)
  love.graphics.rectangle("line", bx, by, bw, bh, 2, 2)
end

-- =============================================
-- DRAW: INTERIOR (inside translate block)
-- =============================================

function M.drawInterior(time)
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  local gs = areas.GRID_SIZE
  local fc = interior.floorColor or {0.35, 0.25, 0.18}
  local wc = interior.wallColor or {0.40, 0.30, 0.22}

  -- Floor planks
  for y = 0, interior.height do
    for x = 0, interior.width do
      local sx = x * gs
      local sy = y * gs
      local hash = (x * 73 + y * 137) % 256 / 256
      love.graphics.setColor(fc[1] + hash * 0.05, fc[2] + hash * 0.04, fc[3] + hash * 0.03)
      love.graphics.rectangle("fill", sx, sy, gs, gs)
      love.graphics.setColor(fc[1] - 0.05, fc[2] - 0.05, fc[3] - 0.05, 0.3)
      love.graphics.line(sx, sy, sx + gs, sy)
    end
  end

  -- Walls (top row)
  for x = 0, interior.width do
    local sx = x * gs
    love.graphics.setColor(wc[1], wc[2], wc[3])
    love.graphics.rectangle("fill", sx, 0, gs, gs)
  end

  -- Furniture
  if interior.furniture then
    for _, f in ipairs(interior.furniture) do
      local fx = f.x * gs
      local fy = f.y * gs
      M.drawFurniture(f, fx, fy, time)
    end
  end

  -- Portals
  if gameState.currentPortals then
    for _, portal in ipairs(gameState.currentPortals) do
      local px = portal.x * gs
      local py = portal.y * gs
      love.graphics.setColor(0.3, 0.5, 0.9, 0.3 + math.sin(time * 2) * 0.1)
      love.graphics.circle("fill", px + 16, py + 16, 14)
      love.graphics.setColor(0.5, 0.7, 1.0, 0.8)
      love.graphics.circle("line", px + 16, py + 16, 14)
      if portal.label then
        love.graphics.setColor(0.8, 0.85, 1.0, 0.8)
        local lw = love.graphics.getFont():getWidth(portal.label)
        love.graphics.print(portal.label, px + 16 - lw / 2, py - 8)
      end
    end
  end

  -- Exit indicator
  local exitX = interior.exitX * gs
  local exitY = interior.exitY * gs
  love.graphics.setColor(0.4, 0.8, 0.4, 0.3 + math.sin(time * 3) * 0.1)
  love.graphics.rectangle("fill", exitX, exitY, gs, gs)
  love.graphics.setColor(0.5, 0.9, 0.5, 0.7)
  love.graphics.print("EXIT", exitX + 2, exitY + 10)
end

function M.drawFurniture(f, fx, fy, time)
  if f.type == "lantern" then
    love.graphics.setColor(0.9, 0.7, 0.3, 0.15)
    love.graphics.circle("fill", fx + 16, fy + 16, 40)
    love.graphics.setColor(0.9, 0.7, 0.3, 0.8)
    love.graphics.circle("fill", fx + 16, fy + 12, 4)
    love.graphics.setColor(0.50, 0.40, 0.30)
    love.graphics.rectangle("fill", fx + 12, fy + 8, 8, 12, 1, 1)
  elseif f.type == "stove" then
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", fx + 4, fy + 4, 24, 24, 2, 2)
    love.graphics.setColor(0.9, 0.4, 0.1, 0.5)
    love.graphics.rectangle("fill", fx + 8, fy + 8, 16, 10, 1, 1)
  elseif f.type == "table" then
    love.graphics.setColor(0.45, 0.32, 0.18)
    love.graphics.rectangle("fill", fx + 2, fy + 8, 28, 16, 2, 2)
  elseif f.type == "altar" then
    love.graphics.setColor(0.85, 0.75, 0.20)
    love.graphics.rectangle("fill", fx + 4, fy + 4, 24, 20, 3, 3)
    love.graphics.setColor(1.0, 0.85, 0.30, 0.3)
    love.graphics.circle("fill", fx + 16, fy + 14, 30)
  elseif f.type == "muse_pedestal" then
    love.graphics.setColor(0.60, 0.55, 0.45)
    love.graphics.rectangle("fill", fx + 8, fy + 12, 16, 16, 2, 2)
    love.graphics.setColor(0.85, 0.80, 0.70)
    love.graphics.rectangle("fill", fx + 10, fy + 8, 12, 6, 2, 2)
    if f.label then
      love.graphics.setColor(0.9, 0.85, 0.7, 0.8)
      love.graphics.print(f.label, fx + 6, fy + 28)
    end
  elseif f.type == "incense" then
    love.graphics.setColor(0.50, 0.40, 0.30)
    love.graphics.rectangle("fill", fx + 12, fy + 16, 8, 10)
    love.graphics.setColor(0.70, 0.70, 0.70, 0.2)
    for i = 1, 3 do
      local smokeX = fx + 16 + math.sin(time * 0.6 + i) * 3
      local smokeY = fy + 16 - i * 5
      love.graphics.circle("fill", smokeX, smokeY, 2 + i * 0.5)
    end
  elseif f.type == "prayer_wheel" then
    love.graphics.setColor(0.85, 0.65, 0.15)
    love.graphics.circle("fill", fx + 16, fy + 16, 10)
    love.graphics.setColor(0.70, 0.50, 0.10)
    love.graphics.circle("line", fx + 16, fy + 16, 10)
    local angle = time * 2
    love.graphics.setColor(0.95, 0.80, 0.25, 0.6)
    love.graphics.line(fx + 16, fy + 16, fx + 16 + math.cos(angle) * 8, fy + 16 + math.sin(angle) * 8)
  else
    love.graphics.setColor(0.40, 0.30, 0.20)
    love.graphics.rectangle("fill", fx + 4, fy + 4, 24, 24, 2, 2)
  end
end

-- =============================================
-- HUD (screen-space)
-- =============================================

function M.drawHUD(time)
  local screenW = love.graphics.getWidth()

  local zone = areas.getZoneAt(gameState.player.gridX, gameState.player.gridY)
  local zoneName = zone and zone.name or "Kala Patthar"

  -- Check if on bridge
  local onBridge, bridge = areas.isOnBridge(gameState.player.gridX, gameState.player.gridY)
  if onBridge and bridge then
    zoneName = bridge.name
  end

  love.graphics.setColor(0.9, 0.85, 0.75, 0.9)
  love.graphics.print("\xe2\x9b\xb0 " .. zoneName, 15, 15)

  love.graphics.setColor(0.6, 0.7, 0.9, 0.7)
  love.graphics.print("Deep Space", 15, 35)

  local temp = lighting.getTemperature()
  love.graphics.setColor(0.6, 0.8, 1.0, 0.7)
  love.graphics.print("\xe2\x9d\x84 " .. temp .. "\xc2\xb0C", screenW - 100, 15)

  environment.drawAltitudeIndicator(gameState.player.y)
end

-- =============================================
-- DIALOGUE BOX
-- =============================================

function M.drawDialogueBox()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  local boxW = 600
  local boxH = 120
  local boxX = (screenW - boxW) / 2
  local boxY = screenH - boxH - 30

  love.graphics.setColor(0.10, 0.08, 0.06, 0.92)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 8, 8)

  love.graphics.setColor(0.50, 0.40, 0.25)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 8, 8)

  -- Decorative corners
  love.graphics.setColor(0.65, 0.55, 0.35)
  local cs = 10
  love.graphics.line(boxX + 4, boxY + 4, boxX + cs, boxY + 4)
  love.graphics.line(boxX + 4, boxY + 4, boxX + 4, boxY + cs)
  love.graphics.line(boxX + boxW - 4, boxY + 4, boxX + boxW - cs, boxY + 4)
  love.graphics.line(boxX + boxW - 4, boxY + 4, boxX + boxW - 4, boxY + cs)
  love.graphics.line(boxX + 4, boxY + boxH - 4, boxX + cs, boxY + boxH - 4)
  love.graphics.line(boxX + 4, boxY + boxH - 4, boxX + 4, boxY + boxH - cs)
  love.graphics.line(boxX + boxW - 4, boxY + boxH - 4, boxX + boxW - cs, boxY + boxH - 4)
  love.graphics.line(boxX + boxW - 4, boxY + boxH - 4, boxX + boxW - 4, boxY + boxH - cs)

  love.graphics.setColor(0.95, 0.85, 0.60)
  love.graphics.print(gameState.dialogueBox.npc, boxX + 20, boxY + 12)

  love.graphics.setColor(0.85, 0.80, 0.70)
  love.graphics.printf(gameState.dialogueBox.text, boxX + 20, boxY + 35, boxW - 40, "left")

  love.graphics.setColor(0.6, 0.7, 0.6, 0.6 + math.sin(gameState.animationTime * 3) * 0.3)
  love.graphics.print("Press E to close", boxX + boxW - 130, boxY + boxH - 20)
end

-- =============================================
-- INPUT
-- =============================================

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

  if key == "up" then
    if gameState.nearBuildingDoor and gameState.location == "outdoors" then
      local b = gameState.nearBuildingDoor
      gameState.transition = {
        phase = "out", timer = 0, duration = 0.2,
        callback = function() M.enterBuilding(b.interior) end
      }
      return
    end
  end

  if key == "e" then
    if gameState.nearbyPortal then
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

function M.textinput(text)
  if gameState.paused then
    pauseMenu.textinput(text)
  end
end

return M

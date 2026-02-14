-- mixia/init.lua
-- Multi-level city planet hub (Coruscant/Taris inspired)
-- Daylight theme with elevator between city levels

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local floors = require("mixia.floors")
local buildings = require("mixia.buildings")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

-- Elevator state
local elevatorState = {
  active = false,
  selectedFloor = 3,
  floors = {},
  animationTime = 0
}

function M.load()
  gameState.currentFloor = gameState.currentFloor or 5  -- Start at Skyline Terrace
  gameState.location = "floor"
  gameState.interiorId = nil

  local floorDef = floors.getFloor(gameState.currentFloor)
  local startX = floorDef.elevatorPos.x * 32 + 16
  local startY = floorDef.elevatorPos.y * 32 + 16
  gameState.player = player.new(startX, startY)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.nearElevator = false
  gameState.collisionMap = floors.createFloorCollisionMap(gameState.currentFloor)
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.buildingEntryCooldown = 0
  gameState.transition = nil
  gameState.returnLocation = nil
  gameState.returnPosition = nil
  gameState.returnFloor = nil
  gameState.fadeInFromStarfox = false

  gameState.credits = 1000000
  gameState.notes = currency.load()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false}
  gameState.paused = false
  gameState.animationTime = 0
  gameState.unlockedQuests = gameState.unlockedQuests or {}

  M.setupFloorNPCs(gameState.currentFloor)

  audio.load()
  pauseMenu.load()

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
function M.clearShopItems() gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false} end
function M.setPaused(paused) gameState.paused = paused end

function M.setFadeInFromStarfox(enable)
  gameState.fadeInFromStarfox = enable
end

-- ═══════════════════════════════════════
-- FLOOR MANAGEMENT
-- ═══════════════════════════════════════

function M.setupFloorNPCs(floorId)
  gameState.currentNPCs = {}
  local floorDef = floors.getFloor(floorId)
  if floorDef and floorDef.npcs then
    for _, npcData in ipairs(floorDef.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
    end
  end
end

function M.changeFloor(newFloor)
  gameState.currentFloor = newFloor
  gameState.location = "floor"
  gameState.interiorId = nil

  local floorDef = floors.getFloor(newFloor)
  if floorDef then
    gameState.player.gridX = floorDef.elevatorPos.x
    gameState.player.gridY = floorDef.elevatorPos.y
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y

    gameState.collisionMap = floors.createFloorCollisionMap(newFloor)
    gameState.currentPortals = nil
    M.setupFloorNPCs(newFloor)
  end

  elevatorState.active = false
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

  -- Initialize maze state if this is a maze interior
  if interior.isMaze then
    gameState.mazeState = M.initMazeState(interior)
    -- Place player at maze entrance
    gameState.player.gridX = interior.entranceX or interior.exitX
    gameState.player.gridY = interior.entranceY or (interior.exitY - 1)
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
  else
    gameState.mazeState = nil
  end

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
  gameState.location = "floor"
  local buildingId = gameState.interiorId
  gameState.interiorId = nil
  gameState.buildingEntryCooldown = 0.5
  gameState.mazeState = nil  -- Clear maze state on exit

  local floorDef = floors.getFloor(gameState.currentFloor)
  if floorDef then
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY + 1
      gameState.player.x = gameState.player.gridX * 32 + 16
      gameState.player.y = gameState.player.gridY * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
      gameState.returnPosition = nil
    else
      if floorDef.buildings then
        for _, b in ipairs(floorDef.buildings) do
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
    end

    gameState.collisionMap = floors.createFloorCollisionMap(gameState.currentFloor)
    gameState.currentPortals = nil
    M.setupFloorNPCs(gameState.currentFloor)
  end
end

-- ═══════════════════════════════════════
-- MAZE STATE (Ancient Citadel)
-- ═══════════════════════════════════════

function M.initMazeState(interior)
  local state = {
    timer = 0,
    -- Obstacle tracking
    darts = {},
    activeTraps = {},
    -- Per-obstacle timers
    obstacleTimers = {},
    -- Crumbling floor states: gridKey -> {state="solid"|"crumbling"|"fallen"|"reforming", timer=0}
    crumbleStates = {},
    -- Swinging blade angles
    bladeAngles = {},
    -- Boulder chase state
    boulder = {
      active = false,
      x = 0, y = 0,
      triggered = false,
      speed = interior.boulderChase and interior.boulderChase.boulderSpeed or 3.5,
      rumbleTimer = 0,
      escaped = false,
    },
    -- Treasure chest
    chest = {
      opened = false,
      glowTimer = 0,
      openAnim = 0,
      rewardCollected = false,
    },
    -- Knockback state
    knockback = {
      active = false,
      timer = 0,
      duration = 0.8,
      flashTimer = 0,
      message = "",
      messageTimer = 0,
    },
    -- Screen shake
    shake = {x = 0, y = 0, intensity = 0, timer = 0},
    -- Particle effects
    particles = {},
    -- Torch flicker positions (decorative along walls)
    torches = {},
    -- Warning message
    warningMessage = "",
    warningTimer = 0,
  }

  -- Initialize obstacle timers
  if interior.obstacles then
    for i, obs in ipairs(interior.obstacles) do
      state.obstacleTimers[i] = 0
      if obs.type == "blade" then
        state.bladeAngles[i] = 0
      end
    end
  end

  -- Find torch positions (placed along walls for ambience)
  if interior.mazeMap then
    for y = 1, #interior.mazeMap - 1 do
      for x = 1, #interior.mazeMap[y] - 1 do
        if interior.mazeMap[y][x] == 1 then
          -- Check if adjacent to a path
          local adjPath = false
          if y > 1 and interior.mazeMap[y-1] and interior.mazeMap[y-1][x] == 0 then adjPath = true end
          if y < #interior.mazeMap and interior.mazeMap[y+1] and interior.mazeMap[y+1][x] == 0 then adjPath = true end
          if x > 1 and interior.mazeMap[y][x-1] == 0 then adjPath = true end
          if x < #interior.mazeMap[y] and interior.mazeMap[y][x+1] == 0 then adjPath = true end
          -- Place torches sparsely
          if adjPath and ((x + y * 7) % 11 == 0) then
            table.insert(state.torches, {x = x - 1, y = y - 1, flicker = math.random() * math.pi * 2})
          end
        end
      end
    end
  end

  return state
end

function M.updateMaze(dt, interior)
  local ms = gameState.mazeState
  if not ms then return end

  ms.timer = ms.timer + dt
  ms.chest.glowTimer = ms.chest.glowTimer + dt

  -- Update screen shake
  if ms.shake.timer > 0 then
    ms.shake.timer = ms.shake.timer - dt
    ms.shake.x = (math.random() - 0.5) * ms.shake.intensity * 2
    ms.shake.y = (math.random() - 0.5) * ms.shake.intensity * 2
    ms.shake.intensity = ms.shake.intensity * 0.95
    if ms.shake.timer <= 0 then
      ms.shake.x = 0
      ms.shake.y = 0
    end
  end

  -- Update warning message
  if ms.warningTimer > 0 then
    ms.warningTimer = ms.warningTimer - dt
    if ms.warningTimer <= 0 then
      ms.warningMessage = ""
    end
  end

  -- Update knockback
  if ms.knockback.active then
    ms.knockback.timer = ms.knockback.timer - dt
    ms.knockback.flashTimer = ms.knockback.flashTimer + dt
    if ms.knockback.timer <= 0 then
      ms.knockback.active = false
      -- Teleport player back to entrance
      local ex = interior.entranceX or interior.exitX
      local ey = interior.entranceY or (interior.exitY - 1)
      gameState.player.gridX = ex
      gameState.player.gridY = ey
      gameState.player.x = ex * 32 + 16
      gameState.player.y = ey * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
      -- Reset boulder
      ms.boulder.active = false
      ms.boulder.triggered = false
      ms.boulder.escaped = false
    end
    return  -- Freeze movement during knockback
  end

  -- Update message timer
  if ms.knockback.messageTimer > 0 then
    ms.knockback.messageTimer = ms.knockback.messageTimer - dt
  end

  local px = gameState.player.gridX
  local py = gameState.player.gridY

  -- Check maze tile under player for traps
  if interior.mazeMap then
    local row = interior.mazeMap[py + 1]
    if row then
      local cell = row[px + 1]
      -- Check trap types
      if cell == 2 then -- Dart trap tile
        -- Darts are handled by obstacle timers below
      elseif cell == 3 then -- Spike pit
        -- Check if spikes are currently active
        local spikesUp = (math.floor(ms.timer / 1.5) % 2 == 0)
        if spikesUp then
          M.triggerMazeKnockback("Impaled by spike trap!", interior)
        end
      elseif cell == 5 then -- Crumbling floor
        local key = px .. "," .. py
        if not ms.crumbleStates[key] then
          ms.crumbleStates[key] = {state = "crumbling", timer = 0.8}
        end
      elseif cell == 7 and not ms.boulder.triggered then -- Boulder trigger
        ms.boulder.triggered = true
        ms.boulder.active = true
        ms.boulder.x = interior.boulderChase.boulderStartX
        ms.boulder.y = interior.boulderChase.boulderStartY
        ms.shake.intensity = 8
        ms.shake.timer = 2.0
        ms.warningMessage = "RUN!!!"
        ms.warningTimer = 3.0
        -- Spawn rumble particles
        for i = 1, 20 do
          table.insert(ms.particles, {
            x = ms.boulder.x * 32 + 16,
            y = ms.boulder.y * 32 + 16,
            vx = (math.random() - 0.5) * 100,
            vy = (math.random() - 0.5) * 100,
            life = 1.0 + math.random() * 0.5,
            maxLife = 1.5,
            size = 2 + math.random() * 3,
            color = {0.6, 0.5, 0.3},
          })
        end
      elseif cell == 8 and not ms.chest.opened then -- Treasure chest
        -- Player reached the treasure! (handled by interaction)
      end
    end
  end

  -- Update obstacles
  if interior.obstacles then
    for i, obs in ipairs(interior.obstacles) do
      ms.obstacleTimers[i] = (ms.obstacleTimers[i] or 0) + dt

      if obs.type == "blade" then
        ms.bladeAngles[i] = (ms.bladeAngles[i] or 0) + dt * obs.swingSpeed
        -- Check if blade hits player
        local bladeCenterX = obs.gridX
        local bladeCenterY = obs.gridY
        local bladeAngle = math.sin(ms.bladeAngles[i])
        -- Blade occupies center tile and swings to adjacent tiles
        local bladeReach = math.floor(bladeAngle * 1.5 + 0.5)
        if py == bladeCenterY and (px == bladeCenterX or px == bladeCenterX + bladeReach) then
          if math.abs(bladeAngle) > 0.3 then
            M.triggerMazeKnockback("Sliced by swinging blade!", interior)
          end
        end
      elseif obs.type == "fire" then
        local cycle = ms.obstacleTimers[i] % (obs.interval + obs.activeTime)
        local isActive = cycle < obs.activeTime
        if isActive and px == obs.gridX and py == obs.gridY then
          M.triggerMazeKnockback("Scorched by fire jet!", interior)
        end
      elseif obs.type == "spikes" then
        local cycle = ms.obstacleTimers[i] % (obs.interval + obs.activeTime)
        local isActive = cycle < obs.activeTime
        if isActive and px == obs.gridX and py == obs.gridY then
          M.triggerMazeKnockback("Impaled by spike trap!", interior)
        end
      end
    end
  end

  -- Update crumbling floors
  for key, cs in pairs(ms.crumbleStates) do
    cs.timer = cs.timer - dt
    if cs.state == "crumbling" and cs.timer <= 0 then
      cs.state = "fallen"
      cs.timer = 3.0
      -- Make tile impassable (pit)
      local kx, ky = key:match("(%d+),(%d+)")
      kx, ky = tonumber(kx), tonumber(ky)
      if gameState.collisionMap[ky] then
        gameState.collisionMap[ky][kx] = true
      end
      -- Check if player is on fallen tile
      if px == kx and py == ky then
        M.triggerMazeKnockback("Fell through crumbling floor!", interior)
      end
    elseif cs.state == "fallen" and cs.timer <= 0 then
      cs.state = "solid"
      -- Restore walkability
      local kx, ky = key:match("(%d+),(%d+)")
      kx, ky = tonumber(kx), tonumber(ky)
      if gameState.collisionMap[ky] then
        gameState.collisionMap[ky][kx] = false
      end
      ms.crumbleStates[key] = nil
    end
  end

  -- Update boulder
  if ms.boulder.active then
    ms.boulder.rumbleTimer = ms.boulder.rumbleTimer + dt
    ms.shake.intensity = math.max(ms.shake.intensity, 3)
    ms.shake.timer = math.max(ms.shake.timer, 0.1)

    -- Move boulder
    local bc = interior.boulderChase
    if bc.chaseDirection == "left" then
      ms.boulder.x = ms.boulder.x - ms.boulder.speed * dt
    elseif bc.chaseDirection == "right" then
      ms.boulder.x = ms.boulder.x + ms.boulder.speed * dt
    elseif bc.chaseDirection == "up" then
      ms.boulder.y = ms.boulder.y - ms.boulder.speed * dt
    elseif bc.chaseDirection == "down" then
      ms.boulder.y = ms.boulder.y + ms.boulder.speed * dt
    end

    -- Spawn dust particles behind boulder
    if ms.boulder.rumbleTimer > 0.05 then
      ms.boulder.rumbleTimer = 0
      for i = 1, 3 do
        table.insert(ms.particles, {
          x = ms.boulder.x * 32 + 16 + (math.random() - 0.5) * 20,
          y = ms.boulder.y * 32 + 16 + (math.random() - 0.5) * 20,
          vx = (math.random() - 0.5) * 60,
          vy = -math.random() * 40,
          life = 0.5 + math.random() * 0.3,
          maxLife = 0.8,
          size = 2 + math.random() * 4,
          color = {0.5, 0.4, 0.3},
        })
      end
    end

    -- Check if boulder hit player
    local boulderGridX = math.floor(ms.boulder.x + 0.5)
    local boulderGridY = math.floor(ms.boulder.y + 0.5)
    if math.abs(px - boulderGridX) <= 1 and math.abs(py - boulderGridY) <= 1 then
      M.triggerMazeKnockback("Crushed by the boulder!", interior)
    end

    -- Check if boulder passed the escape point (player survived)
    if ms.boulder.x < -2 or ms.boulder.x > interior.width + 2 or
       ms.boulder.y < -2 or ms.boulder.y > interior.height + 2 then
      ms.boulder.active = false
      ms.boulder.escaped = true
    end
  end

  -- Update particles
  for i = #ms.particles, 1, -1 do
    local p = ms.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + 80 * dt  -- gravity
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(ms.particles, i)
    end
  end
end

function M.triggerMazeKnockback(message, interior)
  local ms = gameState.mazeState
  if ms.knockback.active then return end  -- Already knocked back
  ms.knockback.active = true
  ms.knockback.timer = ms.knockback.duration
  ms.knockback.flashTimer = 0
  ms.knockback.message = message
  ms.knockback.messageTimer = 2.5
  ms.shake.intensity = 12
  ms.shake.timer = 0.5
  -- Spawn hit particles
  for i = 1, 15 do
    table.insert(ms.particles, {
      x = gameState.player.x,
      y = gameState.player.y,
      vx = (math.random() - 0.5) * 200,
      vy = (math.random() - 0.5) * 200,
      life = 0.6 + math.random() * 0.4,
      maxLife = 1.0,
      size = 1 + math.random() * 3,
      color = {1, 0.3, 0.1},
    })
  end
end

-- ═══════════════════════════════════════
-- ELEVATOR
-- ═══════════════════════════════════════

function M.openElevator()
  elevatorState.active = true
  elevatorState.selectedFloor = gameState.currentFloor
  elevatorState.floors = floors.getElevatorFloors(gameState.unlockedQuests)
  elevatorState.animationTime = 0
end

function M.closeElevator()
  elevatorState.active = false
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
  elevatorState.animationTime = elevatorState.animationTime + dt

  if elevatorState.active then
    return
  end

  -- Freeze gameplay while dialogue is open
  if gameState.dialogueBox then return end

  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  -- Update maze obstacles and boulder if in a maze interior
  if gameState.mazeState and gameState.interiorId then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior and interior.isMaze then
      M.updateMaze(dt, interior)
      -- Skip normal movement during knockback
      if gameState.mazeState.knockback.active then
        camera.update(gameState.camera, gameState.player.x, gameState.player.y)
        return
      end
    end
  end

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
  gameState.nearElevator = false

  if gameState.location == "floor" then
    local floorDef = floors.getFloor(gameState.currentFloor)
    if floorDef and floorDef.buildings and gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(floorDef.buildings) do
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

    if floors.isOnElevator(gameState.currentFloor, gameState.player.gridX, gameState.player.gridY) then
      gameState.nearElevator = true
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
  local floorDef = floors.getFloor(gameState.currentFloor)
  local colors = floorDef and floorDef.colorScheme or floors.COLORS

  -- Sky/background based on level
  if gameState.location == "floor" then
    love.graphics.push()
    M.drawBackground(floorDef)
    love.graphics.pop()
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.setBlendMode("alpha")
  love.graphics.translate(-gameState.camera.x + love.graphics.getWidth() / 2,
                          -gameState.camera.y + love.graphics.getHeight() / 2)

  if gameState.location == "floor" then
    M.drawFloor(floorDef)
  else
    M.drawInterior()
  end

  player.draw(gameState.player, gameState.animationTime)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj)
  end

  love.graphics.pop()

  love.graphics.setColor(1, 1, 1)
  M.drawUI()

  if elevatorState.active then
    M.drawElevator()
  end

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
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  end
end

function M.drawForegroundFog()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local t = gameState.animationTime

  if gameState.currentFloor == 3 then
    -- Warm Parisian golden-hour haze drifting through
    for i = 1, 5 do
      local fogX = (i * 290 + t * 7) % (screenW + 500) - 250
      local fogY = screenH * 0.5 + math.sin(t * 0.1 + i * 1.3) * 40
      local fogAlpha = 0.035 + math.sin(t * 0.15 + i * 0.5) * 0.015
      love.graphics.setColor(0.9, 0.85, 0.7, fogAlpha)
      love.graphics.ellipse("fill", fogX, fogY, 160 + i * 18, 28 + i * 6)
    end
  elseif gameState.currentFloor == 2 then
    -- Atmospheric Parisian mist drifting through narrow streets
    for i = 1, 5 do
      local fogX = (i * 260 + t * 9) % (screenW + 500) - 250
      local fogY = screenH * 0.45 + math.sin(t * 0.08 + i * 1.1) * 45
      local fogAlpha = 0.04 + math.sin(t * 0.15 + i * 0.7) * 0.02
      love.graphics.setColor(0.6, 0.55, 0.48, fogAlpha)
      love.graphics.ellipse("fill", fogX, fogY, 140 + i * 15, 25 + i * 5)
    end
  end
end

function M.drawBackground(floorDef)
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  if not floorDef then return end

  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1)

  local lightLevel = floorDef.lightLevel or 0.8
  local bg = floorDef.colorScheme.bg
  local t = gameState.animationTime

  -- Reset line width so sky gradient lines render consistently
  -- (dialogue box border sets lineWidth=2 which persists across frames)
  love.graphics.setLineWidth(1)

  if gameState.currentFloor >= 4 then
    -- ═══════════════════════════════════════
    -- FLOORS 4-5: ENDLESS SKYLINE (FADED DISTANT CITY)
    -- ═══════════════════════════════════════
    local isF4 = (gameState.currentFloor == 4)
    -- Sky gradient (F4 darker steel-blue, F5 bright cerulean)
    local skyTop, skyBottom
    if isF4 then
      skyTop = {0.32, 0.50, 0.72}
      skyBottom = {0.55, 0.62, 0.72}
    else
      skyTop = {0.42, 0.65, 0.95}
      skyBottom = {0.68, 0.8, 0.92}
    end
    for row = 0, screenH do
      local frac = row / screenH
      love.graphics.setColor(
        skyTop[1] + (skyBottom[1] - skyTop[1]) * frac,
        skyTop[2] + (skyBottom[2] - skyTop[2]) * frac,
        skyTop[3] + (skyBottom[3] - skyTop[3]) * frac
      )
      love.graphics.line(0, row, screenW, row)
    end

    -- Very light atmospheric haze (reduced from before)
    local hazeA = isF4 and 0.06 or 0.04
    love.graphics.setColor(0.75, 0.82, 0.9, hazeA)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Sun with full glow
    local sunX = screenW - 140
    local sunY = 65
    for r = 100, 10, -5 do
      local a = 0.05 + (100 - r) / 100 * 0.4
      love.graphics.setColor(1, 0.95, 0.8, a)
      love.graphics.circle("fill", sunX, sunY, r)
    end
    love.graphics.setColor(1, 0.97, 0.85, 0.95)
    love.graphics.circle("fill", sunX, sunY, 30)

    local skyline = floorDef.skyline or {}

    -- ── Helper: draw a building with type variation ──
    local function drawSkylineBuilding(bx, bw, bh, seed, fadeAlpha, hazeColor)
      local by = screenH - bh
      local bType = seed % 5  -- 0=box, 1=stepped, 2=dome, 3=spire tower, 4=wide

      -- Main body
      love.graphics.setColor(hazeColor[1], hazeColor[2], hazeColor[3], fadeAlpha)
      love.graphics.rectangle("fill", bx, by, bw, bh)

      if bType == 1 then
        -- Stepped/tiered top
        local stepW = bw * 0.6
        local stepH = bh * 0.15
        love.graphics.rectangle("fill", bx + (bw - stepW)/2, by - stepH, stepW, stepH)
        local step2W = stepW * 0.5
        love.graphics.rectangle("fill", bx + (bw - step2W)/2, by - stepH * 1.8, step2W, stepH * 0.8)
      elseif bType == 2 then
        -- Dome top
        love.graphics.setColor(hazeColor[1] + 0.03, hazeColor[2] + 0.03, hazeColor[3] + 0.02, fadeAlpha)
        love.graphics.ellipse("fill", bx + bw/2, by, bw/2, bw * 0.3)
      elseif bType == 3 then
        -- Spire/antenna tower
        local spireH = 20 + (seed * 7 % 30)
        love.graphics.setColor(hazeColor[1], hazeColor[2], hazeColor[3], fadeAlpha * 0.9)
        love.graphics.polygon("fill", bx + bw/2 - 3, by, bx + bw/2, by - spireH, bx + bw/2 + 3, by)
      elseif bType == 4 then
        -- Wide building with rooftop structures
        local boxW = bw * 0.25
        local boxH = 12 + (seed * 3 % 15)
        love.graphics.rectangle("fill", bx + bw * 0.2, by - boxH, boxW, boxH)
        love.graphics.rectangle("fill", bx + bw * 0.6, by - boxH * 0.7, boxW * 0.7, boxH * 0.7)
      end

      -- Faded windows (very subtle)
      love.graphics.setColor(hazeColor[1] + 0.08, hazeColor[2] + 0.07, hazeColor[3] + 0.05, fadeAlpha * 0.5)
      local winSpacingY = (bType == 4) and 8 or 12
      for wy = by + 8, screenH - 10, winSpacingY do
        for wx = bx + 4, bx + bw - 6, 7 do
          love.graphics.rectangle("fill", wx, wy, 3, 4)
        end
      end
    end

    -- ── Layer 1: Very far background (heavily faded, blue-shifted) ──
    local farCount = 18
    for i = 1, farCount do
      local seed = i * 7 + 42
      local gap = 15 + (seed * 3 % 25)  -- spacing between buildings
      local bx = (i - 1) * (screenW + 300) / farCount - 80 + gap
      local bw = 18 + (seed * 13 % 28)
      local bh = 120 + (seed * 17 % 200)
      if skyline.maxHeight then bh = math.min(bh, skyline.maxHeight * 0.7) end
      drawSkylineBuilding(bx, bw, bh, seed, 0.3, {0.62, 0.7, 0.82})
    end

    -- ── Layer 2: Mid distance (more visible now) ──
    local midCount = 12
    for i = 1, midCount do
      local seed = i * 11 + 137
      local gap = 20 + (seed * 5 % 35)
      local bx = (i - 1) * (screenW + 200) / midCount - 40 + gap
      local bw = 22 + (seed * 19 % 34)
      local bh = 150 + (seed * 23 % 220)
      drawSkylineBuilding(bx, bw, bh, seed, 0.45, {0.55, 0.62, 0.74})
    end

    -- ── Layer 3: Nearer buildings (clearly visible) ──
    local nearCount = 8
    for i = 1, nearCount do
      local seed = i * 29 + 256
      local gap = 30 + (seed * 7 % 40)
      local bx = (i - 1) * (screenW + 100) / nearCount - 10 + gap
      local bw = 28 + (seed * 31 % 38)
      local bh = 180 + (seed * 37 % 240)
      drawSkylineBuilding(bx, bw, bh, seed, 0.6, {0.48, 0.56, 0.68})

      -- Sparkle / sun glints on glass
      if skyline.sparkle then
        local sparklePhase = math.sin(t * 2.5 + i * 1.7) * 0.5 + 0.5
        if sparklePhase > 0.85 then
          local by = screenH - bh
          local sx = bx + 5 + (seed * 13 % (math.max(1, bw - 10)))
          local sy = by + 5 + (seed * 7 % math.max(1, math.floor(bh / 3)))
          local brightness = (sparklePhase - 0.85) / 0.15
          love.graphics.setColor(1, 1, 0.95, brightness * 0.7)
          love.graphics.setLineWidth(1)
          love.graphics.line(sx - 5, sy, sx + 5, sy)
          love.graphics.line(sx, sy - 5, sx, sy + 5)
          love.graphics.setColor(1, 1, 1, brightness * 0.5)
          love.graphics.circle("fill", sx, sy, 2)
        end
      end
    end

    -- Minimal distance haze overlay
    local distHaze = isF4 and 0.04 or 0.02
    love.graphics.setColor(0.75, 0.82, 0.9, distHaze)
    love.graphics.rectangle("fill", 0, screenH * 0.5, screenW, screenH * 0.5)

    -- Spaceships cruising in background
    for i = 1, 3 do
      local shipSpeed = 20 + i * 12
      local shipY = 80 + i * 100
      local shipDir = (i % 2 == 0) and 1 or -1
      local shipX
      if shipDir > 0 then
        shipX = (t * shipSpeed + i * 500) % (screenW + 200) - 100
      else
        shipX = screenW + 100 - ((t * shipSpeed + i * 500) % (screenW + 200))
      end
      local shipSize = 6 + i * 2
      -- Ship body
      love.graphics.setColor(0.6, 0.65, 0.7, 0.6)
      if shipDir > 0 then
        love.graphics.polygon("fill",
          shipX - shipSize, shipY - shipSize/3,
          shipX + shipSize, shipY,
          shipX - shipSize, shipY + shipSize/3)
      else
        love.graphics.polygon("fill",
          shipX + shipSize, shipY - shipSize/3,
          shipX - shipSize, shipY,
          shipX + shipSize, shipY + shipSize/3)
      end
      -- Engine glow
      local glowX = shipDir > 0 and (shipX - shipSize - 3) or (shipX + shipSize + 3)
      love.graphics.setColor(0.3, 0.6, 1, 0.45)
      love.graphics.circle("fill", glowX, shipY, 3)
      love.graphics.setColor(0.3, 0.6, 1, 0.15)
      love.graphics.circle("fill", glowX, shipY, 8)
    end

    -- Wispy clouds drifting
    for i = 1, 6 do
      local cx = (i * 230 + t * 6) % (screenW + 300) - 150
      local cloudA = isF4 and 0.15 or 0.22
      love.graphics.setColor(1, 1, 1, cloudA)
      love.graphics.ellipse("fill", cx, 45 + i * 18, 90 + i * 10, 18 + i * 3)
    end

  elseif gameState.currentFloor == 3 then
    -- ═══════════════════════════════════════
    -- FLOOR 3: PARISIAN BOULEVARD - UPPER (warm, elegant)
    -- ═══════════════════════════════════════
    -- Warm Parisian sky gradient (filtered afternoon sun)
    local skyTop3 = {0.6, 0.7, 0.88}
    local skyMid3 = {0.82, 0.78, 0.72}
    local skyBot3 = {0.75, 0.68, 0.58}
    for row = 0, screenH do
      local frac = row / screenH
      local r, g, b
      if frac < 0.4 then
        local f = frac / 0.4
        r = skyTop3[1] + (skyMid3[1] - skyTop3[1]) * f
        g = skyTop3[2] + (skyMid3[2] - skyTop3[2]) * f
        b = skyTop3[3] + (skyMid3[3] - skyTop3[3]) * f
      else
        local f = (frac - 0.4) / 0.6
        r = skyMid3[1] + (skyBot3[1] - skyMid3[1]) * f
        g = skyMid3[2] + (skyBot3[2] - skyMid3[2]) * f
        b = skyMid3[3] + (skyBot3[3] - skyMid3[3]) * f
      end
      love.graphics.setColor(r, g, b)
      love.graphics.line(0, row, screenW, row)
    end

    -- Atmospheric haze (makes background feel distant)
    love.graphics.setColor(0.78, 0.76, 0.72, 0.2)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Filtered sun (partly behind buildings, warm glow)
    local sunX3 = screenW * 0.75
    local sunY3 = 55
    for r = 70, 10, -5 do
      local a = 0.03 + (70 - r) / 70 * 0.2
      love.graphics.setColor(1, 0.92, 0.7, a)
      love.graphics.circle("fill", sunX3, sunY3, r)
    end
    love.graphics.setColor(1, 0.95, 0.8, 0.6)
    love.graphics.circle("fill", sunX3, sunY3, 18)

    -- Sun rays filtering down (golden hour)
    love.graphics.setColor(1, 0.93, 0.7, 0.04)
    for i = 1, 5 do
      local rx = sunX3 - 80 + i * 40
      love.graphics.polygon("fill", rx, sunY3 + 20, rx + 8, sunY3 + 20, rx + 80, screenH, rx - 40, screenH)
    end

    -- ── Parisian Haussmann-style buildings ──
    local parisBuildings3 = {
      {x = 0, w = 65, h = 220, floors = 6, balcony = true, mansard = true},
      {x = 68, w = 55, h = 200, floors = 5, balcony = true, mansard = true},
      {x = 130, w = 48, h = 170, floors = 5, balcony = false, mansard = true},
      {x = 185, w = 70, h = 240, floors = 7, balcony = true, mansard = true},
      {x = 262, w = 52, h = 190, floors = 5, balcony = true, mansard = false},
      {x = 322, w = 60, h = 210, floors = 6, balcony = true, mansard = true},
      {x = 390, w = 45, h = 175, floors = 5, balcony = false, mansard = true},
      {x = 442, w = 68, h = 230, floors = 6, balcony = true, mansard = true},
      {x = 518, w = 50, h = 185, floors = 5, balcony = true, mansard = false},
      {x = 575, w = 58, h = 205, floors = 6, balcony = true, mansard = true},
      {x = 640, w = 55, h = 195, floors = 5, balcony = false, mansard = true},
      {x = 700, w = 65, h = 225, floors = 6, balcony = true, mansard = true},
    }
    for idx, pb in ipairs(parisBuildings3) do
      local bx = pb.x
      local bw = pb.w
      local bh = math.min(pb.h, screenH * 0.55)
      local by = screenH - bh

      -- Building facade (warm cream/sandstone)
      local warmShift = (idx % 3) * 0.02
      love.graphics.setColor(0.88 + warmShift, 0.84 + warmShift, 0.76 + warmShift, 0.5)
      love.graphics.rectangle("fill", bx, by, bw, bh)

      -- Shadow on right side of building
      love.graphics.setColor(0, 0, 0, 0.08)
      love.graphics.rectangle("fill", bx + bw - 6, by, 6, bh)

      -- Mansard roof (angled, zinc-grey with dormers)
      if pb.mansard then
        local roofH = 18 + (idx * 3 % 8)
        love.graphics.setColor(0.4, 0.42, 0.45, 0.6)
        love.graphics.polygon("fill", bx - 2, by, bx + bw + 2, by, bx + bw - 4, by - roofH, bx + 4, by - roofH)
        -- Dormer windows
        love.graphics.setColor(0.85, 0.82, 0.75, 0.5)
        for dx = bx + 10, bx + bw - 15, math.max(1, math.floor(bw / 3)) do
          love.graphics.rectangle("fill", dx, by - roofH + 4, 8, 10)
          love.graphics.polygon("fill", dx - 1, by - roofH + 4, dx + 4, by - roofH - 2, dx + 9, by - roofH + 4)
        end
      end

      -- Tall French windows with warm interior light
      local floorH = math.max(1, math.floor(bh / pb.floors))
      for fy = 0, pb.floors - 1 do
        local winY = by + fy * floorH + 6
        -- Window row
        for wx = bx + 5, bx + bw - 12, 12 do
          -- Window frame (dark ironwork)
          love.graphics.setColor(0.2, 0.2, 0.22, 0.4)
          love.graphics.rectangle("fill", wx, winY, 8, floorH - 10)
          -- Warm interior glow
          love.graphics.setColor(0.95, 0.88, 0.6, 0.3)
          love.graphics.rectangle("fill", wx + 1, winY + 1, 6, floorH - 12)
        end
        -- Iron balcony railing on select floors
        if pb.balcony and (fy == 1 or fy == 3) then
          love.graphics.setColor(0.15, 0.15, 0.18, 0.5)
          love.graphics.setLineWidth(1)
          local balY = winY + floorH - 10
          love.graphics.line(bx + 3, balY, bx + bw - 3, balY)
          -- Intricate ironwork pattern (scrolls)
          for bix = bx + 6, bx + bw - 8, 8 do
            love.graphics.arc("line", bix, balY + 2, 3, 0, math.pi)
            love.graphics.arc("line", bix + 4, balY + 2, 3, 0, math.pi)
          end
        end
      end

      -- Horizontal cornice lines
      love.graphics.setColor(0.82, 0.78, 0.7, 0.4)
      love.graphics.rectangle("fill", bx - 1, by + math.floor(bh * 0.3), bw + 2, 2)
      love.graphics.rectangle("fill", bx - 2, by + math.floor(bh * 0.65), bw + 4, 3)
    end

    -- ── Ornate Parisian ironwork streetlights ──
    for i = 1, 14 do
      local lx = (i - 1) * screenW / 13 + 20 + (i * 17 % 15)
      local lBaseY = screenH - 10
      local lTopY = screenH - 130 - (i * 7 % 30)
      local poleH = lBaseY - lTopY
      -- Ornate pole (tapered)
      love.graphics.setColor(0.12, 0.12, 0.14, 0.65)
      love.graphics.setLineWidth(2)
      love.graphics.line(lx, lBaseY, lx, lTopY)
      -- Decorative base (wider)
      love.graphics.rectangle("fill", lx - 5, lBaseY - 8, 10, 8)
      love.graphics.rectangle("fill", lx - 3, lBaseY - 14, 6, 6)
      -- Mid-pole scroll ornament
      local midY = lTopY + poleH * 0.5
      love.graphics.setLineWidth(1)
      love.graphics.arc("line", lx - 4, midY, 4, -math.pi/2, math.pi/2)
      love.graphics.arc("line", lx + 4, midY, 4, math.pi/2, math.pi * 1.5)
      -- Curved arm(s) at top with lantern
      local armDir = (i % 2 == 0) and 1 or -1
      -- Main arm
      love.graphics.setLineWidth(1.5)
      local armEndX = lx + armDir * 18
      local armEndY = lTopY - 4
      love.graphics.line(lx, lTopY, lx + armDir * 6, lTopY - 8, armEndX, armEndY)
      -- S-curve scroll on arm
      love.graphics.arc("line", lx + armDir * 4, lTopY - 3, 3, 0, math.pi)
      -- Second arm (opposite side, shorter)
      local arm2EndX = lx - armDir * 12
      local arm2EndY = lTopY
      love.graphics.line(lx, lTopY + 4, arm2EndX, arm2EndY)
      -- Lantern on main arm
      love.graphics.setColor(0.2, 0.18, 0.15, 0.7)
      love.graphics.rectangle("fill", armEndX - 4, armEndY - 2, 8, 12)
      love.graphics.polygon("fill", armEndX - 5, armEndY + 10, armEndX + 5, armEndY + 10, armEndX + 3, armEndY + 13, armEndX - 3, armEndY + 13)
      -- Lantern warm glow
      love.graphics.setColor(1, 0.9, 0.55, 0.2)
      love.graphics.circle("fill", armEndX, armEndY + 5, 10)
      love.graphics.setColor(1, 0.92, 0.6, 0.08)
      love.graphics.circle("fill", armEndX, armEndY + 5, 22)
      -- Small lantern on second arm
      love.graphics.setColor(0.2, 0.18, 0.15, 0.5)
      love.graphics.rectangle("fill", arm2EndX - 3, arm2EndY - 1, 6, 9)
      love.graphics.setColor(1, 0.9, 0.55, 0.12)
      love.graphics.circle("fill", arm2EndX, arm2EndY + 4, 7)
      -- Finial on top of pole
      love.graphics.setColor(0.12, 0.12, 0.14, 0.6)
      love.graphics.circle("fill", lx, lTopY - 2, 3)
      love.graphics.polygon("fill", lx - 2, lTopY - 2, lx, lTopY - 7, lx + 2, lTopY - 2)
      -- Lamp shadow on ground
      love.graphics.setColor(0, 0, 0, 0.06)
      love.graphics.ellipse("fill", armEndX, lBaseY + 2, 18, 4)
    end

    -- ── Ironwork fence / railing in foreground ──
    love.graphics.setColor(0.1, 0.1, 0.12, 0.3)
    love.graphics.setLineWidth(1.5)
    local railY = screenH - 25
    love.graphics.line(0, railY, screenW, railY)
    love.graphics.line(0, railY + 12, screenW, railY + 12)
    for i = 0, screenW, 12 do
      -- Vertical bar
      love.graphics.line(i, railY, i, railY + 12)
      -- Spear finial on top
      love.graphics.polygon("fill", i - 1.5, railY, i, railY - 4, i + 1.5, railY)
    end
    -- Scroll pattern between bars
    love.graphics.setLineWidth(1)
    for i = 6, screenW - 6, 24 do
      love.graphics.arc("line", i, railY + 6, 5, 0, math.pi)
      love.graphics.arc("line", i + 12, railY + 6, 5, math.pi, math.pi * 2)
    end

    -- ── Building shadows cast on ground (long afternoon) ──
    for idx, pb in ipairs(parisBuildings3) do
      local shadowLen = 40 + (idx * 7 % 20)
      love.graphics.setColor(0, 0, 0, 0.04)
      love.graphics.polygon("fill",
        pb.x, screenH,
        pb.x + pb.w, screenH,
        pb.x + pb.w + shadowLen, screenH,
        pb.x + shadowLen, screenH)
      love.graphics.setColor(0, 0, 0, 0.03)
      love.graphics.rectangle("fill", pb.x, screenH - 15, pb.w + shadowLen, 15)
    end

    -- ── Potted topiaries and flower boxes ──
    for i = 1, 6 do
      local px = (i * 143 + 30) % screenW
      local py = screenH - 20
      -- Ornate planter
      love.graphics.setColor(0.45, 0.35, 0.28, 0.5)
      love.graphics.rectangle("fill", px - 8, py, 16, 12, 2, 2)
      love.graphics.setColor(0.5, 0.4, 0.32, 0.4)
      love.graphics.rectangle("fill", px - 9, py, 18, 3)
      -- Topiary sphere
      love.graphics.setColor(0.25, 0.45, 0.2, 0.6)
      love.graphics.circle("fill", px, py - 8, 9)
      love.graphics.setColor(0.2, 0.38, 0.15, 0.5)
      love.graphics.circle("fill", px, py - 8, 7)
      -- Stem
      love.graphics.setColor(0.3, 0.22, 0.12, 0.5)
      love.graphics.rectangle("fill", px - 1, py - 2, 2, 4)
    end

    -- ── Gentle drifting fog ──
    for i = 1, 5 do
      local fogX = (i * 210 + t * 8) % (screenW + 400) - 200
      local fogY = screenH * 0.5 + math.sin(t * 0.15 + i * 0.9) * 25
      local fogAlpha = 0.04 + math.sin(t * 0.2 + i * 1.1) * 0.02
      love.graphics.setColor(0.85, 0.82, 0.75, fogAlpha)
      love.graphics.ellipse("fill", fogX, fogY, 130 + i * 15, 22 + i * 4)
    end

    -- ── Jungle canopy visible far below (Surface peeking through) ──
    local jungleA3 = 0.15
    love.graphics.setColor(0.03, 0.08, 0.03, jungleA3)
    for i = 0, screenW, 20 do
      local treeH = 25 + math.sin(i * 0.07) * 15 + math.sin(i * 0.17 + 3) * 10
      love.graphics.ellipse("fill", i, screenH + 5, 18, treeH)
    end
    love.graphics.setColor(0.02, 0.06, 0.02, jungleA3 * 0.8)
    for i = 10, screenW, 30 do
      local treeH = 18 + math.sin(i * 0.09 + 1) * 12
      love.graphics.ellipse("fill", i, screenH + 8, 22, treeH)
    end
    for i = 1, 6 do
      local gx = (i * 131 + 50) % screenW
      local gy = screenH - 8 + math.sin(t * 0.5 + i) * 3
      local glow3 = math.sin(t * 0.8 + i * 1.5) * 0.3 + 0.5
      love.graphics.setColor(0.2, 0.8, 0.3, glow3 * jungleA3 * 1.5)
      love.graphics.circle("fill", gx, gy, 4)
      love.graphics.setColor(0.2, 0.8, 0.3, glow3 * jungleA3 * 0.5)
      love.graphics.circle("fill", gx, gy, 10)
    end

  elseif gameState.currentFloor == 2 then
    -- ═══════════════════════════════════════
    -- FLOOR 2: PARISIAN LOWER QUARTERS (grittier, less sun, romantic)
    -- ═══════════════════════════════════════
    -- Muted warm sky (less sun than floor 3, overcast warmth)
    local skyTop2 = {0.52, 0.55, 0.62}
    local skyMid2 = {0.62, 0.58, 0.52}
    local skyBot2 = {0.55, 0.48, 0.4}
    for row = 0, screenH do
      local frac = row / screenH
      local r, g, b
      if frac < 0.35 then
        local f = frac / 0.35
        r = skyTop2[1] + (skyMid2[1] - skyTop2[1]) * f
        g = skyTop2[2] + (skyMid2[2] - skyTop2[2]) * f
        b = skyTop2[3] + (skyMid2[3] - skyTop2[3]) * f
      else
        local f = (frac - 0.35) / 0.65
        r = skyMid2[1] + (skyBot2[1] - skyMid2[1]) * f
        g = skyMid2[2] + (skyBot2[2] - skyMid2[2]) * f
        b = skyMid2[3] + (skyBot2[3] - skyMid2[3]) * f
      end
      love.graphics.setColor(r, g, b)
      love.graphics.line(0, row, screenW, row)
    end

    -- Atmospheric haze (makes background feel distant)
    love.graphics.setColor(0.55, 0.52, 0.48, 0.22)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Weak sun filtering through (smaller, more diffused)
    local sunX2 = screenW * 0.8
    local sunY2 = 45
    for r = 50, 8, -4 do
      local a = 0.02 + (50 - r) / 50 * 0.12
      love.graphics.setColor(1, 0.9, 0.7, a)
      love.graphics.circle("fill", sunX2, sunY2, r)
    end
    love.graphics.setColor(1, 0.93, 0.78, 0.4)
    love.graphics.circle("fill", sunX2, sunY2, 12)

    -- Faint sun rays (fewer, weaker)
    love.graphics.setColor(1, 0.9, 0.65, 0.025)
    for i = 1, 3 do
      local rx = sunX2 - 40 + i * 35
      love.graphics.polygon("fill", rx, sunY2 + 15, rx + 5, sunY2 + 15, rx + 50, screenH, rx - 20, screenH)
    end

    -- ── Parisian buildings (narrower streets, older, more character) ──
    local parisBuildings2 = {
      {x = -5, w = 58, h = 250, floors = 7, balcony = true, chimney = true},
      {x = 56, w = 50, h = 220, floors = 6, balcony = false, chimney = true},
      {x = 112, w = 45, h = 200, floors = 6, balcony = true, chimney = false},
      {x = 162, w = 62, h = 260, floors = 7, balcony = true, chimney = true},
      {x = 230, w = 48, h = 210, floors = 6, balcony = true, chimney = false},
      {x = 285, w = 55, h = 235, floors = 7, balcony = false, chimney = true},
      {x = 346, w = 42, h = 195, floors = 5, balcony = true, chimney = false},
      {x = 394, w = 60, h = 245, floors = 7, balcony = true, chimney = true},
      {x = 460, w = 52, h = 215, floors = 6, balcony = true, chimney = false},
      {x = 518, w = 46, h = 225, floors = 6, balcony = false, chimney = true},
      {x = 570, w = 58, h = 240, floors = 7, balcony = true, chimney = true},
      {x = 634, w = 50, h = 205, floors = 6, balcony = true, chimney = false},
      {x = 690, w = 55, h = 230, floors = 6, balcony = true, chimney = true},
    }
    for idx, pb in ipairs(parisBuildings2) do
      local bx = pb.x
      local bw = pb.w
      local bh = math.min(pb.h, screenH * 0.6)
      local by = screenH - bh

      -- Building facade (slightly darker/warmer stone, weathered)
      local warmShift = (idx % 4) * 0.015
      local weathered = (idx % 3 == 0) and 0.04 or 0
      love.graphics.setColor(0.78 + warmShift - weathered, 0.74 + warmShift - weathered, 0.66 + warmShift - weathered, 0.55)
      love.graphics.rectangle("fill", bx, by, bw, bh)

      -- Shadow on right side
      love.graphics.setColor(0, 0, 0, 0.1)
      love.graphics.rectangle("fill", bx + bw - 5, by, 5, bh)

      -- Chimney stacks
      if pb.chimney then
        local chX = bx + bw * 0.3 + (idx * 7 % 10)
        love.graphics.setColor(0.5, 0.45, 0.4, 0.5)
        love.graphics.rectangle("fill", chX - 4, by - 18, 8, 18)
        love.graphics.rectangle("fill", chX - 5, by - 20, 10, 4)
        -- Faint smoke
        local smokeA = math.sin(t * 0.3 + idx) * 0.02 + 0.03
        love.graphics.setColor(0.55, 0.52, 0.48, smokeA)
        for s = 0, 2 do
          local smokeX = chX + math.sin(t * 0.25 + s * 0.8 + idx) * 6
          love.graphics.ellipse("fill", smokeX, by - 22 - s * 12, 8 + s * 4, 5 + s * 2)
        end
      end

      -- Mansard-style roof
      local roofH = 15 + (idx * 5 % 8)
      love.graphics.setColor(0.35, 0.32, 0.3, 0.6)
      love.graphics.polygon("fill", bx - 1, by, bx + bw + 1, by, bx + bw - 3, by - roofH, bx + 3, by - roofH)

      -- French windows with iron Juliet balconies
      local floorH = math.max(1, math.floor(bh / pb.floors))
      for fy = 0, pb.floors - 1 do
        local winY = by + fy * floorH + 5
        for wx = bx + 4, bx + bw - 10, 11 do
          -- Window
          love.graphics.setColor(0.18, 0.18, 0.2, 0.4)
          love.graphics.rectangle("fill", wx, winY, 7, floorH - 9)
          -- Warm glow
          love.graphics.setColor(0.9, 0.82, 0.55, 0.25)
          love.graphics.rectangle("fill", wx + 1, winY + 1, 5, floorH - 11)
        end
        -- Iron balcony railings
        if pb.balcony and (fy == 1 or fy == 2 or fy == 4) then
          love.graphics.setColor(0.12, 0.12, 0.15, 0.5)
          love.graphics.setLineWidth(1)
          local balY = winY + floorH - 9
          love.graphics.line(bx + 2, balY, bx + bw - 2, balY)
          for bix = bx + 5, bx + bw - 6, 7 do
            love.graphics.arc("line", bix, balY + 2, 2.5, 0, math.pi)
            love.graphics.arc("line", bix + 3.5, balY + 2, 2.5, 0, math.pi)
          end
        end
      end

      -- Weathering / water stains
      if idx % 3 == 0 then
        love.graphics.setColor(0.4, 0.38, 0.35, 0.06)
        love.graphics.rectangle("fill", bx + bw * 0.1, by + bh * 0.3, bw * 0.15, bh * 0.4)
      end
    end

    -- ── Vintage ironwork streetlights (lots, closer together, grittier) ──
    for i = 1, 16 do
      local lx = (i - 1) * screenW / 15 + 10 + (i * 13 % 12)
      local lBaseY = screenH - 8
      local lTopY = screenH - 115 - (i * 11 % 25)
      local poleH = lBaseY - lTopY
      -- Tapered pole
      love.graphics.setColor(0.08, 0.08, 0.1, 0.7)
      love.graphics.setLineWidth(2)
      love.graphics.line(lx, lBaseY, lx, lTopY)
      -- Ornate base bracket
      love.graphics.rectangle("fill", lx - 4, lBaseY - 6, 8, 6)
      love.graphics.setLineWidth(1)
      love.graphics.arc("line", lx - 5, lBaseY - 10, 5, 0, math.pi/2)
      love.graphics.arc("line", lx + 5, lBaseY - 10, 5, math.pi/2, math.pi)
      -- Mid-pole ring ornament
      local midY = lTopY + poleH * 0.45
      love.graphics.circle("line", lx, midY, 3)
      -- Scrollwork at mid
      love.graphics.arc("line", lx - 5, midY - 3, 4, -math.pi * 0.3, math.pi * 0.6)
      love.graphics.arc("line", lx + 5, midY - 3, 4, math.pi * 0.4, math.pi * 1.3)
      -- Curved arm with lantern
      local armDir = (i % 2 == 0) and 1 or -1
      local armEndX = lx + armDir * 16
      local armEndY = lTopY - 2
      love.graphics.setLineWidth(1.5)
      love.graphics.line(lx, lTopY + 2, lx + armDir * 5, lTopY - 6, armEndX, armEndY)
      -- Scroll decoration on arm
      love.graphics.setLineWidth(1)
      love.graphics.arc("line", lx + armDir * 3, lTopY - 1, 2.5, 0, math.pi)
      -- Lantern housing
      love.graphics.setColor(0.15, 0.14, 0.12, 0.7)
      love.graphics.rectangle("fill", armEndX - 3.5, armEndY - 1, 7, 10)
      love.graphics.polygon("fill", armEndX - 4, armEndY + 9, armEndX + 4, armEndY + 9, armEndX + 2.5, armEndY + 12, armEndX - 2.5, armEndY + 12)
      -- Warm amber glow (dimmer than floor 3)
      love.graphics.setColor(1, 0.85, 0.45, 0.15)
      love.graphics.circle("fill", armEndX, armEndY + 4, 8)
      love.graphics.setColor(1, 0.88, 0.5, 0.05)
      love.graphics.circle("fill", armEndX, armEndY + 4, 18)
      -- Finial
      love.graphics.setColor(0.08, 0.08, 0.1, 0.6)
      love.graphics.circle("fill", lx, lTopY - 1, 2.5)
      love.graphics.polygon("fill", lx - 1.5, lTopY - 1, lx, lTopY - 5, lx + 1.5, lTopY - 1)
      -- Shadow on ground
      love.graphics.setColor(0, 0, 0, 0.05)
      love.graphics.ellipse("fill", armEndX, lBaseY + 2, 14, 3)
    end

    -- ── Decorative iron gate / archway entrance (mid-screen accent) ──
    local gateX = screenW * 0.42
    local gateW = 50
    local gateH = 60
    local gateY = screenH - gateH - 5
    love.graphics.setColor(0.1, 0.1, 0.12, 0.35)
    love.graphics.setLineWidth(2)
    -- Gate pillars
    love.graphics.line(gateX, gateY + gateH, gateX, gateY)
    love.graphics.line(gateX + gateW, gateY + gateH, gateX + gateW, gateY)
    -- Arch
    love.graphics.arc("line", gateX + gateW/2, gateY, gateW/2, math.pi, 0)
    -- Ornate scrollwork inside arch
    love.graphics.setLineWidth(1)
    love.graphics.arc("line", gateX + gateW * 0.3, gateY + 5, 8, math.pi * 0.2, math.pi * 0.8)
    love.graphics.arc("line", gateX + gateW * 0.7, gateY + 5, 8, math.pi * 0.2, math.pi * 0.8)
    love.graphics.arc("line", gateX + gateW * 0.5, gateY - 5, 6, 0, math.pi)
    -- Finials on pillars
    love.graphics.circle("fill", gateX, gateY - 2, 3)
    love.graphics.circle("fill", gateX + gateW, gateY - 2, 3)

    -- ── Iron railing/fence (darker, heavier than floor 3) ──
    love.graphics.setColor(0.08, 0.08, 0.1, 0.35)
    love.graphics.setLineWidth(1.5)
    local railY2 = screenH - 18
    love.graphics.line(0, railY2, screenW, railY2)
    love.graphics.line(0, railY2 + 10, screenW, railY2 + 10)
    for i = 0, screenW, 10 do
      love.graphics.line(i, railY2, i, railY2 + 10)
      love.graphics.polygon("fill", i - 1.5, railY2, i, railY2 - 3.5, i + 1.5, railY2)
    end
    love.graphics.setLineWidth(1)
    for i = 5, screenW - 5, 20 do
      love.graphics.arc("line", i, railY2 + 5, 4, 0, math.pi)
      love.graphics.arc("line", i + 10, railY2 + 5, 4, math.pi, math.pi * 2)
    end

    -- ── Building shadows (longer, moodier) ──
    for idx, pb in ipairs(parisBuildings2) do
      local shadowLen = 50 + (idx * 9 % 25)
      love.graphics.setColor(0, 0, 0, 0.05)
      love.graphics.rectangle("fill", pb.x, screenH - 12, pb.w + shadowLen, 12)
    end

    -- ── Hardy plants in cracks / ivy on walls ──
    for i = 1, 8 do
      local px = (i * 107 + 40) % screenW
      local py = screenH - 22 + (i % 2) * 5
      -- Scrappy plant
      love.graphics.setColor(0.22, 0.38, 0.18, 0.5)
      love.graphics.setLineWidth(1)
      love.graphics.line(px, py + 5, px, py - 3)
      love.graphics.ellipse("fill", px - 3, py - 1, 4, 2.5)
      love.graphics.ellipse("fill", px + 3, py - 2, 4, 2.5)
    end

    -- ── Atmospheric fog / mist ──
    for i = 1, 7 do
      local fogX = (i * 175 + t * 10) % (screenW + 400) - 200
      local fogY = screenH * 0.4 + math.sin(t * 0.12 + i * 0.8) * 35 + i * 10
      local fogAlpha = 0.05 + math.sin(t * 0.18 + i * 0.9) * 0.025
      love.graphics.setColor(0.5, 0.47, 0.42, fogAlpha)
      love.graphics.ellipse("fill", fogX, fogY, 110 + i * 12, 20 + i * 5)
    end

    -- ── Jungle canopy visible below (Surface is closer here) ──
    local jungleA2 = 0.3
    love.graphics.setColor(0.03, 0.1, 0.03, jungleA2)
    for i = 0, screenW, 15 do
      local treeH = 35 + math.sin(i * 0.06) * 20 + math.sin(i * 0.15 + 2) * 12
      love.graphics.ellipse("fill", i, screenH + 3, 16, treeH)
    end
    love.graphics.setColor(0.02, 0.07, 0.02, jungleA2 * 0.8)
    for i = 8, screenW, 22 do
      local treeH = 28 + math.sin(i * 0.08 + 1.5) * 15
      love.graphics.ellipse("fill", i, screenH + 5, 20, treeH)
    end
    love.graphics.setColor(0.05, 0.15, 0.04, jungleA2 * 0.7)
    love.graphics.setLineWidth(1)
    for i = 1, 10 do
      local vx = (i * 87 + 20) % screenW
      local vineLen = 15 + (i * 7 % 20)
      local sway2 = math.sin(t * 0.3 + i * 0.9) * 4
      love.graphics.line(vx, screenH, vx + sway2 * 0.3, screenH - vineLen * 0.5, vx + sway2, screenH - vineLen)
    end
    for i = 1, 10 do
      local gx = (i * 97 + 30) % screenW
      local gy = screenH - 5 + math.sin(t * 0.4 + i * 1.1) * 4
      local glow2 = math.sin(t * 0.7 + i * 1.3) * 0.3 + 0.6
      love.graphics.setColor(0.2, 0.9, 0.35, glow2 * jungleA2 * 1.2)
      love.graphics.circle("fill", gx, gy, 5)
      love.graphics.setColor(0.2, 0.9, 0.35, glow2 * jungleA2 * 0.4)
      love.graphics.circle("fill", gx, gy, 14)
    end

  elseif gameState.currentFloor == 1 then
    -- ═══════════════════════════════════════
    -- FLOOR 1: THE SURFACE (Jungle Night)
    -- ═══════════════════════════════════════
    -- Dark night sky
    love.graphics.setColor(0.02, 0.04, 0.02)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Stars peeking through canopy
    math.randomseed(777)
    for i = 1, 40 do
      local sx = math.random(0, screenW)
      local sy = math.random(0, screenH / 3)
      local twinkle = math.sin(t * 2 + i * 1.3) * 0.3 + 0.5
      love.graphics.setColor(0.8, 0.9, 1, twinkle * 0.4)
      love.graphics.circle("fill", sx, sy, math.random() + 0.5)
    end

    -- Dense canopy silhouette at top
    love.graphics.setColor(0.01, 0.04, 0.01)
    for i = 0, screenW, 15 do
      local leafH = 60 + math.sin(i * 0.05) * 30 + math.sin(i * 0.13 + 2) * 20
      love.graphics.ellipse("fill", i, 0, 25, leafH)
    end

    -- Hanging vines
    love.graphics.setColor(0.08, 0.2, 0.06, 0.7)
    math.randomseed(333)
    for i = 1, 12 do
      local vx = math.random(0, screenW)
      local vLen = math.random(80, 200)
      local sway = math.sin(t * 0.5 + i * 0.7) * 8
      love.graphics.setLineWidth(2)
      local points = {}
      for j = 0, vLen, 5 do
        local jSway = sway * (j / vLen)
        table.insert(points, vx + jSway + math.sin(j * 0.05 + i) * 3)
        table.insert(points, j)
      end
      if #points >= 4 then
        love.graphics.line(points)
      end
    end

    -- Bioluminescent mushrooms on ground edge
    math.randomseed(555)
    for i = 1, 15 do
      local mx = math.random(0, screenW)
      local my = screenH - math.random(20, 80)
      local pulse = math.sin(t * 1.5 + i * 0.9) * 0.3 + 0.7
      local hue = math.random() * 0.3
      -- Glow
      love.graphics.setColor(0.1 + hue, 0.8 - hue * 0.5, 0.3 + hue, 0.15 * pulse)
      love.graphics.circle("fill", mx, my, 18)
      -- Mushroom cap
      love.graphics.setColor(0.15 + hue, 0.7 - hue * 0.3, 0.35 + hue, 0.8 * pulse)
      love.graphics.ellipse("fill", mx, my, 6, 4)
      -- Stem
      love.graphics.setColor(0.1, 0.3, 0.15, 0.6)
      love.graphics.rectangle("fill", mx - 1, my, 2, 8)
    end

    -- Fireflies / bioluminescent particles (slow, gentle drift)
    for i = 1, 25 do
      local fx = (math.sin(t * 0.04 + i * 2.1) * 0.5 + 0.5) * screenW
      local fy = (math.sin(t * 0.05 + i * 1.7) * 0.5 + 0.5) * screenH
      local fBright = math.sin(t * 0.8 + i * 1.3) * 0.4 + 0.6
      love.graphics.setColor(0.3, 1, 0.4, fBright * 0.5)
      love.graphics.circle("fill", fx, fy, 2.5)
      love.graphics.setColor(0.3, 1, 0.4, fBright * 0.15)
      love.graphics.circle("fill", fx, fy, 9)
    end

    -- Low-lying jungle mist
    love.graphics.setColor(0.1, 0.2, 0.1, 0.15)
    for i = 0, 6 do
      local mistX = (i * 200 + t * 5) % (screenW + 300) - 150
      love.graphics.ellipse("fill", mistX, screenH - 50 + math.sin(t * 0.3 + i) * 10, 150, 30)
    end

  else
    -- Lower levels / Ancient Citadel: dark with atmospheric effects
    love.graphics.setColor(bg[1] * lightLevel, bg[2] * lightLevel, bg[3] * lightLevel)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if gameState.currentFloor == 0 then
      -- Ancient Citadel atmospheric background
      -- Faint stone texture suggestion
      love.graphics.setColor(0.12, 0.1, 0.06, 0.3)
      for i = 0, screenW, 40 do
        for j = 0, screenH, 40 do
          local shade = ((i * 7 + j * 13) % 17) / 200
          love.graphics.setColor(0.1 + shade, 0.08 + shade, 0.05 + shade, 0.2)
          love.graphics.rectangle("fill", i, j, 38, 38)
        end
      end

      -- Mysterious floating dust in shafts of dim light
      for i = 1, 3 do
        local shaftX = screenW * (0.2 + i * 0.3) + math.sin(t * 0.1 + i) * 20
        love.graphics.setColor(0.4, 0.3, 0.15, 0.03)
        love.graphics.polygon("fill", shaftX - 15, 0, shaftX + 15, 0, shaftX + 40, screenH, shaftX - 40, screenH)
      end

      -- Faint ancient runes glowing on background walls
      for i = 1, 6 do
        local rx = (i * 127 + 50) % screenW
        local ry = 40 + (i * 89) % (screenH - 80)
        local glow = math.sin(t * 0.4 + i * 1.7) * 0.3 + 0.4
        love.graphics.setColor(0.6, 0.4, 0.1, glow * 0.08)
        love.graphics.circle("fill", rx, ry, 30)
        love.graphics.setColor(0.7, 0.5, 0.15, glow * 0.15)
        local runeType = i % 3
        if runeType == 0 then
          love.graphics.polygon("line", rx, ry - 12, rx - 10, ry + 8, rx + 10, ry + 8)
        elseif runeType == 1 then
          love.graphics.circle("line", rx, ry, 8)
          love.graphics.line(rx - 8, ry, rx + 8, ry)
          love.graphics.line(rx, ry - 8, rx, ry + 8)
        else
          love.graphics.ellipse("line", rx, ry, 10, 6)
          love.graphics.circle("fill", rx, ry, 2)
        end
      end
    end
  end

  -- Reset graphics state for subsequent drawing
  love.graphics.setColor(1, 1, 1)
  love.graphics.setLineWidth(1)
end

function M.drawFloor(floorDef)
  if not floorDef then return end

  local colors = floorDef.colorScheme
  local lightLevel = floorDef.lightLevel or 0.8
  local t = gameState.animationTime

  -- Floor ground
  if gameState.currentFloor == 0 then
    -- Ancient Citadel: dark stone and sand ground
    love.graphics.setColor(0.1, 0.08, 0.05)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)

    -- Scattered ancient rubble and sand
    math.randomseed(999)
    for i = 1, 25 do
      local px = math.random(0, floorDef.width * 32)
      local py = math.random(0, floorDef.height * 32)
      love.graphics.setColor(0.15, 0.12, 0.07, 0.4)
      love.graphics.ellipse("fill", px, py, math.random(8, 25), math.random(4, 12))
    end
    -- Cracked stone tiles
    for cy = 0, floorDef.height * 32, 32 do
      for cx = 0, floorDef.width * 32, 32 do
        local shade = 0.08 + ((cx * 3 + cy * 7) % 11) / 150
        love.graphics.setColor(shade, shade - 0.01, shade - 0.02, 0.3)
        love.graphics.rectangle("fill", cx + 1, cy + 1, 30, 30)
      end
    end
  elseif gameState.currentFloor == 1 then
    -- Surface: jungle ground with undergrowth
    love.graphics.setColor(0.04, 0.07, 0.03)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)

    -- Scattered moss/vegetation patches
    math.randomseed(888)
    for i = 1, 30 do
      local px = math.random(0, floorDef.width * 32)
      local py = math.random(0, floorDef.height * 32)
      love.graphics.setColor(0.06, 0.12, 0.04, 0.5)
      love.graphics.ellipse("fill", px, py, math.random(10, 30), math.random(5, 15))
    end
  elseif gameState.currentFloor == 2 then
    -- Floor 2: Darker Parisian cobblestone
    love.graphics.setColor(0.42, 0.38, 0.34)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)
    -- Cobblestone pattern
    for cy = 0, floorDef.height * 32, 16 do
      for cx = 0, floorDef.width * 32, 16 do
        local offset = (math.floor(cy / 16) % 2 == 0) and 0 or 8
        local shade = 0.38 + ((cx + cy * 7) % 17) / 170
        love.graphics.setColor(shade, shade - 0.03, shade - 0.06, 0.5)
        love.graphics.rectangle("fill", cx + offset, cy, 14, 14, 2, 2)
      end
    end
  elseif gameState.currentFloor == 3 then
    -- Floor 3: Warm Parisian sandstone / elegant pavement
    love.graphics.setColor(0.72, 0.68, 0.6)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)
    -- Herringbone brick pattern
    for cy = 0, floorDef.height * 32, 16 do
      for cx = 0, floorDef.width * 32, 32 do
        local shade = 0.66 + ((cx * 3 + cy * 5) % 19) / 190
        love.graphics.setColor(shade, shade - 0.02, shade - 0.08, 0.35)
        -- Alternating herringbone
        if (math.floor(cy / 16) % 2 == 0) then
          love.graphics.rectangle("fill", cx, cy, 28, 7, 1, 1)
          love.graphics.rectangle("fill", cx + 4, cy + 8, 28, 7, 1, 1)
        else
          love.graphics.rectangle("fill", cx + 14, cy, 7, 14, 1, 1)
          love.graphics.rectangle("fill", cx, cy + 2, 7, 14, 1, 1)
        end
      end
    end
  elseif gameState.currentFloor == 4 then
    -- Floor 4: Slate marble tile (darker, government quarter)
    love.graphics.setColor(0.68, 0.70, 0.76)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)
    for cy = 0, floorDef.height * 32, 32 do
      for cx = 0, floorDef.width * 32, 32 do
        local shade = 0.68 + ((cx + cy) % 64) / 900
        love.graphics.setColor(shade, shade + 0.01, shade + 0.02, 0.4)
        love.graphics.rectangle("fill", cx + 1, cy + 1, 30, 30)
        if (math.floor(cx / 32) + math.floor(cy / 32)) % 3 == 0 then
          love.graphics.setColor(1, 1, 1, 0.025)
          love.graphics.rectangle("fill", cx + 2, cy + 2, 28, 14)
        end
        -- Marble vein detail
        if (cx * 7 + cy * 3) % 97 < 3 then
          love.graphics.setColor(0.62, 0.64, 0.7, 0.15)
          love.graphics.line(cx + 4, cy + 8, cx + 26, cy + 22)
        end
      end
    end
  elseif gameState.currentFloor == 5 then
    -- Floor 5: Bright polished tile (rooftop, full sun)
    love.graphics.setColor(0.85, 0.87, 0.92)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)
    for cy = 0, floorDef.height * 32, 32 do
      for cx = 0, floorDef.width * 32, 32 do
        local shade = 0.85 + ((cx + cy) % 64) / 700
        love.graphics.setColor(shade, shade + 0.01, shade + 0.03, 0.3)
        love.graphics.rectangle("fill", cx + 1, cy + 1, 30, 30)
        if (math.floor(cx / 32) + math.floor(cy / 32)) % 3 == 0 then
          love.graphics.setColor(1, 1, 1, 0.05)
          love.graphics.rectangle("fill", cx + 2, cy + 2, 28, 14)
        end
      end
    end
  else
    love.graphics.setColor(colors.bg[1] * 0.9, colors.bg[2] * 0.9, colors.bg[3] * 0.9)
    love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)
  end

  -- Grid pattern
  if gameState.currentFloor == 0 then
    -- Ancient Citadel: faint stone mortar lines
    love.graphics.setColor(0.06, 0.05, 0.03, 0.15)
  elseif gameState.currentFloor == 1 then
    -- Surface: subtle root/path lines instead of grid
    love.graphics.setColor(0.08, 0.14, 0.06, 0.15)
  elseif gameState.currentFloor == 2 then
    -- Darker Parisian grid lines (mortar)
    love.graphics.setColor(0.3, 0.28, 0.25, 0.12)
  elseif gameState.currentFloor == 3 then
    -- Warm subtle grid
    love.graphics.setColor(0.6, 0.56, 0.48, 0.08)
  elseif gameState.currentFloor == 4 then
    -- Slate tile lines
    love.graphics.setColor(0.58, 0.60, 0.66, 0.2)
  elseif gameState.currentFloor == 5 then
    -- Clean modern tile lines
    love.graphics.setColor(0.75, 0.77, 0.82, 0.15)
  else
    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.1)
  end
  for x = 0, floorDef.width * 32, 32 do
    love.graphics.line(x, 0, x, floorDef.height * 32)
  end
  for y = 0, floorDef.height * 32, 32 do
    love.graphics.line(0, y, floorDef.width * 32, y)
  end

  -- Themed walking paths (high visibility, drawn before buildings)
  if floorDef.paths then
    for _, path in ipairs(floorDef.paths) do
      local px = path.x1 * 32
      local py = path.y1 * 32
      local pw = (path.x2 - path.x1 + 1) * 32
      local ph = (path.y2 - path.y1 + 1) * 32

      if gameState.currentFloor == 0 then
        -- Ancient Citadel: worn stone path with sand
        love.graphics.setColor(0.18, 0.14, 0.08, 0.7)
        love.graphics.rectangle("fill", px, py, pw, ph)
        -- Cracked stone blocks
        for fy = py, py + ph - 1, 20 do
          local rowOff = (math.floor((fy - py) / 20) % 2 == 0) and 0 or 10
          for fx = px + rowOff, px + pw - 1, 20 do
            local shade = 0.16 + ((fx + fy * 3) % 11) / 100
            love.graphics.setColor(shade, shade - 0.02, shade - 0.04, 0.4)
            love.graphics.rectangle("fill", fx + 1, fy + 1, 17, 17, 1, 1)
          end
        end
        -- Sand drifts along edges
        love.graphics.setColor(0.22, 0.18, 0.1, 0.25)
        love.graphics.ellipse("fill", px + pw * 0.3, py + 4, pw * 0.15, 6)
        love.graphics.ellipse("fill", px + pw * 0.7, py + ph - 4, pw * 0.12, 5)
        -- Ancient stone border
        love.graphics.setColor(0.25, 0.2, 0.12, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setLineWidth(1)
      elseif gameState.currentFloor == 1 then
        -- Surface: packed earth trail with wooden planks
        love.graphics.setColor(0.16, 0.12, 0.06, 0.7)
        love.graphics.rectangle("fill", px, py, pw, ph)
        -- Wooden plank slats across trail
        love.graphics.setColor(0.22, 0.16, 0.08, 0.5)
        for fx = px + 4, px + pw - 8, 18 do
          for fy = py + 2, py + ph - 4, 14 do
            love.graphics.rectangle("fill", fx, fy, 14, 10, 1, 1)
          end
        end
        -- Scattered pebbles/roots
        love.graphics.setColor(0.2, 0.15, 0.08, 0.35)
        for i = 0, pw, 20 do
          for j = 0, ph, 20 do
            local ox = (i * 7 + j * 3) % 11
            love.graphics.circle("fill", px + i + ox, py + j + (ox % 5), 2.5)
          end
        end
        -- Visible edges (mossy stone border)
        love.graphics.setColor(0.12, 0.22, 0.08, 0.6)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", px + 1, py + 1, pw - 2, ph - 2)
        love.graphics.setLineWidth(1)
      elseif gameState.currentFloor == 2 then
        -- Parisian lower: aged cobblestone walkway, very visible
        love.graphics.setColor(0.55, 0.5, 0.42, 0.75)
        love.graphics.rectangle("fill", px, py, pw, ph)
        -- Cobblestone pattern (clear individual stones)
        for fy = py, py + ph - 1, 18 do
          local rowOff = (math.floor((fy - py) / 18) % 2 == 0) and 0 or 9
          for fx = px + rowOff, px + pw - 1, 18 do
            local shade = 0.52 + ((fx + fy * 3) % 13) / 100
            love.graphics.setColor(shade, shade - 0.03, shade - 0.06, 0.45)
            love.graphics.rectangle("fill", fx + 1, fy + 1, 15, 15, 2, 2)
          end
        end
        -- Iron drain grates at intervals
        love.graphics.setColor(0.18, 0.18, 0.2, 0.35)
        for gx = px + 50, px + pw - 50, 100 do
          love.graphics.rectangle("fill", gx, py + ph/2 - 5, 22, 10)
          love.graphics.setLineWidth(1)
          for gi = 0, 20, 4 do
            love.graphics.setColor(0.1, 0.1, 0.12, 0.3)
            love.graphics.line(gx + gi, py + ph/2 - 4, gx + gi, py + ph/2 + 4)
          end
        end
        -- Strong curb edges
        love.graphics.setColor(0.35, 0.3, 0.24, 0.7)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setColor(0.42, 0.38, 0.3, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", px + 2, py + 2, pw - 4, ph - 4)
      elseif gameState.currentFloor == 3 then
        -- Parisian upper: elegant sandstone boulevard
        love.graphics.setColor(0.82, 0.76, 0.64, 0.7)
        love.graphics.rectangle("fill", px, py, pw, ph)
        -- Herringbone pattern (visible)
        for fy = py, py + ph - 1, 24 do
          for fx = px, px + pw - 1, 24 do
            love.graphics.setColor(0.78, 0.72, 0.58, 0.35)
            if (math.floor((fy - py)/24) % 2 == 0) then
              love.graphics.rectangle("fill", fx + 1, fy + 1, 20, 8, 1, 1)
              love.graphics.rectangle("fill", fx + 3, fy + 10, 20, 8, 1, 1)
            else
              love.graphics.rectangle("fill", fx + 1, fy + 1, 8, 20, 1, 1)
              love.graphics.rectangle("fill", fx + 10, fy + 3, 8, 20, 1, 1)
            end
            -- Diamond accent at intervals
            if (math.floor((fx - px)/24) + math.floor((fy - py)/24)) % 5 == 0 then
              love.graphics.setColor(0.72, 0.65, 0.45, 0.25)
              local cx = fx + 12
              local cy = fy + 12
              love.graphics.polygon("fill", cx, cy - 8, cx + 8, cy, cx, cy + 8, cx - 8, cy)
            end
          end
        end
        -- Gilded edge trim (strong)
        love.graphics.setColor(0.72, 0.6, 0.3, 0.55)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setColor(0.8, 0.7, 0.4, 0.35)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", px + 3, py + 3, pw - 6, ph - 6)
      elseif gameState.currentFloor == 4 then
        -- Upper district: polished granite walkway (darker than F5)
        love.graphics.setColor(0.72, 0.74, 0.8, 0.7)
        love.graphics.rectangle("fill", px, py, pw, ph)
        -- Granite tile pattern
        for fy = py, py + ph - 1, 32 do
          for fx = px, px + pw - 1, 32 do
            love.graphics.setColor(0.68, 0.70, 0.76, 0.25)
            love.graphics.rectangle("fill", fx + 1, fy + 1, 30, 30, 1, 1)
          end
        end
        -- Center guide stripe
        love.graphics.setColor(0.55, 0.65, 0.85, 0.12)
        love.graphics.rectangle("fill", px + pw/2 - 6, py, 12, ph)
        -- Embedded blue LED strips along edges
        local ledPulse = math.sin(t * 1.5) * 0.06 + 0.2
        love.graphics.setColor(0.4, 0.6, 0.9, ledPulse)
        love.graphics.rectangle("fill", px + 1, py, 3, ph)
        love.graphics.rectangle("fill", px + pw - 4, py, 3, ph)
        -- Steel border
        love.graphics.setColor(0.5, 0.52, 0.58, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setLineWidth(1)
      elseif gameState.currentFloor == 5 then
        -- Skyline terrace: bright glass/steel walkway
        love.graphics.setColor(0.9, 0.92, 0.96, 0.65)
        love.graphics.rectangle("fill", px, py, pw, ph)
        -- Clean tile joints
        love.graphics.setColor(0.82, 0.84, 0.9, 0.2)
        for fx = px, px + pw, 48 do
          love.graphics.line(fx, py, fx, py + ph)
        end
        for fy = py, py + ph, 48 do
          love.graphics.line(px, fy, px + pw, fy)
        end
        -- Center light guide
        love.graphics.setColor(0.7, 0.85, 1, 0.1)
        love.graphics.rectangle("fill", px + pw/2 - 8, py, 16, ph)
        -- Bright LED strips along edges
        local ledPulse5 = math.sin(t * 1.5) * 0.06 + 0.22
        love.graphics.setColor(0.5, 0.8, 1, ledPulse5)
        love.graphics.rectangle("fill", px + 1, py, 3, ph)
        love.graphics.rectangle("fill", px + pw - 4, py, 3, ph)
        -- Bright steel border
        love.graphics.setColor(0.7, 0.72, 0.78, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setLineWidth(1)
      else
        love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.2)
        love.graphics.rectangle("fill", px, py, pw, ph)
        love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setLineWidth(1)
      end
    end
  end

  -- Atmospheric haze on French village streets (floors 2-3)
  if gameState.currentFloor == 2 or gameState.currentFloor == 3 then
    -- Soft ground-level haze that makes streets feel lived-in
    local hazeAlpha = (gameState.currentFloor == 2) and 0.06 or 0.04
    local hazeR = (gameState.currentFloor == 2) and 0.5 or 0.75
    local hazeG = (gameState.currentFloor == 2) and 0.47 or 0.72
    local hazeB = (gameState.currentFloor == 2) and 0.42 or 0.65
    for i = 1, 8 do
      local hx = (i * 167 + t * 3) % (floorDef.width * 32 + 300) - 150
      local hy = (floorDef.height * 16) + math.sin(t * 0.08 + i * 1.2) * 40
      local ha = hazeAlpha + math.sin(t * 0.12 + i * 0.7) * 0.015
      love.graphics.setColor(hazeR, hazeG, hazeB, ha)
      love.graphics.ellipse("fill", hx, hy, 100 + i * 12, 30 + i * 5)
    end
  end

  -- Floor 1: Modern industrial LED streetlights (sleek chrome poles)
  if gameState.currentFloor == 1 and floorDef.paths then
    local mainPath = floorDef.paths[1]
    if mainPath then
      local pathCenterY = ((mainPath.y1 + mainPath.y2) / 2) * 32
      local pathStartX = mainPath.x1 * 32
      local pathEndX = mainPath.x2 * 32
      for lx = pathStartX + 90, pathEndX - 60, 210 do
        local epChk = floorDef.elevatorPos
        if math.abs(lx - epChk.x * 32) > 60 then
          local ly = pathCenterY - 6
          -- Chrome pole (tall, thin)
          love.graphics.setColor(0.42, 0.45, 0.50, 0.75)
          love.graphics.setLineWidth(3)
          love.graphics.line(lx, ly + 12, lx, ly - 36)
          love.graphics.setLineWidth(1)
          -- Sleek base plate
          love.graphics.setColor(0.32, 0.35, 0.40, 0.6)
          love.graphics.rectangle("fill", lx - 5, ly + 10, 10, 4)
          -- Angled LED fixture panel
          love.graphics.setColor(0.28, 0.30, 0.35, 0.7)
          love.graphics.polygon("fill", lx - 10, ly - 36, lx + 10, ly - 36, lx + 7, ly - 32, lx - 7, ly - 32)
          -- Cool blue-white LED glow
          local ledPulse = 0.92 + math.sin(t * 1.2 + lx * 0.02) * 0.08
          love.graphics.setColor(0.55, 0.82, 1, 0.07 * ledPulse)
          love.graphics.circle("fill", lx, ly - 34, 48)
          love.graphics.setColor(0.65, 0.88, 1, 0.16 * ledPulse)
          love.graphics.circle("fill", lx, ly - 34, 24)
          love.graphics.setColor(0.8, 0.94, 1, 0.35 * ledPulse)
          love.graphics.circle("fill", lx, ly - 34, 8)
          -- Ground light pool (cool tone)
          love.graphics.setColor(0.55, 0.82, 1, 0.04 * ledPulse)
          love.graphics.ellipse("fill", lx, ly + 6, 52, 15)
        end
      end
    end
    -- Lower path: smaller LED poles
    local lowerPath = floorDef.paths[2]
    if lowerPath then
      local lpCenterY = ((lowerPath.y1 + lowerPath.y2) / 2) * 32
      local lpStartX = lowerPath.x1 * 32
      local lpEndX = lowerPath.x2 * 32
      for lx = lpStartX + 120, lpEndX - 60, 250 do
        local ly = lpCenterY - 4
        love.graphics.setColor(0.42, 0.45, 0.50, 0.65)
        love.graphics.setLineWidth(2)
        love.graphics.line(lx, ly + 10, lx, ly - 28)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.32, 0.35, 0.40, 0.55)
        love.graphics.rectangle("fill", lx - 4, ly + 8, 8, 3)
        love.graphics.setColor(0.28, 0.30, 0.35, 0.65)
        love.graphics.polygon("fill", lx - 7, ly - 28, lx + 7, ly - 28, lx + 5, ly - 25, lx - 5, ly - 25)
        local ledPulse = 0.9 + math.sin(t * 1.0 + lx * 0.018) * 0.1
        love.graphics.setColor(0.55, 0.82, 1, 0.06 * ledPulse)
        love.graphics.circle("fill", lx, ly - 26, 40)
        love.graphics.setColor(0.65, 0.88, 1, 0.14 * ledPulse)
        love.graphics.circle("fill", lx, ly - 26, 19)
        love.graphics.setColor(0.8, 0.94, 1, 0.3 * ledPulse)
        love.graphics.circle("fill", lx, ly - 26, 6)
        love.graphics.setColor(0.55, 0.82, 1, 0.03 * ledPulse)
        love.graphics.ellipse("fill", lx, ly + 4, 44, 12)
      end
    end
  end

  -- Floor 2: Vintage wrought-iron gas lamps (single lantern, staggered positions)
  if gameState.currentFloor == 2 and floorDef.paths then
    local mainPath = floorDef.paths[1]
    if mainPath then
      local pathTopY = mainPath.y1 * 32
      local pathStartX = mainPath.x1 * 32
      local pathEndX = mainPath.x2 * 32
      for i = 0, math.floor((pathEndX - pathStartX) / 130) do
        local lx = pathStartX + 50 + i * 130 + (i % 2) * 35
        local epChk = floorDef.elevatorPos
        if math.abs(lx - epChk.x * 32) > 60 and lx < pathEndX - 30 then
          local ly = pathTopY + 18 + (i % 2) * 20
          -- Short wrought-iron post
          love.graphics.setColor(0.18, 0.16, 0.14, 0.72)
          love.graphics.setLineWidth(2)
          love.graphics.line(lx, ly + 10, lx, ly - 22)
          love.graphics.setLineWidth(1)
          -- Decorative curl bracket
          love.graphics.setColor(0.16, 0.14, 0.12, 0.55)
          love.graphics.arc("line", "open", lx + 1, ly - 20, 4, -math.pi, -math.pi * 0.4)
          -- Squat pedestal base
          love.graphics.setColor(0.15, 0.14, 0.12, 0.6)
          love.graphics.rectangle("fill", lx - 3, ly + 8, 6, 4)
          -- Single glass lantern housing
          love.graphics.setColor(0.22, 0.19, 0.15, 0.55)
          love.graphics.rectangle("fill", lx - 4, ly - 28, 8, 10)
          -- Pointed lantern cap
          love.graphics.setColor(0.18, 0.16, 0.14, 0.6)
          love.graphics.polygon("fill", lx - 5, ly - 28, lx, ly - 33, lx + 5, ly - 28)
          -- Warm amber gas-flame glow (slightly flickery)
          local gasPulse = 0.82 + math.sin(t * 1.6 + lx * 0.03 + i * 1.1) * 0.18
          love.graphics.setColor(1, 0.75, 0.3, 0.05 * gasPulse)
          love.graphics.circle("fill", lx, ly - 23, 34)
          love.graphics.setColor(1, 0.8, 0.38, 0.13 * gasPulse)
          love.graphics.circle("fill", lx, ly - 23, 17)
          love.graphics.setColor(1, 0.88, 0.5, 0.28 * gasPulse)
          love.graphics.circle("fill", lx, ly - 23, 5)
          -- Warm ground pool
          love.graphics.setColor(1, 0.8, 0.4, 0.03 * gasPulse)
          love.graphics.ellipse("fill", lx, ly + 4, 32, 10)
        end
      end
    end
    -- Lower path: wall-bracket gas lamps (smaller, tighter spacing)
    local lowerPath = floorDef.paths[2]
    if lowerPath then
      local lpTopY = lowerPath.y1 * 32
      local lpStartX = lowerPath.x1 * 32
      local lpEndX = lowerPath.x2 * 32
      for lx = lpStartX + 55, lpEndX - 40, 155 do
        local ly = lpTopY + 14
        -- Short bracket post
        love.graphics.setColor(0.18, 0.16, 0.14, 0.62)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(lx, ly + 8, lx, ly - 16)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.15, 0.14, 0.12, 0.5)
        love.graphics.rectangle("fill", lx - 3, ly + 6, 6, 3)
        -- Small lantern
        love.graphics.setColor(0.2, 0.18, 0.14, 0.5)
        love.graphics.rectangle("fill", lx - 3, ly - 22, 6, 8)
        love.graphics.setColor(0.18, 0.16, 0.14, 0.55)
        love.graphics.polygon("fill", lx - 4, ly - 22, lx, ly - 26, lx + 4, ly - 22)
        local gasPulse = 0.85 + math.sin(t * 1.4 + lx * 0.025) * 0.15
        love.graphics.setColor(1, 0.78, 0.32, 0.04 * gasPulse)
        love.graphics.circle("fill", lx, ly - 18, 28)
        love.graphics.setColor(1, 0.82, 0.4, 0.11 * gasPulse)
        love.graphics.circle("fill", lx, ly - 18, 14)
        love.graphics.setColor(1, 0.88, 0.52, 0.24 * gasPulse)
        love.graphics.circle("fill", lx, ly - 18, 4)
        love.graphics.setColor(1, 0.8, 0.4, 0.025 * gasPulse)
        love.graphics.ellipse("fill", lx, ly + 2, 26, 8)
      end
    end
  end

  -- Floor 3: Ornate Parisian boulevard lamps (tall, double-globe, elegant)
  if gameState.currentFloor == 3 and floorDef.paths then
    local mainPath = floorDef.paths[1]
    if mainPath then
      local pathCenterY = ((mainPath.y1 + mainPath.y2) / 2) * 32
      local pathStartX = mainPath.x1 * 32
      local pathEndX = mainPath.x2 * 32
      for lx = pathStartX + 75, pathEndX - 55, 185 do
        local epChk = floorDef.elevatorPos
        if math.abs(lx - epChk.x * 32) > 60 then
          local ly = pathCenterY
          -- Tall ornate cast-iron post
          love.graphics.setColor(0.14, 0.13, 0.11, 0.78)
          love.graphics.setLineWidth(2.5)
          love.graphics.line(lx, ly + 14, lx, ly - 38)
          love.graphics.setLineWidth(1)
          -- Wide ornate base
          love.graphics.setColor(0.12, 0.11, 0.1, 0.65)
          love.graphics.rectangle("fill", lx - 5, ly + 10, 10, 6)
          love.graphics.rectangle("fill", lx - 3, ly + 6, 6, 4)
          -- Decorative scrollwork arcs
          love.graphics.setColor(0.16, 0.14, 0.12, 0.45)
          love.graphics.arc("line", "open", lx - 3, ly - 26, 6, math.pi * 0.8, math.pi * 1.5)
          love.graphics.arc("line", "open", lx + 3, ly - 26, 6, -math.pi * 0.5, math.pi * 0.2)
          -- Cross arms for two globes
          love.graphics.setColor(0.14, 0.13, 0.11, 0.72)
          love.graphics.setLineWidth(1.5)
          love.graphics.line(lx - 14, ly - 36, lx + 14, ly - 36)
          love.graphics.setLineWidth(1)
          -- Left frosted glass globe
          love.graphics.setColor(0.92, 0.9, 0.82, 0.32)
          love.graphics.circle("fill", lx - 12, ly - 40, 6)
          love.graphics.setColor(0.14, 0.13, 0.11, 0.35)
          love.graphics.circle("line", lx - 12, ly - 40, 6)
          -- Right frosted glass globe
          love.graphics.setColor(0.92, 0.9, 0.82, 0.32)
          love.graphics.circle("fill", lx + 12, ly - 40, 6)
          love.graphics.setColor(0.14, 0.13, 0.11, 0.35)
          love.graphics.circle("line", lx + 12, ly - 40, 6)
          -- Golden crown finial
          love.graphics.setColor(0.62, 0.55, 0.2, 0.5)
          love.graphics.polygon("fill", lx - 2, ly - 38, lx, ly - 44, lx + 2, ly - 38)
          -- Warm golden boulevard glow
          local glowPulse = 0.93 + math.sin(t * 0.65 + lx * 0.012) * 0.07
          love.graphics.setColor(1, 0.92, 0.55, 0.065 * glowPulse)
          love.graphics.circle("fill", lx - 12, ly - 40, 44)
          love.graphics.circle("fill", lx + 12, ly - 40, 44)
          love.graphics.setColor(1, 0.94, 0.62, 0.15 * glowPulse)
          love.graphics.circle("fill", lx - 12, ly - 40, 21)
          love.graphics.circle("fill", lx + 12, ly - 40, 21)
          love.graphics.setColor(1, 0.96, 0.72, 0.32 * glowPulse)
          love.graphics.circle("fill", lx - 12, ly - 40, 7)
          love.graphics.circle("fill", lx + 12, ly - 40, 7)
          -- Warm ground pool
          love.graphics.setColor(1, 0.92, 0.55, 0.05 * glowPulse)
          love.graphics.ellipse("fill", lx, ly + 6, 52, 16)
        end
      end
    end
    -- Lower path: shorter single-globe version
    local lowerPath = floorDef.paths[2]
    if lowerPath then
      local lpCenterY = ((lowerPath.y1 + lowerPath.y2) / 2) * 32
      local lpStartX = lowerPath.x1 * 32
      local lpEndX = lowerPath.x2 * 32
      for lx = lpStartX + 95, lpEndX - 55, 205 do
        local ly = lpCenterY
        -- Ornate single-globe post
        love.graphics.setColor(0.14, 0.13, 0.11, 0.72)
        love.graphics.setLineWidth(2)
        love.graphics.line(lx, ly + 12, lx, ly - 30)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.12, 0.11, 0.1, 0.58)
        love.graphics.rectangle("fill", lx - 4, ly + 8, 8, 5)
        -- Single frosted globe on top
        love.graphics.setColor(0.92, 0.9, 0.82, 0.3)
        love.graphics.circle("fill", lx, ly - 34, 5)
        love.graphics.setColor(0.14, 0.13, 0.11, 0.32)
        love.graphics.circle("line", lx, ly - 34, 5)
        -- Small finial
        love.graphics.setColor(0.62, 0.55, 0.2, 0.42)
        love.graphics.polygon("fill", lx - 1.5, ly - 32, lx, ly - 38, lx + 1.5, ly - 32)
        local glowPulse = 0.9 + math.sin(t * 0.6 + lx * 0.015) * 0.1
        love.graphics.setColor(1, 0.92, 0.55, 0.055 * glowPulse)
        love.graphics.circle("fill", lx, ly - 34, 38)
        love.graphics.setColor(1, 0.94, 0.62, 0.13 * glowPulse)
        love.graphics.circle("fill", lx, ly - 34, 18)
        love.graphics.setColor(1, 0.96, 0.72, 0.28 * glowPulse)
        love.graphics.circle("fill", lx, ly - 34, 6)
        love.graphics.setColor(1, 0.92, 0.55, 0.04 * glowPulse)
        love.graphics.ellipse("fill", lx, ly + 4, 42, 12)
      end
    end
  end

  -- Elevator platform (drawn after paths so it's on top)
  local ep = floorDef.elevatorPos
  local pulse = math.sin(t * 2) * 0.1 + 0.9
  if gameState.currentFloor == 1 then
    -- Surface elevator: ancient-tech look with green glow
    love.graphics.setColor(0.1, 0.4, 0.15, 0.4 * pulse)
    love.graphics.rectangle("fill", (ep.x - 1) * 32, (ep.y - 1) * 32, 96, 96)
    love.graphics.setColor(0.2, 0.8, 0.3, 0.6)
  else
    love.graphics.setColor(colors.accent[1] * pulse, colors.accent[2] * pulse, colors.accent[3] * pulse, 0.5)
    love.graphics.rectangle("fill", (ep.x - 1) * 32, (ep.y - 1) * 32, 96, 96)
    love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.8)
  end
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", (ep.x - 1) * 32, (ep.y - 1) * 32, 96, 96)

  -- Buildings (drawn last so they're always on top of paths and fog)
  if floorDef.buildings then
    for _, b in ipairs(floorDef.buildings) do
      M.drawBuilding(b, colors, lightLevel)
    end
  end

  -- Extra environment for The Surface
  if gameState.currentFloor == 1 and floorDef.environment then
    -- Ground-level fireflies in the walkable area (slow gentle drift)
    for i = 1, 12 do
      local fx = (math.sin(t * 0.035 + i * 2.3) * 0.5 + 0.5) * floorDef.width * 32
      local fy = (math.sin(t * 0.045 + i * 1.9) * 0.5 + 0.5) * floorDef.height * 32
      local bright = math.sin(t * 0.7 + i * 1.7) * 0.4 + 0.5
      love.graphics.setColor(0.3, 1, 0.4, bright * 0.35)
      love.graphics.circle("fill", fx, fy, 2.5)
      love.graphics.setColor(0.3, 1, 0.4, bright * 0.1)
      love.graphics.circle("fill", fx, fy, 8)
    end

    -- Small glowing mushrooms on ground
    math.randomseed(444)
    for i = 1, 10 do
      local mx = math.random(32, floorDef.width * 32 - 32)
      local my = math.random(32, floorDef.height * 32 - 32)
      local glow = math.sin(t * 1.2 + i * 0.8) * 0.2 + 0.6
      love.graphics.setColor(0.2, 0.7, 0.3, glow * 0.2)
      love.graphics.circle("fill", mx, my, 6)
      love.graphics.setColor(0.3, 0.9, 0.4, glow * 0.6)
      love.graphics.ellipse("fill", mx, my, 3, 2)
    end
  end

  -- Extra sparkle particles for floors 4-5 skyline
  if gameState.currentFloor >= 4 and floorDef.skyline and floorDef.skyline.sparkle then
    -- Floating light motes / dust in sunlight
    for i = 1, 8 do
      local mx = (math.sin(t * 0.2 + i * 1.8) * 0.5 + 0.5) * floorDef.width * 32
      local my = (math.cos(t * 0.15 + i * 2.1) * 0.5 + 0.5) * floorDef.height * 32
      local bright = math.sin(t * 1.5 + i * 0.9) * 0.3 + 0.5
      love.graphics.setColor(1, 0.97, 0.85, bright * 0.4)
      love.graphics.circle("fill", mx, my, 2)
    end
  end
end

function M.drawBuilding(b, colors, lightLevel)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32
  local t = gameState.animationTime

  -- Building shadow
  love.graphics.setColor(0, 0, 0, 0.25)
  love.graphics.rectangle("fill", x + 5, y + 5, w, h)

  -- Building body
  local br, bgc, bb = b.color[1] * lightLevel, b.color[2] * lightLevel, b.color[3] * lightLevel
  love.graphics.setColor(br, bgc, bb)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Facade texture detail
  local flr = gameState.currentFloor
  if flr >= 2 and flr <= 3 then
    -- Parisian stonework (horizontal course lines + corner quoins)
    love.graphics.setColor(0, 0, 0, 0.04)
    for ty = y + 12, y + h - 4, 10 do
      love.graphics.line(x, ty, x + w, ty)
    end
    love.graphics.setColor(br * 0.88, bgc * 0.88, bb * 0.88, 0.35)
    for ty = y, y + h - 8, 16 do
      love.graphics.rectangle("fill", x, ty, 6, 14)
      love.graphics.rectangle("fill", x + w - 6, ty, 6, 14)
    end
    -- Flower boxes under select windows
    if b.w >= 6 then
      for fbx = x + 10, x + w - 22, 28 do
        -- Planter box
        love.graphics.setColor(0.45, 0.3, 0.2, 0.5)
        love.graphics.rectangle("fill", fbx, y + 32, 18, 6, 1, 1)
        -- Flowers
        local fColors = {{0.9, 0.3, 0.35}, {0.9, 0.7, 0.2}, {0.85, 0.4, 0.6}}
        local fc = fColors[(math.floor(fbx) % 3) + 1]
        for fi = 0, 3 do
          love.graphics.setColor(fc[1], fc[2], fc[3], 0.6)
          love.graphics.circle("fill", fbx + 3 + fi * 4, y + 30, 2.5)
        end
        -- Green leaves
        love.graphics.setColor(0.2, 0.5, 0.2, 0.5)
        love.graphics.ellipse("fill", fbx + 9, y + 29, 8, 2)
      end
    end
    -- Iron balconette on 2nd floor position
    if h > 100 then
      love.graphics.setColor(0.1, 0.1, 0.12, 0.45)
      love.graphics.setLineWidth(1)
      local balcY = y + math.floor(h * 0.45)
      love.graphics.line(x + 4, balcY, x + w - 4, balcY)
      for bix = x + 8, x + w - 8, 10 do
        love.graphics.arc("line", bix, balcY + 2, 4, 0, math.pi)
      end
    end
  elseif flr >= 4 then
    -- Modern glass/steel panels with reflective curtain wall
    love.graphics.setColor(1, 1, 1, 0.04)
    for tx = x + 16, x + w - 8, 18 do
      love.graphics.rectangle("fill", tx, y + 8, 2, h - 16)
    end
    love.graphics.setColor(0, 0, 0, 0.05)
    love.graphics.rectangle("fill", x, y + h * 0.7, w, h * 0.3)
    -- Glass canopy entrance
    if b.w >= 7 then
      love.graphics.setColor(0.7, 0.82, 0.95, 0.2)
      love.graphics.polygon("fill", x + w/2 - 20, y + h - 4, x + w/2 + 20, y + h - 4,
        x + w/2 + 16, y + h - 14, x + w/2 - 16, y + h - 14)
    end
    -- Rooftop accent (antenna/garden)
    if b.x % 3 == 0 then
      -- Antenna mast
      love.graphics.setColor(0.5, 0.52, 0.56, 0.5)
      love.graphics.setLineWidth(1)
      love.graphics.line(x + w/2, y, x + w/2, y - 12)
      love.graphics.circle("fill", x + w/2, y - 13, 2)
    elseif b.x % 3 == 1 then
      -- Rooftop garden strip
      love.graphics.setColor(0.35, 0.55, 0.3, 0.4)
      love.graphics.rectangle("fill", x + 6, y - 3, w - 12, 4, 2, 2)
    end
    -- LED accent line at top
    local ledA = math.sin(t * 2 + b.x) * 0.05 + 0.15
    love.graphics.setColor(0.5, 0.75, 1, ledA)
    love.graphics.rectangle("fill", x, y + 4, w, 2)
  elseif flr == 1 then
    -- Jungle rustic: weathered plank texture + hanging vines
    love.graphics.setColor(0, 0, 0, 0.06)
    for ty = y + 6, y + h - 2, 8 do
      love.graphics.line(x + 2, ty, x + w - 2, ty)
    end
    -- Hanging vine from roof edge
    love.graphics.setColor(0.1, 0.3, 0.1, 0.5)
    love.graphics.setLineWidth(1)
    for vi = 0, 2 do
      local vx = x + 8 + vi * math.floor(w / 3)
      local vLen = 8 + (b.x * 3 + vi * 7) % 14
      local vSway = math.sin(t * 0.4 + vi + b.x) * 2
      love.graphics.line(vx, y, vx + vSway * 0.5, y + vLen)
      love.graphics.setColor(0.15, 0.4, 0.15, 0.4)
      love.graphics.circle("fill", vx + vSway * 0.5, y + vLen, 2)
      love.graphics.setColor(0.1, 0.3, 0.1, 0.5)
    end
    -- Wooden beam supports
    love.graphics.setColor(0.12, 0.08, 0.04, 0.4)
    love.graphics.rectangle("fill", x + 2, y, 4, h)
    love.graphics.rectangle("fill", x + w - 6, y, 4, h)
  end

  -- Foundation / base strip
  love.graphics.setColor(br * 0.75, bgc * 0.75, bb * 0.75, 0.8)
  love.graphics.rectangle("fill", x - 1, y + h - 8, w + 2, 8)

  -- Cornice / roofline trim
  love.graphics.setColor(br * 0.85, bgc * 0.85, bb * 0.85, 0.9)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, 4)
  if flr >= 2 and flr <= 3 then
    -- Dentil molding under cornice
    love.graphics.setColor(br * 0.8, bgc * 0.8, bb * 0.8, 0.6)
    for dx = x, x + w - 4, 6 do
      love.graphics.rectangle("fill", dx, y + 2, 4, 3)
    end
    -- Chimney on some buildings
    if b.x % 5 < 2 then
      love.graphics.setColor(br * 0.65, bgc * 0.65, bb * 0.65, 0.7)
      local chX = x + w * 0.7
      love.graphics.rectangle("fill", chX - 4, y - 14, 8, 16)
      love.graphics.rectangle("fill", chX - 5, y - 16, 10, 4)
    end
  elseif flr >= 4 then
    -- Modern clean edge highlight
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("fill", x, y, w, 2)
    -- Decorative flag or banner
    if b.w >= 7 and b.x % 4 == 0 then
      local flagColor = (b.x % 2 == 0) and {0.3, 0.5, 0.8} or {0.7, 0.3, 0.4}
      love.graphics.setColor(flagColor[1], flagColor[2], flagColor[3], 0.4)
      local flagSway = math.sin(t * 1.5 + b.x) * 3
      love.graphics.polygon("fill", x + w - 8, y + 10, x + w - 8 + flagSway, y + 16, x + w - 8, y + 22)
    end
  end

  -- Architectural detail based on archStyle
  if b.archStyle == "iron_arch" then
    -- Iron arch entrance
    love.graphics.setColor(b.accentColor[1] * 0.8, b.accentColor[2] * 0.8, b.accentColor[3] * 0.8, 0.6)
    love.graphics.arc("line", x + w/2, y + h, w/3, math.pi, 0)
    love.graphics.arc("line", x + w/2, y + h, w/3 - 3, math.pi, 0)
  elseif b.archStyle == "gothic_window" then
    -- Pointed arch windows
    love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.5)
    for wx = x + 12, x + w - 20, 24 do
      love.graphics.polygon("fill", wx, y + 12, wx + 8, y + 8, wx + 16, y + 12, wx + 16, y + 28, wx, y + 28)
    end
  elseif b.archStyle == "cathedral" then
    -- Rose window
    love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3], 0.5)
    love.graphics.circle("line", x + w/2, y + h/3, 15)
    for a = 0, 5 do
      local angle = a * math.pi / 3
      love.graphics.line(x + w/2, y + h/3,
        x + w/2 + math.cos(angle) * 15, y + h/3 + math.sin(angle) * 15)
    end
  elseif b.archStyle == "grand_arch" then
    -- Grand Roman arch
    love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3], 0.4)
    love.graphics.arc("line", x + w/2, y, w/2 - 5, 0, math.pi)
    -- Decorative keystone
    love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3], 0.6)
    love.graphics.polygon("fill", x + w/2 - 4, y - 2, x + w/2 + 4, y - 2, x + w/2 + 3, y + 6, x + w/2 - 3, y + 6)
  elseif b.archStyle == "crystal_dome" then
    -- Dome top
    love.graphics.setColor(0.6, 0.75, 0.9, 0.4)
    love.graphics.arc("fill", x + w/2, y, w/3, math.pi, 0)
    -- Glass sparkle
    local sparkle = math.sin(t * 3 + b.x) * 0.3 + 0.5
    love.graphics.setColor(1, 1, 1, sparkle * 0.3)
    love.graphics.circle("fill", x + w/2 - 5, y - 5, 3)
  elseif b.archStyle == "art_deco" then
    -- Stepped facade
    love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3], 0.5)
    for step = 0, 2 do
      local sw = w - step * 16
      love.graphics.rectangle("fill", x + step * 8, y - step * 4 - 4, sw, 4)
    end
  elseif b.archStyle == "marble_column" then
    -- Marble columns at entrance
    love.graphics.setColor(0.85, 0.82, 0.75, 0.6)
    love.graphics.rectangle("fill", x + 4, y + 4, 6, h - 8)
    love.graphics.rectangle("fill", x + w - 10, y + 4, 6, h - 8)
    -- Column capitals
    love.graphics.rectangle("fill", x + 2, y + 2, 10, 4)
    love.graphics.rectangle("fill", x + w - 12, y + 2, 10, 4)
  end

  -- Accent stripe
  love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3])
  love.graphics.rectangle("fill", x, y, w, 8)

  -- Windows with detail
  local windowY = y + 16
  if flr == 1 then
    -- Surface: warm glowing windows at night
    local windowGlow = math.sin(t * 0.8 + b.x * 0.1) * 0.1 + 0.7
    for wx = x + 8, x + w - 20, 20 do
      love.graphics.setColor(0.1, 0.08, 0.05, 0.6)
      love.graphics.rectangle("fill", wx - 1, windowY - 1, 14, 12)
      love.graphics.setColor(1, 0.85, 0.5, windowGlow)
      love.graphics.rectangle("fill", wx, windowY, 12, 10)
      love.graphics.setColor(0.1, 0.08, 0.05, 0.5)
      love.graphics.line(wx + 6, windowY, wx + 6, windowY + 10)
      love.graphics.line(wx, windowY + 5, wx + 12, windowY + 5)
    end
  elseif flr >= 2 and flr <= 3 then
    -- Parisian: tall windows with shutters and sills
    for wx = x + 8, x + w - 20, 20 do
      love.graphics.setColor(0.15, 0.15, 0.2, 0.5)
      love.graphics.rectangle("fill", wx, windowY, 12, 14)
      love.graphics.setColor(0.95, 0.88, 0.6, 0.35)
      love.graphics.rectangle("fill", wx + 1, windowY + 1, 10, 12)
      love.graphics.setColor(br * 0.7, bgc * 0.7, bb * 0.7, 0.7)
      love.graphics.rectangle("line", wx, windowY, 12, 14)
      love.graphics.line(wx + 6, windowY, wx + 6, windowY + 14)
      love.graphics.line(wx, windowY + 7, wx + 12, windowY + 7)
      -- Shutters
      love.graphics.setColor(b.accentColor[1] * 0.7, b.accentColor[2] * 0.7, b.accentColor[3] * 0.7, 0.4)
      love.graphics.rectangle("fill", wx - 3, windowY, 3, 14)
      love.graphics.rectangle("fill", wx + 12, windowY, 3, 14)
      -- Window sill
      love.graphics.setColor(br * 0.85, bgc * 0.85, bb * 0.85, 0.6)
      love.graphics.rectangle("fill", wx - 1, windowY + 14, 14, 2)
    end
    -- Second row for tall buildings
    if h > 128 then
      for wx = x + 14, x + w - 20, 22 do
        love.graphics.setColor(0.15, 0.15, 0.2, 0.4)
        love.graphics.rectangle("fill", wx, y + 38, 10, 12)
        love.graphics.setColor(0.95, 0.88, 0.6, 0.25)
        love.graphics.rectangle("fill", wx + 1, y + 39, 8, 10)
      end
    end
  elseif flr >= 4 then
    -- Modern: large glass panels with reflections
    for wx = x + 6, x + w - 16, 18 do
      love.graphics.setColor(0.7, 0.82, 0.95, 0.4)
      love.graphics.rectangle("fill", wx, windowY, 14, 12)
      love.graphics.setColor(1, 1, 1, 0.1)
      love.graphics.rectangle("fill", wx + 1, windowY + 1, 6, 5)
      love.graphics.setColor(0.6, 0.65, 0.7, 0.3)
      love.graphics.rectangle("line", wx, windowY, 14, 12)
    end
    if h > 128 then
      for wx = x + 6, x + w - 16, 18 do
        love.graphics.setColor(0.7, 0.82, 0.95, 0.35)
        love.graphics.rectangle("fill", wx, y + 36, 14, 10)
        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.rectangle("fill", wx + 1, y + 37, 6, 4)
      end
    end
  else
    love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.7)
    for wx = x + 8, x + w - 20, 20 do
      love.graphics.rectangle("fill", wx, windowY, 12, 10)
    end
  end

  -- Door with details
  local doorPx = b.doorX * 32 + 4
  local doorPy = b.doorY * 32 - 28
  love.graphics.setColor(b.accentColor[1] * 0.6, b.accentColor[2] * 0.6, b.accentColor[3] * 0.6)
  love.graphics.rectangle("fill", doorPx, doorPy, 24, 28)
  -- Door frame
  love.graphics.setColor(b.accentColor[1] * 0.4, b.accentColor[2] * 0.4, b.accentColor[3] * 0.4, 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", doorPx, doorPy, 24, 28)
  -- Door handle
  love.graphics.setColor(0.8, 0.75, 0.5, 0.6)
  love.graphics.circle("fill", doorPx + 19, doorPy + 15, 2)
  -- Awning / overhang
  if flr >= 2 then
    love.graphics.setColor(b.accentColor[1] * 0.8, b.accentColor[2] * 0.5, b.accentColor[3] * 0.5, 0.35)
    love.graphics.polygon("fill", doorPx - 4, doorPy, doorPx + 28, doorPy, doorPx + 24, doorPy - 8, doorPx, doorPy - 8)
    love.graphics.setColor(0, 0, 0, 0.06)
    love.graphics.rectangle("fill", doorPx, doorPy, 24, 4)
  end

  -- Neon sign with glow and bloom
  if b.neonSign then
    local sign = b.neonSign
    local signX = x + w/2
    local signY = y - 8
    local pulse = math.sin(t * 2.5 + (b.x or 0) * 0.5) * 0.15 + 0.85

    -- Outer glow (bloom)
    local gr = sign.glowRadius or 35
    love.graphics.setColor(sign.color[1], sign.color[2], sign.color[3], 0.08 * pulse)
    love.graphics.circle("fill", signX, signY, gr)
    love.graphics.setColor(sign.color[1], sign.color[2], sign.color[3], 0.15 * pulse)
    love.graphics.circle("fill", signX, signY, gr * 0.6)

    -- Sign background
    local font = love.graphics.getFont()
    local textW = font:getWidth(sign.text)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", signX - textW/2 - 6, signY - 10, textW + 12, 20, 3, 3)

    -- Neon text with glow
    love.graphics.setColor(sign.color[1], sign.color[2], sign.color[3], pulse)
    love.graphics.print(sign.text, signX - textW/2, signY - 7)
    -- Extra bright center pass
    love.graphics.setColor(
      math.min(1, sign.color[1] + 0.3),
      math.min(1, sign.color[2] + 0.3),
      math.min(1, sign.color[3] + 0.3),
      pulse * 0.5
    )
    love.graphics.print(sign.text, signX - textW/2, signY - 7)

    -- Neon reflection on ground below sign
    love.graphics.setColor(sign.color[1], sign.color[2], sign.color[3], 0.06 * pulse)
    love.graphics.ellipse("fill", signX, y + h + 10, gr * 0.8, 8)
  end

  -- Building name (adaptive color for readability)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  if not b.neonSign then
    local nameX = x + w/2 - textW/2
    local nameY = y - 20
    if flr >= 3 then
      -- Dark text with shadow for light backgrounds
      love.graphics.setColor(0, 0, 0, 0.35)
      love.graphics.print(b.name, nameX + 1, nameY + 1)
      love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
    else
      -- Light text with shadow for dark backgrounds
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.print(b.name, nameX + 1, nameY + 1)
      love.graphics.setColor(1, 1, 1, 0.9)
    end
    love.graphics.print(b.name, nameX, nameY)
  end
end

-- ═══════════════════════════════════════
-- MAZE INTERIOR DRAWING (Ancient Citadel)
-- ═══════════════════════════════════════

function M.drawMazeInterior(interior)
  local ms = gameState.mazeState
  local t = ms.timer
  local GS = 32 -- grid size

  -- Apply screen shake
  if ms.shake.timer > 0 then
    love.graphics.translate(ms.shake.x, ms.shake.y)
  end

  -- Dark stone floor base
  love.graphics.setColor(0.12, 0.1, 0.08)
  love.graphics.rectangle("fill", 0, 0, interior.width * GS, interior.height * GS)

  -- Floor tile pattern (ancient stone)
  for y = 0, interior.height - 1 do
    for x = 0, interior.width - 1 do
      local row = interior.mazeMap[y + 1]
      if not row then goto continue_floor end
      local cell = row[x + 1]
      local px = x * GS
      local py = y * GS

      if cell == 1 then
        -- Wall block: carved stone with hieroglyphic accents
        local shade = 0.18 + ((x * 7 + y * 13) % 17) / 170
        love.graphics.setColor(shade, shade - 0.02, shade - 0.04)
        love.graphics.rectangle("fill", px, py, GS, GS)

        -- Stone brick lines
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", px + 1, py + 1, GS - 2, GS - 2)

        -- Occasional hieroglyph carvings on walls
        if (x * 11 + y * 3) % 23 == 0 then
          love.graphics.setColor(0.3, 0.25, 0.15, 0.3)
          local glyphType = (x + y) % 4
          if glyphType == 0 then
            -- Eye symbol
            love.graphics.ellipse("line", px + 16, py + 16, 8, 5)
            love.graphics.circle("fill", px + 16, py + 16, 2)
          elseif glyphType == 1 then
            -- Triangle (pyramid)
            love.graphics.polygon("line", px + 16, py + 6, px + 8, py + 26, px + 24, py + 26)
          elseif glyphType == 2 then
            -- Ankh
            love.graphics.circle("line", px + 16, py + 10, 5)
            love.graphics.line(px + 16, py + 15, px + 16, py + 28)
            love.graphics.line(px + 11, py + 20, px + 21, py + 20)
          else
            -- Scarab
            love.graphics.ellipse("line", px + 16, py + 16, 6, 8)
            love.graphics.line(px + 10, py + 12, px + 6, py + 8)
            love.graphics.line(px + 22, py + 12, px + 26, py + 8)
          end
        end
      else
        -- Path tile: worn stone floor
        local pathShade = 0.2 + ((x * 3 + y * 11) % 13) / 180
        love.graphics.setColor(pathShade, pathShade - 0.01, pathShade - 0.03)
        love.graphics.rectangle("fill", px, py, GS, GS)

        -- Tile cracks and mortar
        love.graphics.setColor(0, 0, 0, 0.08)
        love.graphics.rectangle("line", px + 1, py + 1, GS - 2, GS - 2)

        -- Random cracks on floor
        if (x * 17 + y * 7) % 31 == 0 then
          love.graphics.setColor(0, 0, 0, 0.12)
          love.graphics.setLineWidth(1)
          love.graphics.line(px + 4, py + 8, px + 18, py + 24)
          love.graphics.line(px + 18, py + 24, px + 28, py + 20)
        end

        -- Draw trap indicators on special cells
        if cell == 2 then
          -- Dart trap: small holes in wall
          love.graphics.setColor(0.08, 0.06, 0.04)
          love.graphics.circle("fill", px + 8, py + 16, 3)
          love.graphics.circle("fill", px + 24, py + 16, 3)
          -- Warning scratches on floor
          love.graphics.setColor(0.5, 0.15, 0.1, 0.3)
          love.graphics.line(px + 4, py + 4, px + 12, py + 12)
          love.graphics.line(px + 20, py + 4, px + 28, py + 12)
        elseif cell == 3 then
          -- Spike pit: grate pattern
          local spikesUp = (math.floor(t / 1.5) % 2 == 0)
          if spikesUp then
            love.graphics.setColor(0.6, 0.15, 0.1, 0.8)
            for sx = px + 4, px + 28, 6 do
              love.graphics.polygon("fill", sx, py + 28, sx + 2, py + 28, sx + 1, py + 8)
            end
          else
            love.graphics.setColor(0.05, 0.03, 0.02, 0.8)
            love.graphics.rectangle("fill", px + 2, py + 2, 28, 28)
            love.graphics.setColor(0.08, 0.06, 0.04)
            for sx = px + 5, px + 28, 8 do
              love.graphics.line(sx, py + 4, sx, py + 28)
            end
          end
        elseif cell == 4 then
          -- Swinging blade: find obstacle for angle
          local bladeAngle = 0
          if interior.obstacles then
            for i, obs in ipairs(interior.obstacles) do
              if obs.type == "blade" and obs.gridX == x and obs.gridY == y then
                bladeAngle = math.sin(ms.bladeAngles[i] or 0)
                break
              end
            end
          end
          -- Blade pendulum
          local bladeLen = 14
          local bladeTipX = px + 16 + bladeAngle * bladeLen
          local bladeTipY = py + 16
          -- Blade arc trail
          love.graphics.setColor(0.7, 0.7, 0.75, 0.15)
          love.graphics.arc("fill", px + 16, py + 4, bladeLen + 2, math.pi * 0.15, math.pi * 0.85)
          -- Blade
          love.graphics.setColor(0.65, 0.65, 0.7, 0.9)
          love.graphics.setLineWidth(3)
          love.graphics.line(px + 16, py + 4, bladeTipX, bladeTipY)
          love.graphics.setLineWidth(1)
          -- Blade tip glow
          love.graphics.setColor(0.8, 0.8, 0.85, 0.6)
          love.graphics.circle("fill", bladeTipX, bladeTipY, 3)
          -- Pivot point
          love.graphics.setColor(0.4, 0.35, 0.3)
          love.graphics.circle("fill", px + 16, py + 4, 4)
        elseif cell == 5 then
          -- Crumbling floor
          local key = x .. "," .. y
          local cs = ms.crumbleStates[key]
          if cs then
            if cs.state == "crumbling" then
              -- Shaking/cracking animation
              local shake = math.sin(t * 20) * 2
              love.graphics.setColor(0.25, 0.2, 0.12, 0.7)
              love.graphics.rectangle("fill", px + shake, py, GS, GS)
              -- Cracks spreading
              love.graphics.setColor(0.05, 0.03, 0.01)
              love.graphics.setLineWidth(2)
              love.graphics.line(px + 16, py + 2, px + 8, py + 16)
              love.graphics.line(px + 8, py + 16, px + 20, py + 30)
              love.graphics.line(px + 16, py + 2, px + 28, py + 18)
              love.graphics.setLineWidth(1)
            elseif cs.state == "fallen" then
              -- Dark pit
              love.graphics.setColor(0.02, 0.01, 0.01)
              love.graphics.rectangle("fill", px + 2, py + 2, 28, 28)
              -- Depth shading
              love.graphics.setColor(0, 0, 0, 0.5)
              love.graphics.rectangle("fill", px + 4, py + 4, 24, 24)
            end
          else
            -- Intact but suspicious floor (subtle cracks)
            love.graphics.setColor(0.35, 0.28, 0.15, 0.3)
            love.graphics.setLineWidth(1)
            love.graphics.line(px + 6, py + 10, px + 26, py + 22)
            love.graphics.line(px + 14, py + 4, px + 20, py + 28)
          end
        elseif cell == 6 then
          -- Fire jet
          local fireActive = false
          if interior.obstacles then
            for i, obs in ipairs(interior.obstacles) do
              if obs.type == "fire" and obs.gridX == x and obs.gridY == y then
                local cycle = ms.obstacleTimers[i] % (obs.interval + obs.activeTime)
                fireActive = (cycle < obs.activeTime)
                break
              end
            end
          end
          -- Vent grate
          love.graphics.setColor(0.15, 0.12, 0.08)
          love.graphics.rectangle("fill", px + 8, py + 8, 16, 16)
          love.graphics.setColor(0.08, 0.06, 0.04)
          for gy = py + 10, py + 22, 4 do
            love.graphics.line(px + 10, gy, px + 22, gy)
          end
          if fireActive then
            -- Animated fire
            for fi = 0, 4 do
              local flameH = 12 + math.sin(t * 8 + fi * 1.5) * 6
              local flameW = 4 + math.sin(t * 6 + fi * 2) * 2
              local flameX = px + 12 + fi * 3 + math.sin(t * 10 + fi) * 2
              local alpha = 0.7 - fi * 0.1
              -- Outer flame (orange-red)
              love.graphics.setColor(1, 0.3, 0.05, alpha * 0.6)
              love.graphics.ellipse("fill", flameX, py + 16 - flameH/2, flameW, flameH/2)
              -- Inner flame (yellow)
              love.graphics.setColor(1, 0.8, 0.1, alpha * 0.8)
              love.graphics.ellipse("fill", flameX, py + 16 - flameH/3, flameW * 0.6, flameH/3)
              -- Core (white-yellow)
              love.graphics.setColor(1, 1, 0.7, alpha)
              love.graphics.ellipse("fill", flameX, py + 16 - flameH/4, flameW * 0.3, flameH/4)
            end
            -- Heat distortion glow
            love.graphics.setColor(1, 0.4, 0.1, 0.15)
            love.graphics.circle("fill", px + 16, py + 8, 20)
          else
            -- Warning glow before activation
            local cycle = 0
            if interior.obstacles then
              for i, obs in ipairs(interior.obstacles) do
                if obs.type == "fire" and obs.gridX == x and obs.gridY == y then
                  cycle = ms.obstacleTimers[i] % (obs.interval + obs.activeTime)
                  break
                end
              end
            end
            local warning = cycle / 2.5
            if warning > 0.7 then
              love.graphics.setColor(1, 0.3, 0.05, (warning - 0.7) * 0.5)
              love.graphics.circle("fill", px + 16, py + 16, 8)
            end
          end
        elseif cell == 7 then
          -- Boulder trigger plate
          if not ms.boulder.triggered then
            local trigPulse = math.sin(t * 2) * 0.15 + 0.6
            love.graphics.setColor(0.6, 0.4, 0.15, trigPulse)
            love.graphics.rectangle("fill", px + 4, py + 4, 24, 24)
            love.graphics.setColor(0.8, 0.6, 0.2, trigPulse)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", px + 6, py + 6, 20, 20)
            love.graphics.setLineWidth(1)
            -- Warning icon
            love.graphics.setColor(0.9, 0.2, 0.1, trigPulse)
            love.graphics.print("!", px + 13, py + 8)
          end
        elseif cell == 8 then
          -- Treasure chest
          M.drawTreasureChest(px, py, t, ms)
        end
      end

      ::continue_floor::
    end
  end

  -- Draw torches on walls (animated flickering)
  for _, torch in ipairs(ms.torches) do
    local tx = torch.x * GS + 16
    local ty = torch.y * GS + 16
    local flicker = math.sin(t * 5 + torch.flicker) * 0.2 + 0.8

    -- Torch bracket
    love.graphics.setColor(0.3, 0.25, 0.15)
    love.graphics.rectangle("fill", tx - 2, ty - 4, 4, 12)

    -- Flame
    local flameH = 8 + math.sin(t * 7 + torch.flicker) * 3
    local flameSway = math.sin(t * 4 + torch.flicker * 2) * 2
    love.graphics.setColor(1, 0.5, 0.1, flicker * 0.9)
    love.graphics.ellipse("fill", tx + flameSway, ty - 8, 4, flameH / 2)
    love.graphics.setColor(1, 0.8, 0.2, flicker)
    love.graphics.ellipse("fill", tx + flameSway * 0.5, ty - 8, 2.5, flameH / 3)
    love.graphics.setColor(1, 1, 0.7, flicker * 0.8)
    love.graphics.ellipse("fill", tx + flameSway * 0.3, ty - 7, 1.5, flameH / 4)

    -- Light glow on surrounding area
    love.graphics.setColor(1, 0.6, 0.15, 0.08 * flicker)
    love.graphics.circle("fill", tx, ty - 6, 45)
    love.graphics.setColor(1, 0.7, 0.2, 0.04 * flicker)
    love.graphics.circle("fill", tx, ty - 6, 70)
  end

  -- Draw boulder
  if ms.boulder.active then
    local bx = ms.boulder.x * GS + 16
    local by = ms.boulder.y * GS + 16
    local boulderRadius = 14
    local rollAngle = t * 8

    -- Boulder shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.ellipse("fill", bx + 3, by + boulderRadius + 2, boulderRadius + 2, 5)

    -- Boulder body (rocky sphere)
    love.graphics.setColor(0.45, 0.38, 0.28)
    love.graphics.circle("fill", bx, by, boulderRadius)

    -- Rock texture / cracks
    love.graphics.setColor(0.35, 0.28, 0.18)
    love.graphics.arc("fill", bx - 2, by - 3, boulderRadius - 2, rollAngle, rollAngle + 1.2)
    love.graphics.arc("fill", bx + 4, by + 2, boulderRadius - 4, rollAngle + 2.5, rollAngle + 3.5)

    -- Highlight (rolling glint)
    love.graphics.setColor(0.6, 0.5, 0.35, 0.5)
    local hlx = bx + math.cos(rollAngle) * 5
    local hly = by + math.sin(rollAngle) * 5 - 3
    love.graphics.circle("fill", hlx, hly, 4)

    -- Crack lines
    love.graphics.setColor(0.25, 0.2, 0.12, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(bx - 8, by - 2, bx + 3, by + 6)
    love.graphics.line(bx + 2, by - 8, bx - 4, by + 4)
    love.graphics.line(bx + 6, by - 4, bx + 10, by + 8)

    -- Dust cloud around boulder
    love.graphics.setColor(0.5, 0.4, 0.3, 0.3)
    for di = 0, 5 do
      local dx = bx + 20 + math.sin(t * 6 + di * 1.5) * 12
      local dy = by + math.sin(t * 4 + di * 2) * 10
      love.graphics.circle("fill", dx, dy, 3 + math.sin(t * 3 + di) * 2)
    end
  end

  -- Draw particles
  for _, p in ipairs(ms.particles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.8)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
  end

  -- Exit door (ancient stone archway)
  local exitPx = interior.exitX * GS
  local exitPy = interior.exitY * GS
  love.graphics.setColor(0.3, 0.25, 0.15, 0.6)
  love.graphics.rectangle("fill", exitPx, exitPy, GS, GS)
  love.graphics.setColor(0.5, 0.4, 0.2, 0.8)
  love.graphics.arc("line", exitPx + 16, exitPy + 4, 14, math.pi, 0)
  love.graphics.setLineWidth(2)
  love.graphics.line(exitPx + 2, exitPy + 4, exitPx + 2, exitPy + GS)
  love.graphics.line(exitPx + 30, exitPy + 4, exitPx + 30, exitPy + GS)
  love.graphics.setLineWidth(1)

  -- Ambient dust motes floating in the air
  for i = 1, 20 do
    local dx = (math.sin(t * 0.15 + i * 2.7) * 0.5 + 0.5) * interior.width * GS
    local dy = (math.sin(t * 0.12 + i * 1.9) * 0.5 + 0.5) * interior.height * GS
    local bright = math.sin(t * 0.5 + i * 1.3) * 0.3 + 0.4
    love.graphics.setColor(0.8, 0.7, 0.5, bright * 0.2)
    love.graphics.circle("fill", dx, dy, 1.5)
  end

  -- Interior name
  love.graphics.setColor(0.8, 0.6, 0.2)
  love.graphics.print(interior.name, 40, 10)
end

function M.drawTreasureChest(px, py, t, ms)
  local GS = 32

  if ms.chest.opened then
    -- Opened chest with golden glow
    local openGlow = math.sin(t * 2) * 0.15 + 0.85

    -- Chest base (opened)
    love.graphics.setColor(0.4, 0.25, 0.1)
    love.graphics.rectangle("fill", px + 4, py + 14, 24, 14, 2, 2)

    -- Chest lid (opened, tilted back)
    love.graphics.setColor(0.45, 0.3, 0.12)
    love.graphics.polygon("fill", px + 4, py + 14, px + 28, py + 14, px + 26, py + 4, px + 6, py + 4)

    -- Gold inside
    love.graphics.setColor(1, 0.85, 0.2, openGlow)
    love.graphics.rectangle("fill", px + 6, py + 16, 20, 10, 1, 1)

    -- Golden rays emanating
    for ri = 0, 7 do
      local angle = ri * math.pi / 4 + t * 0.5
      local rayLen = 18 + math.sin(t * 3 + ri) * 6
      love.graphics.setColor(1, 0.85, 0.3, 0.2 * openGlow)
      love.graphics.line(px + 16, py + 16, px + 16 + math.cos(angle) * rayLen, py + 16 + math.sin(angle) * rayLen)
    end

    -- Sparkle particles
    for si = 0, 5 do
      local sx = px + 10 + math.sin(t * 2.5 + si * 1.2) * 12
      local sy = py + 10 + math.cos(t * 2 + si * 1.5) * 8 - si * 2
      local sparkle = math.sin(t * 4 + si * 0.8) * 0.4 + 0.6
      love.graphics.setColor(1, 0.95, 0.5, sparkle * 0.7)
      love.graphics.circle("fill", sx, sy, 1.5)
    end

    -- "COLLECTED!" text
    if ms.chest.rewardCollected then
      love.graphics.setColor(1, 0.9, 0.3)
      love.graphics.print("✦", px + 10, py - 8)
    end
  else
    -- Closed chest with mystical glow
    local glow = math.sin(ms.chest.glowTimer * 1.5) * 0.2 + 0.8

    -- Pulsing golden aura
    love.graphics.setColor(1, 0.8, 0.15, 0.06 * glow)
    love.graphics.circle("fill", px + 16, py + 16, 40)
    love.graphics.setColor(1, 0.85, 0.2, 0.12 * glow)
    love.graphics.circle("fill", px + 16, py + 16, 25)
    love.graphics.setColor(1, 0.9, 0.3, 0.2 * glow)
    love.graphics.circle("fill", px + 16, py + 16, 14)

    -- Chest base
    love.graphics.setColor(0.35, 0.22, 0.08)
    love.graphics.rectangle("fill", px + 4, py + 14, 24, 14, 2, 2)

    -- Chest lid (rounded top)
    love.graphics.setColor(0.4, 0.26, 0.1)
    love.graphics.rectangle("fill", px + 3, py + 10, 26, 6)
    love.graphics.arc("fill", px + 16, py + 10, 13, math.pi, 0)

    -- Metal bands
    love.graphics.setColor(0.6, 0.5, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(px + 4, py + 18, px + 28, py + 18)
    love.graphics.line(px + 16, py + 10, px + 16, py + 28)
    love.graphics.setLineWidth(1)

    -- Lock (golden)
    love.graphics.setColor(0.85, 0.7, 0.2, glow)
    love.graphics.rectangle("fill", px + 13, py + 14, 6, 5)
    love.graphics.circle("line", px + 16, py + 13, 3)

    -- Rotating sparkles around chest
    for si = 0, 5 do
      local angle = ms.chest.glowTimer * 1.2 + si * math.pi / 3
      local dist = 20 + math.sin(ms.chest.glowTimer * 2 + si) * 5
      local sx = px + 16 + math.cos(angle) * dist
      local sy = py + 16 + math.sin(angle) * dist * 0.6
      local sparkle = math.sin(ms.chest.glowTimer * 3 + si * 1.1) * 0.3 + 0.7
      love.graphics.setColor(1, 0.9, 0.3, sparkle * 0.6)
      love.graphics.circle("fill", sx, sy, 2)
      love.graphics.setColor(1, 0.95, 0.5, sparkle * 0.3)
      love.graphics.circle("fill", sx, sy, 4)
    end

    -- "E to open" hint when player is near
    local pdist = math.abs(gameState.player.gridX - math.floor(px / GS)) + math.abs(gameState.player.gridY - math.floor(py / GS))
    if pdist <= 2 then
      love.graphics.setColor(1, 0.9, 0.3, glow)
      local font = love.graphics.getFont()
      local tw = font:getWidth("Press E")
      love.graphics.print("Press E", px + 16 - tw/2, py - 14)
    end
  end
end

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Use special maze renderer for maze interiors
  if interior.isMaze and gameState.mazeState then
    M.drawMazeInterior(interior)
    return
  end

  local floorDef = floors.getFloor(gameState.currentFloor)
  local colors = floorDef and floorDef.colorScheme or {bg = {0.7, 0.7, 0.7}, accent = {0.5, 0.5, 0.5}, light = {1, 1, 1}}
  local lightLevel = floorDef and floorDef.lightLevel or 0.8
  local t = gameState.animationTime

  -- Special rendering for Golden Vault Casino (black & gold)
  local isGoldenVault = (gameState.interiorId == "golden_vault_casino")

  if isGoldenVault then
    -- Black marble floor
    love.graphics.setColor(0.06, 0.05, 0.04)
    love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

    -- Gold-flecked floor pattern
    love.graphics.setColor(0.3, 0.25, 0.1, 0.15)
    for y = 0, interior.height * 32, 32 do
      for x = 0, interior.width * 32, 32 do
        if (math.floor(x / 32) + math.floor(y / 32)) % 2 == 0 then
          love.graphics.rectangle("fill", x, y, 32, 32)
        end
      end
    end

    -- Gold accent sparkles on floor
    math.randomseed(999)
    for i = 1, 20 do
      local sx = math.random(32, interior.width * 32 - 32)
      local sy = math.random(32, interior.height * 32 - 32)
      local sparkle = math.sin(t * 2 + i * 1.1) * 0.3 + 0.4
      love.graphics.setColor(0.85, 0.7, 0.2, sparkle * 0.3)
      love.graphics.circle("fill", sx, sy, 1.5)
    end

    -- Black walls with gold trim
    love.graphics.setColor(0.04, 0.03, 0.03)
    love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
    love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
    love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
    love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

    -- Gold trim lines
    love.graphics.setColor(0.85, 0.7, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 30, 30, interior.width * 32 - 60, interior.height * 32 - 60)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 33, 33, interior.width * 32 - 66, interior.height * 32 - 66)

    -- Gold chandelier accents
    for i = 1, 3 do
      local cx = interior.width * 32 * i / 4
      local cy = 50
      local glow = math.sin(t * 1.5 + i * 1.2) * 0.1 + 0.8
      love.graphics.setColor(0.85, 0.7, 0.2, 0.1 * glow)
      love.graphics.circle("fill", cx, cy, 40)
      love.graphics.setColor(0.95, 0.85, 0.4, 0.5 * glow)
      love.graphics.circle("fill", cx, cy, 5)
      -- Dangling points
      for j = -2, 2 do
        love.graphics.setColor(0.85, 0.7, 0.2, 0.4)
        love.graphics.line(cx + j * 12, cy, cx + j * 12, cy + 10)
        love.graphics.setColor(0.95, 0.85, 0.4, 0.6)
        love.graphics.circle("fill", cx + j * 12, cy + 12, 2)
      end
    end

    -- Exit door (gold framed)
    love.graphics.setColor(0.85, 0.7, 0.2, 0.4)
    love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)
    love.graphics.setColor(0.95, 0.85, 0.4, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", interior.exitX * 32, interior.exitY * 32, 32, 32)

  else
    -- Standard interior rendering
    love.graphics.setColor(colors.bg[1] * 0.8 * lightLevel, colors.bg[2] * 0.8 * lightLevel, colors.bg[3] * 0.8 * lightLevel)
    love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

    -- Floor 1 (Surface/Jungle Night Market): Subtle luxurious floor pattern
    if gameState.currentFloor == 1 then
      -- Understated checkerboard with subtle wood grain
      for y = 1, interior.height - 2 do
        for x = 1, interior.width - 2 do
          local tileX = x * 32
          local tileY = y * 32
          local isLight = (x + y) % 2 == 0
          
          if isLight then
            -- Light hardwood
            love.graphics.setColor(0.22, 0.14, 0.10, 0.4)
          else
            -- Dark hardwood
            love.graphics.setColor(0.16, 0.10, 0.07, 0.4)
          end
          love.graphics.rectangle("fill", tileX, tileY, 32, 32)
          
          -- Subtle wood grain lines
          love.graphics.setColor(0, 0, 0, 0.08)
          love.graphics.setLineWidth(1)
          for i = 0, 1 do
            love.graphics.line(tileX + 8 + i * 16, tileY + 4, tileX + 8 + i * 16, tileY + 28)
          end
          
          -- Very subtle sheen in corners
          if isLight and (x + y) % 4 == 0 then
            love.graphics.setColor(1, 1, 0.9, 0.03)
            love.graphics.rectangle("fill", tileX + 3, tileY + 3, 8, 8)
          end
        end
      end
      
      love.graphics.setLineWidth(1)
    end

    -- Walls
    love.graphics.setColor(colors.bg[1] * 0.6, colors.bg[2] * 0.6, colors.bg[3] * 0.6)
    love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
    love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
    love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
    love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

    -- Exit door
    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.6)
    love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)
  end

  -- Portals (gold-tinted for Golden Vault)
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local px = portal.x * 32
      local py = portal.y * 32
      local pulse = math.sin(t * 3) * 0.2 + 0.8

      if isGoldenVault then
        -- Gold portal glow
        love.graphics.setColor(0.85, 0.7, 0.2, 0.2 * pulse)
        love.graphics.circle("fill", px + 16, py + 16, 28)
        love.graphics.setColor(0.95, 0.85, 0.4, 0.4 * pulse)
        love.graphics.circle("fill", px + 16, py + 16, 20)
        love.graphics.setColor(1, 0.95, 0.7, pulse)
        love.graphics.circle("fill", px + 16, py + 16, 12)
      else
        love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.3 * pulse)
        love.graphics.circle("fill", px + 16, py + 16, 25)
        love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], pulse)
        love.graphics.circle("fill", px + 16, py + 16, 18)
      end

      if isGoldenVault then
        love.graphics.setColor(0.95, 0.85, 0.4)
      else
        love.graphics.setColor(1, 1, 1)
      end
      local font = love.graphics.getFont()
      local textW = font:getWidth(portal.name)
      love.graphics.print(portal.name, px + 16 - textW/2, py + 40)
    end
  end

  -- Interior name
  if isGoldenVault then
    love.graphics.setColor(0.95, 0.85, 0.4)
  else
    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3])
  end
  love.graphics.print(interior.name, 40, 40)
end

function M.drawElevator()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Overlay
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Panel
  local panelW = 350
  local panelH = 400
  local panelX = screenW/2 - panelW/2
  local panelY = screenH/2 - panelH/2

  love.graphics.setColor(0.2, 0.22, 0.25)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
  love.graphics.setColor(0.5, 0.55, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)

  -- Title
  love.graphics.setColor(1, 1, 1)
  local title = "CITY TRANSIT"
  local font = love.graphics.getFont()
  local titleW = font:getWidth(title)
  love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 20)

  -- Floor buttons
  local buttonY = panelY + 60
  for i, floorId in ipairs(elevatorState.floors) do
    local floorDef = floors.getFloor(floorId)
    local isSelected = (floorId == elevatorState.selectedFloor)
    local isCurrent = (floorId == gameState.currentFloor)

    -- Button background
    if isSelected then
      love.graphics.setColor(0.4, 0.5, 0.6)
    elseif isCurrent then
      love.graphics.setColor(0.3, 0.4, 0.45)
    else
      love.graphics.setColor(0.25, 0.28, 0.32)
    end
    love.graphics.rectangle("fill", panelX + 20, buttonY, panelW - 40, 45, 5, 5)

    -- Level indicator
    love.graphics.setColor(floorDef.colorScheme.accent[1], floorDef.colorScheme.accent[2], floorDef.colorScheme.accent[3])
    love.graphics.rectangle("fill", panelX + 25, buttonY + 5, 8, 35)

    -- Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("L" .. floorId .. ": " .. floorDef.name, panelX + 45, buttonY + 8)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(floorDef.subtitle, panelX + 45, buttonY + 25)

    if isCurrent then
      love.graphics.setColor(0.5, 0.8, 0.5)
      love.graphics.print("[HERE]", panelX + panelW - 70, buttonY + 15)
    end

    buttonY = buttonY + 55
  end

  -- Instructions
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.print("UP/DOWN: Select   ENTER: Go   ESC: Close", panelX + 30, panelY + panelH - 35)
end

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local floorDef = floors.getFloor(gameState.currentFloor)

  -- Maze overlay effects
  if gameState.mazeState then
    local ms = gameState.mazeState

    -- Knockback flash overlay
    if ms.knockback.active then
      local flashAlpha = math.sin(ms.knockback.flashTimer * 12) * 0.3 + 0.3
      love.graphics.setColor(0.8, 0.1, 0.05, flashAlpha)
      love.graphics.rectangle("fill", 0, 0, screenW, screenH)

      -- Knockback message
      love.graphics.setColor(1, 0.2, 0.1)
      local font = love.graphics.getFont()
      local tw = font:getWidth(ms.knockback.message)
      love.graphics.print(ms.knockback.message, screenW/2 - tw/2, screenH/2 - 20)

      love.graphics.setColor(0.8, 0.8, 0.8)
      local subMsg = "Returning to entrance..."
      local sw = font:getWidth(subMsg)
      love.graphics.print(subMsg, screenW/2 - sw/2, screenH/2 + 10)
    end

    -- Warning message (RUN!!! etc)
    if ms.warningTimer > 0 and not ms.knockback.active then
      local warningPulse = math.sin(ms.timer * 8) * 0.2 + 0.8
      local msgAlpha = math.min(1, ms.warningTimer)

      -- Warning background
      love.graphics.setColor(0, 0, 0, 0.6 * msgAlpha)
      local font = love.graphics.getFont()
      local tw = font:getWidth(ms.warningMessage)
      love.graphics.rectangle("fill", screenW/2 - tw/2 - 20, screenH * 0.2 - 15, tw + 40, 40, 8, 8)

      -- Warning text
      if ms.warningMessage == "RUN!!!" then
        love.graphics.setColor(1, 0.15, 0.05, warningPulse * msgAlpha)
      else
        love.graphics.setColor(1, 0.85, 0.2, warningPulse * msgAlpha)
      end
      love.graphics.print(ms.warningMessage, screenW/2 - tw/2, screenH * 0.2 - 7)
    end

    -- Boulder chase indicator
    if ms.boulder.active then
      local rumblePulse = math.sin(ms.timer * 10) * 0.15 + 0.85
      -- Screen edge red vignette
      love.graphics.setColor(0.5, 0.05, 0.02, 0.15 * rumblePulse)
      love.graphics.rectangle("fill", 0, 0, 40, screenH)
      love.graphics.rectangle("fill", screenW - 40, 0, 40, screenH)
      love.graphics.rectangle("fill", 0, 0, screenW, 30)
      love.graphics.rectangle("fill", 0, screenH - 30, screenW, 30)
    end
  end

  -- Floor indicator
  if gameState.location == "floor" and floorDef then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 10, 10, 220, 50, 5, 5)
    love.graphics.setColor(floorDef.colorScheme.accent[1], floorDef.colorScheme.accent[2], floorDef.colorScheme.accent[3])
    love.graphics.print("L" .. gameState.currentFloor .. ": " .. floorDef.name, 20, 17)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(floorDef.subtitle, 20, 35)
  elseif gameState.location == "interior" then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", 10, 10, 250, 30, 5, 5)
      love.graphics.setColor(1, 1, 1)
      love.graphics.print(interior.name, 20, 17)
    end
  end

  -- Currency
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", screenW - 160, 10, 150, 30, 5, 5)
  love.graphics.setColor(0.9, 0.8, 0.4)
  love.graphics.print("Notes: " .. gameState.notes, screenW - 150, 17)

  -- Prompts
  if gameState.nearElevator and gameState.location == "floor" then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 100, screenH - 60, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to use Transit", screenW/2 - 100, screenH - 50, 200, "center")
  elseif gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW/2 - 120, screenH - 50, 240, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to talk to " .. gameState.nearbyNPC.name, screenW/2 - 120, screenH - 50, 240, "center")
  end

  -- Dialogue
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 140)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 115, screenW - 140, "left")
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Press E to close", 70, screenH - 50)
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

  if elevatorState.active then
    if key == "up" then
      local idx = 1
      for i, f in ipairs(elevatorState.floors) do
        if f == elevatorState.selectedFloor then idx = i break end
      end
      if idx > 1 then
        elevatorState.selectedFloor = elevatorState.floors[idx - 1]
      end
    elseif key == "down" then
      local idx = 1
      for i, f in ipairs(elevatorState.floors) do
        if f == elevatorState.selectedFloor then idx = i break end
      end
      if idx < #elevatorState.floors then
        elevatorState.selectedFloor = elevatorState.floors[idx + 1]
      end
    elseif key == "return" or key == "space" then
      if elevatorState.selectedFloor ~= gameState.currentFloor then
        M.changeFloor(elevatorState.selectedFloor)
        audio.playPortal()
      else
        M.closeElevator()
      end
    elseif key == "escape" then
      M.closeElevator()
    end
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
    -- Maze treasure chest interaction
    if gameState.mazeState and gameState.interiorId then
      local interior = buildings.getInterior(gameState.interiorId)
      if interior and interior.isMaze and interior.treasureChest then
        local tc = interior.treasureChest
        local ms = gameState.mazeState
        if not ms.chest.opened then
          local dx = math.abs(gameState.player.gridX - tc.x)
          local dy = math.abs(gameState.player.gridY - tc.y)
          if dx <= 1 and dy <= 1 then
            ms.chest.opened = true
            ms.chest.openAnim = 0
            -- Award treasure
            if tc.rewardType == "notes" then
              M.addNotes(tc.reward)
              ms.chest.rewardCollected = true
              ms.warningMessage = "Found " .. tc.reward .. " Notes!"
              ms.warningTimer = 3.0
            end
            -- Celebration particles
            for i = 1, 30 do
              table.insert(ms.particles, {
                x = tc.x * 32 + 16,
                y = tc.y * 32 + 16,
                vx = (math.random() - 0.5) * 150,
                vy = -math.random() * 120 - 30,
                life = 1.0 + math.random() * 1.0,
                maxLife = 2.0,
                size = 2 + math.random() * 3,
                color = {1, 0.85, 0.2},
              })
            end
            return
          end
        end
      end
    end

    if gameState.nearElevator and gameState.location == "floor" then
      M.openElevator()
      audio.playPortal()
      return
    end

    if gameState.nearbyPortal then
      audio.playPortal()
      gameState.returnLocation = gameState.location
      gameState.returnFloor = gameState.currentFloor
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

  if gameState.returnLocation and gameState.returnLocation ~= "floor" then
    if gameState.returnFloor then
      gameState.currentFloor = gameState.returnFloor
    end
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
    if gameState.returnFloor then
      M.changeFloor(gameState.returnFloor)
    else
      M.changeFloor(gameState.currentFloor)
    end
  end
  gameState.returnLocation = nil
  gameState.returnPosition = nil
  gameState.returnFloor = nil
end

function M.spawnAtPDHQ()
  -- Override current position to Mixia Level 4 Galaxy PD HQ door
  M.changeFloor(4)
  -- Galaxy PD HQ door is at gridX=31, gridY=14. Spawn player one tile below the door.
  gameState.player.gridX = 31
  gameState.player.gridY = 15
  gameState.player.x = gameState.player.gridX * 32 + 16
  gameState.player.y = gameState.player.gridY * 32 + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y
end

return M

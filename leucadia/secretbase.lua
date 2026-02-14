-- leucadia/secretbase.lua
-- Aircraft carrier Secret Base sublevel beneath Leucadia
-- Inspired by Camp Pendleton, San Diego Navy culture, and USS-class carriers
-- Accessed via trapdoor in Driftwood Cottage (Beach House 2)

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local npc = require("hub.npc")
local audio = require("hub.audio")
local floors = require("leucadia.floors")
local buildings = require("leucadia.buildings")

local GRID_SIZE = 32

-- ═══════════════════════════════════════
-- CARRIER COLOR PALETTE
-- ═══════════════════════════════════════
local COLORS = {
  -- Hull and structure
  deck_gray = {0.35, 0.38, 0.42},        -- Flight deck nonskid
  bulkhead = {0.25, 0.28, 0.32},         -- Interior bulkhead steel
  floor_main = {0.2, 0.22, 0.26},        -- Main corridor floor
  floor_accent = {0.15, 0.17, 0.2},      -- Floor grid lines
  pipe = {0.45, 0.42, 0.38},             -- Overhead pipes/conduits

  -- Navy colors
  navy_blue = {0.08, 0.12, 0.3},         -- Deep navy blue
  navy_white = {0.88, 0.9, 0.92},        -- Clean white markings
  haze_gray = {0.5, 0.52, 0.55},         -- Haze gray hull paint

  -- Safety / warning
  warning_red = {0.85, 0.15, 0.1},       -- Ordnance / danger
  caution_yellow = {0.9, 0.8, 0.15},     -- Caution stripes
  safety_green = {0.15, 0.7, 0.25},      -- Safe / go

  -- Atmosphere
  ocean_deep = {0.08, 0.18, 0.35},       -- Deep ocean through portholes
  sky_carrier = {0.55, 0.7, 0.85},       -- Open sky on flight deck

  -- UI
  text_bright = {0.85, 0.88, 0.92},
  text_dim = {0.45, 0.48, 0.55},
  hud_green = {0.2, 0.85, 0.3},
  status_amber = {0.95, 0.7, 0.15},
}

-- ═══════════════════════════════════════
-- FLOOR LAYOUT
-- ═══════════════════════════════════════
local floorDef = floors.getFloor(-1)
local BASE_WIDTH = floorDef.width
local BASE_HEIGHT = floorDef.height

-- Walkable zones within the carrier
local zones = {
  -- Main fore-aft corridor (O-3 level, hangar deck)
  main_corridor = {
    name = "Main Passageway",
    x1 = 1, y1 = 8, x2 = 49, y2 = 16,
    floor = "corridor"
  },
  -- Port side passage (below deck)
  port_passage = {
    name = "Port Passageway",
    x1 = 1, y1 = 14, x2 = 12, y2 = 24,
    floor = "below_deck"
  },
  -- Starboard side passage (below deck)
  starboard_passage = {
    name = "Starboard Passageway",
    x1 = 35, y1 = 14, x2 = 48, y2 = 24,
    floor = "below_deck"
  },
  -- Cross-passage connecting lower buildings
  cross_passage = {
    name = "Second Deck Cross-passage",
    x1 = 12, y1 = 22, x2 = 40, y2 = 25,
    floor = "below_deck"
  },
  -- Spur connections to upper doors
  spur_hangar = { name = "Hangar Spur", x1 = 6, y1 = 7, x2 = 8, y2 = 8, floor = "corridor" },
  spur_mess = { name = "Mess Spur", x1 = 20, y1 = 6, x2 = 22, y2 = 7, floor = "corridor" },
  spur_bridge = { name = "Bridge Spur", x1 = 39, y1 = 8, x2 = 41, y2 = 9, floor = "corridor" },
  -- Spur connections to lower doors
  spur_armory = { name = "Armory Spur", x1 = 5, y1 = 22, x2 = 7, y2 = 23, floor = "below_deck" },
  spur_berthing = { name = "Berthing Spur", x1 = 17, y1 = 22, x2 = 19, y2 = 23, floor = "below_deck" },
  spur_warroom = { name = "War Room Spur", x1 = 31, y1 = 22, x2 = 33, y2 = 23, floor = "below_deck" },
  spur_engineering = { name = "Engineering Spur", x1 = 42, y1 = 22, x2 = 44, y2 = 23, floor = "below_deck" },
}

-- ═══════════════════════════════════════
-- GAME STATE
-- ═══════════════════════════════════════
local gameState = {}

M.returnToHub = nil

function M.load()
  gameState.location = "base_outdoors"  -- Main carrier deck
  gameState.interiorId = nil

  -- Player spawns at center of main corridor (ladder from trapdoor)
  local startX = 25 * GRID_SIZE + 16
  local startY = 12 * GRID_SIZE + 16
  gameState.player = player.new(startX, startY)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.collisionMap = floors.createFloorCollisionMap(-1)
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.buildingEntryCooldown = 0
  gameState.transition = nil
  gameState.returnPosition = nil
  gameState.animationTime = 0

  -- Carrier atmosphere animations
  gameState.pipeDrip = 0
  gameState.fluorFlicker = 0
  gameState.hullCreak = 0
  gameState.signalFlagWave = 0

  M.setupBaseNPCs()
end

function M.setupBaseNPCs()
  gameState.currentNPCs = {}
  if floorDef.npcs then
    for _, npcData in ipairs(floorDef.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
    end
  end
end

-- ═══════════════════════════════════════
-- BUILDING ENTRY / EXIT
-- ═══════════════════════════════════════

function M.enterBuilding(buildingId)
  local interior = buildings.getInterior(buildingId)
  if not interior then return end

  gameState.interiorId = buildingId
  gameState.location = "base_interior"
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}

  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * GRID_SIZE + 16
  gameState.player.y = gameState.player.gridY * GRID_SIZE + 16
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
  gameState.location = "base_outdoors"
  gameState.interiorId = nil
  gameState.buildingEntryCooldown = 0.5

  if gameState.returnPosition then
    gameState.player.gridX = gameState.returnPosition.gridX
    gameState.player.gridY = gameState.returnPosition.gridY + 1
    gameState.player.x = gameState.player.gridX * GRID_SIZE + 16
    gameState.player.y = gameState.player.gridY * GRID_SIZE + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.returnPosition = nil
  end

  gameState.collisionMap = floors.createFloorCollisionMap(-1)
  gameState.currentPortals = nil
  M.setupBaseNPCs()
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  gameState.animationTime = gameState.animationTime + dt

  -- Carrier atmosphere animations
  gameState.pipeDrip = gameState.pipeDrip + dt * 0.8
  gameState.fluorFlicker = gameState.fluorFlicker + dt * 12
  gameState.hullCreak = gameState.hullCreak + dt * 0.3
  gameState.signalFlagWave = gameState.signalFlagWave + dt * 2

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

  if gameState.buildingEntryCooldown > 0 then
    gameState.buildingEntryCooldown = gameState.buildingEntryCooldown - dt
    if gameState.buildingEntryCooldown < 0 then
      gameState.buildingEntryCooldown = 0
    end
  end

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil

  if gameState.location == "base_outdoors" then
    -- Check building doors
    if gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(floorDef.buildings) do
        if gameState.player.gridX == b.doorX and gameState.player.gridY == b.doorY then
          gameState.nearBuildingDoor = b
          local interiorId = b.interior
          gameState.transition = {
            phase = "out",
            timer = 0,
            duration = 0.2,
            callback = function()
              M.enterBuilding(interiorId)
            end
          }
          break
        end
      end
    end

    -- Check exit (center of main corridor, ladder back up)
    -- Exit zone at grid y=12, x=24-26 (ladder well)
    if gameState.player.gridY == 12 and
       gameState.player.gridX >= 24 and gameState.player.gridX <= 26 then
      -- Don't auto-exit; require pressing up or E near the ladder
    end
  else
    -- Interior: check portals
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
      local interior = buildings.getInterior(gameState.interiorId)
      if interior and gameState.player.gridX == interior.exitX and gameState.player.gridY == interior.exitY then
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

  -- Check if near exit ladder (center of base)
  if gameState.location == "base_outdoors" then
    if gameState.player.gridY >= 11 and gameState.player.gridY <= 13 and
       gameState.player.gridX >= 24 and gameState.player.gridX <= 26 then
      gameState.nearExitLadder = true
    else
      gameState.nearExitLadder = false
    end
  else
    gameState.nearExitLadder = false
  end
end

-- ═══════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════

function M.draw()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Dark carrier interior background
  love.graphics.setColor(COLORS.bulkhead[1], COLORS.bulkhead[2], COLORS.bulkhead[3])
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  love.graphics.push()
  love.graphics.translate(-gameState.camera.x + screenW / 2,
                          -gameState.camera.y + screenH / 2)

  if gameState.location == "base_outdoors" then
    M.drawBaseFloor()
  else
    M.drawBaseInterior()
  end

  player.draw(gameState.player, gameState.animationTime)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj)
  end

  love.graphics.pop()

  M.drawBaseUI()

  -- Fade transition
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

function M.drawBaseFloor()
  local gs = GRID_SIZE

  -- Draw zone floors
  for _, zone in pairs(zones) do
    local zx = zone.x1 * gs
    local zy = zone.y1 * gs
    local zw = (zone.x2 - zone.x1 + 1) * gs
    local zh = (zone.y2 - zone.y1 + 1) * gs

    -- Floor color based on zone type
    if zone.floor == "corridor" then
      love.graphics.setColor(COLORS.floor_main[1], COLORS.floor_main[2], COLORS.floor_main[3], 0.95)
    elseif zone.floor == "below_deck" then
      love.graphics.setColor(COLORS.floor_main[1] * 0.8, COLORS.floor_main[2] * 0.8, COLORS.floor_main[3] * 0.8, 0.95)
    else
      love.graphics.setColor(COLORS.floor_main[1], COLORS.floor_main[2], COLORS.floor_main[3], 0.95)
    end
    love.graphics.rectangle("fill", zx, zy, zw, zh)

    -- Steel deck grid lines (rivets / panel seams)
    love.graphics.setColor(COLORS.floor_accent[1], COLORS.floor_accent[2], COLORS.floor_accent[3], 0.3)
    love.graphics.setLineWidth(1)
    for gx = zx, zx + zw, gs do
      love.graphics.line(gx, zy, gx, zy + zh)
    end
    for gy = zy, zy + zh, gs do
      love.graphics.line(zx, gy, zx + zw, gy)
    end

    -- Zone border (bulkhead lines)
    love.graphics.setColor(COLORS.haze_gray[1], COLORS.haze_gray[2], COLORS.haze_gray[3], 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", zx, zy, zw, zh)
  end

  -- Draw buildings
  for _, b in ipairs(floorDef.buildings) do
    M.drawCarrierBuilding(b)
  end

  -- Draw hazard stripes along corridor edges
  M.drawHazardStripes(1 * gs, 8 * gs, 48 * gs, gs * 0.3)
  M.drawHazardStripes(1 * gs, 16 * gs, 48 * gs, gs * 0.3)

  -- Draw exit ladder indicator (center of base)
  local exitPulse = math.sin(gameState.animationTime * 2) * 0.2 + 0.8
  love.graphics.setColor(COLORS.navy_blue[1], COLORS.navy_blue[2], COLORS.navy_blue[3], 0.4 * exitPulse)
  love.graphics.rectangle("fill", 24 * gs, 11 * gs, 3 * gs, 3 * gs)
  love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3], 0.7)
  local font = love.graphics.getFont()
  local exitText = "LADDER UP"
  local exitTextW = font:getWidth(exitText)
  love.graphics.print(exitText, 25.5 * gs - exitTextW / 2, 11 * gs + 8)
  local exitText2 = "TO LEUCADIA"
  local exitText2W = font:getWidth(exitText2)
  love.graphics.print(exitText2, 25.5 * gs - exitText2W / 2, 11 * gs + 24)

  -- USS Pendleton branding on main corridor wall
  love.graphics.setColor(COLORS.navy_blue[1], COLORS.navy_blue[2], COLORS.navy_blue[3], 0.6)
  love.graphics.rectangle("fill", 15 * gs, 15 * gs, 10 * gs, gs)
  love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3], 0.9)
  local shipName = "USS PENDLETON  CVN-82"
  local shipNameW = font:getWidth(shipName)
  love.graphics.print(shipName, 20 * gs - shipNameW / 2, 15 * gs + 8)

  -- Motto below
  love.graphics.setColor(COLORS.caution_yellow[1], COLORS.caution_yellow[2], COLORS.caution_yellow[3], 0.6)
  love.graphics.rectangle("fill", 16 * gs, 16 * gs, 8 * gs, gs * 0.6)
  love.graphics.setColor(COLORS.navy_blue[1], COLORS.navy_blue[2], COLORS.navy_blue[3], 0.9)
  local motto = "READY FOR ALL  •  YIELDING TO NONE"
  local mottoW = font:getWidth(motto)
  love.graphics.print(motto, 20 * gs - mottoW / 2, 16 * gs + 2)

  -- Overhead pipes along corridors
  M.drawOverheadPipes()

  -- Signal flags decoration
  M.drawSignalFlags()
end

function M.drawCarrierBuilding(b)
  local gs = GRID_SIZE
  local bx = b.x * gs
  local by = b.y * gs
  local bw = b.w * gs
  local bh = b.h * gs

  -- Building body (steel gray)
  love.graphics.setColor(b.color[1], b.color[2], b.color[3])
  love.graphics.rectangle("fill", bx, by, bw, bh)

  -- Accent border
  if b.accentColor then
    love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3])
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh)
  end

  -- Door indicator
  local doorX = b.doorX * gs
  local doorY = b.doorY * gs
  local doorPulse = math.sin(gameState.animationTime * 3) * 0.15 + 0.85
  love.graphics.setColor(COLORS.safety_green[1], COLORS.safety_green[2], COLORS.safety_green[3], doorPulse)
  love.graphics.rectangle("fill", doorX, doorY, gs, gs)

  -- Building name label
  love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3], 0.8)
  local font = love.graphics.getFont()
  local nameW = font:getWidth(b.name)
  love.graphics.print(b.name, bx + bw / 2 - nameW / 2, by + 6)

  -- Neon sign (if any)
  if b.neonSign then
    local signGlow = math.sin(gameState.animationTime * 1.5) * 0.2 + 0.8
    love.graphics.setColor(b.neonSign.color[1], b.neonSign.color[2], b.neonSign.color[3], signGlow)
    local signW = font:getWidth(b.neonSign.text)
    love.graphics.print(b.neonSign.text, bx + bw / 2 - signW / 2, by + bh - 20)
  end
end

function M.drawHazardStripes(x, y, w, h)
  local stripeW = 12
  love.graphics.setColor(COLORS.caution_yellow[1], COLORS.caution_yellow[2], COLORS.caution_yellow[3], 0.3)
  for sx = x, x + w, stripeW * 2 do
    love.graphics.polygon("fill",
      sx, y,
      sx + stripeW, y,
      sx + stripeW - h, y + h,
      sx - h, y + h)
  end
end

function M.drawOverheadPipes()
  local gs = GRID_SIZE
  -- Horizontal pipes along main corridor ceiling
  love.graphics.setColor(COLORS.pipe[1], COLORS.pipe[2], COLORS.pipe[3], 0.25)
  love.graphics.setLineWidth(3)
  love.graphics.line(1 * gs, 8.3 * gs, 49 * gs, 8.3 * gs)
  love.graphics.line(1 * gs, 8.6 * gs, 49 * gs, 8.6 * gs)
  -- Cross-passage pipes
  love.graphics.line(12 * gs, 22.3 * gs, 40 * gs, 22.3 * gs)

  -- Vertical pipes along port/starboard passages
  love.graphics.line(1.3 * gs, 14 * gs, 1.3 * gs, 24 * gs)
  love.graphics.line(48.7 * gs, 14 * gs, 48.7 * gs, 24 * gs)

  -- Occasional drip animation
  local dripPhase = math.sin(gameState.pipeDrip * math.pi) * 0.5 + 0.5
  if dripPhase > 0.9 then
    love.graphics.setColor(0.3, 0.5, 0.7, 0.3)
    love.graphics.circle("fill", 20 * gs, 8.6 * gs + 4, 2)
  end
end

function M.drawSignalFlags()
  local gs = GRID_SIZE
  local wave = gameState.signalFlagWave
  -- Signal flags strung across main corridor
  local flagColors = {
    {0.9, 0.1, 0.1},  -- Red
    {0.9, 0.9, 0.1},  -- Yellow
    {0.1, 0.1, 0.9},  -- Blue
    {0.9, 0.9, 0.9},  -- White
    {0.1, 0.6, 0.1},  -- Green
    {0.9, 0.5, 0.1},  -- Orange
  }
  for i = 0, 15 do
    local fx = (3 + i * 3) * gs
    local fy = 9 * gs + math.sin(wave + i * 0.5) * 3
    local flagColor = flagColors[(i % #flagColors) + 1]
    love.graphics.setColor(flagColor[1], flagColor[2], flagColor[3], 0.35)
    love.graphics.rectangle("fill", fx, fy, gs * 0.6, gs * 0.4)
  end
end

function M.drawBaseInterior()
  local gs = GRID_SIZE
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  -- Floor
  love.graphics.setColor(COLORS.floor_main[1], COLORS.floor_main[2], COLORS.floor_main[3])
  love.graphics.rectangle("fill", 0, 0, interior.width * gs, interior.height * gs)

  -- Grid
  love.graphics.setColor(COLORS.floor_accent[1], COLORS.floor_accent[2], COLORS.floor_accent[3], 0.2)
  love.graphics.setLineWidth(1)
  for x = 0, interior.width * gs, gs do
    love.graphics.line(x, 0, x, interior.height * gs)
  end
  for y = 0, interior.height * gs, gs do
    love.graphics.line(0, y, interior.width * gs, y)
  end

  -- Walls
  love.graphics.setColor(COLORS.bulkhead[1], COLORS.bulkhead[2], COLORS.bulkhead[3])
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", 0, 0, interior.width * gs, interior.height * gs)

  -- Exit indicator
  local exitPulse = math.sin(gameState.animationTime * 3) * 0.15 + 0.85
  love.graphics.setColor(COLORS.safety_green[1], COLORS.safety_green[2], COLORS.safety_green[3], exitPulse)
  love.graphics.rectangle("fill", interior.exitX * gs, interior.exitY * gs, gs, gs)

  -- Room name
  love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3], 0.8)
  local font = love.graphics.getFont()
  local nameW = font:getWidth(interior.name)
  love.graphics.print(interior.name, interior.width * gs / 2 - nameW / 2, 6)

  -- Draw portals
  if gameState.currentPortals then
    for _, portal in ipairs(gameState.currentPortals) do
      local px = portal.x * gs + gs / 2
      local py = portal.y * gs + gs / 2
      local glow = math.sin(gameState.animationTime * 2) * 0.2 + 0.8
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], glow * 0.5)
      love.graphics.circle("fill", px, py, gs * 0.8)
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], glow)
      love.graphics.circle("fill", px, py, gs * 0.4)
      love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3], 0.85)
      local portalW = font:getWidth(portal.name)
      love.graphics.print(portal.name, px - portalW / 2, py - gs - 4)
    end
  end

  -- Draw decorations
  if interior.decorations then
    for _, deco in ipairs(interior.decorations) do
      local dx = deco.x * gs
      local dy = deco.y * gs
      local dw = (deco.w or 1) * gs
      local dh = (deco.h or 1) * gs
      love.graphics.setColor(COLORS.haze_gray[1], COLORS.haze_gray[2], COLORS.haze_gray[3], 0.5)
      love.graphics.rectangle("fill", dx, dy, dw, dh)
      love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3], 0.5)
      local typeW = font:getWidth(deco.type)
      if typeW < dw then
        love.graphics.print(deco.type, dx + dw / 2 - typeW / 2, dy + dh / 2 - 6)
      end
    end
  end
end

function M.drawBaseUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local font = love.graphics.getFont()

  -- Location header
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, 0, screenW, 40)
  love.graphics.setColor(COLORS.navy_white[1], COLORS.navy_white[2], COLORS.navy_white[3])
  love.graphics.print("USS PENDLETON — SECRET BASE", 10, 5)
  love.graphics.setColor(COLORS.text_dim[1], COLORS.text_dim[2], COLORS.text_dim[3])
  if gameState.location == "base_interior" and gameState.interiorId then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.print(interior.name, 10, 22)
    end
  else
    love.graphics.print("Main Deck", 10, 22)
  end

  -- Prompts
  if gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW / 2 - 60, screenH - 35, 120, 25, 4)
    love.graphics.setColor(COLORS.hud_green[1], COLORS.hud_green[2], COLORS.hud_green[3])
    love.graphics.print("Press E to talk", screenW / 2 - 48, screenH - 30)
  end

  if gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW / 2 - 60, screenH - 35, 120, 25, 4)
    love.graphics.setColor(COLORS.status_amber[1], COLORS.status_amber[2], COLORS.status_amber[3])
    love.graphics.print("Press E to enter", screenW / 2 - 50, screenH - 30)
  end

  if gameState.nearExitLadder and gameState.location == "base_outdoors" then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW / 2 - 80, screenH - 35, 160, 25, 4)
    love.graphics.setColor(COLORS.caution_yellow[1], COLORS.caution_yellow[2], COLORS.caution_yellow[3])
    love.graphics.print("Press E to climb ladder", screenW / 2 - 68, screenH - 30)
  end

  -- Dialogue box
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 60, screenH - 140, screenW - 120, 120, 6)
    love.graphics.setColor(COLORS.haze_gray[1], COLORS.haze_gray[2], COLORS.haze_gray[3])
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 60, screenH - 140, screenW - 120, 120, 6)
    love.graphics.setColor(COLORS.status_amber[1], COLORS.status_amber[2], COLORS.status_amber[3])
    love.graphics.print(gameState.dialogueBox.npc, 80, screenH - 130)
    love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3])
    love.graphics.printf(gameState.dialogueBox.text, 80, screenH - 110, screenW - 180)
    love.graphics.setColor(COLORS.text_dim[1], COLORS.text_dim[2], COLORS.text_dim[3])
    love.graphics.print("Press E to close", 80, screenH - 40)
  end
end

-- ═══════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════

function M.keypressed(key)
  if gameState.dialogueBox then
    if key == "e" or key == "escape" or key == "return" then
      gameState.dialogueBox = nil
    end
    return
  end

  if key == "escape" then
    -- Return to Leucadia
    if M.returnToHub then
      M.returnToHub()
    end
    return
  end

  if key == "e" then
    -- Exit ladder
    if gameState.nearExitLadder and gameState.location == "base_outdoors" then
      if M.returnToHub then
        M.returnToHub()
      end
      return
    end

    -- Portal interaction
    if gameState.nearbyPortal then
      audio.playPortal()
      -- Portal games are handled via switchToGame in the parent hub
      -- For now, we return to hub and let it handle
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

return M

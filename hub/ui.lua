-- hub/ui.lua (REWRITTEN)
-- Complete visual overhaul: Neon Coruscant art style
-- Pokemon Emerald-style sprites for player/NPCs
-- Floor-specific rendering with galaxy windows and spaceship flybys

local M = {}
local neon = require("hub.neon")
local windows = require("hub.windows")
local spaceships = require("hub.spaceships")
local floors = require("hub.floors")

local fonts = {}
local GRID_SIZE = 32

function M.load()
  fonts.normal = love.graphics.newFont(14)
  fonts.large = love.graphics.newFont(20)
  fonts.small = love.graphics.newFont(12)
  fonts.title = love.graphics.newFont(24)
  fonts.tiny = love.graphics.newFont(10)
  windows.init()
end

function M.draw(gameState, time)
  time = time or 0
  love.graphics.push()
  love.graphics.translate(-gameState.camera.x + love.graphics.getWidth() / 2,
                          -gameState.camera.y + love.graphics.getHeight() / 2)

  if gameState.location == "floor" then
    M.drawFloor(gameState, time)
  elseif gameState.location == "casino" then
    M.drawCasinoInterior(gameState, time)
  elseif gameState.interiorId then
    M.drawInterior(gameState, time)
  end

  love.graphics.pop()

  -- UI overlay (drawn in screen space)
  M.drawUI(gameState, time)
end

-- ═══════════════════════════════════════════════════════
-- FLOOR RENDERING (Coruscant-style neon space station)
-- ═══════════════════════════════════════════════════════

function M.drawFloor(gameState, time)
  local floorDef = floors.getFloor(gameState.currentFloor)
  if not floorDef then return end

  local colorScheme = floorDef.colorScheme
  local gs = GRID_SIZE

  -- Floor tiles with neon accents
  neon.drawFloorTiles(floorDef.width, floorDef.height, gs, colorScheme, time)

  -- Galaxy windows along the walls (top, left, right only)
  local windowStyle = floorDef.windowStyle or "starfield"
  windows.drawWindowRow(windowStyle, "top", floorDef.width, floorDef.height, gs, time)
  windows.drawWindowRow(windowStyle, "left", floorDef.width, floorDef.height, gs, time)
  windows.drawWindowRow(windowStyle, "right", floorDef.width, floorDef.height, gs, time)

  -- Draw spaceships in windows (rendered in world space but clipped)
  -- (spaceships are drawn separately in the window system)

  -- Walking paths with neon guide lights
  if floorDef.paths then
    local nr, ng, nb = colorScheme.neon[1], colorScheme.neon[2], colorScheme.neon[3]
    for _, path in ipairs(floorDef.paths) do
      neon.drawPath(path, gs, nr, ng, nb, time)
    end
  end

  -- Crates (Floor 1: Slateport warehouse)
  if floorDef.crates then
    for _, crate in ipairs(floorDef.crates) do
      neon.drawCrate(crate, gs, time)
    end
  end

  -- Buildings (neon Coruscant architecture)
  if floorDef.buildings then
    for _, b in ipairs(floorDef.buildings) do
      local building = {
        x = b.x, y = b.y, w = b.w, h = b.h,
        doorX = b.doorX, doorY = b.doorY,
        name = b.name,
        neonColor = b.neonColor or colorScheme.neon,
        color = b.color or colorScheme.bg
      }
      neon.drawNeonBuilding(building, gs, time)
    end
  end

  -- Elevator pad
  if floorDef.elevatorPos then
    neon.drawElevatorPad(floorDef.elevatorPos, gs, colorScheme.neon, time)
  end

  -- NPCs
  for _, npcObj in ipairs(gameState.currentNPCs) do
    M.drawNPC(npcObj, colorScheme.neon, time)
  end

  -- Player (Pokemon Emerald style)
  M.drawPlayer(gameState.player, time)
end

-- ═══════════════════════════════════════════════════════
-- INTERIOR RENDERING (inside buildings)
-- ═══════════════════════════════════════════════════════

function M.drawInterior(gameState, time)
  local buildings = require("hub.buildings")
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  local gs = GRID_SIZE
  local floorDef = floors.getFloor(gameState.currentFloor)
  local colorScheme = floorDef and floorDef.colorScheme or {bg = {0.05, 0.05, 0.1}, neon = {0.0, 0.8, 1.0}}

  -- Interior floor (dark metallic)
  love.graphics.setColor(0.06, 0.06, 0.1)
  love.graphics.rectangle("fill", 0, 0, interior.width * gs, interior.height * gs)

  -- Floor tile grid
  for x = 0, interior.width - 1 do
    for y = 0, interior.height - 1 do
      local shade = 0.02 + 0.01 * ((x + y) % 2)
      love.graphics.setColor(0.06 + shade, 0.06 + shade, 0.1 + shade)
      love.graphics.rectangle("fill", x * gs + 1, y * gs + 1, gs - 2, gs - 2)
    end
  end

  -- Zones (if casino-style interior)
  if interior.zones then
    for _, zone in ipairs(interior.zones) do
      M.drawFloorZone(zone, gs)
    end
  end

  -- Neon wall border
  local nr, ng, nb = colorScheme.neon[1], colorScheme.neon[2], colorScheme.neon[3]
  neon.drawNeonRect(0, 0, interior.width * gs, interior.height * gs, nr, ng, nb, 0.6, 2)

  -- Interior name sign (top center)
  love.graphics.setFont(fonts.small)
  local nameW = fonts.small:getWidth(interior.name) + 20
  local nameX = (interior.width * gs) / 2 - nameW / 2
  neon.drawNeonSign(interior.name, nameX, 4, nameW, 20, fonts.small, nr, ng, nb, time)

  -- Exit door (glowing green)
  local exitGlow = 0.5 + 0.5 * math.sin(time * 2)
  neon.drawNeonRect(interior.exitX * gs + 2, interior.exitY * gs + 2, gs - 4, gs - 4, 0.2, 0.8, 0.3, exitGlow)
  love.graphics.setColor(0.1, 0.3, 0.1, 0.6)
  love.graphics.rectangle("fill", interior.exitX * gs + 4, interior.exitY * gs + 4, gs - 8, gs - 8, 2)
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.3, 0.9, 0.3, exitGlow)
  love.graphics.printf("EXIT", interior.exitX * gs, interior.exitY * gs + 10, gs, "center")

  -- Decorations (casino)
  if interior.decorations then
    for _, deco in ipairs(interior.decorations) do
      if deco.type == "fountain" then
        M.drawFountain(deco.x * gs + gs/2, deco.y * gs + gs/2, time)
      elseif deco.type == "sculpture" then
        M.drawSculpture(deco.x, deco.y, gs)
      elseif deco.type == "counter" then
        M.drawShopCounter(deco.x, deco.y, gs, deco.w or 4)
      elseif deco.type == "slots" then
        M.drawSlotMachines(deco.x, deco.y, gs, time)
      elseif deco.type == "blackjack_table" then
        M.drawBlackjackTable(deco.x, deco.y, gs)
      elseif deco.type == "roulette_table" then
        M.drawRouletteTable(deco.x, deco.y, gs, time)
      end
    end
  end

  -- Portals (neon-styled)
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local pr, pg, pb = portal.color[1], portal.color[2], portal.color[3]
      local portalPulse = 0.3 + 0.3 * math.sin(time * 2 + portal.x)

      -- Portal glow
      love.graphics.setColor(pr, pg, pb, portalPulse * 0.15)
      love.graphics.rectangle("fill", portal.x * gs - 4, portal.y * gs - 4, gs * 2 + 8, gs * 2 + 8, 4)

      -- Portal border
      neon.drawNeonRect(portal.x * gs, portal.y * gs, gs * 2, gs * 2, pr, pg, pb, 0.5 + portalPulse)

      -- Portal name
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.printf(portal.name, portal.x * gs, (portal.y - 0.6) * gs, gs * 2, "center")
    end
  end

  -- NPCs
  for _, npcObj in ipairs(gameState.currentNPCs) do
    M.drawNPC(npcObj, colorScheme.neon, time)
  end

  -- Player
  M.drawPlayer(gameState.player, time)
end

-- ═══════════════════════════════════════════════════════
-- CASINO INTERIOR (special Bellagio rendering)
-- ═══════════════════════════════════════════════════════

function M.drawCasinoInterior(gameState, time)
  local buildings = require("hub.buildings")
  local interior = buildings.getInterior("casino")
  if not interior then return end

  local gs = GRID_SIZE

  -- Draw floor zones first (marble, carpet, etc.)
  if interior.zones then
    for _, zone in ipairs(interior.zones) do
      M.drawFloorZone(zone, gs)
    end
  end

  -- Neon wall border
  neon.drawNeonRect(0, 0, interior.width * gs, interior.height * gs, 1.0, 0.6, 0.8, 0.5, 2)

  -- Chihuly ceiling
  M.drawChihulyCeiling(interior.width * gs / 2, gs * 1.5, time)

  -- Decorations
  if interior.decorations then
    for _, deco in ipairs(interior.decorations) do
      if deco.type == "fountain" then
        M.drawFountain(deco.x * gs + gs/2, deco.y * gs + gs/2, time)
      elseif deco.type == "sculpture" then
        M.drawSculpture(deco.x, deco.y, gs)
      elseif deco.type == "counter" then
        M.drawShopCounter(deco.x, deco.y, gs, deco.w or 4)
      elseif deco.type == "slots" then
        M.drawSlotMachines(deco.x, deco.y, gs, time)
      elseif deco.type == "blackjack_table" then
        M.drawBlackjackTable(deco.x, deco.y, gs)
      elseif deco.type == "roulette_table" then
        M.drawRouletteTable(deco.x, deco.y, gs, time)
      end
    end
  end

  -- Exit
  local exitGlow = 0.5 + 0.5 * math.sin(time * 2)
  neon.drawNeonRect(interior.exitX * gs + 2, interior.exitY * gs + 2, gs - 4, gs - 4, 0.2, 0.8, 0.3, exitGlow)
  love.graphics.setColor(0.1, 0.3, 0.1, 0.6)
  love.graphics.rectangle("fill", interior.exitX * gs + 4, interior.exitY * gs + 4, gs - 8, gs - 8, 2)

  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local pr, pg, pb = portal.color[1], portal.color[2], portal.color[3]
      love.graphics.setColor(pr, pg, pb, 0.25)
      love.graphics.rectangle("fill", portal.x * gs, portal.y * gs, gs * 2, gs * 2)
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.printf(portal.name, portal.x * gs, (portal.y - 0.5) * gs, gs * 2, "center")
    end
  end

  -- NPCs
  for _, npcObj in ipairs(gameState.currentNPCs) do
    M.drawNPC(npcObj, {1, 0.6, 0.8}, time)
  end

  M.drawPlayer(gameState.player, time)
end

-- ═══════════════════════════════════════════════════════
-- POKEMON EMERALD-STYLE PLAYER SPRITE
-- ═══════════════════════════════════════════════════════

function M.drawPlayer(player, time)
  time = time or 0
  local px, py = player.x, player.y
  local dir = player.direction or "down"

  -- Walking or idle animation
  local walkBob = 0
  local footOffset = 0
  local armSwing = 0
  local isMoving = player.isMoving or player.moving

  if isMoving then
    -- Walking animation
    walkBob = math.sin(time * 10) * 2
    footOffset = math.sin(time * 10) * 2
    armSwing = math.sin(time * 10) * 3
  else
    -- Idle animations - more noticeable like NPCs
    -- Breathing animation (vertical bob)
    walkBob = math.sin(time * 1.5) * 1
    
    -- Occasional blink/look around (every few seconds)
    local lookCycle = time % 5
    if lookCycle < 0.2 then
      -- Quick blink
    elseif lookCycle > 3 and lookCycle < 3.5 then
      -- Head tilt/look
      walkBob = walkBob + math.sin((lookCycle - 3) * 12) * 0.5
    end
    
    -- Occasional arm adjustment
    if math.sin(time * 0.4) > 0.8 then
      armSwing = math.sin(time * 4) * 1
    end
  end

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", px, py + 12, 9, 4)

  if dir == "left" then
    -- === LEFT-FACING SPRITE ===
    -- Feet (staggered depth)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.rectangle("fill", px - 4, py + 6 + walkBob + footOffset, 4, 5)
    love.graphics.rectangle("fill", px - 2, py + 7 + walkBob, 4, 4)

    -- Legs
    love.graphics.setColor(0.2, 0.3, 0.5)
    love.graphics.rectangle("fill", px - 3, py + 1 + walkBob, 5, 6)

    -- Body (side view, narrower)
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 5, py - 8 + walkBob, 10, 10)

    -- Belt
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("fill", px - 4, py + walkBob, 8, 2)

    -- Arm (side view - one visible)
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 2, py - 6 + walkBob + armSwing, 4, 8)
    -- Hand
    love.graphics.setColor(0.9, 0.75, 0.6)
    love.graphics.rectangle("fill", px - 2, py + 1 + walkBob + armSwing, 4, 3)

    -- Head (side profile)
    love.graphics.setColor(0.92, 0.78, 0.62)
    love.graphics.rectangle("fill", px - 5, py - 16 + walkBob, 10, 9)

    -- Nose
    love.graphics.setColor(0.88, 0.74, 0.58)
    love.graphics.rectangle("fill", px - 7, py - 13 + walkBob, 3, 3)

    -- Hair (side profile)
    love.graphics.setColor(0.25, 0.2, 0.15)
    love.graphics.rectangle("fill", px - 4, py - 18 + walkBob, 10, 5)
    love.graphics.rectangle("fill", px + 3, py - 14 + walkBob, 3, 4)

    -- Eye (one visible)
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle("fill", px - 4, py - 12 + walkBob, 2, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", px - 4, py - 12 + walkBob, 1, 1)

  elseif dir == "right" then
    -- === RIGHT-FACING SPRITE ===
    -- Feet (staggered depth)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.rectangle("fill", px, py + 6 + walkBob + footOffset, 4, 5)
    love.graphics.rectangle("fill", px - 2, py + 7 + walkBob, 4, 4)

    -- Legs
    love.graphics.setColor(0.2, 0.3, 0.5)
    love.graphics.rectangle("fill", px - 2, py + 1 + walkBob, 5, 6)

    -- Body (side view, narrower)
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 5, py - 8 + walkBob, 10, 10)

    -- Belt
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("fill", px - 4, py + walkBob, 8, 2)

    -- Arm (side view - one visible)
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 2, py - 6 + walkBob + armSwing, 4, 8)
    -- Hand
    love.graphics.setColor(0.9, 0.75, 0.6)
    love.graphics.rectangle("fill", px - 2, py + 1 + walkBob + armSwing, 4, 3)

    -- Head (side profile)
    love.graphics.setColor(0.92, 0.78, 0.62)
    love.graphics.rectangle("fill", px - 5, py - 16 + walkBob, 10, 9)

    -- Nose
    love.graphics.setColor(0.88, 0.74, 0.58)
    love.graphics.rectangle("fill", px + 4, py - 13 + walkBob, 3, 3)

    -- Hair (side profile)
    love.graphics.setColor(0.25, 0.2, 0.15)
    love.graphics.rectangle("fill", px - 6, py - 18 + walkBob, 10, 5)
    love.graphics.rectangle("fill", px - 6, py - 14 + walkBob, 3, 4)

    -- Eye (one visible)
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle("fill", px + 2, py - 12 + walkBob, 2, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", px + 3, py - 12 + walkBob, 1, 1)

  elseif dir == "up" then
    -- === UP-FACING SPRITE (back view) ===
    -- Feet
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.rectangle("fill", px - 6, py + 6 + walkBob, 4, 5)
    love.graphics.rectangle("fill", px + 2, py + 6 + walkBob + footOffset, 4, 5)

    -- Legs
    love.graphics.setColor(0.2, 0.3, 0.5)
    love.graphics.rectangle("fill", px - 5, py + 1 + walkBob, 4, 6)
    love.graphics.rectangle("fill", px + 1, py + 1 + walkBob, 4, 6)

    -- Body
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 7, py - 8 + walkBob, 14, 10)

    -- Belt
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("fill", px - 6, py + walkBob, 12, 2)

    -- Arms
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 9, py - 6 + walkBob + armSwing, 3, 8)
    love.graphics.rectangle("fill", px + 6, py - 6 + walkBob - armSwing, 3, 8)

    -- Hands
    love.graphics.setColor(0.9, 0.75, 0.6)
    love.graphics.rectangle("fill", px - 9, py + 1 + walkBob + armSwing, 3, 3)
    love.graphics.rectangle("fill", px + 6, py + 1 + walkBob - armSwing, 3, 3)

    -- Head (back of head - more hair visible)
    love.graphics.setColor(0.25, 0.2, 0.15)
    love.graphics.rectangle("fill", px - 6, py - 16 + walkBob, 12, 9)
    love.graphics.rectangle("fill", px - 7, py - 18 + walkBob, 14, 5)

  else
    -- === DOWN-FACING SPRITE (front view, default) ===
    -- Feet
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.rectangle("fill", px - 6, py + 6 + walkBob, 4, 5)
    love.graphics.rectangle("fill", px + 2, py + 6 + walkBob + footOffset, 4, 5)

    -- Legs
    love.graphics.setColor(0.2, 0.3, 0.5)
    love.graphics.rectangle("fill", px - 5, py + 1 + walkBob, 4, 6)
    love.graphics.rectangle("fill", px + 1, py + 1 + walkBob, 4, 6)

    -- Body/torso
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 7, py - 8 + walkBob, 14, 10)

    -- Belt
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("fill", px - 6, py + walkBob, 12, 2)

    -- Arms
    love.graphics.setColor(0.2, 0.45, 0.85)
    love.graphics.rectangle("fill", px - 9, py - 6 + walkBob + armSwing, 3, 8)
    love.graphics.rectangle("fill", px + 6, py - 6 + walkBob - armSwing, 3, 8)

    -- Hands
    love.graphics.setColor(0.9, 0.75, 0.6)
    love.graphics.rectangle("fill", px - 9, py + 1 + walkBob + armSwing, 3, 3)
    love.graphics.rectangle("fill", px + 6, py + 1 + walkBob - armSwing, 3, 3)

    -- Head
    love.graphics.setColor(0.92, 0.78, 0.62)
    love.graphics.rectangle("fill", px - 6, py - 16 + walkBob, 12, 9)

    -- Hair
    love.graphics.setColor(0.25, 0.2, 0.15)
    love.graphics.rectangle("fill", px - 7, py - 18 + walkBob, 14, 5)
    love.graphics.rectangle("fill", px - 7, py - 14 + walkBob, 2, 4)
    love.graphics.rectangle("fill", px + 5, py - 14 + walkBob, 2, 4)

    -- Eyes
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle("fill", px - 4, py - 12 + walkBob, 2, 2)
    love.graphics.rectangle("fill", px + 2, py - 12 + walkBob, 2, 2)
    -- Eye shine
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", px - 3, py - 12 + walkBob, 1, 1)
    love.graphics.rectangle("fill", px + 3, py - 12 + walkBob, 1, 1)
  end
end

-- ═══════════════════════════════════════════════════════
-- POKEMON EMERALD-STYLE NPC SPRITE
-- ═══════════════════════════════════════════════════════

function M.drawNPC(npcObj, neonColor, time)
  time = time or 0
  local gs = GRID_SIZE
  local nx = npcObj.x * gs + gs / 2
  local ny = npcObj.y * gs + gs / 2
  local dir = npcObj.direction or "down"

  -- Special rendering for Piano Robot with Steinway grand piano
  if npcObj.name == "Piano Robot" then
    M.drawPianoRobotWithPiano(nx, ny, neonColor, time)
    return
  end

  -- Walking or idle animation
  local bob = 0
  local footOffset = 0
  local armSwing = 0
  if npcObj.moving then
    bob = math.sin(time * 10) * 2
    footOffset = math.sin(time * 10) * 2
    armSwing = math.sin(time * 10) * 3
  else
    bob = math.sin(time * 1.5 + npcObj.x * 2) * 1
  end

  -- Body color (varies by NPC - use a hash of name for color variation)
  local nameHash = 0
  for i = 1, #(npcObj.name or "NPC") do
    nameHash = nameHash + string.byte(npcObj.name, i)
  end
  local bodyR = 0.4 + (nameHash % 60) / 100
  local bodyG = 0.3 + ((nameHash * 7) % 50) / 100
  local bodyB = 0.3 + ((nameHash * 13) % 60) / 100
  local hairR = (nameHash % 80) / 255 + 0.1
  local hairG = ((nameHash * 3) % 80) / 255 + 0.1
  local hairB = ((nameHash * 7) % 80) / 255 + 0.1

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", nx, ny + 12, 9, 4)

  if dir == "left" then
    -- === LEFT-FACING NPC ===
    -- Feet
    love.graphics.setColor(0.3, 0.2, 0.2)
    love.graphics.rectangle("fill", nx - 3, ny + 7 + bob + footOffset, 4, 4)
    love.graphics.rectangle("fill", nx - 1, ny + 8 + bob, 4, 3)

    -- Legs
    love.graphics.setColor(0.35, 0.25, 0.2)
    love.graphics.rectangle("fill", nx - 2, ny + 2 + bob, 5, 6)

    -- Body (side view)
    love.graphics.setColor(bodyR, bodyG, bodyB)
    love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 8, 10)

    -- Arm (one visible)
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    love.graphics.rectangle("fill", nx - 1, ny - 5 + bob + armSwing, 3, 7)
    -- Hand
    love.graphics.setColor(0.88, 0.73, 0.58)
    love.graphics.rectangle("fill", nx - 1, ny + 1 + bob + armSwing, 3, 3)

    -- Head (side profile)
    love.graphics.setColor(0.9, 0.76, 0.6)
    love.graphics.rectangle("fill", nx - 4, ny - 15 + bob, 8, 9)
    -- Nose
    love.graphics.setColor(0.86, 0.72, 0.56)
    love.graphics.rectangle("fill", nx - 6, ny - 12 + bob, 3, 3)

    -- Hair
    love.graphics.setColor(hairR, hairG, hairB)
    love.graphics.rectangle("fill", nx - 3, ny - 17 + bob, 8, 5)
    love.graphics.rectangle("fill", nx + 2, ny - 13 + bob, 3, 3)

    -- Eye
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", nx - 3, ny - 11 + bob, 2, 2)

  elseif dir == "right" then
    -- === RIGHT-FACING NPC ===
    -- Feet
    love.graphics.setColor(0.3, 0.2, 0.2)
    love.graphics.rectangle("fill", nx - 1, ny + 7 + bob + footOffset, 4, 4)
    love.graphics.rectangle("fill", nx - 3, ny + 8 + bob, 4, 3)

    -- Legs
    love.graphics.setColor(0.35, 0.25, 0.2)
    love.graphics.rectangle("fill", nx - 3, ny + 2 + bob, 5, 6)

    -- Body (side view)
    love.graphics.setColor(bodyR, bodyG, bodyB)
    love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 8, 10)

    -- Arm (one visible)
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    love.graphics.rectangle("fill", nx - 2, ny - 5 + bob + armSwing, 3, 7)
    -- Hand
    love.graphics.setColor(0.88, 0.73, 0.58)
    love.graphics.rectangle("fill", nx - 2, ny + 1 + bob + armSwing, 3, 3)

    -- Head (side profile)
    love.graphics.setColor(0.9, 0.76, 0.6)
    love.graphics.rectangle("fill", nx - 4, ny - 15 + bob, 8, 9)
    -- Nose
    love.graphics.setColor(0.86, 0.72, 0.56)
    love.graphics.rectangle("fill", nx + 3, ny - 12 + bob, 3, 3)

    -- Hair
    love.graphics.setColor(hairR, hairG, hairB)
    love.graphics.rectangle("fill", nx - 5, ny - 17 + bob, 8, 5)
    love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 3, 3)

    -- Eye
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", nx + 1, ny - 11 + bob, 2, 2)

  elseif dir == "up" then
    -- === UP-FACING NPC (back view) ===
    -- Feet
    love.graphics.setColor(0.3, 0.2, 0.2)
    love.graphics.rectangle("fill", nx - 5, ny + 7 + bob, 4, 4)
    love.graphics.rectangle("fill", nx + 1, ny + 7 + bob + footOffset, 4, 4)

    -- Legs
    love.graphics.setColor(0.35, 0.25, 0.2)
    love.graphics.rectangle("fill", nx - 4, ny + 2 + bob, 4, 6)
    love.graphics.rectangle("fill", nx + 1, ny + 2 + bob, 4, 6)

    -- Body
    love.graphics.setColor(bodyR, bodyG, bodyB)
    love.graphics.rectangle("fill", nx - 6, ny - 7 + bob, 12, 10)

    -- Arms
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    love.graphics.rectangle("fill", nx - 8, ny - 5 + bob + armSwing, 3, 7)
    love.graphics.rectangle("fill", nx + 5, ny - 5 + bob - armSwing, 3, 7)

    -- Hands
    love.graphics.setColor(0.88, 0.73, 0.58)
    love.graphics.rectangle("fill", nx - 8, ny + 1 + bob + armSwing, 3, 3)
    love.graphics.rectangle("fill", nx + 5, ny + 1 + bob - armSwing, 3, 3)

    -- Head (back - more hair)
    love.graphics.setColor(hairR, hairG, hairB)
    love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
    love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)

  else
    -- === DOWN-FACING NPC (front view, default) ===
    -- Feet
    love.graphics.setColor(0.3, 0.2, 0.2)
    love.graphics.rectangle("fill", nx - 5, ny + 7 + bob, 4, 4)
    love.graphics.rectangle("fill", nx + 1, ny + 7 + bob + footOffset, 4, 4)

    -- Legs
    love.graphics.setColor(0.35, 0.25, 0.2)
    love.graphics.rectangle("fill", nx - 4, ny + 2 + bob, 4, 6)
    love.graphics.rectangle("fill", nx + 1, ny + 2 + bob, 4, 6)

    -- Body
    love.graphics.setColor(bodyR, bodyG, bodyB)
    love.graphics.rectangle("fill", nx - 6, ny - 7 + bob, 12, 10)

    -- Arms
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    love.graphics.rectangle("fill", nx - 8, ny - 5 + bob + armSwing, 3, 7)
    love.graphics.rectangle("fill", nx + 5, ny - 5 + bob - armSwing, 3, 7)

    -- Hands
    love.graphics.setColor(0.88, 0.73, 0.58)
    love.graphics.rectangle("fill", nx - 8, ny + 1 + bob + armSwing, 3, 3)
    love.graphics.rectangle("fill", nx + 5, ny + 1 + bob - armSwing, 3, 3)

    -- Head
    love.graphics.setColor(0.9, 0.76, 0.6)
    love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)

    -- Hair
    love.graphics.setColor(hairR, hairG, hairB)
    love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)

    -- Eyes
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", nx - 3, ny - 11 + bob, 2, 2)
    love.graphics.rectangle("fill", nx + 2, ny - 11 + bob, 2, 2)
  end

  -- Name tag (small, above NPC, with neon tint)
  if neonColor then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(neonColor[1], neonColor[2], neonColor[3], 0.8)
    love.graphics.printf(npcObj.name, nx - 40, ny - 24 + bob, 80, "center")
  end
end

function M.drawPianoRobotWithPiano(nx, ny, neonColor, time)
  -- Robot sits on the RIGHT, facing LEFT toward the piano on the LEFT
  local robotX = nx + 10
  local robotY = ny

  -- ─── STEINWAY GRAND PIANO (to the left, facing left) ───
  local pianoX = nx - 28
  local pianoY = ny + 2

  -- Piano shadow (large, soft)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.ellipse("fill", pianoX - 5, pianoY + 18, 38, 10)

  -- Three tapered legs with brass casters
  for _, lx in ipairs({pianoX - 26, pianoX - 6, pianoX + 18}) do
    love.graphics.setColor(0.04, 0.04, 0.06)
    love.graphics.polygon("fill", lx, pianoY + 12, lx + 3, pianoY + 12, lx + 2, pianoY + 20, lx + 1, pianoY + 20)
    love.graphics.setColor(0.55, 0.45, 0.2, 0.8)
    love.graphics.circle("fill", lx + 1.5, pianoY + 20, 1.5) -- brass caster
  end

  -- Body – glossy black Steinway curved rim
  love.graphics.setColor(0.04, 0.04, 0.07)
  love.graphics.polygon("fill",
    pianoX + 22, pianoY + 4,   -- right straight edge (keyboard end)
    pianoX + 22, pianoY + 12,
    pianoX - 28, pianoY + 12,  -- far left bottom
    pianoX - 32, pianoY + 6,   -- tail curve
    pianoX - 30, pianoY - 4,
    pianoX - 22, pianoY - 10,  -- outer rim curve
    pianoX - 8,  pianoY - 12,
    pianoX + 8,  pianoY - 10,
    pianoX + 22, pianoY - 4    -- straight edge top
  )

  -- Rim highlight (top edge reflection)
  love.graphics.setColor(0.18, 0.18, 0.22, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.line(
    pianoX - 30, pianoY - 4,
    pianoX - 22, pianoY - 10,
    pianoX - 8,  pianoY - 12,
    pianoX + 8,  pianoY - 10,
    pianoX + 22, pianoY - 4
  )

  -- Glossy body reflections
  love.graphics.setColor(0.12, 0.12, 0.16, 0.5)
  love.graphics.polygon("fill",
    pianoX - 20, pianoY - 7,
    pianoX - 6,  pianoY - 9,
    pianoX + 6,  pianoY - 7,
    pianoX + 2,  pianoY + 0,
    pianoX - 16, pianoY + 0
  )
  love.graphics.setColor(0.15, 0.15, 0.2, 0.3)
  love.graphics.polygon("fill",
    pianoX - 24, pianoY + 2,
    pianoX - 10, pianoY + 0,
    pianoX - 8,  pianoY + 8,
    pianoX - 26, pianoY + 10
  )

  -- Raised lid (propped open, angled up)
  love.graphics.setColor(0.06, 0.06, 0.09)
  love.graphics.polygon("fill",
    pianoX - 28, pianoY - 4,
    pianoX - 22, pianoY - 10,
    pianoX - 8,  pianoY - 12,
    pianoX + 8,  pianoY - 10,
    pianoX + 5,  pianoY - 22,
    pianoX - 12, pianoY - 24,
    pianoX - 26, pianoY - 18
  )
  -- Lid shine
  love.graphics.setColor(0.14, 0.14, 0.2, 0.5)
  love.graphics.polygon("fill",
    pianoX - 20, pianoY - 12,
    pianoX - 5,  pianoY - 13,
    pianoX + 0,  pianoY - 21,
    pianoX - 16, pianoY - 20
  )
  -- Lid prop stick
  love.graphics.setColor(0.55, 0.45, 0.2, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.line(pianoX - 2, pianoY - 10, pianoX + 2, pianoY - 21)

  -- Keyboard (on the right edge, facing the robot)
  -- White keys
  local keysX = pianoX + 14
  local keysY = pianoY + 1
  love.graphics.setColor(0.96, 0.94, 0.90)
  love.graphics.rectangle("fill", keysX, keysY, 8, 10, 1)
  -- Individual white key lines
  love.graphics.setColor(0.8, 0.78, 0.74, 0.5)
  for i = 1, 6 do
    love.graphics.line(keysX, keysY + i * 1.4, keysX + 8, keysY + i * 1.4)
  end
  -- Black keys (animating with playing)
  local playOff1 = math.sin(time * 6) * 0.4
  local playOff2 = math.sin(time * 6 + 1.2) * 0.4
  local playOff3 = math.sin(time * 6 + 2.8) * 0.4
  love.graphics.setColor(0.06, 0.06, 0.08)
  love.graphics.rectangle("fill", keysX, keysY + 1 + playOff1, 5, 1.2)
  love.graphics.rectangle("fill", keysX, keysY + 3, 5, 1.2)
  love.graphics.rectangle("fill", keysX, keysY + 5.5 + playOff2, 5, 1.2)
  love.graphics.rectangle("fill", keysX, keysY + 7 + playOff3, 5, 1.2)

  -- Pedals (brass, beneath keyboard end)
  love.graphics.setColor(0.6, 0.5, 0.2, 0.7)
  love.graphics.rectangle("fill", pianoX + 6, pianoY + 19, 2, 2, 0.5)
  love.graphics.rectangle("fill", pianoX + 10, pianoY + 19, 2, 2, 0.5)
  love.graphics.rectangle("fill", pianoX + 14, pianoY + 19, 2, 2, 0.5)

  -- ─── ROBOT (seated on bench, facing left) ───
  local bob = math.sin(time * 1.8) * 0.8 -- gentle sway as it plays
  local headTilt = math.sin(time * 1.2) * 1.5 -- head tilts with feeling

  -- Piano bench (bench top at benchY)
  local benchY = robotY + 6
  love.graphics.setColor(0.08, 0.08, 0.1)
  love.graphics.rectangle("fill", robotX - 7, benchY, 14, 5, 2)
  love.graphics.setColor(0.04, 0.04, 0.06)
  love.graphics.rectangle("fill", robotX - 5, benchY + 5, 3, 8)
  love.graphics.rectangle("fill", robotX + 3, benchY + 5, 3, 8)
  love.graphics.setColor(0.5, 0.4, 0.18, 0.6)
  love.graphics.circle("fill", robotX - 3.5, benchY + 13, 1.5) -- caster
  love.graphics.circle("fill", robotX + 4.5, benchY + 13, 1.5)

  -- Robot's butt sits ON the bench — torso rises from benchY
  local torsoY = benchY - 12 -- torso bottom aligns with bench top

  -- Robot legs (extending forward from bench toward pedals)
  love.graphics.setColor(0.48, 0.5, 0.54)
  -- Upper legs (sitting flat on bench, going forward-left)
  love.graphics.polygon("fill",
    robotX - 5, benchY + 1,
    robotX - 3, benchY - 1,
    robotX - 8, benchY + 6,
    robotX - 10, benchY + 6
  )
  love.graphics.polygon("fill",
    robotX + 1, benchY + 1,
    robotX + 3, benchY - 1,
    robotX - 2, benchY + 6,
    robotX - 4, benchY + 6
  )
  -- Lower legs (going down from knee to floor)
  love.graphics.setColor(0.45, 0.48, 0.52)
  love.graphics.rectangle("fill", robotX - 10, benchY + 5, 3, 8)
  love.graphics.rectangle("fill", robotX - 4, benchY + 5, 3, 8)
  -- Knee joints
  love.graphics.setColor(0.35, 0.37, 0.4)
  love.graphics.circle("fill", robotX - 9, benchY + 5, 2)
  love.graphics.circle("fill", robotX - 3, benchY + 5, 2)
  -- Robot feet (resting near pedals)
  love.graphics.setColor(0.4, 0.42, 0.45)
  love.graphics.rectangle("fill", robotX - 12, benchY + 12, 5, 3, 1)
  love.graphics.rectangle("fill", robotX - 6, benchY + 12, 5, 3, 1)

  -- Robot torso (chrome, facing left) — seated on bench
  love.graphics.setColor(0.58, 0.62, 0.68)
  love.graphics.rectangle("fill", robotX - 7, torsoY + bob, 14, 14, 3)
  -- Chest plate
  love.graphics.setColor(0.7, 0.74, 0.8, 0.5)
  love.graphics.rectangle("fill", robotX - 5, torsoY + 1 + bob, 10, 6, 2)
  -- Chest light (heartbeat glow)
  local heartbeat = 0.5 + 0.5 * math.sin(time * 4)
  love.graphics.setColor(0.3, 0.7, 1.0, heartbeat * 0.8)
  love.graphics.circle("fill", robotX, torsoY + 5 + bob, 2)
  -- Panel seams
  love.graphics.setColor(0.35, 0.38, 0.42, 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.line(robotX - 6, torsoY + 8 + bob, robotX + 6, torsoY + 8 + bob)

  -- Shoulder joints
  love.graphics.setColor(0.45, 0.48, 0.52)
  love.graphics.circle("fill", robotX - 8, torsoY + 2 + bob, 3)
  love.graphics.circle("fill", robotX + 8, torsoY + 2 + bob, 3)

  -- Arms reaching LEFT toward keyboard, animated playing
  local lArmPlay = math.sin(time * 5.5) * 2       -- left hand moves up/down keys
  local rArmPlay = math.sin(time * 5.5 + 1.5) * 2 -- right hand offset
  -- Upper arms
  love.graphics.setColor(0.52, 0.56, 0.6)
  love.graphics.polygon("fill",
    robotX - 8, torsoY + 1 + bob,
    robotX - 10, torsoY + 1 + bob,
    robotX - 16, torsoY + 8 + bob,
    robotX - 14, torsoY + 9 + bob
  )
  love.graphics.polygon("fill",
    robotX + 8, torsoY + 1 + bob,
    robotX + 10, torsoY + 1 + bob,
    robotX + 4,  torsoY + 8 + bob,
    robotX + 2,  torsoY + 9 + bob
  )
  -- Forearms (reaching to keys)
  love.graphics.setColor(0.55, 0.58, 0.63)
  love.graphics.polygon("fill",
    robotX - 15, torsoY + 8 + bob,
    robotX - 14, torsoY + 7 + bob,
    robotX - 20, torsoY + 12 + bob + lArmPlay * 0.3,
    robotX - 21, torsoY + 13 + bob + lArmPlay * 0.3
  )
  love.graphics.polygon("fill",
    robotX + 3, torsoY + 8 + bob,
    robotX + 2, torsoY + 7 + bob,
    robotX - 8,  torsoY + 14 + bob + rArmPlay * 0.3,
    robotX - 9,  torsoY + 15 + bob + rArmPlay * 0.3
  )
  -- Elbow joints
  love.graphics.setColor(0.4, 0.42, 0.46)
  love.graphics.circle("fill", robotX - 15, torsoY + 9 + bob, 2)
  love.graphics.circle("fill", robotX + 3, torsoY + 9 + bob, 2)
  -- Hands (chrome fingers on keys)
  love.graphics.setColor(0.72, 0.76, 0.82)
  love.graphics.circle("fill", robotX - 21, torsoY + 13 + bob + lArmPlay * 0.3, 3)
  love.graphics.circle("fill", robotX - 9,  torsoY + 15 + bob + rArmPlay * 0.3, 3)
  -- Finger details
  love.graphics.setColor(0.6, 0.64, 0.7)
  for f = -1, 1 do
    love.graphics.rectangle("fill", robotX - 23 + f, torsoY + 14 + bob + lArmPlay * 0.3, 1, 2)
    love.graphics.rectangle("fill", robotX - 11 + f, torsoY + 16 + bob + rArmPlay * 0.3, 1, 2)
  end

  -- Neck
  love.graphics.setColor(0.5, 0.52, 0.56)
  love.graphics.rectangle("fill", robotX - 2, torsoY - 4 + bob, 4, 5, 1)

  -- Head (facing left, slight tilt)
  love.graphics.push()
  love.graphics.translate(robotX, torsoY - 10 + bob)
  love.graphics.rotate(math.rad(headTilt))
  -- Cranium
  love.graphics.setColor(0.62, 0.66, 0.72)
  love.graphics.rectangle("fill", -6, -5, 12, 11, 3)
  -- Face plate (facing left)
  love.graphics.setColor(0.55, 0.58, 0.64)
  love.graphics.rectangle("fill", -8, -3, 4, 8, 2)
  -- Visor/eyes (glowing blue, facing left)
  local visorGlow = 0.6 + 0.4 * math.sin(time * 2.5)
  love.graphics.setColor(0.2, 0.7, 1.0, visorGlow)
  love.graphics.rectangle("fill", -7, -1, 3, 2, 1)
  love.graphics.rectangle("fill", -7, 2, 3, 2, 1)
  -- Visor glow bloom
  love.graphics.setColor(0.2, 0.7, 1.0, visorGlow * 0.2)
  love.graphics.circle("fill", -6, 1, 6)
  -- Mouth grille
  love.graphics.setColor(0.35, 0.38, 0.42)
  for g = 0, 2 do
    love.graphics.line(-6, 5 + g * 1.5, -3, 5 + g * 1.5)
  end
  -- Ear piece
  love.graphics.setColor(0.45, 0.48, 0.52)
  love.graphics.circle("fill", 6, 1, 3)
  love.graphics.setColor(0.3, 0.6, 0.9, 0.4)
  love.graphics.circle("fill", 6, 1, 1.5)
  -- Antenna
  love.graphics.setColor(0.5, 0.52, 0.56)
  love.graphics.rectangle("fill", -1, -8, 2, 4)
  love.graphics.pop()

  -- ─── EFFECTS ───
  -- Musical notes drifting up from the piano
  if neonColor then
    love.graphics.setFont(fonts.small)
    local nr, ng, nb = neonColor[1], neonColor[2], neonColor[3]
    for i = 0, 3 do
      local phase = time * 1.2 + i * 1.6
      local noteAlpha = 0.9 - (phase % 4) / 4 * 0.9
      if noteAlpha > 0 then
        local noteX2 = pianoX - 5 + math.sin(phase * 0.8 + i) * 12
        local noteY2 = pianoY - 20 - (phase % 4) * 8
        love.graphics.setColor(nr, ng, nb, noteAlpha)
        local noteChar = (i % 2 == 0) and "♪" or "♫"
        love.graphics.print(noteChar, noteX2, noteY2)
      end
    end
  end

  -- Name tag
  if neonColor then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(neonColor[1], neonColor[2], neonColor[3], 0.8)
    love.graphics.printf("Piano Robot", nx - 40, torsoY - 22 + bob, 80, "center")
  end
end

-- ═══════════════════════════════════════════════════════
-- UI OVERLAY
-- ═══════════════════════════════════════════════════════

function M.drawUI(gameState, time)
  local screenW, screenH = love.graphics.getDimensions()

  -- Location bar (top)
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 0, 0, screenW, 40)

  local floorDef = floors.getFloor(gameState.currentFloor)
  local locationName = ""
  if gameState.interiorId then
    local buildings = require("hub.buildings")
    local interior = buildings.getInterior(gameState.interiorId)
    locationName = interior and interior.name or gameState.interiorId
  elseif floorDef then
    locationName = floorDef.name .. " - " .. floorDef.subtitle
  end

  -- Floor indicator
  if floorDef then
    local nr, ng, nb = floorDef.colorScheme.neon[1], floorDef.colorScheme.neon[2], floorDef.colorScheme.neon[3]
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(nr, ng, nb, 0.9)
    love.graphics.print("F" .. (gameState.currentFloor or 2), 10, 4)

    -- Location name with neon glow
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(nr, ng, nb, 0.4)
    love.graphics.printf(locationName, 1, 9, screenW, "center")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(locationName, 0, 8, screenW, "center")
  end

  -- Currency display (top right)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.2, 0.8, 0.2, 0.9)
  love.graphics.printf("Cr: " .. (gameState.credits or 0), 0, 6, screenW - 10, "right")
  love.graphics.setColor(0.8, 0.8, 0.2, 0.9)
  love.graphics.printf("♪: " .. (gameState.notes or 0), 0, 22, screenW - 10, "right")

  -- Controls bar (bottom)
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, screenH - 30, screenW, 30)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.7, 0.7, 0.8)
  love.graphics.printf("Arrow Keys: Move  |  Z: Run  |  E: Interact  |  ESC: Pause", 10, screenH - 22, screenW - 20, "center")

  -- Interaction prompts (centered)
  if gameState.nearbyPortal then
    M.drawInteractionPrompt("Press E to enter " .. gameState.nearbyPortal.name, {1, 1, 0.3}, time)
  elseif gameState.nearbyNPC then
    M.drawInteractionPrompt("Press E to talk to " .. gameState.nearbyNPC.name, {0.3, 1, 0.5}, time)
  elseif gameState.nearElevator then
    M.drawInteractionPrompt("Press E to use Elevator", {0.3, 0.8, 1}, time)
  end

  -- Dialogue box (neon styled)
  if gameState.dialogueBox then
    M.drawDialogueBox(gameState.dialogueBox, time)
  end
end

function M.drawInteractionPrompt(text, color, time)
  local screenW = love.graphics.getDimensions()
  local pulse = 0.7 + 0.3 * math.sin(time * 3)

  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.rectangle("fill", screenW/2 - 180, 260, 360, 50, 6)

  neon.drawNeonRect(screenW/2 - 180, 260, 360, 50, color[1], color[2], color[3], pulse * 0.6, 2)

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(color[1], color[2], color[3], pulse)
  love.graphics.printf(text, screenW/2 - 170, 278, 340, "center")
end

function M.drawDialogueBox(dialogue, time)
  local screenW, screenH = love.graphics.getDimensions()
  local boxX = 80
  local boxY = screenH - 200
  local boxW = screenW - 160
  local boxH = 150

  -- Save current font
  local previousFont = love.graphics.getFont()

  -- Box background
  love.graphics.setColor(0.02, 0.02, 0.06, 0.95)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6)

  -- Neon border
  neon.drawNeonRect(boxX, boxY, boxW, boxH, 0.0, 0.7, 1.0, 0.7, 2)

  -- NPC name
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.0, 0.9, 1.0)
  love.graphics.print(dialogue.npc, boxX + 20, boxY + 12)

  -- Dialogue text
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.9, 0.9, 0.95)
  love.graphics.printf(dialogue.text, boxX + 20, boxY + 45, boxW - 40, "left")

  -- Close hint
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.6, 0.5 + 0.5 * math.sin(time * 3))
  love.graphics.print("Press E or ESC to close", boxX + 20, boxY + boxH - 25)

  -- Restore previous font
  love.graphics.setFont(previousFont)
end

-- ═══════════════════════════════════════════════════════
-- CASINO DECORATION DRAWERS (preserved from original)
-- ═══════════════════════════════════════════════════════

function M.drawChihulyCeiling(centerX, y, time)
  for i = 1, 15 do
    local xOffset = (i - 8) * 55
    local yOffset = math.sin(time * 1.5 + i * 0.7) * 8
    local size = 12 + math.sin(time * 2 + i) * 4
    local hue = ((i * 25) + time * 30) % 360
    local r, g, b = M.hslToRgb(hue / 360, 0.8, 0.55)
    love.graphics.setColor(r, g, b, 0.85)
    love.graphics.circle("fill", centerX + xOffset, y + yOffset, size)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.circle("fill", centerX + xOffset - 3, y + yOffset - 3, size * 0.4)
  end
end

function M.hslToRgb(h, s, l)
  if s == 0 then return l, l, l end
  local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
  end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3)
end

function M.drawFountain(x, y, time)
  love.graphics.setColor(0.2, 0.5, 0.9, 0.6)
  love.graphics.circle("fill", x, y, 40)
  for ring = 1, 4 do
    local phase = (time * 2 + ring * 0.8) % 3
    local radius = 10 + phase * 15
    local alpha = 1 - (phase / 3)
    love.graphics.setColor(0.4, 0.7, 1, alpha * 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, radius)
  end
  love.graphics.setColor(0.6, 0.85, 1, 0.9)
  love.graphics.circle("fill", x, y, 8)
end

function M.drawFloorZone(zone, gridSize)
  local x1, y1 = zone.x1 * gridSize, zone.y1 * gridSize
  local w = (zone.x2 - zone.x1 + 1) * gridSize
  local h = (zone.y2 - zone.y1 + 1) * gridSize

  if zone.floor == "marble" then
    for gx = zone.x1, zone.x2 do
      for gy = zone.y1, zone.y2 do
        local isLight = (gx + gy) % 2 == 0
        if isLight then
          love.graphics.setColor(0.95, 0.92, 0.85)
        else
          love.graphics.setColor(0.85, 0.80, 0.72)
        end
        love.graphics.rectangle("fill", gx * gridSize, gy * gridSize, gridSize, gridSize)
      end
    end
  elseif zone.floor == "carpet_red" then
    love.graphics.setColor(0.55, 0.08, 0.08)
    love.graphics.rectangle("fill", x1, y1, w, h)
    love.graphics.setColor(0.85, 0.7, 0.2)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x1 + 2, y1 + 2, w - 4, h - 4)
  elseif zone.floor == "carpet_dark" then
    love.graphics.setColor(0.18, 0.1, 0.1)
    love.graphics.rectangle("fill", x1, y1, w, h)
    love.graphics.setColor(0.25, 0.15, 0.15, 0.5)
    for gx = zone.x1, zone.x2 do
      for gy = zone.y1, zone.y2 do
        if (gx + gy) % 2 == 0 then
          local cx = gx * gridSize + gridSize / 2
          local cy = gy * gridSize + gridSize / 2
          love.graphics.polygon("fill", cx, cy - 12, cx + 12, cy, cx, cy + 12, cx - 12, cy)
        end
      end
    end
  end
end

function M.drawBlackjackTable(x, y, gridSize)
  local cx = x * gridSize + gridSize * 1.5
  local cy = y * gridSize + gridSize * 1.5
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", cx + 3, cy + 3, gridSize * 1.4, gridSize * 1.1)
  love.graphics.setColor(0.1, 0.45, 0.2)
  love.graphics.arc("fill", cx, cy + gridSize * 0.3, gridSize * 1.3, math.pi, 0)
  love.graphics.setColor(0.4, 0.25, 0.1)
  love.graphics.setLineWidth(4)
  love.graphics.arc("line", cx, cy + gridSize * 0.3, gridSize * 1.3, math.pi, 0)
  love.graphics.setColor(1, 1, 1, 0.4)
  love.graphics.setLineWidth(2)
  for i = -1, 1 do
    love.graphics.circle("line", cx + i * gridSize * 0.7, cy - gridSize * 0.2, 10)
  end
  love.graphics.setColor(0.8, 0.7, 0.2)
  love.graphics.rectangle("fill", cx - 15, cy + gridSize * 0.15, 30, 6)
end

function M.drawRouletteTable(x, y, gridSize, time)
  local cx = x * gridSize + gridSize * 2
  local cy = y * gridSize + gridSize * 1.5
  love.graphics.setColor(0.1, 0.45, 0.2)
  love.graphics.rectangle("fill", x * gridSize + gridSize * 2.5, y * gridSize, gridSize * 1.5, gridSize * 3)
  love.graphics.setColor(0.35, 0.2, 0.1)
  love.graphics.circle("fill", cx, cy, gridSize * 1.2)
  local segments = 12
  local rotation = time * 0.5
  for i = 0, segments - 1 do
    local angle1 = (i / segments) * math.pi * 2 + rotation
    local angle2 = ((i + 1) / segments) * math.pi * 2 + rotation
    if i == 0 then love.graphics.setColor(0, 0.6, 0)
    elseif i % 2 == 0 then love.graphics.setColor(0.8, 0.1, 0.1)
    else love.graphics.setColor(0.1, 0.1, 0.1) end
    love.graphics.arc("fill", cx, cy, gridSize, angle1, angle2)
  end
  love.graphics.setColor(0.85, 0.75, 0.3)
  love.graphics.circle("fill", cx, cy, gridSize * 0.25)
  love.graphics.setColor(0.5, 0.35, 0.15)
  love.graphics.setLineWidth(5)
  love.graphics.circle("line", cx, cy, gridSize * 1.2)
end

function M.drawSlotMachines(x, y, gridSize, time)
  for i = 0, 2 do
    local mx = x * gridSize + i * gridSize
    local my = y * gridSize
    love.graphics.setColor(0.7, 0.55, 0.1)
    love.graphics.rectangle("fill", mx + 4, my + 4, gridSize - 8, gridSize * 1.8)
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", mx + 8, my + 12, gridSize - 16, gridSize * 0.7)
    local blink = math.sin(time * 4 + i * 2) > 0
    love.graphics.setColor(blink and 1 or 0.3, blink and 0.2 or 0.1, blink and 0.2 or 0.1)
    love.graphics.circle("fill", mx + 12, my + 8, 4)
    local blink2 = math.sin(time * 4 + i * 2 + 1) > 0
    love.graphics.setColor(blink2 and 0.2 or 0.1, blink2 and 1 or 0.3, blink2 and 0.2 or 0.1)
    love.graphics.circle("fill", mx + gridSize - 12, my + 8, 4)
    love.graphics.setColor(0.6, 0.1, 0.1)
    love.graphics.rectangle("fill", mx + gridSize - 6, my + gridSize * 0.9, 4, gridSize * 0.6)
    love.graphics.circle("fill", mx + gridSize - 4, my + gridSize * 0.85, 6)
  end
end

function M.drawShopCounter(x, y, gridSize, width)
  love.graphics.setColor(0.5, 0.35, 0.2)
  love.graphics.rectangle("fill", x * gridSize, y * gridSize, width * gridSize, gridSize)
  love.graphics.setColor(0.7, 0.6, 0.5)
  love.graphics.rectangle("fill", x * gridSize, y * gridSize, width * gridSize, 8)
  for i = 0, width - 1 do
    love.graphics.setColor(0.8, 0.85, 0.9, 0.5)
    love.graphics.rectangle("fill", x * gridSize + i * gridSize + 6, y * gridSize + 12, gridSize - 12, gridSize - 16)
    love.graphics.setColor(0.6, 0.5, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x * gridSize + i * gridSize + 6, y * gridSize + 12, gridSize - 12, gridSize - 16)
  end
end

function M.drawSculpture(x, y, gridSize)
  local cx = x * gridSize + gridSize / 2
  local cy = y * gridSize + gridSize / 2
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.rectangle("fill", cx - 12, cy + 5, 24, 10)
  love.graphics.setColor(0.85, 0.75, 0.3)
  love.graphics.polygon("fill", cx, cy - 15, cx + 10, cy, cx - 10, cy)
  love.graphics.setColor(0.75, 0.65, 0.25)
  love.graphics.rectangle("fill", cx - 8, cy, 16, 8)
end

return M

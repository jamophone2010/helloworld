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
  fonts.normal = love.graphics.newFont("fonts/Exo2-Regular.ttf", 16)
  fonts.large = love.graphics.newFont("fonts/Exo2-Regular.ttf", 20)
  fonts.small = love.graphics.newFont("fonts/Exo2-Regular.ttf", 12)
  fonts.title = love.graphics.newFont("fonts/Exo2-Regular.ttf", 24)
  fonts.tiny = love.graphics.newFont("fonts/Exo2-Regular.ttf", 10)
  windows.init()
end

function M.draw(gameState, time)
  time = time or 0
  love.graphics.push()
  love.graphics.translate(math.floor(-gameState.camera.x + love.graphics.getWidth() / 2),
                          math.floor(-gameState.camera.y + love.graphics.getHeight() / 2))

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
-- POKEMON EMERALD-STYLE NPC SPRITE (Multi-Design System)
-- ═══════════════════════════════════════════════════════

-- Design definitions for varied NPC appearances
-- Male designs: 1-6, Female designs: 1-6
-- Each NPC auto-selects a design from their name hash, or use npcObj.design to override
local NPC_DESIGNS = {
  male = {
    -- Design 1: Standard guy - short hair, regular build
    {hair = "short", body = "regular", accessory = "none", shoe = "boots"},
    -- Design 2: Spiky punk - tall spiky hair, slim
    {hair = "spiky", body = "slim", accessory = "none", shoe = "boots"},
    -- Design 3: Military buzz - buzz cut, broad shoulders
    {hair = "buzz", body = "broad", accessory = "none", shoe = "heavy"},
    -- Design 4: Scientist - messy hair, lab coat
    {hair = "messy", body = "regular", accessory = "glasses", shoe = "shoes"},
    -- Design 5: Slick exec - slicked back, suit-ready
    {hair = "slicked", body = "slim", accessory = "none", shoe = "shoes"},
    -- Design 6: Rugged explorer - bandana, muscular
    {hair = "bandana", body = "broad", accessory = "none", shoe = "heavy"},
  },
  female = {
    -- Design 1: Long flowing hair, fitted silhouette, earrings
    {hair = "long_flowing", body = "curvy", accessory = "earrings", shoe = "heels"},
    -- Design 2: High ponytail, athletic build
    {hair = "ponytail_high", body = "athletic", accessory = "none", shoe = "boots"},
    -- Design 3: Bob cut with bangs, petite
    {hair = "bob", body = "petite", accessory = "earrings", shoe = "heels"},
    -- Design 4: Bun updo, elegant, glasses
    {hair = "bun", body = "slim", accessory = "glasses", shoe = "heels"},
    -- Design 5: Twin tails, youthful look
    {hair = "twintails", body = "petite", accessory = "none", shoe = "shoes"},
    -- Design 6: Side-swept long hair, bold silhouette
    {hair = "side_swept", body = "curvy", accessory = "earrings", shoe = "boots"},
  }
}

function M.drawNPC(npcObj, neonColor, time)
  time = time or 0
  local gs = GRID_SIZE
  local nx = npcObj.x * gs + gs / 2
  local ny = npcObj.y * gs + gs / 2
  local dir = npcObj.direction or "down"
  local isFemale = (npcObj.gender == "female")

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

  -- Name hash for procedural variation
  local nameHash = 0
  for i = 1, #(npcObj.name or "NPC") do
    nameHash = nameHash + string.byte(npcObj.name, i)
  end

  -- Pick design (explicit or auto from hash)
  local genderKey = isFemale and "female" or "male"
  local designList = NPC_DESIGNS[genderKey]
  local designIdx = npcObj.design or ((nameHash % #designList) + 1)
  local design = designList[designIdx] or designList[1]

  -- ── Color palette ──
  local bodyR, bodyG, bodyB
  if npcObj.outfit == "suit" then
    bodyR, bodyG, bodyB = 0.12, 0.12, 0.15
  elseif npcObj.outfit == "labcoat" then
    bodyR, bodyG, bodyB = 0.88, 0.88, 0.9
  elseif npcObj.outfit == "uniform" then
    bodyR = 0.25 + (nameHash % 20) / 100
    bodyG = 0.3 + ((nameHash * 3) % 20) / 100
    bodyB = 0.45 + ((nameHash * 5) % 20) / 100
  elseif isFemale then
    -- More vibrant palette for female NPCs
    local palettes = {
      {0.7, 0.25, 0.35},  -- rose
      {0.3, 0.5, 0.7},    -- sky blue
      {0.55, 0.3, 0.65},  -- purple
      {0.2, 0.55, 0.5},   -- teal
      {0.75, 0.45, 0.2},  -- amber
      {0.4, 0.6, 0.35},   -- sage green
    }
    local pal = palettes[(nameHash % #palettes) + 1]
    bodyR, bodyG, bodyB = pal[1], pal[2], pal[3]
  else
    bodyR = 0.4 + (nameHash % 60) / 100
    bodyG = 0.3 + ((nameHash * 7) % 50) / 100
    bodyB = 0.3 + ((nameHash * 13) % 60) / 100
  end

  -- Hair color palettes (more variety)
  local hairPalettes = {
    {0.12, 0.08, 0.05},   -- dark brown/black
    {0.55, 0.35, 0.15},   -- chestnut
    {0.75, 0.6, 0.3},     -- blonde
    {0.3, 0.15, 0.1},     -- auburn
    {0.15, 0.12, 0.1},    -- near-black
    {0.6, 0.25, 0.15},    -- red
    {0.4, 0.25, 0.18},    -- medium brown
    {0.8, 0.75, 0.6},     -- platinum
  }
  local hairPal = hairPalettes[(nameHash % #hairPalettes) + 1]
  local hairR, hairG, hairB = hairPal[1], hairPal[2], hairPal[3]

  -- Skin tone variation
  local skinTones = {
    {0.92, 0.78, 0.65},  -- light
    {0.85, 0.7, 0.55},   -- medium light
    {0.72, 0.55, 0.4},   -- medium
    {0.55, 0.38, 0.25},  -- medium dark
    {0.4, 0.28, 0.18},   -- dark
  }
  local skinPal = skinTones[((nameHash * 3) % #skinTones) + 1]
  local skinR, skinG, skinB = skinPal[1], skinPal[2], skinPal[3]

  -- Eye color for females (more visible)
  local eyeR, eyeG, eyeB = 0.1, 0.1, 0.15
  if isFemale then
    local eyeColors = {
      {0.15, 0.25, 0.4},  -- blue
      {0.2, 0.35, 0.15},  -- green
      {0.3, 0.18, 0.1},   -- brown
      {0.25, 0.2, 0.35},  -- violet
    }
    local ec = eyeColors[((nameHash * 11) % #eyeColors) + 1]
    eyeR, eyeG, eyeB = ec[1], ec[2], ec[3]
  end

  -- Shoe color
  local shoeR, shoeG, shoeB = 0.3, 0.2, 0.2
  if design.shoe == "heels" then
    shoeR, shoeG, shoeB = 0.25, 0.12, 0.12
  elseif design.shoe == "heavy" then
    shoeR, shoeG, shoeB = 0.22, 0.2, 0.18
  end

  -- Lip color for females
  local lipR, lipG, lipB = skinR + 0.12, skinG - 0.05, skinB - 0.08

  -- Accessory color (glasses frame, earrings)
  local accR, accG, accB = 0.7, 0.6, 0.3  -- gold-ish

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", nx, ny + 12, 9, 4)

  -- ══════════════════════════════════════
  -- HELPER: Draw body shape by design
  -- ══════════════════════════════════════

  local function drawFeet_front()
    love.graphics.setColor(shoeR, shoeG, shoeB)
    if design.shoe == "heels" and isFemale then
      -- Smaller pointed heels
      love.graphics.rectangle("fill", nx - 5, ny + 8 + bob, 3, 4)
      love.graphics.rectangle("fill", nx + 2, ny + 8 + bob + footOffset, 3, 4)
      -- Heel accent
      love.graphics.setColor(shoeR * 0.7, shoeG * 0.7, shoeB * 0.7)
      love.graphics.rectangle("fill", nx - 5, ny + 11 + bob, 1, 2)
      love.graphics.rectangle("fill", nx + 4, ny + 11 + bob + footOffset, 1, 2)
    elseif design.shoe == "heavy" then
      -- Thick heavy boots
      love.graphics.rectangle("fill", nx - 6, ny + 6 + bob, 5, 5)
      love.graphics.rectangle("fill", nx + 1, ny + 6 + bob + footOffset, 5, 5)
      -- Boot strap
      love.graphics.setColor(shoeR * 1.3, shoeG * 1.3, shoeB * 1.3)
      love.graphics.rectangle("fill", nx - 6, ny + 7 + bob, 5, 1)
      love.graphics.rectangle("fill", nx + 1, ny + 7 + bob + footOffset, 5, 1)
    else
      love.graphics.rectangle("fill", nx - 5, ny + 7 + bob, 4, 4)
      love.graphics.rectangle("fill", nx + 1, ny + 7 + bob + footOffset, 4, 4)
    end
  end

  local function drawLegs_front()
    if isFemale and (design.body == "curvy" or design.body == "athletic") then
      -- Slimmer, more shaped legs
      love.graphics.setColor(0.3, 0.22, 0.18)
      love.graphics.rectangle("fill", nx - 4, ny + 2 + bob, 3, 6)
      love.graphics.rectangle("fill", nx + 1, ny + 2 + bob, 3, 6)
    else
      love.graphics.setColor(0.35, 0.25, 0.2)
      love.graphics.rectangle("fill", nx - 4, ny + 2 + bob, 4, 6)
      love.graphics.rectangle("fill", nx + 1, ny + 2 + bob, 4, 6)
    end
  end

  local function drawBody_front()
    love.graphics.setColor(bodyR, bodyG, bodyB)
    if isFemale then
      if design.body == "curvy" then
        -- Hourglass: wider bust, narrow waist, wider hips
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 3)   -- chest
        love.graphics.rectangle("fill", nx - 4, ny - 4 + bob, 8, 2)    -- waist
        love.graphics.rectangle("fill", nx - 5, ny - 2 + bob, 10, 4)   -- hips
        -- Bust line accent
        love.graphics.setColor(bodyR * 0.85, bodyG * 0.85, bodyB * 0.85)
        love.graphics.rectangle("fill", nx - 4, ny - 5 + bob, 8, 1)
      elseif design.body == "athletic" then
        -- Toned, straight but defined shoulders
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 3)
        love.graphics.rectangle("fill", nx - 4, ny - 4 + bob, 8, 3)
        love.graphics.rectangle("fill", nx - 4, ny - 1 + bob, 8, 3)
      elseif design.body == "petite" then
        -- Smaller, narrower frame
        love.graphics.rectangle("fill", nx - 4, ny - 6 + bob, 8, 3)
        love.graphics.rectangle("fill", nx - 3, ny - 3 + bob, 6, 2)
        love.graphics.rectangle("fill", nx - 4, ny - 1 + bob, 8, 3)
      else -- slim
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 4)
        love.graphics.rectangle("fill", nx - 4, ny - 3 + bob, 8, 3)
        love.graphics.rectangle("fill", nx - 5, ny + 0 + bob, 10, 3)
      end
      -- Neckline / collar detail for females
      love.graphics.setColor(skinR, skinG, skinB)
      love.graphics.rectangle("fill", nx - 2, ny - 7 + bob, 4, 2)
    else
      if design.body == "broad" then
        -- Wide muscular torso
        love.graphics.rectangle("fill", nx - 7, ny - 7 + bob, 14, 10)
        -- Shoulder accents
        love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
        love.graphics.rectangle("fill", nx - 7, ny - 7 + bob, 14, 2)
      elseif design.body == "slim" then
        -- Narrower, taller looking
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 10)
      else -- regular
        love.graphics.rectangle("fill", nx - 6, ny - 7 + bob, 12, 10)
      end
      -- Collar for males
      love.graphics.setColor(bodyR * 1.1, bodyG * 1.1, bodyB * 1.1)
      love.graphics.rectangle("fill", nx - 3, ny - 7 + bob, 6, 2)
    end
  end

  local function drawArms_front()
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    if isFemale then
      -- Slimmer arms
      love.graphics.rectangle("fill", nx - 7, ny - 5 + bob + armSwing, 3, 7)
      love.graphics.rectangle("fill", nx + 4, ny - 5 + bob - armSwing, 3, 7)
    else
      if design.body == "broad" then
        love.graphics.rectangle("fill", nx - 9, ny - 5 + bob + armSwing, 3, 8)
        love.graphics.rectangle("fill", nx + 6, ny - 5 + bob - armSwing, 3, 8)
      else
        love.graphics.rectangle("fill", nx - 8, ny - 5 + bob + armSwing, 3, 7)
        love.graphics.rectangle("fill", nx + 5, ny - 5 + bob - armSwing, 3, 7)
      end
    end
    -- Hands
    love.graphics.setColor(skinR, skinG, skinB)
    if isFemale then
      love.graphics.rectangle("fill", nx - 7, ny + 1 + bob + armSwing, 3, 2)
      love.graphics.rectangle("fill", nx + 4, ny + 1 + bob - armSwing, 3, 2)
    else
      if design.body == "broad" then
        love.graphics.rectangle("fill", nx - 9, ny + 2 + bob + armSwing, 3, 3)
        love.graphics.rectangle("fill", nx + 6, ny + 2 + bob - armSwing, 3, 3)
      else
        love.graphics.rectangle("fill", nx - 8, ny + 1 + bob + armSwing, 3, 3)
        love.graphics.rectangle("fill", nx + 5, ny + 1 + bob - armSwing, 3, 3)
      end
    end
  end

  local function drawHead_front()
    -- Head shape
    love.graphics.setColor(skinR, skinG, skinB)
    if isFemale then
      -- Slightly rounder/softer face
      love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
      -- Chin highlight (softer jawline)
      love.graphics.setColor(skinR + 0.03, skinG + 0.02, skinB + 0.01)
      love.graphics.rectangle("fill", nx - 3, ny - 8 + bob, 6, 2)
    else
      love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
      if design.body == "broad" then
        -- Wider jaw
        love.graphics.rectangle("fill", nx - 6, ny - 12 + bob, 12, 6)
      end
    end
  end

  local function drawHair_front()
    love.graphics.setColor(hairR, hairG, hairB)
    if isFemale then
      if design.hair == "long_flowing" then
        -- Voluminous long hair flowing past shoulders
        love.graphics.rectangle("fill", nx - 7, ny - 19 + bob, 14, 7)   -- top volume
        love.graphics.rectangle("fill", nx - 7, ny - 13 + bob, 3, 10)   -- left side long
        love.graphics.rectangle("fill", nx + 5, ny - 13 + bob, 3, 10)   -- right side long
        -- Wispy ends
        love.graphics.rectangle("fill", nx - 6, ny - 4 + bob, 2, 3)
        love.graphics.rectangle("fill", nx + 5, ny - 4 + bob, 2, 3)
        -- Soft bangs
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 2)
      elseif design.hair == "ponytail_high" then
        -- High ponytail with volume on top
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        -- Ponytail sticking up then falling
        love.graphics.rectangle("fill", nx - 1, ny - 22 + bob, 4, 5)
        love.graphics.rectangle("fill", nx + 2, ny - 20 + bob, 3, 3)
        -- Scrunchie / hair tie
        love.graphics.setColor(bodyR * 0.8, bodyG * 0.8, bodyB * 1.2)
        love.graphics.rectangle("fill", nx - 1, ny - 18 + bob, 4, 2)
        love.graphics.setColor(hairR, hairG, hairB)
        -- Side wisps
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 2, 3)
        love.graphics.rectangle("fill", nx + 4, ny - 13 + bob, 2, 3)
      elseif design.hair == "bob" then
        -- Chin-length bob with straight bangs
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 6, ny - 13 + bob, 3, 6)
        love.graphics.rectangle("fill", nx + 4, ny - 13 + bob, 3, 6)
        -- Thick straight bangs
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 3)
      elseif design.hair == "bun" then
        -- Elegant updo bun
        love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)
        -- Bun on top
        love.graphics.rectangle("fill", nx - 3, ny - 22 + bob, 6, 6)
        love.graphics.rectangle("fill", nx - 2, ny - 23 + bob, 4, 3)
        -- Decorative pin
        love.graphics.setColor(0.85, 0.7, 0.3)
        love.graphics.rectangle("fill", nx + 2, ny - 21 + bob, 2, 2)
        love.graphics.setColor(hairR, hairG, hairB)
        -- Swept-back sides
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 2, 3)
        love.graphics.rectangle("fill", nx + 4, ny - 13 + bob, 2, 3)
      elseif design.hair == "twintails" then
        -- Twin tails on each side
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        -- Left tail
        love.graphics.rectangle("fill", nx - 8, ny - 14 + bob, 3, 10)
        love.graphics.rectangle("fill", nx - 7, ny - 5 + bob, 2, 4)
        -- Right tail
        love.graphics.rectangle("fill", nx + 6, ny - 14 + bob, 3, 10)
        love.graphics.rectangle("fill", nx + 6, ny - 5 + bob, 2, 4)
        -- Hair ties
        love.graphics.setColor(0.9, 0.3, 0.4)
        love.graphics.rectangle("fill", nx - 8, ny - 14 + bob, 3, 2)
        love.graphics.rectangle("fill", nx + 6, ny - 14 + bob, 3, 2)
        love.graphics.setColor(hairR, hairG, hairB)
        -- Bangs
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 2)
      elseif design.hair == "side_swept" then
        -- Long side-swept hair, dramatic part
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        -- Swept heavily to one side
        love.graphics.rectangle("fill", nx - 7, ny - 15 + bob, 4, 12)
        love.graphics.rectangle("fill", nx - 7, ny - 4 + bob, 3, 4)
        -- Light side
        love.graphics.rectangle("fill", nx + 4, ny - 13 + bob, 3, 5)
        -- Dramatic side bang
        love.graphics.rectangle("fill", nx - 6, ny - 13 + bob, 7, 3)
      else
        -- Fallback: shoulder-length with bangs
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 6, ny - 13 + bob, 3, 7)
        love.graphics.rectangle("fill", nx + 4, ny - 13 + bob, 3, 7)
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 2)
      end
    else
      if design.hair == "spiky" then
        -- Tall spiky hair
        love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)
        love.graphics.rectangle("fill", nx - 4, ny - 21 + bob, 3, 5)
        love.graphics.rectangle("fill", nx + 0, ny - 22 + bob, 3, 6)
        love.graphics.rectangle("fill", nx + 3, ny - 20 + bob, 3, 4)
      elseif design.hair == "buzz" then
        -- Very short buzz cut
        love.graphics.rectangle("fill", nx - 5, ny - 16 + bob, 10, 3)
      elseif design.hair == "messy" then
        -- Tousled messy hair
        love.graphics.rectangle("fill", nx - 7, ny - 18 + bob, 14, 6)
        love.graphics.rectangle("fill", nx - 6, ny - 13 + bob, 2, 3)
        love.graphics.rectangle("fill", nx + 5, ny - 14 + bob, 2, 2)
        love.graphics.rectangle("fill", nx - 3, ny - 19 + bob, 3, 2)
      elseif design.hair == "slicked" then
        -- Slicked back, neat
        love.graphics.rectangle("fill", nx - 5, ny - 17 + bob, 10, 4)
        love.graphics.rectangle("fill", nx - 5, ny - 14 + bob, 2, 2)
        love.graphics.rectangle("fill", nx + 4, ny - 14 + bob, 2, 2)
      elseif design.hair == "bandana" then
        -- Bandana wrapped around head
        love.graphics.rectangle("fill", nx - 5, ny - 17 + bob, 10, 3)
        -- Bandana band
        love.graphics.setColor(0.7, 0.15, 0.1)
        love.graphics.rectangle("fill", nx - 6, ny - 15 + bob, 12, 2)
        -- Bandana knot on side
        love.graphics.rectangle("fill", nx + 5, ny - 16 + bob, 3, 4)
        love.graphics.setColor(hairR, hairG, hairB)
      else
        -- Default short hair
        love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)
      end
    end
  end

  local function drawEyes_front()
    love.graphics.setColor(eyeR, eyeG, eyeB)
    if isFemale then
      -- Larger, more expressive eyes
      love.graphics.rectangle("fill", nx - 4, ny - 12 + bob, 3, 3)
      love.graphics.rectangle("fill", nx + 1, ny - 12 + bob, 3, 3)
      -- Eye shine / highlights
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.rectangle("fill", nx - 3, ny - 12 + bob, 1, 1)
      love.graphics.rectangle("fill", nx + 2, ny - 12 + bob, 1, 1)
      -- Eyelashes (thicker, more defined)
      love.graphics.setColor(0.05, 0.05, 0.1)
      love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 4, 1)
      love.graphics.rectangle("fill", nx + 1, ny - 13 + bob, 4, 1)
      -- Lower lash line
      love.graphics.rectangle("fill", nx - 4, ny - 9 + bob, 3, 1)
      love.graphics.rectangle("fill", nx + 1, ny - 9 + bob, 3, 1)
    else
      love.graphics.rectangle("fill", nx - 3, ny - 11 + bob, 2, 2)
      love.graphics.rectangle("fill", nx + 2, ny - 11 + bob, 2, 2)
    end
  end

  local function drawFaceDetails_front()
    if isFemale then
      -- Lips
      love.graphics.setColor(lipR, lipG, lipB)
      love.graphics.rectangle("fill", nx - 2, ny - 8 + bob, 4, 1)
      -- Blush
      love.graphics.setColor(skinR + 0.15, skinG - 0.02, skinB - 0.05, 0.35)
      love.graphics.rectangle("fill", nx - 5, ny - 10 + bob, 2, 2)
      love.graphics.rectangle("fill", nx + 3, ny - 10 + bob, 2, 2)
    end
    -- Glasses accessory
    if design.accessory == "glasses" then
      love.graphics.setColor(0.3, 0.3, 0.35, 0.9)
      -- Left lens
      love.graphics.rectangle("line", nx - 5, ny - 13 + bob, 4, 4)
      -- Right lens
      love.graphics.rectangle("line", nx + 1, ny - 13 + bob, 4, 4)
      -- Bridge
      love.graphics.rectangle("fill", nx - 1, ny - 12 + bob, 2, 1)
    end
    -- Earrings accessory (front view shows small studs)
    if design.accessory == "earrings" and isFemale then
      love.graphics.setColor(accR, accG, accB)
      love.graphics.rectangle("fill", nx - 6, ny - 10 + bob, 2, 2)
      love.graphics.rectangle("fill", nx + 5, ny - 10 + bob, 2, 2)
      -- Dangling part
      love.graphics.setColor(accR, accG, accB, 0.7)
      love.graphics.rectangle("fill", nx - 5, ny - 8 + bob, 1, 2)
      love.graphics.rectangle("fill", nx + 5, ny - 8 + bob, 1, 2)
    end
  end

  -- ══════════════════════════════════════
  -- SIDE-VIEW HELPERS
  -- ══════════════════════════════════════

  local function drawFeet_side(facingLeft)
    love.graphics.setColor(shoeR, shoeG, shoeB)
    if design.shoe == "heels" and isFemale then
      if facingLeft then
        love.graphics.rectangle("fill", nx - 4, ny + 8 + bob + footOffset, 3, 4)
        love.graphics.rectangle("fill", nx - 2, ny + 9 + bob, 3, 3)
        love.graphics.setColor(shoeR * 0.7, shoeG * 0.7, shoeB * 0.7)
        love.graphics.rectangle("fill", nx - 1, ny + 11 + bob + footOffset, 1, 2)
      else
        love.graphics.rectangle("fill", nx + 1, ny + 8 + bob + footOffset, 3, 4)
        love.graphics.rectangle("fill", nx - 1, ny + 9 + bob, 3, 3)
        love.graphics.setColor(shoeR * 0.7, shoeG * 0.7, shoeB * 0.7)
        love.graphics.rectangle("fill", nx, ny + 11 + bob + footOffset, 1, 2)
      end
    elseif design.shoe == "heavy" then
      if facingLeft then
        love.graphics.rectangle("fill", nx - 4, ny + 7 + bob + footOffset, 5, 5)
        love.graphics.rectangle("fill", nx - 2, ny + 8 + bob, 5, 4)
      else
        love.graphics.rectangle("fill", nx - 1, ny + 7 + bob + footOffset, 5, 5)
        love.graphics.rectangle("fill", nx - 3, ny + 8 + bob, 5, 4)
      end
    else
      if facingLeft then
        love.graphics.rectangle("fill", nx - 3, ny + 7 + bob + footOffset, 4, 4)
        love.graphics.rectangle("fill", nx - 1, ny + 8 + bob, 4, 3)
      else
        love.graphics.rectangle("fill", nx - 1, ny + 7 + bob + footOffset, 4, 4)
        love.graphics.rectangle("fill", nx - 3, ny + 8 + bob, 4, 3)
      end
    end
  end

  local function drawLegs_side(facingLeft)
    if isFemale and (design.body == "curvy" or design.body == "athletic") then
      love.graphics.setColor(0.3, 0.22, 0.18)
    else
      love.graphics.setColor(0.35, 0.25, 0.2)
    end
    love.graphics.rectangle("fill", nx - 2, ny + 2 + bob, 5, 6)
  end

  local function drawBody_side(facingLeft)
    love.graphics.setColor(bodyR, bodyG, bodyB)
    if isFemale then
      if design.body == "curvy" then
        -- Side profile: bust and hip visible
        if facingLeft then
          love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 7, 3)
          love.graphics.rectangle("fill", nx - 3, ny - 4 + bob, 5, 2)
          love.graphics.rectangle("fill", nx - 4, ny - 2 + bob, 7, 4)
          -- Bust silhouette
          love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
          love.graphics.rectangle("fill", nx - 5, ny - 6 + bob, 2, 3)
        else
          love.graphics.rectangle("fill", nx - 3, ny - 7 + bob, 7, 3)
          love.graphics.rectangle("fill", nx - 2, ny - 4 + bob, 5, 2)
          love.graphics.rectangle("fill", nx - 3, ny - 2 + bob, 7, 4)
          love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
          love.graphics.rectangle("fill", nx + 3, ny - 6 + bob, 2, 3)
        end
      elseif design.body == "athletic" then
        love.graphics.rectangle("fill", nx - 3, ny - 7 + bob, 7, 10)
      elseif design.body == "petite" then
        love.graphics.rectangle("fill", nx - 3, ny - 6 + bob, 6, 9)
      else
        love.graphics.rectangle("fill", nx - 3, ny - 7 + bob, 7, 10)
      end
      -- Neckline
      love.graphics.setColor(skinR, skinG, skinB)
      if facingLeft then
        love.graphics.rectangle("fill", nx - 2, ny - 7 + bob, 3, 2)
      else
        love.graphics.rectangle("fill", nx - 1, ny - 7 + bob, 3, 2)
      end
    else
      if design.body == "broad" then
        love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 9, 10)
      elseif design.body == "slim" then
        love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 7, 10)
      else
        love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 8, 10)
      end
    end
  end

  local function drawArm_side(facingLeft)
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    if isFemale then
      love.graphics.rectangle("fill", nx - 1, ny - 5 + bob + armSwing, 3, 6)
      love.graphics.setColor(skinR, skinG, skinB)
      love.graphics.rectangle("fill", nx - 1, ny + 0 + bob + armSwing, 3, 2)
    else
      if facingLeft then
        love.graphics.rectangle("fill", nx - 1, ny - 5 + bob + armSwing, 3, 7)
      else
        love.graphics.rectangle("fill", nx - 2, ny - 5 + bob + armSwing, 3, 7)
      end
      love.graphics.setColor(skinR, skinG, skinB)
      if facingLeft then
        love.graphics.rectangle("fill", nx - 1, ny + 1 + bob + armSwing, 3, 3)
      else
        love.graphics.rectangle("fill", nx - 2, ny + 1 + bob + armSwing, 3, 3)
      end
    end
  end

  local function drawHead_side(facingLeft)
    love.graphics.setColor(skinR, skinG, skinB)
    love.graphics.rectangle("fill", nx - 4, ny - 15 + bob, 8, 9)
    -- Nose
    love.graphics.setColor(skinR - 0.04, skinG - 0.04, skinB - 0.04)
    if facingLeft then
      love.graphics.rectangle("fill", nx - 6, ny - 12 + bob, 3, 3)
    else
      love.graphics.rectangle("fill", nx + 3, ny - 12 + bob, 3, 3)
    end
    -- Lips for female (side)
    if isFemale then
      love.graphics.setColor(lipR, lipG, lipB)
      if facingLeft then
        love.graphics.rectangle("fill", nx - 5, ny - 9 + bob, 3, 1)
      else
        love.graphics.rectangle("fill", nx + 2, ny - 9 + bob, 3, 1)
      end
      -- Blush
      love.graphics.setColor(skinR + 0.15, skinG - 0.02, skinB - 0.05, 0.3)
      if facingLeft then
        love.graphics.rectangle("fill", nx - 3, ny - 10 + bob, 2, 2)
      else
        love.graphics.rectangle("fill", nx + 1, ny - 10 + bob, 2, 2)
      end
    end
  end

  local function drawHair_side(facingLeft)
    love.graphics.setColor(hairR, hairG, hairB)
    local behindX = facingLeft and 1 or -1  -- direction hair falls behind

    if isFemale then
      if design.hair == "long_flowing" then
        love.graphics.rectangle("fill", nx - 3, ny - 18 + bob, 8, 6)
        -- Long hair falling behind
        local bx = facingLeft and nx + 2 or nx - 5
        love.graphics.rectangle("fill", bx, ny - 13 + bob, 4, 12)
        love.graphics.rectangle("fill", bx + behindX, ny - 2 + bob, 3, 4)
        -- Front wisps
        local fx = facingLeft and nx - 4 or nx + 2
        love.graphics.rectangle("fill", fx, ny - 14 + bob, 2, 4)
      elseif design.hair == "ponytail_high" then
        love.graphics.rectangle("fill", nx - 3, ny - 18 + bob, 8, 6)
        -- High ponytail
        local bx = facingLeft and nx + 3 or nx - 5
        love.graphics.rectangle("fill", bx, ny - 20 + bob, 3, 4)
        love.graphics.rectangle("fill", bx, ny - 17 + bob, 3, 12)
        love.graphics.rectangle("fill", bx + behindX, ny - 6 + bob, 2, 4)
        -- Scrunchie
        love.graphics.setColor(bodyR * 0.8, bodyG * 0.8, bodyB * 1.2)
        love.graphics.rectangle("fill", bx, ny - 17 + bob, 3, 2)
      elseif design.hair == "bob" then
        love.graphics.rectangle("fill", nx - 3, ny - 18 + bob, 8, 6)
        -- Chin-length on both sides
        local bx = facingLeft and nx + 2 or nx - 4
        love.graphics.rectangle("fill", bx, ny - 13 + bob, 3, 6)
        -- Bang on visible side
        local fx = facingLeft and nx - 4 or nx + 2
        love.graphics.rectangle("fill", fx, ny - 14 + bob, 4, 5)
      elseif design.hair == "bun" then
        love.graphics.rectangle("fill", nx - 3, ny - 17 + bob, 8, 5)
        -- Bun on back of head
        local bx = facingLeft and nx + 3 or nx - 6
        love.graphics.rectangle("fill", bx, ny - 17 + bob, 4, 5)
        love.graphics.rectangle("fill", bx + (facingLeft and 0 or 1), ny - 18 + bob, 3, 3)
        -- Pin
        love.graphics.setColor(0.85, 0.7, 0.3)
        love.graphics.rectangle("fill", bx + 1, ny - 18 + bob, 2, 2)
      elseif design.hair == "twintails" then
        love.graphics.rectangle("fill", nx - 3, ny - 18 + bob, 8, 6)
        -- Visible twin tail (one in front, one behind)
        local bx = facingLeft and nx + 2 or nx - 5
        love.graphics.rectangle("fill", bx, ny - 14 + bob, 3, 10)
        love.graphics.rectangle("fill", bx + behindX, ny - 5 + bob, 2, 4)
        -- Hair tie
        love.graphics.setColor(0.9, 0.3, 0.4)
        love.graphics.rectangle("fill", bx, ny - 14 + bob, 3, 2)
      elseif design.hair == "side_swept" then
        love.graphics.rectangle("fill", nx - 3, ny - 18 + bob, 8, 6)
        -- Heavy sweep to one side
        local bx = facingLeft and nx + 2 or nx - 6
        love.graphics.rectangle("fill", bx, ny - 15 + bob, 4, 12)
        love.graphics.rectangle("fill", bx + behindX, ny - 4 + bob, 3, 4)
        -- Dramatic side bang covering one eye
        local fx = facingLeft and nx - 5 or nx + 1
        love.graphics.rectangle("fill", fx, ny - 14 + bob, 5, 5)
      else
        love.graphics.rectangle("fill", nx - 3, ny - 18 + bob, 8, 6)
        local bx = facingLeft and nx + 3 or nx - 6
        love.graphics.rectangle("fill", bx, ny - 14 + bob, 3, 8)
      end
    else
      if design.hair == "spiky" then
        love.graphics.rectangle("fill", nx - 3, ny - 17 + bob, 8, 5)
        love.graphics.rectangle("fill", nx - 2, ny - 21 + bob, 3, 5)
        love.graphics.rectangle("fill", nx + 1, ny - 20 + bob, 3, 4)
      elseif design.hair == "buzz" then
        love.graphics.rectangle("fill", nx - 3, ny - 16 + bob, 8, 3)
      elseif design.hair == "messy" then
        love.graphics.rectangle("fill", nx - 4, ny - 18 + bob, 10, 6)
        love.graphics.rectangle("fill", nx - 3, ny - 19 + bob, 3, 2)
        local bx = facingLeft and nx + 3 or nx - 5
        love.graphics.rectangle("fill", bx, ny - 13 + bob, 2, 3)
      elseif design.hair == "slicked" then
        love.graphics.rectangle("fill", nx - 3, ny - 17 + bob, 8, 4)
        local bx = facingLeft and nx + 2 or nx - 5
        love.graphics.rectangle("fill", bx, ny - 13 + bob, 3, 3)
      elseif design.hair == "bandana" then
        love.graphics.rectangle("fill", nx - 3, ny - 17 + bob, 8, 3)
        love.graphics.setColor(0.7, 0.15, 0.1)
        love.graphics.rectangle("fill", nx - 4, ny - 15 + bob, 10, 2)
        local knotX = facingLeft and nx - 5 or nx + 5
        love.graphics.rectangle("fill", knotX, ny - 16 + bob, 3, 4)
      else
        love.graphics.rectangle("fill", nx - 3, ny - 17 + bob, 8, 5)
        local bx = facingLeft and nx + 2 or nx - 5
        love.graphics.rectangle("fill", bx, ny - 13 + bob, 3, 3)
      end
    end
  end

  local function drawEye_side(facingLeft)
    love.graphics.setColor(eyeR, eyeG, eyeB)
    if isFemale then
      -- Larger eye with lashes
      if facingLeft then
        love.graphics.rectangle("fill", nx - 3, ny - 12 + bob, 3, 2)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("fill", nx - 2, ny - 12 + bob, 1, 1)
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", nx - 4, ny - 13 + bob, 4, 1)
      else
        love.graphics.rectangle("fill", nx + 1, ny - 12 + bob, 3, 2)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("fill", nx + 2, ny - 12 + bob, 1, 1)
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", nx + 1, ny - 13 + bob, 4, 1)
      end
    else
      if facingLeft then
        love.graphics.rectangle("fill", nx - 3, ny - 11 + bob, 2, 2)
      else
        love.graphics.rectangle("fill", nx + 1, ny - 11 + bob, 2, 2)
      end
    end
    -- Glasses side view
    if design.accessory == "glasses" then
      love.graphics.setColor(0.3, 0.3, 0.35, 0.9)
      if facingLeft then
        love.graphics.rectangle("line", nx - 5, ny - 13 + bob, 5, 4)
      else
        love.graphics.rectangle("line", nx, ny - 13 + bob, 5, 4)
      end
    end
    -- Earring side view
    if design.accessory == "earrings" and isFemale then
      love.graphics.setColor(accR, accG, accB)
      local ex = facingLeft and nx + 3 or nx - 4
      love.graphics.rectangle("fill", ex, ny - 9 + bob, 2, 2)
      love.graphics.setColor(accR, accG, accB, 0.7)
      love.graphics.rectangle("fill", ex, ny - 7 + bob, 1, 2)
    end
  end

  -- ══════════════════════════════════════
  -- BACK-VIEW HELPERS
  -- ══════════════════════════════════════

  local function drawFeet_back()
    love.graphics.setColor(shoeR, shoeG, shoeB)
    if design.shoe == "heels" and isFemale then
      love.graphics.rectangle("fill", nx - 5, ny + 8 + bob, 3, 4)
      love.graphics.rectangle("fill", nx + 2, ny + 8 + bob + footOffset, 3, 4)
      love.graphics.setColor(shoeR * 0.7, shoeG * 0.7, shoeB * 0.7)
      love.graphics.rectangle("fill", nx - 4, ny + 11 + bob, 1, 2)
      love.graphics.rectangle("fill", nx + 3, ny + 11 + bob + footOffset, 1, 2)
    elseif design.shoe == "heavy" then
      love.graphics.rectangle("fill", nx - 6, ny + 6 + bob, 5, 5)
      love.graphics.rectangle("fill", nx + 1, ny + 6 + bob + footOffset, 5, 5)
    else
      love.graphics.rectangle("fill", nx - 5, ny + 7 + bob, 4, 4)
      love.graphics.rectangle("fill", nx + 1, ny + 7 + bob + footOffset, 4, 4)
    end
  end

  local function drawLegs_back()
    if isFemale and (design.body == "curvy" or design.body == "athletic") then
      love.graphics.setColor(0.3, 0.22, 0.18)
      love.graphics.rectangle("fill", nx - 4, ny + 2 + bob, 3, 6)
      love.graphics.rectangle("fill", nx + 1, ny + 2 + bob, 3, 6)
    else
      love.graphics.setColor(0.35, 0.25, 0.2)
      love.graphics.rectangle("fill", nx - 4, ny + 2 + bob, 4, 6)
      love.graphics.rectangle("fill", nx + 1, ny + 2 + bob, 4, 6)
    end
  end

  local function drawBody_back()
    love.graphics.setColor(bodyR, bodyG, bodyB)
    if isFemale then
      if design.body == "curvy" then
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 3)
        love.graphics.rectangle("fill", nx - 4, ny - 4 + bob, 8, 2)
        love.graphics.rectangle("fill", nx - 5, ny - 2 + bob, 10, 4)
      elseif design.body == "athletic" then
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 3)
        love.graphics.rectangle("fill", nx - 4, ny - 4 + bob, 8, 6)
      elseif design.body == "petite" then
        love.graphics.rectangle("fill", nx - 4, ny - 6 + bob, 8, 3)
        love.graphics.rectangle("fill", nx - 3, ny - 3 + bob, 6, 5)
      else
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 4)
        love.graphics.rectangle("fill", nx - 4, ny - 3 + bob, 8, 3)
        love.graphics.rectangle("fill", nx - 5, ny + 0 + bob, 10, 3)
      end
    else
      if design.body == "broad" then
        love.graphics.rectangle("fill", nx - 7, ny - 7 + bob, 14, 10)
      elseif design.body == "slim" then
        love.graphics.rectangle("fill", nx - 5, ny - 7 + bob, 10, 10)
      else
        love.graphics.rectangle("fill", nx - 6, ny - 7 + bob, 12, 10)
      end
    end
  end

  local function drawArms_back()
    love.graphics.setColor(bodyR * 0.9, bodyG * 0.9, bodyB * 0.9)
    if isFemale then
      love.graphics.rectangle("fill", nx - 7, ny - 5 + bob + armSwing, 3, 7)
      love.graphics.rectangle("fill", nx + 4, ny - 5 + bob - armSwing, 3, 7)
    else
      if design.body == "broad" then
        love.graphics.rectangle("fill", nx - 9, ny - 5 + bob + armSwing, 3, 8)
        love.graphics.rectangle("fill", nx + 6, ny - 5 + bob - armSwing, 3, 8)
      else
        love.graphics.rectangle("fill", nx - 8, ny - 5 + bob + armSwing, 3, 7)
        love.graphics.rectangle("fill", nx + 5, ny - 5 + bob - armSwing, 3, 7)
      end
    end
    -- Hands
    love.graphics.setColor(skinR, skinG, skinB)
    if isFemale then
      love.graphics.rectangle("fill", nx - 7, ny + 1 + bob + armSwing, 3, 2)
      love.graphics.rectangle("fill", nx + 4, ny + 1 + bob - armSwing, 3, 2)
    else
      if design.body == "broad" then
        love.graphics.rectangle("fill", nx - 9, ny + 2 + bob + armSwing, 3, 3)
        love.graphics.rectangle("fill", nx + 6, ny + 2 + bob - armSwing, 3, 3)
      else
        love.graphics.rectangle("fill", nx - 8, ny + 1 + bob + armSwing, 3, 3)
        love.graphics.rectangle("fill", nx + 5, ny + 1 + bob - armSwing, 3, 3)
      end
    end
  end

  local function drawHair_back()
    love.graphics.setColor(hairR, hairG, hairB)
    if isFemale then
      if design.hair == "long_flowing" then
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 9)
        -- Long flowing down back
        love.graphics.rectangle("fill", nx - 4, ny - 5 + bob, 8, 6)
        love.graphics.rectangle("fill", nx - 3, ny + 0 + bob, 6, 3)
      elseif design.hair == "ponytail_high" then
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 7)
        -- Ponytail cascading down center
        love.graphics.rectangle("fill", nx - 2, ny - 21 + bob, 4, 4)
        love.graphics.rectangle("fill", nx - 2, ny - 7 + bob, 4, 8)
        -- Hair tie
        love.graphics.setColor(bodyR * 0.8, bodyG * 0.8, bodyB * 1.2)
        love.graphics.rectangle("fill", nx - 2, ny - 7 + bob, 4, 2)
      elseif design.hair == "bob" then
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 6)
        -- Clean bob edge
        love.graphics.setColor(hairR * 0.9, hairG * 0.9, hairB * 0.9)
        love.graphics.rectangle("fill", nx - 5, ny - 8 + bob, 10, 1)
      elseif design.hair == "bun" then
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
        love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)
        -- Prominent bun
        love.graphics.rectangle("fill", nx - 3, ny - 22 + bob, 6, 7)
        love.graphics.rectangle("fill", nx - 2, ny - 23 + bob, 4, 3)
        -- Hair pin
        love.graphics.setColor(0.85, 0.7, 0.3)
        love.graphics.rectangle("fill", nx + 2, ny - 21 + bob, 2, 2)
        love.graphics.rectangle("fill", nx - 3, ny - 20 + bob, 2, 2)
      elseif design.hair == "twintails" then
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 5)
        -- Two tails
        love.graphics.rectangle("fill", nx - 7, ny - 9 + bob, 3, 10)
        love.graphics.rectangle("fill", nx + 5, ny - 9 + bob, 3, 10)
        -- Hair ties
        love.graphics.setColor(0.9, 0.3, 0.4)
        love.graphics.rectangle("fill", nx - 7, ny - 9 + bob, 3, 2)
        love.graphics.rectangle("fill", nx + 5, ny - 9 + bob, 3, 2)
      elseif design.hair == "side_swept" then
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 5, ny - 13 + bob, 10, 9)
        -- Asymmetric: one side longer
        love.graphics.rectangle("fill", nx - 6, ny - 5 + bob, 4, 6)
        love.graphics.rectangle("fill", nx + 3, ny - 5 + bob, 3, 3)
      else
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 4, ny - 7 + bob, 8, 6)
        love.graphics.setColor(bodyR * 0.8, bodyG * 0.8, bodyB * 0.8)
        love.graphics.rectangle("fill", nx - 2, ny - 8 + bob, 4, 2)
      end
    else
      if design.hair == "spiky" then
        love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
        love.graphics.rectangle("fill", nx - 3, ny - 20 + bob, 3, 4)
        love.graphics.rectangle("fill", nx + 1, ny - 19 + bob, 3, 3)
      elseif design.hair == "buzz" then
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 8)
        love.graphics.rectangle("fill", nx - 5, ny - 16 + bob, 10, 3)
      elseif design.hair == "messy" then
        love.graphics.rectangle("fill", nx - 6, ny - 18 + bob, 12, 6)
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
        love.graphics.rectangle("fill", nx - 5, ny - 19 + bob, 3, 2)
        love.graphics.rectangle("fill", nx + 3, ny - 19 + bob, 3, 2)
      elseif design.hair == "slicked" then
        love.graphics.rectangle("fill", nx - 5, ny - 17 + bob, 10, 4)
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
      elseif design.hair == "bandana" then
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
        love.graphics.rectangle("fill", nx - 5, ny - 17 + bob, 10, 3)
        love.graphics.setColor(0.7, 0.15, 0.1)
        love.graphics.rectangle("fill", nx - 6, ny - 15 + bob, 12, 2)
        -- Knot at back
        love.graphics.rectangle("fill", nx - 1, ny - 14 + bob, 3, 4)
      else
        love.graphics.rectangle("fill", nx - 5, ny - 15 + bob, 10, 9)
        love.graphics.rectangle("fill", nx - 6, ny - 17 + bob, 12, 5)
      end
    end
    -- Earrings from behind
    if design.accessory == "earrings" and isFemale then
      love.graphics.setColor(accR, accG, accB)
      love.graphics.rectangle("fill", nx - 6, ny - 10 + bob, 2, 2)
      love.graphics.rectangle("fill", nx + 5, ny - 10 + bob, 2, 2)
    end
  end

  -- ══════════════════════════════════════
  -- DRAW BASED ON DIRECTION
  -- ══════════════════════════════════════

  if dir == "left" then
    drawFeet_side(true)
    drawLegs_side(true)
    drawBody_side(true)
    drawArm_side(true)
    drawHead_side(true)
    drawHair_side(true)
    drawEye_side(true)
  elseif dir == "right" then
    drawFeet_side(false)
    drawLegs_side(false)
    drawBody_side(false)
    drawArm_side(false)
    drawHead_side(false)
    drawHair_side(false)
    drawEye_side(false)
  elseif dir == "up" then
    drawFeet_back()
    drawLegs_back()
    drawBody_back()
    drawArms_back()
    drawHair_back()
  else -- "down" (front view, default)
    drawFeet_front()
    drawLegs_front()
    drawBody_front()
    drawArms_front()
    drawHead_front()
    drawHair_front()
    drawEyes_front()
    drawFaceDetails_front()
  end

  -- Name tag (small, above NPC, with neon tint)
  if neonColor then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(neonColor[1], neonColor[2], neonColor[3], 0.8)
    love.graphics.printf(npcObj.name, nx - 40, ny - 38 + bob, 80, "center")
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

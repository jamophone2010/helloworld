-- kalapatthar/muses.lua
-- The Four Muses of the Galaxy — quest tracking and powerup system
--
-- THE MUSES:
--   Melo (Melancholy) — Lives in Mixia. Item: Perfect Piano (red Nord piano).
--     Found in: Temple of Peril. Power: Time Slow (30s cooldown)
--   Djolt (Jolt) — Lives in Singularity. Item: Decks of Destiny (Pioneer DJ vinyl deck).
--     Found in: Black hole dungeon at Singularity. Power: Chain Lightning (15s, 30s cooldown)
--   Tierra — Lives in Leucadia. Item: Gravitron Guitar (Martin dreadnought acoustic).
--     Found in: Greenhouse on Cereus. Power: Screen Wrap (30s cooldown)
--   Clarity — Lives in Cereus. Item: Mystic Microphone (Shure SM58).
--     Found in: Studio at Hometown Station. Power: Clear Vision (rest of stage, 30s cooldown)
--
-- USAGE:
--   In starfox or asteroids, hold B to activate the selected Muse power.
--   The player selects which Muse power is active by talking to the Sage at Kala Patthar.
--   Only one power can be active at a time.

local M = {}

-- ═══════════════════════════════════════
-- MUSE DEFINITIONS
-- ═══════════════════════════════════════

M.MUSES = {
  melo = {
    id = "melo",
    name = "Melo",
    title = "The Melancholy",
    location = "Mixia",
    item = "Perfect Piano",
    itemDescription = "A red electric piano, like a Nord. Warm tone, sunset timbre.",
    itemLocation = "Temple of Peril",
    power = "Time Slow",
    powerDescription = "Slows down time for everything except the player.",
    powerDuration = nil,  -- Instant toggle, 30s cooldown
    cooldown = 30,
    color = {0.80, 0.30, 0.30},
    itemColor = {0.85, 0.20, 0.15},
  },
  djolt = {
    id = "djolt",
    name = "Djolt",
    title = "The Jolt",
    location = "Singularity",
    item = "Decks of Destiny",
    itemDescription = "A turntable like a Pioneer DJ vinyl deck. Spins fate itself.",
    itemLocation = "Black hole dungeon at Singularity",
    power = "Chain Lightning",
    powerDescription = "Bullets add chain lightning for the next 15 seconds.",
    powerDuration = 15,
    cooldown = 30,
    color = {0.30, 0.80, 0.90},
    itemColor = {0.20, 0.20, 0.20},
  },
  tierra = {
    id = "tierra",
    name = "Tierra",
    title = "The Earth",
    location = "Leucadia",
    item = "Gravitron Guitar",
    itemDescription = "An acoustic guitar like a Martin dreadnought. Bends gravity.",
    itemLocation = "Greenhouse on Cereus",
    power = "Screen Wrap",
    powerDescription = "The player can go off the sides of the screen and appear on the other side.",
    powerDuration = nil,  -- Toggle, 30s cooldown
    cooldown = 30,
    color = {0.30, 0.70, 0.25},
    itemColor = {0.60, 0.40, 0.20},
  },
  clarity = {
    id = "clarity",
    name = "Clarity",
    title = "The Clear",
    location = "Cereus",
    item = "Mystic Microphone",
    itemDescription = "A microphone like a Shure SM58. Cuts through any darkness.",
    itemLocation = "Studio at Hometown Station",
    power = "Clear Vision",
    powerDescription = "Any fog, mist, or darkness is cleared for the rest of the stage.",
    powerDuration = nil,  -- Permanent for the stage
    cooldown = 30,
    color = {0.90, 0.85, 0.40},
    itemColor = {0.55, 0.55, 0.55},
  },
}

-- Order for display
M.MUSE_ORDER = {"melo", "djolt", "tierra", "clarity"}

-- ═══════════════════════════════════════
-- QUEST STATE
-- ═══════════════════════════════════════

-- Which instruments have been found and returned
M.itemsFound = {
  melo = false,
  djolt = false,
  tierra = false,
  clarity = false,
}

-- Which instruments have been returned to their Muse (unlocks power)
M.powersUnlocked = {
  melo = false,
  djolt = false,
  tierra = false,
  clarity = false,
}

-- Currently selected active power (only one at a time)
M.activePower = nil  -- "melo", "djolt", "tierra", or "clarity"

-- ═══════════════════════════════════════
-- COMBAT STATE (used during starfox/asteroids)
-- ═══════════════════════════════════════

M.powerActive = false       -- Is the power currently being channeled
M.powerTimer = 0            -- Duration remaining (for timed powers)
M.cooldownTimer = 0         -- Cooldown remaining
M.bHeld = false             -- Is B button being held

-- ═══════════════════════════════════════
-- QUEST API
-- ═══════════════════════════════════════

function M.findItem(museId)
  if M.MUSES[museId] then
    M.itemsFound[museId] = true
  end
end

function M.hasItem(museId)
  return M.itemsFound[museId] == true
end

function M.returnItem(museId)
  if M.MUSES[museId] and M.itemsFound[museId] then
    M.powersUnlocked[museId] = true
    return true
  end
  return false
end

function M.hasPower(museId)
  return M.powersUnlocked[museId] == true
end

function M.setActivePower(museId)
  if museId == nil or M.powersUnlocked[museId] then
    M.activePower = museId
    return true
  end
  return false
end

function M.getActivePower()
  return M.activePower
end

function M.getActiveMuseInfo()
  if M.activePower then
    return M.MUSES[M.activePower]
  end
  return nil
end

function M.getUnlockedPowers()
  local list = {}
  for _, id in ipairs(M.MUSE_ORDER) do
    if M.powersUnlocked[id] then
      table.insert(list, M.MUSES[id])
    end
  end
  return list
end

function M.getFoundItems()
  local list = {}
  for _, id in ipairs(M.MUSE_ORDER) do
    if M.itemsFound[id] then
      table.insert(list, M.MUSES[id])
    end
  end
  return list
end

-- ═══════════════════════════════════════
-- COMBAT API (called from starfox/asteroids)
-- ═══════════════════════════════════════

function M.resetCombatState()
  M.powerActive = false
  M.powerTimer = 0
  M.cooldownTimer = 0
  M.bHeld = false
end

function M.canActivate()
  return M.activePower ~= nil
     and M.powersUnlocked[M.activePower]
     and not M.powerActive
     and M.cooldownTimer <= 0
end

function M.activate()
  if not M.canActivate() then return false end

  local muse = M.MUSES[M.activePower]
  M.powerActive = true

  if muse.powerDuration then
    M.powerTimer = muse.powerDuration
  else
    M.powerTimer = 0  -- Instant/toggle powers
  end

  return true
end

function M.deactivate()
  if not M.powerActive then return end

  local muse = M.MUSES[M.activePower]
  M.powerActive = false
  M.powerTimer = 0
  M.cooldownTimer = muse.cooldown
end

function M.updateCombat(dt)
  -- Update cooldown
  if M.cooldownTimer > 0 then
    M.cooldownTimer = M.cooldownTimer - dt
    if M.cooldownTimer < 0 then M.cooldownTimer = 0 end
  end

  -- Update active power timer
  if M.powerActive and M.activePower then
    local muse = M.MUSES[M.activePower]

    if muse.powerDuration then
      -- Timed power (e.g., Djolt chain lightning 15s)
      M.powerTimer = M.powerTimer - dt
      if M.powerTimer <= 0 then
        M.deactivate()
      end
    end
    -- Non-timed powers (Melo, Tierra, Clarity) stay active until deactivated
    -- Clarity: stays active for the rest of the stage (no auto-deactivate)
  end
end

-- ═══════════════════════════════════════
-- POWER QUERIES (for starfox/asteroids)
-- ═══════════════════════════════════════

-- Melo: Should time be slowed?
function M.isTimeSlowed()
  return M.powerActive and M.activePower == "melo"
end

function M.getTimeScale()
  if M.isTimeSlowed() then
    return 0.25  -- Everything at 25% speed except player
  end
  return 1.0
end

-- Djolt: Should bullets have chain lightning?
function M.hasChainLightning()
  return M.powerActive and M.activePower == "djolt"
end

-- Tierra: Can the player wrap around screen edges?
function M.hasScreenWrap()
  return M.powerActive and M.activePower == "tierra"
end

-- Clarity: Is fog/mist/darkness cleared?
function M.hasClarity()
  return M.powerActive and M.activePower == "clarity"
end

-- ═══════════════════════════════════════
-- HUD DRAWING (for starfox/asteroids)
-- ═══════════════════════════════════════

function M.drawMuseHUD()
  if not M.activePower then return end

  local muse = M.MUSES[M.activePower]
  local screenW = love.graphics.getWidth()
  local hudX = screenW - 180
  local hudY = 100

  -- Background
  love.graphics.setColor(0.05, 0.05, 0.10, 0.7)
  love.graphics.rectangle("fill", hudX, hudY, 170, 50, 6, 6)

  -- Muse color accent
  love.graphics.setColor(muse.color[1], muse.color[2], muse.color[3], 0.8)
  love.graphics.rectangle("fill", hudX, hudY, 4, 50, 2, 2)

  -- Muse name and power
  love.graphics.setColor(muse.color[1], muse.color[2], muse.color[3])
  love.graphics.print(muse.name .. " — " .. muse.power, hudX + 10, hudY + 5)

  -- Status
  if M.powerActive then
    love.graphics.setColor(0.3, 1.0, 0.3, 0.9)
    if muse.powerDuration then
      love.graphics.print(string.format("ACTIVE: %.1fs", M.powerTimer), hudX + 10, hudY + 22)
    else
      love.graphics.print("ACTIVE", hudX + 10, hudY + 22)
    end
  elseif M.cooldownTimer > 0 then
    love.graphics.setColor(0.8, 0.4, 0.2, 0.9)
    love.graphics.print(string.format("Cooldown: %.0fs", M.cooldownTimer), hudX + 10, hudY + 22)
  else
    love.graphics.setColor(0.7, 0.8, 0.9, 0.7)
    love.graphics.print("Hold B to activate", hudX + 10, hudY + 22)
  end

  -- Cooldown bar
  if M.cooldownTimer > 0 and muse.cooldown > 0 then
    local barW = 150
    local filled = 1 - (M.cooldownTimer / muse.cooldown)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.rectangle("fill", hudX + 10, hudY + 40, barW, 4, 2, 2)
    love.graphics.setColor(muse.color[1], muse.color[2], muse.color[3], 0.8)
    love.graphics.rectangle("fill", hudX + 10, hudY + 40, barW * filled, 4, 2, 2)
  end
end

-- ═══════════════════════════════════════
-- SAVE / LOAD
-- ═══════════════════════════════════════

function M.getSaveData()
  return {
    itemsFound = {
      melo = M.itemsFound.melo,
      djolt = M.itemsFound.djolt,
      tierra = M.itemsFound.tierra,
      clarity = M.itemsFound.clarity,
    },
    powersUnlocked = {
      melo = M.powersUnlocked.melo,
      djolt = M.powersUnlocked.djolt,
      tierra = M.powersUnlocked.tierra,
      clarity = M.powersUnlocked.clarity,
    },
    activePower = M.activePower,
  }
end

function M.loadSaveData(data)
  if not data then return end
  if data.itemsFound then
    M.itemsFound.melo = data.itemsFound.melo or false
    M.itemsFound.djolt = data.itemsFound.djolt or false
    M.itemsFound.tierra = data.itemsFound.tierra or false
    M.itemsFound.clarity = data.itemsFound.clarity or false
  end
  if data.powersUnlocked then
    M.powersUnlocked.melo = data.powersUnlocked.melo or false
    M.powersUnlocked.djolt = data.powersUnlocked.djolt or false
    M.powersUnlocked.tierra = data.powersUnlocked.tierra or false
    M.powersUnlocked.clarity = data.powersUnlocked.clarity or false
  end
  M.activePower = data.activePower
end

return M

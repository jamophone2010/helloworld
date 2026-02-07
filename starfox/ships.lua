local M = {}

-- Ship definitions
-- Base stats reference: Starwing has health=100, speedMult=1.0, dodgeMult=1.0
M.defs = {
  starwing = {
    id = "starwing",
    name = "Starwing",
    type = "Balanced",
    description = "The standard Arwing. Reliable and well-rounded with no frills.",
    healthMultiplier = 1.0,
    speedMultiplier = 1.0,
    dodgeMultiplier = 1.0,
    hasSpecial = false,
    specialName = "None",
    specialDesc = "No special ability.",
    color = {0.3, 0.5, 1.0},
    accentColor = {0.5, 0.7, 1.0},
  },
  lancer = {
    id = "lancer",
    name = "Lancer",
    type = "Interceptor",
    description = "Lightweight interceptor. Fragile but lightning fast with a devastating multi-lock barrage.",
    healthMultiplier = 0.5,
    speedMultiplier = 1.5,
    dodgeMultiplier = 1.5,
    hasSpecial = true,
    specialName = "Multi Lock",
    specialDesc = "Target unlimited enemies for 3s, then unleash a homing barrage. Enemies slowed to 0.5x.",
    color = {1.0, 0.4, 0.1},
    accentColor = {1.0, 0.7, 0.3},
  },
  paladin = {
    id = "paladin",
    name = "Paladin",
    type = "Heavy",
    description = "Armoured heavy fighter. Slow but tough, with a reflective shield that turns enemy fire back on them.",
    healthMultiplier = 2.0,
    speedMultiplier = 0.75,
    dodgeMultiplier = 0.75,
    hasSpecial = true,
    specialName = "Reflect Shield",
    specialDesc = "Invulnerable for 5s, reflects all bullets. Enemies slowed to 0.5x.",
    color = {0.2, 0.8, 0.3},
    accentColor = {0.5, 1.0, 0.6},
  },
  mistral = {
    id = "mistral",
    name = "Mistral",
    type = "Interceptor",
    description = "Agile interceptor with mind-control tech. Convert enemies into loyal wingmen.",
    healthMultiplier = 0.5,
    speedMultiplier = 1.5,
    dodgeMultiplier = 1.5,
    hasSpecial = true,
    specialName = "Convert",
    specialDesc = "Next 2 kills become wingmen (purple shots). Enemies drawn toward you at 0.75x, can't shoot.",
    color = {0.6, 0.2, 1.0},
    accentColor = {0.8, 0.5, 1.0},
  },
  phantom = {
    id = "phantom",
    name = "Phantom",
    type = "Heavy",
    description = "Stealth heavy fighter. Phase through walls and enemies while invisible to enemy targeting.",
    healthMultiplier = 2.0,
    speedMultiplier = 0.5,
    dodgeMultiplier = 0.75,
    hasSpecial = true,
    specialName = "Phase Cloak",
    specialDesc = "Invulnerable & intangible for 5s, pass through walls. Enemies drawn toward you at 0.75x, can't shoot.",
    color = {0.3, 0.3, 0.4},
    accentColor = {0.6, 0.6, 0.8},
  },
}

-- Ordered list for UI navigation
M.order = {"starwing", "lancer", "paladin", "mistral", "phantom"}

-- Currently selected ship (default starwing)
local selectedShip = "starwing"

function M.getSelected()
  return selectedShip
end

function M.setSelected(id)
  if M.defs[id] then
    selectedShip = id
  end
end

function M.getDef(id)
  return M.defs[id or selectedShip]
end

function M.getSelectedDef()
  return M.defs[selectedShip]
end

--- Apply ship stats to a player object
function M.applyToPlayer(p)
  local def = M.defs[selectedShip]
  if not def then return end

  local baseHealth = 100
  p.maxHealth = baseHealth * def.healthMultiplier
  p.health = p.maxHealth
  p.speedMultiplier = def.speedMultiplier
  p.dodgeMultiplier = def.dodgeMultiplier
  p.shipType = selectedShip
  p.hasSpecial = def.hasSpecial
end

--- Get the special gauge bonus for a medal threshold
function M.getSpecialGaugeBonus(medalThreshold)
  local bonuses = {
    [5]  = 5,   -- Supershot
    [10] = 10,  -- Megashot
    [15] = 15,  -- Gigashot
    [20] = 20,  -- Ubershot
    [30] = 30,  -- Terashot
  }
  return bonuses[medalThreshold] or 0
end

--- Kill count needed to fill gauge from kills alone
M.GAUGE_MAX = 50

return M

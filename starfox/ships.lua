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
  prototype = {
    id = "prototype",
    name = "Prototype",
    type = "Experimental",
    description = "An advanced experimental starfighter from Leucadia Labs. Blazing fast with devastating EMP weapons.",
    healthMultiplier = 1.5,
    speedMultiplier = 1.3,
    dodgeMultiplier = 1.3,
    hasSpecial = true,
    specialName = "EMP Burst",
    specialDesc = "Fire an EMP pulse that stuns all enemies on screen for 3s. Enemies slowed to 0.5x.",
    color = {0.1, 0.1, 0.15},
    accentColor = {0.0, 0.8, 1.0},
  },
  firebird = {
    id = "firebird",
    name = "Firebird",
    type = "Muscle",
    description = "Forged in Vela's pulsar fire. Inspired by the '69 Pontiac GTO — raw power, burning presence. Immune to cold. Bullets deal burn damage and melt ice.",
    healthMultiplier = 1.3,
    speedMultiplier = 1.1,
    dodgeMultiplier = 0.9,
    hasSpecial = true,
    specialName = "Inferno",
    specialDesc = "Unleash a screen-clearing firestorm that destroys everything. Charges at 100 kills instead of 50.",
    color = {0.75, 0.12, 0.08},
    accentColor = {1.0, 0.45, 0.1},
    coldImmune = true,
    burnDamage = 1,          -- 1 DPS burn on bullet hit
    burnDuration = 3,        -- 3 seconds of burn
    meltsIce = true,         -- bullets melt ice walls
    infernoGaugeMax = 100,   -- charges at 100 instead of 50
  },
  icecube = {
    id = "icecube",
    name = "Ice Cube",
    type = "Elemental",
    description = "A ship that is literally an ice cube. Hitting an enemy 3x freezes it solid. Cold aura damages nearby foes.",
    healthMultiplier = 1.4,
    speedMultiplier = 0.9,
    dodgeMultiplier = 0.85,
    hasSpecial = true,
    specialName = "Deep Freeze",
    specialDesc = "Freezes the entire screen for 5 seconds. All enemies stop in their tracks.",
    color = {0.25, 0.55, 0.95},
    accentColor = {0.5, 0.85, 1.0},
    freezeOnHit = true,       -- hitting enemy 3x freezes it
    freezeHitsRequired = 3,   -- hits needed to freeze
  },
}

-- Ordered list for UI navigation
M.order = {"starwing", "lancer", "paladin", "mistral", "phantom", "prototype", "firebird", "icecube"}

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

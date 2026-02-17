-- singularity/sciencelab.lua
-- NASA-inspired Science Lab sublevel within The Singularity
-- Features: nuclear fusion tokamak, particle accelerator, black hole observation window
-- Accessed via trapdoor in the Quantum Lab building

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local npc = require("hub.npc")
local audio = require("hub.audio")

local GRID_SIZE = 32

-- ═══════════════════════════════════════
-- NASA SCIENCE LAB COLOR PALETTE
-- ═══════════════════════════════════════
local COLORS = {
  -- Facility walls and floors
  wall_dark = {0.12, 0.14, 0.18},        -- Dark steel-blue walls
  wall_light = {0.2, 0.22, 0.28},        -- Lighter wall panels
  floor = {0.15, 0.16, 0.2},             -- Polished lab floor
  floor_accent = {0.1, 0.12, 0.15},      -- Floor grid accent
  ceiling_pipe = {0.25, 0.27, 0.32},     -- Exposed pipes/conduits

  -- NASA blue/white
  nasa_blue = {0.05, 0.15, 0.45},        -- Deep NASA blue
  nasa_white = {0.92, 0.94, 0.96},       -- Clean white
  nasa_red = {0.85, 0.12, 0.08},         -- NASA red chevron
  nasa_silver = {0.7, 0.72, 0.78},       -- Metallic silver

  -- Tokamak plasma
  plasma_core = {0.3, 0.6, 1.0},         -- Hot blue plasma
  plasma_glow = {0.4, 0.7, 1.0},         -- Plasma outer glow
  plasma_ring = {0.2, 0.45, 0.9},        -- Magnetic containment ring
  plasma_hot = {0.7, 0.85, 1.0},         -- White-hot center

  -- Particle accelerator
  accel_beam = {0.1, 1.0, 0.4},          -- Green particle beam
  accel_ring = {0.3, 0.35, 0.45},        -- Accelerator ring structure
  accel_glow = {0.05, 0.8, 0.3},         -- Green glow
  accel_spark = {1.0, 1.0, 0.3},         -- Collision sparks

  -- Black hole observation window
  void = {0.02, 0.02, 0.04},             -- Deep space
  amber = {0.95, 0.65, 0.2},             -- Warm amber (Interstellar)
  gold = {1.0, 0.85, 0.4},              -- Gold highlights
  starlight = {0.9, 0.85, 0.7},          -- Star glow

  -- UI and text
  text_bright = {0.85, 0.9, 0.95},       -- Bright text
  text_dim = {0.5, 0.55, 0.65},          -- Dim text
  hud_green = {0.2, 0.9, 0.3},           -- HUD readout green
  warning_red = {1.0, 0.3, 0.2},         -- Warning indicators
  status_blue = {0.3, 0.6, 1.0},         -- Status displays
}

-- ═══════════════════════════════════════
-- LAB LAYOUT
-- ═══════════════════════════════════════
local LAB_WIDTH = 50
local LAB_HEIGHT = 32

-- Zones within the lab
local zones = {
  -- Main corridor running east-west
  main_corridor = {
    name = "Main Corridor",
    x1 = 1, y1 = 14, x2 = 48, y2 = 17,
    floor = "corridor"
  },
  -- Entrance vestibule (south)
  vestibule = {
    name = "Access Vestibule",
    x1 = 22, y1 = 17, x2 = 27, y2 = 30,
    floor = "vestibule"
  },
  -- Tokamak chamber (northwest)
  tokamak_chamber = {
    name = "Tokamak Fusion Reactor",
    x1 = 2, y1 = 2, x2 = 18, y2 = 13,
    floor = "tokamak",
    feature = "tokamak"
  },
  -- Particle accelerator ring (northeast)
  accelerator_hall = {
    name = "Particle Accelerator Ring",
    x1 = 28, y1 = 2, x2 = 47, y2 = 13,
    floor = "accelerator",
    feature = "accelerator"
  },
  -- Observation deck with black hole window (north center, elevated)
  observation_deck = {
    name = "Black Hole Observation Window",
    x1 = 19, y1 = 2, x2 = 27, y2 = 8,
    floor = "observation",
    feature = "window"
  },
  -- North connector (connects tokamak to observation)
  north_connector_w = {
    name = "Connector West",
    x1 = 18, y1 = 9, x2 = 19, y2 = 14,
    floor = "corridor"
  },
  -- North connector (connects observation to accelerator)
  north_connector_e = {
    name = "Connector East",
    x1 = 27, y1 = 9, x2 = 28, y2 = 14,
    floor = "corridor"
  },
  -- Control room (southwest)
  control_room = {
    name = "Mission Control Annex",
    x1 = 2, y1 = 18, x2 = 16, y2 = 27,
    floor = "control"
  },
  -- Data center (southeast)
  data_center = {
    name = "Quantum Computing Center",
    x1 = 33, y1 = 18, x2 = 47, y2 = 27,
    floor = "data"
  },
  -- South connector (connects vestibule to control room)
  south_connector_w = {
    name = "Connector SW",
    x1 = 16, y1 = 18, x2 = 22, y2 = 20,
    floor = "corridor"
  },
  -- South connector (connects vestibule to data center)
  south_connector_e = {
    name = "Connector SE",
    x1 = 27, y1 = 18, x2 = 33, y2 = 20,
    floor = "corridor"
  },
}

-- Buildings within the lab (sub-rooms accessible via doors)
local buildings = {
  {name = "Fusion Control Room", x = 4, y = 4, w = 5, h = 3, doorX = 6, doorY = 7, interior = "lab_fusion_control",
   color = {0.18, 0.2, 0.28}, glowColor = COLORS.plasma_glow},
  {name = "Specimen Vault", x = 12, y = 4, w = 4, h = 3, doorX = 13, doorY = 7, interior = "lab_specimen_vault",
   color = {0.16, 0.18, 0.24}, glowColor = COLORS.nasa_silver},
  {name = "Beam Control", x = 30, y = 4, w = 5, h = 3, doorX = 32, doorY = 7, interior = "lab_beam_control",
   color = {0.15, 0.2, 0.22}, glowColor = COLORS.accel_glow},
  {name = "Detector Array", x = 40, y = 4, w = 5, h = 3, doorX = 42, doorY = 7, interior = "lab_detector_array",
   color = {0.18, 0.2, 0.25}, glowColor = {0.3, 0.7, 0.5}},
  {name = "Director's Office", x = 4, y = 20, w = 5, h = 4, doorX = 6, doorY = 24, interior = "lab_directors_office",
   color = {0.2, 0.22, 0.3}, glowColor = COLORS.nasa_blue},
  {name = "Clean Room", x = 10, y = 20, w = 4, h = 4, doorX = 11, doorY = 24, interior = "lab_clean_room",
   color = {0.22, 0.24, 0.28}, glowColor = COLORS.nasa_white},
  {name = "Server Core", x = 35, y = 20, w = 5, h = 4, doorX = 37, doorY = 24, interior = "lab_server_core",
   color = {0.14, 0.16, 0.22}, glowColor = COLORS.status_blue},
  {name = "Astro Lab", x = 42, y = 20, w = 4, h = 4, doorX = 43, doorY = 24, interior = "lab_astro_lab",
   color = {0.16, 0.18, 0.26}, glowColor = COLORS.gold},
}

-- Scientists and NPCs
local labNPCs = {
  -- Tokamak Chamber
  {name = "Dr. Elena Vasquez", x = 8, y = 10, dialogue = "The tokamak sustains a plasma at 150 million degrees Celsius. Hotter than the sun's core. And it's contained by magnets thinner than your arm.", gender = "female", design = 4},
  {name = "Fusion Tech Nakamura", x = 15, y = 10, dialogue = "Deuterium-tritium reaction is holding steady. We've maintained sustained ignition for 47 days now. New record.", gender = "male", design = 3},

  -- Particle Accelerator Hall
  {name = "Dr. James Chen", x = 35, y = 10, dialogue = "We're colliding particles at 99.9999% the speed of light. The black hole's gravity lets us reach energies CERN could only dream of.", gender = "male", design = 5},
  {name = "Beam Physicist Okafor", x = 42, y = 11, dialogue = "Last week we detected a particle that shouldn't exist. It was there for a femtosecond, then gone. We call it the 'ghost boson'.", gender = "female", design = 2},

  -- Observation Deck
  {name = "Dr. Amelia Brand", x = 22, y = 5, dialogue = "Look at it. Gargantua. Every photon orbiting that event horizon has been trapped for millions of years. We're witnessing eternity.", gender = "female", design = 1},
  {name = "Astrophysicist Romero", x = 25, y = 4, dialogue = "The gravitational lensing creates an Einstein ring. Light from behind the black hole bends around it. We can see the back of our own station.", gender = "male"},

  -- Main Corridor
  {name = "Lab Director Hayes", x = 15, y = 15, dialogue = "This facility was built to answer humanity's greatest questions. Fusion power, fundamental particles, the nature of spacetime itself.", gender = "male", design = 5},
  {name = "Safety Officer Park", x = 34, y = 16, dialogue = "Radiation badges mandatory. Magnetic containment field exposure limited to 4 hours per shift. No exceptions, not even for directors.", gender = "female", design = 6},

  -- Control Room
  {name = "Flight Director Kowalski", x = 8, y = 22, dialogue = "All stations nominal. Tokamak at 98% efficiency. Accelerator ring integrity green. Observation shields holding. Science is GO.", gender = "male"},
  {name = "Telemetry Analyst Singh", x = 13, y = 24, dialogue = "I monitor every sensor in this facility. 14,000 data points per second. The black hole's tidal forces require constant adjustment.", gender = "female", design = 3},

  -- Data Center
  {name = "Quantum Programmer Liu", x = 38, y = 22, dialogue = "Our quantum computer runs simulations of the black hole's interior. The results are... philosophically disturbing.", gender = "male"},
  {name = "AI Specialist Torres", x = 44, y = 24, dialogue = "The AI predicts gravitational anomalies 6 hours before they happen. We don't know how. It won't explain its reasoning.", gender = "female", design = 4},

  -- Vestibule
  {name = "Security Chief Volkov", x = 24, y = 25, dialogue = "Level 5 clearance required beyond this point. NASA, ESA, and JAXA joint facility. No unauthorized personnel.", gender = "male", design = 6},
}

-- ═══════════════════════════════════════
-- GAME STATE
-- ═══════════════════════════════════════
local gameState = {}

M.returnToHub = nil

function M.load()
  gameState.location = "lab_outdoors"  -- Main lab floor
  gameState.interiorId = nil

  -- Player spawns at vestibule entrance
  local startX = 24 * GRID_SIZE + 16
  local startY = 28 * GRID_SIZE + 16
  gameState.player = player.new(startX, startY)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.collisionMap = M.createLabCollisionMap()
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.buildingEntryCooldown = 0
  gameState.transition = nil
  gameState.returnPosition = nil
  gameState.animationTime = 0

  -- Tokamak animation
  gameState.tokamakRotation = 0
  gameState.tokamakPulse = 0
  gameState.tokamakPlasmaParticles = {}

  -- Accelerator animation
  gameState.acceleratorPhase = 0
  gameState.acceleratorParticles = {}
  gameState.collisionSparks = {}

  -- Black hole window animation
  gameState.blackHoleRotation = 0
  gameState.gravitationalPulse = 0

  -- Background stars for observation window
  gameState.windowStars = {}
  for i = 1, 80 do
    table.insert(gameState.windowStars, {
      x = math.random(19 * GRID_SIZE, 27 * GRID_SIZE),
      y = math.random(2 * GRID_SIZE, 7 * GRID_SIZE),
      size = math.random() * 1.5 + 0.3,
      brightness = math.random() * 0.6 + 0.4,
      twinkleSpeed = math.random() * 3 + 1,
      twinkleOffset = math.random() * math.pi * 2,
      warmth = math.random()
    })
  end

  -- Initialize tokamak plasma particles
  for i = 1, 30 do
    table.insert(gameState.tokamakPlasmaParticles, {
      angle = math.random() * math.pi * 2,
      radius = math.random() * 20 + 50,
      speed = (math.random() * 2 + 1) * (math.random() > 0.5 and 1 or -1),
      size = math.random() * 3 + 1,
      brightness = math.random() * 0.5 + 0.5
    })
  end

  -- Initialize accelerator beam particles
  for i = 1, 20 do
    table.insert(gameState.acceleratorParticles, {
      angle = math.random() * math.pi * 2,
      speed = math.random() * 4 + 2,
      size = math.random() * 2 + 1,
      brightness = math.random() * 0.5 + 0.5
    })
  end

  M.setupLabNPCs()
end

function M.setupLabNPCs()
  gameState.currentNPCs = {}
  for _, npcData in ipairs(labNPCs) do
    table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
  end
end

-- ═══════════════════════════════════════
-- COLLISION MAP
-- ═══════════════════════════════════════

function M.createLabCollisionMap()
  local map = {}
  for y = 0, LAB_HEIGHT - 1 do
    map[y] = {}
    for x = 0, LAB_WIDTH - 1 do
      -- Default: walls (not walkable)
      map[y][x] = true
    end
  end

  -- Carve out walkable zones
  for _, zone in pairs(zones) do
    for y = zone.y1, zone.y2 do
      for x = zone.x1, zone.x2 do
        if map[y] then
          map[y][x] = false
        end
      end
    end
  end

  -- Buildings are solid except doors
  for _, b in ipairs(buildings) do
    for by = b.y, b.y + b.h - 1 do
      for bx = b.x, b.x + b.w - 1 do
        if map[by] then
          map[by][bx] = true
        end
      end
    end
    -- Door is walkable
    if map[b.doorY] then
      map[b.doorY][b.doorX] = false
    end
    if map[b.doorY - 1] then
      map[b.doorY - 1][b.doorX] = false
    end
  end

  return map
end

-- ═══════════════════════════════════════
-- BUILDING INTERIORS
-- ═══════════════════════════════════════
local interiors = {
  lab_fusion_control = {
    name = "Tokamak Fusion Control",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Lead Fusion Engineer", x = 5, y = 3, dialogue = "Magnetic confinement at 12 Tesla. Plasma temperature holding at 150 million Kelvin. We're cooking a star in a bottle.", gender = "male"},
      {name = "Plasma Diagnostician", x = 10, y = 5, dialogue = "Thomson scattering confirms electron density is optimal. ITER was just the prototype — this is the real deal.", gender = "female", design = 2}
    }
  },
  lab_specimen_vault = {
    name = "Specimen Vault",
    width = 10, height = 8,
    exitX = 5, exitY = 7,
    npcs = {
      {name = "Vault Curator", x = 5, y = 3, dialogue = "Materials recovered from near the event horizon. Their molecular structure defies known physics.", gender = "female", design = 4}
    }
  },
  lab_beam_control = {
    name = "Beam Control Center",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Beam Operator", x = 5, y = 3, dialogue = "Proton beam injection nominal. 27 kilometers of superconducting magnets keeping the beam on track. One hiccup and we breach containment.", gender = "male", design = 3},
      {name = "Collision Analyst", x = 10, y = 5, dialogue = "We logged 40 billion collisions last run. Somewhere in that data is evidence of a fifth fundamental force. I can feel it.", gender = "female", design = 5}
    }
  },
  lab_detector_array = {
    name = "Detector Array Station",
    width = 12, height = 8,
    exitX = 6, exitY = 7,
    npcs = {
      {name = "Detector Specialist", x = 6, y = 3, dialogue = "The calorimeters measure particle energy down to the electronvolt. Our detector is more sensitive than anything on Earth by a factor of ten thousand.", gender = "male"},
      {name = "Data Pipeline Tech", x = 9, y = 5, dialogue = "Petabytes of collision data per hour. We'd need every computer on Earth to process it in real time. Good thing we have quantum cores.", gender = "female", design = 6}
    }
  },
  lab_directors_office = {
    name = "Lab Director's Office",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Deputy Director Webb", x = 6, y = 4, dialogue = "Director Hayes built this facility from nothing. NASA, ESA, JAXA, Roscosmos — he convinced them all. 'Science knows no borders,' he said.", gender = "female", design = 1},
      {name = "Grant Writer Martinez", x = 10, y = 6, dialogue = "Do you know how hard it is to write a grant proposal for 'we built a lab next to a black hole'? The peer reviewers had concerns.", gender = "male"}
    }
  },
  lab_clean_room = {
    name = "ISO Class 1 Clean Room",
    width = 10, height = 10,
    exitX = 5, exitY = 9,
    npcs = {
      {name = "Nanofab Engineer", x = 5, y = 3, dialogue = "One speck of dust ruins a month of work. We maintain fewer than 10 particles per cubic meter. Cleaner than outer space, ironically.", gender = "female", design = 2},
      {name = "Materials Scientist", x = 7, y = 6, dialogue = "We're fabricating metamaterials that bend light around objects. Practical invisibility. The military is... very interested.", gender = "male", design = 4}
    }
  },
  lab_server_core = {
    name = "Quantum Server Core",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Sysadmin Zero", x = 5, y = 3, dialogue = "4,096 qubits, error-corrected, running at 15 millikelvin. This machine simulates reality faster than reality computes itself.", gender = "male", design = 3},
      {name = "Cryptographer Nash", x = 10, y = 5, dialogue = "This quantum computer could break every encryption on Earth in seconds. That's why it's airgapped. Physically. By a black hole.", gender = "female", design = 5}
    }
  },
  lab_astro_lab = {
    name = "Astrometrics Laboratory",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Astrometrics Officer", x = 5, y = 3, dialogue = "We map the gravitational lensing in real time. Every photon path around Gargantua, catalogued. It's the most detailed spacetime map ever created.", gender = "female", design = 1},
      {name = "Exoplanet Hunter", x = 9, y = 6, dialogue = "The black hole's lensing acts as a natural telescope. We've discovered 2,000 exoplanets just by watching light bend around it.", gender = "male"}
    }
  },
}

function M.getInterior(interiorId)
  return interiors[interiorId]
end

function M.createInteriorCollisionMap(interiorId)
  local interior = interiors[interiorId]
  if not interior then return {} end

  local map = {}
  for y = 0, interior.height - 1 do
    map[y] = {}
    for x = 0, interior.width - 1 do
      if y == 0 or y == interior.height - 1 or x == 0 or x == interior.width - 1 then
        if not (x == interior.exitX and y == interior.exitY) then
          map[y][x] = true
        end
      end
    end
  end
  return map
end

-- ═══════════════════════════════════════
-- BUILDING ENTRY/EXIT
-- ═══════════════════════════════════════

function M.enterBuilding(buildingId)
  local interior = interiors[buildingId]
  if not interior then return end

  gameState.interiorId = buildingId
  gameState.location = "lab_interior"
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}

  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * GRID_SIZE + 16
  gameState.player.y = gameState.player.gridY * GRID_SIZE + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y

  gameState.collisionMap = M.createInteriorCollisionMap(buildingId)
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
  gameState.location = "lab_outdoors"
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

  gameState.collisionMap = M.createLabCollisionMap()
  gameState.currentPortals = nil
  M.setupLabNPCs()
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  gameState.animationTime = gameState.animationTime + dt

  -- Tokamak animations
  gameState.tokamakRotation = gameState.tokamakRotation + dt * 1.5
  gameState.tokamakPulse = gameState.tokamakPulse + dt * 2.0

  -- Accelerator animations
  gameState.acceleratorPhase = gameState.acceleratorPhase + dt * 3.0

  -- Black hole window animation
  gameState.blackHoleRotation = gameState.blackHoleRotation + dt * 0.02
  gameState.gravitationalPulse = gameState.gravitationalPulse + dt * 0.5

  -- Update plasma particles
  for _, p in ipairs(gameState.tokamakPlasmaParticles) do
    p.angle = p.angle + dt * p.speed
  end

  -- Update accelerator particles
  for _, p in ipairs(gameState.acceleratorParticles) do
    p.angle = p.angle + dt * p.speed
  end

  -- Update collision sparks
  for i = #gameState.collisionSparks, 1, -1 do
    local s = gameState.collisionSparks[i]
    s.life = s.life - dt
    s.x = s.x + s.vx * dt
    s.y = s.y + s.vy * dt
    if s.life <= 0 then
      table.remove(gameState.collisionSparks, i)
    end
  end

  -- Occasional collision sparks in accelerator
  if math.random() < dt * 2 then
    local cx = 37.5 * GRID_SIZE
    local cy = 7.5 * GRID_SIZE
    for j = 1, 3 do
      table.insert(gameState.collisionSparks, {
        x = cx, y = cy,
        vx = (math.random() - 0.5) * 200,
        vy = (math.random() - 0.5) * 200,
        life = math.random() * 0.5 + 0.2,
        size = math.random() * 2 + 1
      })
    end
  end

  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.update(npcObj, dt, gameState.collisionMap, gameState.currentNPCs, gameState.player)
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

  if gameState.location == "lab_outdoors" then
    -- Check building doors
    if gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(buildings) do
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

    -- Check exit (vestibule bottom edge)
    if gameState.player.gridY >= LAB_HEIGHT - 2 and
       gameState.player.gridX >= 22 and gameState.player.gridX <= 27 then
      -- Return to Singularity
      if M.returnToHub then
        M.returnToHub()
      end
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

    -- Check exit
    if gameState.interiorId then
      local interior = interiors[gameState.interiorId]
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
end

-- ═══════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════

function M.draw()
  -- Dark lab background
  love.graphics.setColor(COLORS.wall_dark[1], COLORS.wall_dark[2], COLORS.wall_dark[3])
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.push()
  love.graphics.translate(-gameState.camera.x + love.graphics.getWidth() / 2,
                          -gameState.camera.y + love.graphics.getHeight() / 2)

  if gameState.location == "lab_outdoors" then
    M.drawLabFloor()
  else
    M.drawLabInterior()
  end

  player.draw(gameState.player, gameState.animationTime)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj)
  end

  love.graphics.pop()

  M.drawLabUI()

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
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  end
end

function M.drawLabFloor()
  -- Draw zone floors
  for _, zone in pairs(zones) do
    local zx = zone.x1 * GRID_SIZE
    local zy = zone.y1 * GRID_SIZE
    local zw = (zone.x2 - zone.x1 + 1) * GRID_SIZE
    local zh = (zone.y2 - zone.y1 + 1) * GRID_SIZE

    -- Floor color based on zone type
    if zone.floor == "tokamak" then
      love.graphics.setColor(0.1, 0.12, 0.18, 0.95)
    elseif zone.floor == "accelerator" then
      love.graphics.setColor(0.1, 0.13, 0.15, 0.95)
    elseif zone.floor == "observation" then
      -- Observation window: draw space void
      love.graphics.setColor(COLORS.void[1], COLORS.void[2], COLORS.void[3], 1)
    elseif zone.floor == "control" then
      love.graphics.setColor(0.12, 0.13, 0.18, 0.95)
    elseif zone.floor == "data" then
      love.graphics.setColor(0.1, 0.11, 0.16, 0.95)
    elseif zone.floor == "vestibule" then
      love.graphics.setColor(0.14, 0.15, 0.2, 0.95)
    else
      love.graphics.setColor(COLORS.floor[1], COLORS.floor[2], COLORS.floor[3], 0.95)
    end
    love.graphics.rectangle("fill", zx, zy, zw, zh)

    -- Grid lines (NASA facility style - clean, precise)
    love.graphics.setColor(COLORS.floor_accent[1], COLORS.floor_accent[2], COLORS.floor_accent[3], 0.3)
    love.graphics.setLineWidth(1)
    for gx = zx, zx + zw, GRID_SIZE do
      love.graphics.line(gx, zy, gx, zy + zh)
    end
    for gy = zy, zy + zh, GRID_SIZE do
      love.graphics.line(zx, gy, zx + zw, gy)
    end

    -- Zone border (clean white lines like lab markings)
    if zone.floor ~= "observation" then
      love.graphics.setColor(COLORS.nasa_silver[1], COLORS.nasa_silver[2], COLORS.nasa_silver[3], 0.3)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", zx, zy, zw, zh)
    end
  end

  -- Draw observation window content (black hole view)
  M.drawObservationWindow()

  -- Draw tokamak
  M.drawTokamak()

  -- Draw particle accelerator
  M.drawParticleAccelerator()

  -- Draw buildings
  for _, b in ipairs(buildings) do
    M.drawLabBuilding(b)
  end

  -- Draw exit indicator at vestibule bottom
  local exitPulse = math.sin(gameState.animationTime * 2) * 0.2 + 0.8
  love.graphics.setColor(COLORS.nasa_blue[1], COLORS.nasa_blue[2], COLORS.nasa_blue[3], 0.4 * exitPulse)
  love.graphics.rectangle("fill", 22 * GRID_SIZE, (LAB_HEIGHT - 2) * GRID_SIZE, 6 * GRID_SIZE, GRID_SIZE)
  love.graphics.setColor(COLORS.nasa_white[1], COLORS.nasa_white[2], COLORS.nasa_white[3], 0.7)
  local font = love.graphics.getFont()
  local exitText = "EXIT TO SINGULARITY"
  local exitTextW = font:getWidth(exitText)
  love.graphics.print(exitText, 24.5 * GRID_SIZE - exitTextW / 2, (LAB_HEIGHT - 2) * GRID_SIZE + 8)

  -- NASA logo/branding on corridor walls
  love.graphics.setColor(COLORS.nasa_blue[1], COLORS.nasa_blue[2], COLORS.nasa_blue[3], 0.5)
  love.graphics.rectangle("fill", 23 * GRID_SIZE, 13 * GRID_SIZE, 4 * GRID_SIZE, GRID_SIZE)
  love.graphics.setColor(COLORS.nasa_white[1], COLORS.nasa_white[2], COLORS.nasa_white[3], 0.9)
  local nasaText = "NASA DEEP SPACE RESEARCH FACILITY"
  local nasaTextW = font:getWidth(nasaText)
  love.graphics.print(nasaText, 25 * GRID_SIZE - nasaTextW / 2, 13 * GRID_SIZE + 8)

  -- Hazard stripes near tokamak
  M.drawHazardStripes(2 * GRID_SIZE, 13 * GRID_SIZE, 17 * GRID_SIZE, GRID_SIZE)

  -- Hazard stripes near accelerator
  M.drawHazardStripes(28 * GRID_SIZE, 13 * GRID_SIZE, 20 * GRID_SIZE, GRID_SIZE)

  -- Draw collision sparks
  for _, spark in ipairs(gameState.collisionSparks) do
    local alpha = spark.life * 2
    love.graphics.setColor(COLORS.accel_spark[1], COLORS.accel_spark[2], COLORS.accel_spark[3], alpha)
    love.graphics.circle("fill", spark.x, spark.y, spark.size)
  end
end

function M.drawHazardStripes(x, y, w, h)
  local stripeW = 12
  love.graphics.setColor(COLORS.warning_red[1], COLORS.warning_red[2], COLORS.warning_red[3], 0.4)
  for sx = x, x + w, stripeW * 2 do
    love.graphics.polygon("fill",
      sx, y,
      sx + stripeW, y,
      sx + stripeW - h, y + h,
      sx - h, y + h)
  end
end

function M.drawObservationWindow()
  local zone = zones.observation_deck
  local wx = zone.x1 * GRID_SIZE
  local wy = zone.y1 * GRID_SIZE
  local ww = (zone.x2 - zone.x1 + 1) * GRID_SIZE
  local wh = (zone.y2 - zone.y1 + 1) * GRID_SIZE

  -- Stars in the window
  for _, star in ipairs(gameState.windowStars) do
    local twinkle = math.sin(gameState.animationTime * star.twinkleSpeed + star.twinkleOffset) * 0.3 + 0.7
    local brightness = star.brightness * twinkle
    local r = 1.0 * (1 - star.warmth * 0.3) + COLORS.amber[1] * star.warmth * 0.3
    local g = 1.0 * (1 - star.warmth * 0.5) + COLORS.amber[2] * star.warmth * 0.5
    local b = 1.0 * (1 - star.warmth * 0.7) + COLORS.amber[3] * star.warmth * 0.7
    love.graphics.setColor(r, g, b, brightness)
    love.graphics.circle("fill", star.x, star.y, star.size)
  end

  -- Black hole in the observation window
  local bhX = wx + ww / 2
  local bhY = wy + wh * 0.4
  local bhRadius = 45
  local pulse = math.sin(gameState.gravitationalPulse) * 0.1 + 0.9

  -- Distant warm glow
  for i = 12, 1, -1 do
    local glowR = bhRadius + i * 12
    local alpha = (13 - i) / 13 * 0.15 * pulse
    love.graphics.setColor(1.0, 0.7, 0.25, alpha)
    love.graphics.circle("fill", bhX, bhY, glowR)
  end

  -- Accretion disk
  love.graphics.push()
  love.graphics.translate(bhX, bhY)
  love.graphics.rotate(gameState.blackHoleRotation)

  for i = 8, 1, -1 do
    local diskR = bhRadius * 2.0 - i * 4
    local alpha = (9 - i) / 9 * 0.4 * pulse
    love.graphics.setColor(1.0, 0.55 + i * 0.03, 0.1 + i * 0.02, alpha)
    love.graphics.setLineWidth(3 + i)
    love.graphics.ellipse("line", 0, 0, diskR, diskR * 0.3)
  end

  -- Bright inner ring
  love.graphics.setColor(1.0, 0.95, 0.75, 0.8 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.ellipse("line", 0, 0, bhRadius * 1.1, bhRadius * 1.1 * 0.3)

  love.graphics.pop()

  -- Black center
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.circle("fill", bhX, bhY, bhRadius)

  -- Photon sphere edge
  love.graphics.setColor(1.0, 0.92, 0.7, 0.5 * pulse)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", bhX, bhY, bhRadius)

  -- Window frame (thick reinforced steel)
  love.graphics.setColor(COLORS.wall_light[1], COLORS.wall_light[2], COLORS.wall_light[3], 1)
  love.graphics.setLineWidth(6)
  love.graphics.rectangle("line", wx, wy, ww, wh)

  -- Window frame inner highlight
  love.graphics.setColor(COLORS.nasa_silver[1], COLORS.nasa_silver[2], COLORS.nasa_silver[3], 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", wx + 4, wy + 4, ww - 8, wh - 8)

  -- Window label
  love.graphics.setColor(COLORS.nasa_white[1], COLORS.nasa_white[2], COLORS.nasa_white[3], 0.9)
  local font = love.graphics.getFont()
  local winLabel = "OBSERVATION WINDOW - GARGANTUA"
  local winLabelW = font:getWidth(winLabel)
  love.graphics.print(winLabel, bhX - winLabelW / 2, wy + wh + 4)

  -- Warning lights on frame
  local warnPulse = math.sin(gameState.animationTime * 4) > 0 and 1 or 0.3
  love.graphics.setColor(COLORS.warning_red[1], COLORS.warning_red[2], COLORS.warning_red[3], warnPulse)
  love.graphics.circle("fill", wx + 8, wy + 8, 4)
  love.graphics.circle("fill", wx + ww - 8, wy + 8, 4)
end

function M.drawTokamak()
  local zone = zones.tokamak_chamber
  local cx = (zone.x1 + zone.x2) / 2 * GRID_SIZE + 16
  local cy = (zone.y1 + zone.y2) / 2 * GRID_SIZE + 16
  local outerRadius = 80
  local innerRadius = 50

  local pulse = math.sin(gameState.tokamakPulse) * 0.15 + 0.85

  -- Outer containment ring (structural)
  love.graphics.setColor(COLORS.accel_ring[1], COLORS.accel_ring[2], COLORS.accel_ring[3], 0.6)
  love.graphics.setLineWidth(8)
  love.graphics.circle("line", cx, cy, outerRadius)

  -- Magnetic field coils (segments around the ring)
  for i = 0, 11 do
    local angle = i * math.pi / 6 + gameState.tokamakRotation * 0.2
    local coilX = cx + math.cos(angle) * outerRadius
    local coilY = cy + math.sin(angle) * outerRadius
    love.graphics.setColor(COLORS.nasa_silver[1], COLORS.nasa_silver[2], COLORS.nasa_silver[3], 0.8)
    love.graphics.circle("fill", coilX, coilY, 6)
    -- Coil glow
    love.graphics.setColor(COLORS.plasma_core[1], COLORS.plasma_core[2], COLORS.plasma_core[3], 0.3 * pulse)
    love.graphics.circle("fill", coilX, coilY, 10)
  end

  -- Inner plasma containment
  love.graphics.setColor(COLORS.plasma_ring[1], COLORS.plasma_ring[2], COLORS.plasma_ring[3], 0.4)
  love.graphics.setLineWidth(4)
  love.graphics.circle("line", cx, cy, innerRadius)

  -- Plasma glow (pulsing blue-white)
  for i = 6, 1, -1 do
    local glowR = innerRadius - 5 + i * 3
    local alpha = (7 - i) / 7 * 0.25 * pulse
    love.graphics.setColor(COLORS.plasma_glow[1], COLORS.plasma_glow[2], COLORS.plasma_glow[3], alpha)
    love.graphics.circle("fill", cx, cy, glowR)
  end

  -- Hot plasma core (toroidal shape approximated as ring)
  love.graphics.setColor(COLORS.plasma_hot[1], COLORS.plasma_hot[2], COLORS.plasma_hot[3], 0.4 * pulse)
  love.graphics.setLineWidth(12)
  love.graphics.circle("line", cx, cy, (innerRadius + outerRadius) / 2 - 10)

  -- Plasma particles orbiting
  for _, p in ipairs(gameState.tokamakPlasmaParticles) do
    local px = cx + math.cos(p.angle) * p.radius
    local py = cy + math.sin(p.angle) * p.radius
    love.graphics.setColor(COLORS.plasma_core[1], COLORS.plasma_core[2], COLORS.plasma_core[3], p.brightness * pulse)
    love.graphics.circle("fill", px, py, p.size)
    -- Particle trail
    local trailX = cx + math.cos(p.angle - 0.2 * (p.speed > 0 and 1 or -1)) * p.radius
    local trailY = cy + math.sin(p.angle - 0.2 * (p.speed > 0 and 1 or -1)) * p.radius
    love.graphics.setColor(COLORS.plasma_glow[1], COLORS.plasma_glow[2], COLORS.plasma_glow[3], p.brightness * 0.3 * pulse)
    love.graphics.line(px, py, trailX, trailY)
  end

  -- Center label
  love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3], 0.8)
  local font = love.graphics.getFont()
  local tokLabel = "TOKAMAK MK-IV"
  local tokLabelW = font:getWidth(tokLabel)
  love.graphics.print(tokLabel, cx - tokLabelW / 2, cy - 6)

  -- Status readout below
  love.graphics.setColor(COLORS.hud_green[1], COLORS.hud_green[2], COLORS.hud_green[3], 0.7)
  local statusText = "PLASMA: 150M°K | STABLE"
  local statusW = font:getWidth(statusText)
  love.graphics.print(statusText, cx - statusW / 2, cy + 8)
end

function M.drawParticleAccelerator()
  local zone = zones.accelerator_hall
  local cx = (zone.x1 + zone.x2) / 2 * GRID_SIZE + 16
  local cy = (zone.y1 + zone.y2) / 2 * GRID_SIZE + 16
  local radiusX = 130
  local radiusY = 70

  local phase = gameState.acceleratorPhase

  -- Accelerator ring structure
  love.graphics.setColor(COLORS.accel_ring[1], COLORS.accel_ring[2], COLORS.accel_ring[3], 0.7)
  love.graphics.setLineWidth(10)
  love.graphics.ellipse("line", cx, cy, radiusX, radiusY)

  -- Inner ring
  love.graphics.setColor(COLORS.accel_ring[1] * 0.8, COLORS.accel_ring[2] * 0.8, COLORS.accel_ring[3] * 0.8, 0.5)
  love.graphics.setLineWidth(4)
  love.graphics.ellipse("line", cx, cy, radiusX - 12, radiusY - 8)

  -- Superconducting magnet segments
  for i = 0, 15 do
    local angle = i * math.pi / 8
    local mx = cx + math.cos(angle) * radiusX
    local my = cy + math.sin(angle) * radiusY
    love.graphics.setColor(COLORS.nasa_silver[1], COLORS.nasa_silver[2], COLORS.nasa_silver[3], 0.7)
    love.graphics.rectangle("fill", mx - 4, my - 4, 8, 8)
  end

  -- Beam particles traveling around the ring
  for _, p in ipairs(gameState.acceleratorParticles) do
    local px = cx + math.cos(p.angle) * (radiusX - 6)
    local py = cy + math.sin(p.angle) * (radiusY - 4)
    love.graphics.setColor(COLORS.accel_beam[1], COLORS.accel_beam[2], COLORS.accel_beam[3], p.brightness)
    love.graphics.circle("fill", px, py, p.size)

    -- Trail
    local trailLen = 0.15
    local tx = cx + math.cos(p.angle - trailLen) * (radiusX - 6)
    local ty = cy + math.sin(p.angle - trailLen) * (radiusY - 4)
    love.graphics.setColor(COLORS.accel_glow[1], COLORS.accel_glow[2], COLORS.accel_glow[3], p.brightness * 0.4)
    love.graphics.line(px, py, tx, ty)
  end

  -- Collision point (glowing)
  local collPulse = math.sin(phase * 2) * 0.3 + 0.7
  local collX = cx + radiusX - 6
  local collY = cy
  for i = 4, 1, -1 do
    love.graphics.setColor(COLORS.accel_beam[1], COLORS.accel_beam[2], COLORS.accel_beam[3], (5 - i) / 5 * 0.3 * collPulse)
    love.graphics.circle("fill", collX, collY, i * 6)
  end
  love.graphics.setColor(1, 1, 1, 0.8 * collPulse)
  love.graphics.circle("fill", collX, collY, 3)

  -- Center label
  love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3], 0.8)
  local font = love.graphics.getFont()
  local accLabel = "PARTICLE ACCELERATOR"
  local accLabelW = font:getWidth(accLabel)
  love.graphics.print(accLabel, cx - accLabelW / 2, cy - 6)

  -- Status readout
  love.graphics.setColor(COLORS.hud_green[1], COLORS.hud_green[2], COLORS.hud_green[3], 0.7)
  local accStatus = "BEAM: 99.9999% c | COLLIDING"
  local accStatusW = font:getWidth(accStatus)
  love.graphics.print(accStatus, cx - accStatusW / 2, cy + 8)
end

function M.drawLabBuilding(b)
  local x = b.x * GRID_SIZE
  local y = b.y * GRID_SIZE
  local w = b.w * GRID_SIZE
  local h = b.h * GRID_SIZE

  local pulse = math.sin(gameState.animationTime * 2 + x * 0.01) * 0.2 + 0.8

  -- Building glow
  if b.glowColor then
    love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.15 * pulse)
    love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6)
  end

  -- Building body
  love.graphics.setColor(b.color[1], b.color[2], b.color[3])
  love.graphics.rectangle("fill", x, y, w, h)

  -- Windows (blue-white glow — NASA clean room style)
  love.graphics.setColor(COLORS.status_blue[1], COLORS.status_blue[2], COLORS.status_blue[3], 0.6)
  local windowY = y + 6
  for wx = x + 6, x + w - 14, 14 do
    love.graphics.rectangle("fill", wx, windowY, 8, 6)
  end

  -- Door
  local doorPx = b.doorX * GRID_SIZE + 2
  local doorPy = (b.y + b.h - 1) * GRID_SIZE + 2
  local doorW = 28
  local doorH = 28

  -- Door glow
  if b.glowColor then
    for gi = 3, 1, -1 do
      love.graphics.setColor(b.glowColor[1], b.glowColor[2], b.glowColor[3], 0.06 * (4 - gi) * pulse)
      love.graphics.rectangle("fill", doorPx - gi * 2, doorPy - gi * 2, doorW + gi * 4, doorH + gi * 4, 1)
    end
  end

  -- Dark doorway
  love.graphics.setColor(0.04, 0.04, 0.06)
  love.graphics.rectangle("fill", doorPx, doorPy, doorW, doorH, 1)

  -- Door frame (NASA blue)
  love.graphics.setColor(COLORS.nasa_blue[1], COLORS.nasa_blue[2], COLORS.nasa_blue[3], 0.7 * pulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", doorPx, doorPy, doorW, doorH, 1)

  -- Building edge
  love.graphics.setColor(COLORS.nasa_silver[1], COLORS.nasa_silver[2], COLORS.nasa_silver[3], 0.4 * pulse)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h)

  -- Building name
  love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3], 0.9)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  love.graphics.print(b.name, x + w / 2 - textW / 2, y - 14)
end

function M.drawLabInterior()
  local interior = interiors[gameState.interiorId]
  if not interior then return end

  -- Dark lab floor
  love.graphics.setColor(COLORS.floor[1], COLORS.floor[2], COLORS.floor[3])
  love.graphics.rectangle("fill", 0, 0, interior.width * GRID_SIZE, interior.height * GRID_SIZE)

  -- Grid lines
  love.graphics.setColor(COLORS.floor_accent[1], COLORS.floor_accent[2], COLORS.floor_accent[3], 0.25)
  love.graphics.setLineWidth(1)
  for x = 0, interior.width * GRID_SIZE, GRID_SIZE do
    love.graphics.line(x, 0, x, interior.height * GRID_SIZE)
  end
  for y = 0, interior.height * GRID_SIZE, GRID_SIZE do
    love.graphics.line(0, y, interior.width * GRID_SIZE, y)
  end

  -- Walls (dark steel-blue)
  love.graphics.setColor(COLORS.wall_dark[1], COLORS.wall_dark[2], COLORS.wall_dark[3])
  love.graphics.rectangle("fill", 0, 0, interior.width * GRID_SIZE, GRID_SIZE)
  love.graphics.rectangle("fill", 0, 0, GRID_SIZE, interior.height * GRID_SIZE)
  love.graphics.rectangle("fill", (interior.width - 1) * GRID_SIZE, 0, GRID_SIZE, interior.height * GRID_SIZE)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * GRID_SIZE, interior.width * GRID_SIZE, GRID_SIZE)

  -- Exit door
  love.graphics.setColor(COLORS.nasa_blue[1], COLORS.nasa_blue[2], COLORS.nasa_blue[3], 0.5)
  love.graphics.rectangle("fill", interior.exitX * GRID_SIZE, interior.exitY * GRID_SIZE, GRID_SIZE, GRID_SIZE)

  -- Interior name
  love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3])
  love.graphics.print(interior.name, 40, 40)
end

function M.drawLabUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Zone name display
  local zoneName = "Science Lab"
  if gameState.location == "lab_outdoors" then
    -- Find which zone player is in
    for _, zone in pairs(zones) do
      if gameState.player.gridX >= zone.x1 and gameState.player.gridX <= zone.x2 and
         gameState.player.gridY >= zone.y1 and gameState.player.gridY <= zone.y2 then
        zoneName = zone.name
        break
      end
    end
  elseif gameState.location == "lab_interior" then
    local interior = interiors[gameState.interiorId]
    if interior then
      zoneName = interior.name
    end
  end

  -- Zone HUD
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 10, 10, 280, 30, 5, 5)
  love.graphics.setColor(COLORS.nasa_blue[1] + 0.3, COLORS.nasa_blue[2] + 0.3, COLORS.nasa_blue[3] + 0.3, 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 10, 10, 280, 30, 5, 5)
  love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3])
  love.graphics.print("⬡ " .. zoneName, 20, 17)

  -- NASA facility badge
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", screenW - 180, 10, 170, 30, 5, 5)
  love.graphics.setColor(COLORS.nasa_red[1], COLORS.nasa_red[2], COLORS.nasa_red[3])
  love.graphics.print("NASA", screenW - 170, 17)
  love.graphics.setColor(COLORS.text_dim[1], COLORS.text_dim[2], COLORS.text_dim[3])
  love.graphics.print("SCIENCE LAB", screenW - 120, 17)

  -- Interaction prompts
  if gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", screenW / 2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3])
    love.graphics.printf("Press E to talk to " .. gameState.nearbyNPC.name, screenW / 2 - 120, screenH - 50, 240, "center")
  end

  -- Exit prompt
  if gameState.location == "lab_outdoors" and
     gameState.player.gridY >= LAB_HEIGHT - 3 and
     gameState.player.gridX >= 22 and gameState.player.gridX <= 27 then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", screenW / 2 - 140, screenH - 60, 280, 40, 5, 5)
    love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3])
    love.graphics.printf("Walk south to return to The Singularity", screenW / 2 - 140, screenH - 50, 280, "center")
  end

  -- Dialogue box
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(COLORS.nasa_blue[1] + 0.2, COLORS.nasa_blue[2] + 0.2, COLORS.nasa_blue[3] + 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(COLORS.status_blue[1], COLORS.status_blue[2], COLORS.status_blue[3])
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 140)
    love.graphics.setColor(COLORS.text_bright[1], COLORS.text_bright[2], COLORS.text_bright[3])
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 115, screenW - 140, "left")
    love.graphics.setColor(COLORS.text_dim[1], COLORS.text_dim[2], COLORS.text_dim[3])
    love.graphics.print("Press E to close", 70, screenH - 50)
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
    -- Return to Singularity
    if M.returnToHub then
      M.returnToHub()
    end
    return
  end

  if key == "e" then
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

return M

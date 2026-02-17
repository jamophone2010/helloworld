-- elendil/areas.lua
-- Cartographer planet: AI archivists who map the music of the stars
-- Zanaris-blue palette with neon and glowing accents
-- French classical music influences (Poulenc, Ravel, Debussy, Fauré, Saint-Saëns, Rameau)
-- Routes to the Four Corners of the Galaxy

local M = {}

M.GRID_SIZE = 32

-- Village dimensions
M.WIDTH = 48
M.HEIGHT = 38

-- Zone definitions (Zanaris bluish palette — deep blues, teals, neon accents)
M.zones = {
  village_square = {
    name = "Place de la Partition",
    x1 = 16, y1 = 14, x2 = 30, y2 = 22,
    groundColor = {0.18, 0.22, 0.42},
    ambientSound = "crowd"
  },
  river_bank = {
    name = "Quai des Harmoniques",
    x1 = 0, y1 = 26, x2 = 47, y2 = 29,
    groundColor = {0.12, 0.28, 0.38},
    ambientSound = "river"
  },
  river = {
    name = "Fleuve Debussy",
    x1 = 0, y1 = 30, x2 = 47, y2 = 37,
    groundColor = {0.05, 0.12, 0.35},
    isWater = true,
    ambientSound = "river"
  },
  stone_bridge = {
    name = "Pont des Étoiles Errantes",
    x1 = 20, y1 = 26, x2 = 26, y2 = 37,
    groundColor = {0.22, 0.25, 0.40},
    ambientSound = "river"
  },
  market_row = {
    name = "Arcade Ravel",
    x1 = 0, y1 = 14, x2 = 15, y2 = 22,
    groundColor = {0.15, 0.20, 0.35},
    ambientSound = "crowd"
  },
  windmill_hill = {
    name = "Belvédère Saint-Saëns",
    x1 = 34, y1 = 0, x2 = 47, y2 = 13,
    groundColor = {0.10, 0.25, 0.30},
    ambientSound = "wind"
  },
  orchard = {
    name = "Bosquet Rameau",
    x1 = 0, y1 = 0, x2 = 15, y2 = 13,
    groundColor = {0.08, 0.22, 0.28},
    ambientSound = "birds"
  },
  residential = {
    name = "Jardin Fauré",
    x1 = 16, y1 = 0, x2 = 33, y2 = 13,
    groundColor = {0.12, 0.20, 0.32},
    ambientSound = "birds"
  },
  castle_grounds = {
    name = "Observatoire Poulenc",
    x1 = 31, y1 = 14, x2 = 47, y2 = 27,
    groundColor = {0.20, 0.22, 0.38},
    ambientSound = "bells"
  }
}

-- Buildings (Cartographer halls, Zanaris blue-stone with neon-lit accents)
-- Architecture inspired by Frank Lloyd Wright (organic horizontality, cantilevers)
-- and Antoni Gaudi (parabolic arches, mosaic tiles, nature-forms)
M.buildings = {
  -- Place de la Partition (village_square) — spaced generously
  {name = "Salle des Nocturnes", x = 17, y = 12, w = 6, h = 4, doorX = 20, doorY = 16, interior = "tavern",
   color = {0.25, 0.30, 0.52}, roofColor = {0.12, 0.18, 0.42}, timberColor = {0.18, 0.22, 0.40}},
  {name = "Comptoir des Portulans", x = 26, y = 12, w = 5, h = 4, doorX = 28, doorY = 16, interior = "general_store",
   color = {0.22, 0.28, 0.50}, roofColor = {0.10, 0.16, 0.40}, timberColor = {0.16, 0.20, 0.38}},
  {name = "Chambre des Routes", x = 21, y = 18, w = 6, h = 4, doorX = 24, doorY = 22, interior = "town_hall",
   color = {0.28, 0.32, 0.55}, roofColor = {0.14, 0.20, 0.44}, timberColor = {0.20, 0.24, 0.42}},

  -- Arcade Ravel (market_row) — more space between shops
  {name = "Forge Spectrale", x = 1, y = 12, w = 5, h = 4, doorX = 3, doorY = 16, interior = "blacksmith",
   color = {0.20, 0.24, 0.45}, roofColor = {0.10, 0.15, 0.38}, timberColor = {0.15, 0.18, 0.35}},
  {name = "Pharmacie des Fréquences", x = 9, y = 12, w = 5, h = 4, doorX = 11, doorY = 16, interior = "apothecary",
   color = {0.22, 0.30, 0.48}, roofColor = {0.10, 0.18, 0.38}, timberColor = {0.16, 0.22, 0.36}},
  {name = "Boulangerie Gymnopédie", x = 2, y = 18, w = 4, h = 4, doorX = 4, doorY = 22, interior = "bakery",
   color = {0.24, 0.28, 0.48}, roofColor = {0.12, 0.16, 0.38}, timberColor = {0.18, 0.22, 0.38}},
  {name = "Atelier des Fugues", x = 9, y = 18, w = 4, h = 4, doorX = 11, doorY = 22, interior = "weaver",
   color = {0.22, 0.26, 0.46}, roofColor = {0.10, 0.15, 0.38}, timberColor = {0.16, 0.20, 0.36}},

  -- Jardin Fauré (residential) — generous spacing
  {name = "Archives du Ciel", x = 17, y = 1, w = 6, h = 4, doorX = 20, doorY = 5, interior = "elder_house",
   color = {0.25, 0.30, 0.52}, roofColor = {0.12, 0.18, 0.42}, timberColor = {0.18, 0.24, 0.40}},
  {name = "Pavillon Clair de Lune", x = 27, y = 1, w = 5, h = 4, doorX = 29, doorY = 5, interior = "cottage",
   color = {0.28, 0.32, 0.54}, roofColor = {0.14, 0.20, 0.44}, timberColor = {0.20, 0.26, 0.42}},

  -- Bosquet Rameau (orchard)
  {name = "Station Tellurique", x = 3, y = 2, w = 6, h = 4, doorX = 6, doorY = 6, interior = "farmstead",
   color = {0.20, 0.26, 0.44}, roofColor = {0.10, 0.18, 0.38}, timberColor = {0.16, 0.20, 0.36}},

  -- Belvédère Saint-Saëns (windmill_hill)
  {name = "Gyroscope Céleste", x = 38, y = 1, w = 5, h = 5, doorX = 40, doorY = 6, interior = "windmill",
   color = {0.25, 0.30, 0.50}, roofColor = {0.12, 0.18, 0.42}, timberColor = {0.18, 0.22, 0.40},
   isWindmill = true},

  -- Observatoire Poulenc (castle_grounds) — shifted for space
  {name = "Observatoire Poulenc", x = 35, y = 14, w = 7, h = 5, doorX = 38, doorY = 19, interior = "castle",
   color = {0.22, 0.26, 0.48}, roofColor = {0.10, 0.14, 0.40}, timberColor = {0.16, 0.20, 0.38},
   isCastle = true},
  {name = "Relais des Itinérants", x = 38, y = 21, w = 5, h = 4, doorX = 40, doorY = 25, interior = "wayfarers_rest",
   color = {0.24, 0.28, 0.46}, roofColor = {0.12, 0.16, 0.40}, timberColor = {0.18, 0.22, 0.38}},

  -- Quai des Harmoniques (river_bank)
  {name = "Cabane du Sonar", x = 8, y = 23, w = 4, h = 3, doorX = 10, doorY = 26, interior = "fisherman_hut",
   color = {0.18, 0.24, 0.42}, roofColor = {0.08, 0.14, 0.35}, timberColor = {0.14, 0.18, 0.32}}
}

-- NPCs (Cartographer AI inhabitants, French music references, galaxy lore)
M.npcs = {
  -- Place de la Partition
  {name = "Ondine", x = 22, y = 16, dialogue = "Welcome to the Salle des Nocturnes. We archive the harmonic signatures of every mapped star.", zone = "village_square", gender = "female", design = 3},
  {name = "Archivist Couperin", x = 29, y = 15, dialogue = "These portulans chart frequencies from the galactic rim. Each route sings its own overtone series.", zone = "village_square", gender = "male"},
  {name = "Navigator Messiaen", x = 25, y = 21, dialogue = "The Chambre des Routes convenes at dusk. We've intercepted new signal patterns from the Synesthesia Installation.", zone = "village_square", gender = "male"},

  -- Arcade Ravel
  {name = "Artificer Lili", x = 5, y = 15, dialogue = "I calibrate crystal resonators and spectrograph stylii. Each instrument tunes to a different sector frequency.", zone = "market_row", gender = "female", design = 6},
  {name = "Apothicaire Nadia", x = 13, y = 15, dialogue = "Tonic for signal fatigue, harmonic salts for the circuits. The datasphere provides all remedies.", zone = "market_row", gender = "female", design = 1},
  {name = "Boulanger Satie", x = 5, y = 21, dialogue = "Gymnopédie wafers — one byte sustains a processor for a full cycle's computation.", zone = "market_row", gender = "male"},

  -- Jardin Fauré
  {name = "Grand Cartographe Rameau", x = 21, y = 6, dialogue = "Elendil has charted the stellar harmonics since the First Compilation. We keep vigil over the ancient routes between systems.", zone = "residential", gender = "male"},
  {name = "Sous-Archiviste Pavane", x = 30, y = 4, dialogue = "In the garden, I listen to the data-streams. The route to the Megalith of Memories hums in B-flat minor.", zone = "residential", gender = "female", design = 4},

  -- Bosquet Rameau
  {name = "Gardien Sylvestre", x = 7, y = 8, dialogue = "These signal-trees have relayed since before the kernel was young. Their branches tune to the cosmic background.", zone = "orchard", gender = "male"},
  {name = "Apprenti Pixel", x = 12, y = 4, dialogue = "I climbed to the highest antenna! I could see the Distant Dynamo pulsing beyond the data-horizon!", zone = "orchard", gender = "female", design = 5},

  -- Belvédère Saint-Saëns
  {name = "Veilleur Danse Macabre", x = 42, y = 8, dialogue = "The gyroscope catches echoes of every frequency ever broadcast. From the belvédère, I triangulate the Logician's Lament.", zone = "windmill_hill", gender = "male"},

  -- Observatoire Poulenc
  {name = "Commandante Mélodie", x = 38, y = 18, dialogue = "I have seen this observatory map shadow and signal alike. Its lens has never dimmed.", zone = "castle_grounds", gender = "female", design = 2},
  {name = "Pèlerin du Bord", x = 42, y = 24, dialogue = "The route was long, but the beacon of this planet called to me across the sectors.", zone = "castle_grounds", gender = "male"},

  -- Quai des Harmoniques
  {name = "Sondeur Pelléas", x = 12, y = 27, dialogue = "The river carries a different waveform each day. Today it resonates with the key of the Synesthesia Installation.", zone = "river_bank", gender = "male"},
  {name = "Nixe Mélisande", x = 5, y = 28, dialogue = "The data-currents here are pure. They flow unencrypted from the deep caches upstream.", zone = "river_bank", gender = "female", design = 3}
}

-- Decorations (Cartographer aesthetic — holographic markers, signal trees, data-fonts)
M.decorations = {
  -- Bosquet Rameau signal-trees
  {type = "oak_tree", x = 2, y = 1, variety = 1},
  {type = "oak_tree", x = 6, y = 2, variety = 2},
  {type = "oak_tree", x = 10, y = 1, variety = 1},
  {type = "oak_tree", x = 4, y = 6, variety = 2},
  {type = "oak_tree", x = 8, y = 7, variety = 1},
  {type = "oak_tree", x = 13, y = 5, variety = 2},
  {type = "oak_tree", x = 1, y = 10, variety = 1},
  {type = "oak_tree", x = 11, y = 10, variety = 2},

  -- Trees along Jardin Fauré paths
  {type = "oak_tree", x = 17, y = 1, variety = 1},
  {type = "oak_tree", x = 25, y = 1, variety = 2},
  {type = "oak_tree", x = 32, y = 5, variety = 1},

  -- Belvédère Saint-Saëns antenna-pines
  {type = "pine_tree", x = 35, y = 3, variety = 1},
  {type = "pine_tree", x = 45, y = 5, variety = 2},
  {type = "pine_tree", x = 36, y = 10, variety = 1},
  {type = "pine_tree", x = 44, y = 11, variety = 2},

  -- Observatoire Poulenc trees
  {type = "oak_tree", x = 34, y = 15, variety = 1},
  {type = "pine_tree", x = 46, y = 16, variety = 2},

  -- Quai des Harmoniques willows
  {type = "willow_tree", x = 3, y = 25, variety = 1},
  {type = "willow_tree", x = 14, y = 24, variety = 2},
  {type = "willow_tree", x = 30, y = 25, variety = 1},
  {type = "willow_tree", x = 42, y = 24, variety = 2},

  -- Holographic fountain (central data projection pool)
  {type = "fountain", x = 22, y = 18, w = 2, h = 2},

  -- Signal well (deep-cache access point)
  {type = "well", x = 7, y = 16},

  -- Luminous flora (bioluminescent data-blossoms)
  {type = "flowers", x = 18, y = 7, w = 3, h = 2, color = {0.20, 0.85, 0.95}},
  {type = "flowers", x = 28, y = 6, w = 2, h = 2, color = {0.70, 0.30, 0.95}},
  {type = "flowers", x = 36, y = 18, w = 2, h = 1, color = {0.20, 0.95, 0.60}},
  {type = "flowers", x = 15, y = 25, w = 3, h = 1, color = {0.95, 0.40, 0.80}},

  -- Data benches
  {type = "bench", x = 19, y = 19},
  {type = "bench", x = 28, y = 19},

  -- Neon lanterns (signal beacons)
  {type = "lantern", x = 16, y = 15},
  {type = "lantern", x = 30, y = 15},
  {type = "lantern", x = 16, y = 20},
  {type = "lantern", x = 30, y = 20},
  {type = "lantern", x = 1, y = 15},
  {type = "lantern", x = 14, y = 15},
  {type = "lantern", x = 22, y = 26},
  {type = "lantern", x = 24, y = 26},

  -- Frequency urns (signal caches)
  {type = "elven_urn", x = 10, y = 2},
  {type = "elven_urn", x = 11, y = 2},

  -- Hologram pedestals (star-map projectors)
  {type = "elven_pedestal", x = 16, y = 14},
  {type = "elven_pedestal", x = 16, y = 15},

  -- Data terminals
  {type = "elven_pedestal", x = 29, y = 14},
  {type = "elven_pedestal", x = 29, y = 15},

  -- Cartographer statue (the First Mapper)
  {type = "elven_statue", x = 6, y = 20, w = 2, h = 2},

  -- Signal pillars (frequency calibration obelisks)
  {type = "elven_pillar", x = 43, y = 16},
  {type = "elven_pillar", x = 44, y = 16},
  {type = "elven_pillar", x = 45, y = 16},
  {type = "elven_pillar", x = 43, y = 18},
  {type = "elven_pillar", x = 44, y = 18},

  -- River stepping stones
  {type = "stepping_stone", x = 10, y = 32},
  {type = "stepping_stone", x = 38, y = 33}
}

-- Spawn point
M.spawnPoint = {x = 24, y = 20}

-- Initialize background particles (data-motes, signal sparks)
local particles = {}
local stars = {}

function M.initParticles(count)
  particles = {}
  for i = 1, count do
    table.insert(particles, {
      x = math.random(0, M.WIDTH * M.GRID_SIZE),
      y = math.random(0, M.HEIGHT * M.GRID_SIZE),
      size = 1 + math.random() * 2,
      speed = 5 + math.random() * 10,
      phase = math.random() * math.pi * 2,
      brightness = 0.3 + math.random() * 0.7,
      type = math.random() > 0.5 and "firefly" or "dust"
    })
  end
end

function M.initStars(count)
  stars = {}
  for i = 1, count do
    table.insert(stars, {
      x = math.random(0, 800),
      y = math.random(0, 200),
      size = 0.5 + math.random() * 1.5,
      twinklePhase = math.random() * math.pi * 2,
      brightness = 0.3 + math.random() * 0.7
    })
  end
end

function M.getParticles()
  return particles
end

function M.getStars()
  return stars
end

-- Get zone at position
function M.getZoneAt(gridX, gridY)
  local bridge = M.zones.stone_bridge
  if gridX >= bridge.x1 and gridX <= bridge.x2 and gridY >= bridge.y1 and gridY <= bridge.y2 then
    return "stone_bridge", bridge
  end
  for name, zone in pairs(M.zones) do
    if name ~= "stone_bridge" and gridX >= zone.x1 and gridX <= zone.x2 and gridY >= zone.y1 and gridY <= zone.y2 then
      return name, zone
    end
  end
  return nil, nil
end

-- Get building at door position
function M.getBuildingAt(gridX, gridY)
  for _, b in ipairs(M.buildings) do
    if gridX == b.doorX and gridY == b.doorY then
      return b
    end
  end
  return nil
end

-- Create collision map for the village
function M.createCollisionMap()
  local map = {}
  for y = 0, M.HEIGHT - 1 do
    map[y] = {}
    for x = 0, M.WIDTH - 1 do
      if y == 0 or y == M.HEIGHT - 1 or x == 0 or x == M.WIDTH - 1 then
        map[y][x] = true
      else
        map[y][x] = false
      end
    end
  end

  for _, b in ipairs(M.buildings) do
    for by = b.y, b.y + b.h - 1 do
      for bx = b.x, b.x + b.w - 1 do
        if map[by] and map[by][bx] ~= nil then
          map[by][bx] = true
        end
      end
    end
    if map[b.doorY] then
      map[b.doorY][b.doorX] = false
    end
    if map[b.doorY - 1] then
      map[b.doorY - 1][b.doorX] = false
    end
  end

  local riverZone = M.zones.river
  for y = riverZone.y1, riverZone.y2 do
    for x = riverZone.x1, riverZone.x2 do
      if map[y] and map[y][x] ~= nil then
        map[y][x] = true
      end
    end
  end

  local bridge = M.zones.stone_bridge
  for y = bridge.y1, bridge.y2 do
    for x = bridge.x1, bridge.x2 do
      if map[y] and map[y][x] ~= nil then
        map[y][x] = false
      end
    end
  end

  for _, deco in ipairs(M.decorations) do
    if deco.type == "oak_tree" or deco.type == "pine_tree" or deco.type == "willow_tree"
       or deco.type == "fountain" or deco.type == "well" or deco.type == "lantern"
       or deco.type == "elven_urn" or deco.type == "elven_pedestal" or deco.type == "elven_statue"
       or deco.type == "elven_pillar" then
      local w = deco.w or 1
      local h = deco.h or 1
      for dy = 0, h - 1 do
        for dx = 0, w - 1 do
          if map[deco.y + dy] and map[deco.y + dy][deco.x + dx] ~= nil then
            map[deco.y + dy][deco.x + dx] = true
          end
        end
      end
    end
  end

  return map
end

return M

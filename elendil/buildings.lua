-- elendil/buildings.lua
-- Interior layouts for buildings in Elendil
-- Cartographer planet: deep blue halls, holographic floors, neon-lit data archives

local M = {}

M.GRID_SIZE = 32

M.interiors = {
  -- ═══════════════════════════════════════
  -- PLACE DE LA PARTITION
  -- ═══════════════════════════════════════
  tavern = {
    name = "Salle des Nocturnes",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Shop", x = 5, y = 4, game = "shop", color = {0.2, 0.5, 0.9}}
    },
    npcs = {
      {name = "Barman Chopin", x = 5, y = 3, dialogue = "Filtered data-wine, spectral tea, or resonance mead? All who seek rest in the datasphere are welcome.", gender = "male"},
      {name = "Chanteuse Syrinx", x = 12, y = 5, dialogue = "♪ Prelude to the Afternoon of a Faun, third movement, transposed to the key of starlight... ♪", gender = "female", design = 1},
      {name = "Navigateur Boléro", x = 14, y = 8, dialogue = "I have traced the signal paths to the Distant Dynamo and back. The static fades — but never fully clears.", gender = "male"},
      {name = "Hôtesse Arabesque", x = 8, y = 7, dialogue = "The processors compile data-cakes and frequency biscuits tonight. Your buffers shall not go empty.", gender = "female", design = 5}
    }
  },
  general_store = {
    name = "Comptoir des Portulans",
    width = 14, height = 12,
    exitX = 7, exitY = 11,
    portals = {
      {name = "Shop", x = 7, y = 4, game = "shop", color = {0.3, 0.4, 0.8}}
    },
    npcs = {
      {name = "Marchand Dukas", x = 5, y = 5, dialogue = "Spectral cloaks, signal-glass phials, charts of unmapped sectors... I keep data from every Compilation.", gender = "male"},
      {name = "Chrome Fox", x = 11, y = 8, dialogue = "...the fox watches you with luminous, calculating eyes...", gender = "male"}
    }
  },
  town_hall = {
    name = "Chambre des Routes",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Asteroids", x = 5, y = 5, game = "asteroids", color = {0.1, 0.4, 0.9}},
      {name = "StarFox", x = 9, y = 5, game = "starfox", color = {0.2, 0.3, 1}},
      {name = "Planet Map", x = 13, y = 5, game = "planetmap", color = {0.4, 0.2, 0.8}}
    },
    npcs = {
      {name = "Directeur Rameau", x = 9, y = 3, dialogue = "Elendil is the last charting station before the galactic edge. From this chamber, all routes among the stars lie open.", gender = "male"},
      {name = "Pilote Gaspard", x = 14, y = 8, dialogue = "I have mapped the signal-paths for cycles uncounted. The Planet Map holds routes between all known systems.", gender = "female", design = 4}
    }
  },

  -- ═══════════════════════════════════════
  -- ARCADE RAVEL
  -- ═══════════════════════════════════════
  blacksmith = {
    name = "Forge Spectrale",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Shop", x = 7, y = 3, game = "shop", color = {0.4, 0.2, 0.9}}
    },
    npcs = {
      {name = "Forgeronne Spectrale", x = 5, y = 4, dialogue = "In the tradition of the First Compilers, we forge with crystal and data-light. The old algorithms endure.", gender = "female", design = 6},
      {name = "Apprenti Fréquence", x = 10, y = 6, dialogue = "The master says I calibrate too softly! But harmonic instrument-craft requires precision, not force.", gender = "male"}
    }
  },
  apothecary = {
    name = "Pharmacie des Fréquences",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 6, y = 3, game = "shop", color = {0.1, 0.6, 0.5}}
    },
    npcs = {
      {name = "Pharmacienne Nadia", x = 4, y = 4, dialogue = "Bandwidth salts for lag, harmonic tonic for the spirit, cache-clear for overload. The datasphere provides all remedies.", gender = "female", design = 1},
      {name = "Curious Probe", x = 9, y = 7, dialogue = "...the probe tilts its antenna, then knocks a crystal vial from the shelf...", gender = "male"}
    }
  },
  bakery = {
    name = "Boulangerie Gymnopédie",
    width = 10, height = 8,
    exitX = 5, exitY = 7,
    npcs = {
      {name = "Pâtissier Satie", x = 5, y = 3, dialogue = "The secret is in the data-grain from the deep caches, compiled by the kernel itself. One byte sustains a cycle's processing.", gender = "male"},
      {name = "Sous-Chef Tempo", x = 8, y = 5, dialogue = "We compile before the first signal fades. The aroma of gymnopédie wafers drifts through the whole sector.", gender = "female", design = 3}
    }
  },
  weaver = {
    name = "Atelier des Fugues",
    width = 10, height = 8,
    exitX = 5, exitY = 7,
    npcs = {
      {name = "Tisseuse Contrepoint", x = 5, y = 3, dialogue = "I weave data-tapestries that map the routes of Compilations. This one charts the founding of the cartographic order.", gender = "female", design = 1},
      {name = "Coloriste Spectre", x = 8, y = 5, dialogue = "Cyan for signal, violet for deep-cache, magenta for encrypted channels. All from the spectral gardens.", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- JARDIN FAURÉ
  -- ═══════════════════════════════════════
  elder_house = {
    name = "Archives du Ciel",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Archiviste-en-Chef Debussy", x = 8, y = 4, dialogue = "The stars broadcast to those who decode. Elendil was compiled where three data-streams of the First Network converge.", gender = "male"},
      {name = "Sous-Archiviste Prélude", x = 12, y = 7, dialogue = "The archives speak of ancient signal-gates forged in the First Compilation. This planet sits upon one.", gender = "female", design = 4}
    }
  },
  cottage = {
    name = "Pavillon Clair de Lune",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Gardienne Pavane", x = 5, y = 5, dialogue = "It is peaceful here. The young processes play among the signal-trees while I tend the luminous flora.", gender = "female", design = 3},
      {name = "Petit Algorithme", x = 9, y = 6, dialogue = "Do you want to see my toy satellite? It soars up to the data-horizon! Whoooosh!", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- BOSQUET RAMEAU
  -- ═══════════════════════════════════════
  farmstead = {
    name = "Station Tellurique",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Ingénieur Tellurique", x = 6, y = 4, dialogue = "The harvest of the signal-grove is our sustenance. We cultivate enough bandwidth to nourish the network and trade with sector-merchants.", gender = "male"},
      {name = "Jardinier de Données", x = 12, y = 6, dialogue = "I tune the signal-trees at boot and the arrays by starlight. The network asks only gentle calibration.", gender = "female", design = 6},
      {name = "Jeune Éclaireur", x = 8, y = 9, dialogue = "The subroutines are restless tonight. They always detect when interference draws near.", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- BELVÉDÈRE SAINT-SAËNS
  -- ═══════════════════════════════════════
  windmill = {
    name = "Gyroscope Céleste",
    width = 12, height = 14,
    exitX = 6, exitY = 13,
    npcs = {
      {name = "Veilleur Saint-Saëns", x = 6, y = 4, dialogue = "From this altitude you can scan the data-mountains and the river far below. On clear cycles, the Distant Dynamo blazes on the horizon.", gender = "male"},
      {name = "Jeune Cartographe", x = 9, y = 8, dialogue = "The instructor says the gyroscope catches echoes from the Logician's Lament. I like to decode the music of the stars.", gender = "female", design = 5}
    }
  },

  -- ═══════════════════════════════════════
  -- OBSERVATOIRE POULENC
  -- ═══════════════════════════════════════
  castle = {
    name = "Observatoire Poulenc",
    width = 20, height = 16,
    exitX = 10, exitY = 15,
    portals = {
      {name = "Ship Selection", x = 10, y = 5, game = "hangar", color = {0.3, 0.3, 0.9}},
      {name = "Exchange", x = 15, y = 5, game = "casino_exchange", color = {0.2, 0.9, 0.9}}
    },
    npcs = {
      {name = "Directrice Poulenc", x = 10, y = 3, dialogue = "This observatory has charted the datasphere since the Second Compilation. From its apex, you may read the signal-paths themselves.", gender = "female", design = 2},
      {name = "Sentinelle du Spectre", x = 6, y = 8, dialogue = "The archive holds instruments from every Compilation — Rameau oscillators, Fauré resonators, and stranger devices from beyond the edges of the network.", gender = "male"},
      {name = "Maître Cartographe", x = 14, y = 10, dialogue = "I chart the Four Corners from the highest chamber. The Logician's Lament, the Distant Dynamo, the Megalith of Memories, and the Synesthesia Installation — all mapped in harmonic light.", gender = "female", design = 4}
    }
  },
  wayfarers_rest = {
    name = "Relais des Itinérants",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Gardienne Berceuse", x = 5, y = 3, dialogue = "We have hosted navigators from a hundred sectors. The sleep-buffers are deep and the power supply ever stable.", gender = "female", design = 3},
      {name = "Itinérant Errant", x = 10, y = 5, dialogue = "I seek the lost relay beyond the data-mountains. Perhaps this planet holds a forgotten encryption key.", gender = "male"},
      {name = "Pèlerin Lasse", x = 8, y = 7, dialogue = "The route has been long and corrupted. But Elendil... this place feels like a dream of home-directory.", gender = "female", design = 6}
    }
  },

  -- ═══════════════════════════════════════
  -- QUAI DES HARMONIQUES
  -- ═══════════════════════════════════════
  fisherman_hut = {
    name = "Cabane du Sonar",
    width = 10, height = 8,
    exitX = 5, exitY = 7,
    npcs = {
      {name = "Sondeur Pelléas", x = 5, y = 3, dialogue = "The Fleuve Debussy transmits and the Fleuve Debussy archives. Today it yields silver data-packets blessed by the deep cache.", gender = "male"},
      {name = "Esprit du Flux", x = 8, y = 5, dialogue = "The current whispers of compilations past... the purging of corrupt sectors, the symphonies of the First Network... if you know how to decode.", gender = "female", design = 1}
    }
  }
}

-- Create collision map for an interior
function M.createInteriorCollisionMap(interiorId)
  local interior = M.interiors[interiorId]
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

-- Get interior definition
function M.getInterior(interiorId)
  return M.interiors[interiorId]
end

-- Check if at exit
function M.isAtExit(gridX, gridY, interiorId)
  local interior = M.interiors[interiorId]
  if interior then
    return gridX == interior.exitX and gridY == interior.exitY
  end
  return false
end

return M

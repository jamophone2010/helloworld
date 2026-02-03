local M = {}

M.CORNERIA = {
  {time = 2, type = "wave", formation = "v", x = 400, count = 5},
  {time = 8, type = "wave", formation = "line", x = 400, count = 4},
  {time = 15, type = "wave", formation = "v", x = 300, count = 5},
  {time = 20, type = "wave", formation = "v", x = 500, count = 5},
  {time = 25, type = "callout", message = "triggerEnemyWarning"},
  {time = 30, type = "turret", x = 200},
  {time = 32, type = "turret", x = 600},
  {time = 35, type = "wave", formation = "line", x = 400, count = 6},
  {time = 40, type = "turret", x = 400},
  {time = 45, type = "callout", message = "triggerBossWarning"},
  {time = 47, type = "midboss"},
  {time = 65, type = "wave", formation = "v", x = 400, count = 7},
  {time = 70, type = "turret", x = 150},
  {time = 70, type = "turret", x = 650},
  {time = 75, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 80, type = "callout", message = "triggerCover"},
  {time = 85, type = "wave", formation = "v", x = 300, count = 5},
  {time = 85, type = "wave", formation = "v", x = 500, count = 5},
  {time = 95, type = "callout", message = "triggerBossWarning"},
  {time = 100, type = "finalboss"}
}

M.AREA6 = {
  -- Intense opening - wave after wave
  {time = 2, type = "wave", formation = "v", x = 400, count = 7},
  {time = 5, type = "wave", formation = "line", x = 400, count = 6},
  {time = 8, type = "capitalship", x = 400},
  {time = 9, type = "wave", formation = "v", x = 300, count = 5},
  {time = 12, type = "wave", formation = "v", x = 500, count = 5},
  {time = 15, type = "callout", message = "triggerEnemyWarning"},
  {time = 16, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 19, type = "turret", x = 150},
  {time = 19, type = "turret", x = 650},
  {time = 22, type = "wave", formation = "line", x = 400, count = 7},

  -- Second capital ship wave
  {time = 25, type = "capitalship", x = 300},
  {time = 26, type = "wave", formation = "v", x = 500, count = 6},
  {time = 29, type = "wave", formation = "v", x = 200, count = 5},
  {time = 29, type = "wave", formation = "v", x = 600, count = 5},
  {time = 32, type = "turret", x = 400},
  {time = 35, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 38, type = "callout", message = "triggerCover"},
  {time = 40, type = "wave", formation = "line", x = 300, count = 6},
  {time = 40, type = "wave", formation = "line", x = 500, count = 6},

  -- Third capital ship - flanking
  {time = 45, type = "capitalship", x = 200},
  {time = 46, type = "capitalship", x = 600},
  {time = 48, type = "wave", formation = "v", x = 400, count = 8},
  {time = 51, type = "turret", x = 200},
  {time = 51, type = "turret", x = 400},
  {time = 51, type = "turret", x = 600},
  {time = 54, type = "wave", formation = "wave", x = 400, count = 9},
  {time = 57, type = "wave", formation = "v", x = 300, count = 6},
  {time = 57, type = "wave", formation = "v", x = 500, count = 6},

  -- Final push before boss
  {time = 60, type = "callout", message = "triggerEnemyWarning"},
  {time = 62, type = "capitalship", x = 400},
  {time = 63, type = "wave", formation = "line", x = 400, count = 8},
  {time = 66, type = "wave", formation = "v", x = 400, count = 7},
  {time = 69, type = "wave", formation = "wave", x = 400, count = 10},
  {time = 72, type = "wave", formation = "v", x = 250, count = 5},
  {time = 72, type = "wave", formation = "v", x = 550, count = 5},

  -- Area 6 Boss
  {time = 75, type = "callout", message = "triggerBossWarning"},
  {time = 80, type = "area6boss"}
}

M.MACBETH = {
  -- 7 groups of enemies in different formations
  {time = 2, type = "wave", formation = "v", x = 350, count = 6},
  {time = 8, type = "wave", formation = "line", x = 400, count = 7},
  {time = 14, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 20, type = "callout", message = "triggerRivalWarning"},
  {time = 22, type = "rival", hp = 35, variant = "teleport"},
  {time = 28, type = "wave", formation = "v", x = 300, count = 5},
  {time = 34, type = "wave", formation = "v", x = 500, count = 5},
  {time = 40, type = "wave", formation = "line", x = 400, count = 6},
  {time = 50, type = "wave", formation = "v", x = 400, count = 7},
  {time = 58, type = "callout", message = "triggerBossWarning"},
  {time = 60, type = "finalboss"}
}

M.KATINA = {
  -- Bill's squadron arrives
  {time = 0, type = "callout", message = "triggerAlliesInbound"},
  {time = 2, type = "allies"},

  -- Mothership descends
  {time = 5, type = "mothership", x = 400},

  -- Initial enemy waves
  {time = 8, type = "wave", formation = "v", x = 400, count = 5},
  {time = 12, type = "wave", formation = "line", x = 300, count = 4},
  {time = 12, type = "wave", formation = "line", x = 500, count = 4},

  -- Intensifying
  {time = 18, type = "wave", formation = "v", x = 350, count = 6},
  {time = 22, type = "wave", formation = "v", x = 450, count = 6},
  {time = 25, type = "callout", message = "triggerHelp"},

  -- Heavy assault
  {time = 28, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 33, type = "wave", formation = "v", x = 300, count = 5},
  {time = 33, type = "wave", formation = "v", x = 500, count = 5},

  -- Mid-battle callout
  {time = 38, type = "callout", message = "triggerMothershipWarning"},
  {time = 40, type = "wave", formation = "line", x = 400, count = 6},

  -- Final push
  {time = 45, type = "wave", formation = "v", x = 400, count = 7},
  {time = 50, type = "wave", formation = "wave", x = 400, count = 10},
  {time = 55, type = "wave", formation = "v", x = 300, count = 5},
  {time = 55, type = "wave", formation = "v", x = 500, count = 5},

  -- Continuous waves (mothership spawns fighters throughout)
  {time = 60, type = "callout", message = "triggerCover"},
  {time = 62, type = "wave", formation = "line", x = 400, count = 8},
  {time = 68, type = "wave", formation = "v", x = 400, count = 6}
}

M.METEO = {
  -- Opening - asteroids and first portal
  {time = 0, type = "callout", message = "triggerWarpRings"},
  {time = 3, type = "wave", formation = "line", x = 400, count = 4},
  {time = 5, type = "portal", x = 400},  -- Portal 1

  {time = 8, type = "wave", formation = "v", x = 300, count = 5},
  {time = 10, type = "wave", formation = "v", x = 500, count = 5},
  {time = 13, type = "portal", x = 250},  -- Portal 2

  {time = 16, type = "wave", formation = "wave", x = 400, count = 6},
  {time = 20, type = "capitalship", x = 400},
  {time = 22, type = "portal", x = 550},  -- Portal 3

  -- Mid-section intensifies
  {time = 25, type = "wave", formation = "v", x = 400, count = 7},
  {time = 28, type = "wave", formation = "line", x = 300, count = 5},
  {time = 28, type = "wave", formation = "line", x = 500, count = 5},
  {time = 32, type = "portal", x = 400},  -- Portal 4

  {time = 35, type = "wave", formation = "v", x = 350, count = 6},
  {time = 38, type = "wave", formation = "v", x = 450, count = 6},
  {time = 40, type = "capitalship", x = 250},
  {time = 40, type = "capitalship", x = 550},
  {time = 44, type = "portal", x = 300},  -- Portal 5

  -- Final stretch
  {time = 48, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 52, type = "wave", formation = "v", x = 400, count = 8},
  {time = 55, type = "portal", x = 500},  -- Portal 6

  {time = 58, type = "wave", formation = "line", x = 400, count = 6},
  {time = 60, type = "wave", formation = "v", x = 300, count = 5},
  {time = 60, type = "wave", formation = "v", x = 500, count = 5},
  {time = 64, type = "portal", x = 400},  -- Portal 7 (final)

  -- Normal ending - boss if portals not collected
  {time = 70, type = "callout", message = "triggerBossWarning"},
  {time = 75, type = "midboss"}
}

M.BOLSE = {
  -- Opening fighter waves
  {time = 2, type = "wave", formation = "v", x = 400, count = 5},
  {time = 6, type = "wave", formation = "line", x = 400, count = 4},
  {time = 10, type = "wave", formation = "v", x = 300, count = 5},
  {time = 10, type = "wave", formation = "v", x = 500, count = 5},

  -- Station appears
  {time = 15, type = "callout", message = "triggerBossWarning"},
  {time = 18, type = "bolsestation"},

  -- Continuous fighter support while station active
  {time = 25, type = "wave", formation = "line", x = 400, count = 4},
  {time = 32, type = "wave", formation = "v", x = 300, count = 4},
  {time = 32, type = "wave", formation = "v", x = 500, count = 4},
  {time = 40, type = "wave", formation = "wave", x = 400, count = 6},

  -- Rival appears mid-fight
  {time = 45, type = "callout", message = "triggerRivalWarning"},
  {time = 48, type = "rival"},

  -- More waves
  {time = 55, type = "wave", formation = "v", x = 400, count = 5},
  {time = 62, type = "wave", formation = "line", x = 300, count = 4},
  {time = 62, type = "wave", formation = "line", x = 500, count = 4},
  {time = 70, type = "wave", formation = "wave", x = 400, count = 6},
  {time = 78, type = "wave", formation = "v", x = 400, count = 5},
  {time = 85, type = "wave", formation = "v", x = 300, count = 4},
  {time = 85, type = "wave", formation = "v", x = 500, count = 4}
}

M.SECTORX = {
  -- Eerie opening - enemies emerge from darkness
  {time = 3, type = "wave", formation = "line", x = 400, count = 4},
  {time = 8, type = "wave", formation = "v", x = 300, count = 5},
  {time = 12, type = "wave", formation = "v", x = 500, count = 5},
  {time = 18, type = "wave", formation = "wave", x = 400, count = 6},
  {time = 25, type = "turret", x = 200},
  {time = 25, type = "turret", x = 600},
  {time = 30, type = "wave", formation = "line", x = 400, count = 5},
  {time = 35, type = "wave", formation = "v", x = 350, count = 6},
  {time = 35, type = "wave", formation = "v", x = 450, count = 6},
  {time = 42, type = "capitalship", x = 400},
  {time = 48, type = "wave", formation = "wave", x = 400, count = 7},
  {time = 55, type = "wave", formation = "v", x = 300, count = 5},
  {time = 55, type = "wave", formation = "v", x = 500, count = 5},
  {time = 62, type = "turret", x = 300},
  {time = 62, type = "turret", x = 500},
  {time = 68, type = "wave", formation = "line", x = 400, count = 6},
  {time = 75, type = "capitalship", x = 250},
  {time = 75, type = "capitalship", x = 550},
  {time = 82, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 90, type = "callout", message = "triggerBossWarning"},
  {time = 95, type = "midboss"}
}

M.VENOM = {
  -- Phase 1: Opening waves
  {time = 2, type = "wave", formation = "v", x = 400, count = 6},
  {time = 6, type = "wave", formation = "line", x = 400, count = 5},
  {time = 10, type = "wave", formation = "v", x = 300, count = 5},
  {time = 10, type = "wave", formation = "v", x = 500, count = 5},
  {time = 15, type = "capitalship", x = 400},
  {time = 18, type = "wave", formation = "wave", x = 400, count = 7},

  -- First Rival Encounter
  {time = 22, type = "callout", message = "triggerRivalWarning"},
  {time = 25, type = "rival", hp = 40},

  -- Phase 2: Waves during/after rival
  {time = 35, type = "wave", formation = "v", x = 400, count = 6},
  {time = 40, type = "wave", formation = "line", x = 300, count = 4},
  {time = 40, type = "wave", formation = "line", x = 500, count = 4},
  {time = 45, type = "capitalship", x = 250},
  {time = 45, type = "capitalship", x = 550},
  {time = 50, type = "wave", formation = "wave", x = 400, count = 8},

  -- Second Rival Encounter (boosted HP)
  {time = 55, type = "callout", message = "triggerRivalReturn"},
  {time = 58, type = "rival", hp = 50},

  -- Phase 3: Pre-maze waves
  {time = 68, type = "wave", formation = "v", x = 400, count = 7},
  {time = 72, type = "wave", formation = "line", x = 400, count = 6},
  {time = 75, type = "turret", x = 200},
  {time = 75, type = "turret", x = 600},

  -- Maze Section
  {time = 80, type = "callout", message = "triggerMazeWarning"},
  {time = 82, type = "mazestart"},
  {time = 85, type = "mazewall", pattern = "center"},
  {time = 88, type = "mazewall", pattern = "left"},
  {time = 91, type = "mazewall", pattern = "right"},
  {time = 94, type = "mazewall", pattern = "zigzag"},
  {time = 97, type = "mazewall", pattern = "narrow"},
  {time = 100, type = "mazewall", pattern = "center"},
  {time = 103, type = "mazewall", pattern = "zigzag"},
  {time = 106, type = "mazewall", pattern = "left"},
  {time = 109, type = "mazeend"},

  -- Final Boss
  {time = 112, type = "callout", message = "triggerVenomBossWarning"},
  {time = 115, type = "venomboss"}
}

function M.getWaves(levelId)
  if levelId == 2 then
    return M.METEO
  elseif levelId == 5 then
    return M.KATINA
  elseif levelId == 8 then
    return M.SECTORX
  elseif levelId == 10 then
    return M.MACBETH
  elseif levelId == 13 then
    return M.BOLSE
  elseif levelId == 14 then
    return M.AREA6
  elseif levelId == 18 then
    return M.VENOM
  end
  return M.CORNERIA
end

function M.getName(levelId)
  local names = {
    [1] = "CORNERIA",
    [2] = "METEO",
    [3] = "SECTOR Y",
    [4] = "FORTUNA",
    [5] = "KATINA",
    [6] = "AQUAS",
    [7] = "SOLAR",
    [8] = "SECTOR X",
    [9] = "ZONESS",
    [10] = "MACBETH",
    [11] = "TITANIA",
    [12] = "SECTOR Z",
    [13] = "BOLSE",
    [14] = "AREA 6",
    [15] = "FICHINA",
    [16] = "OUTER",
    [17] = "VENOM II",
    [18] = "VENOM"
  }
  return names[levelId] or "CORNERIA"
end

return M

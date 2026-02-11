local M = {}

M.CORNERIA = {
  {time = 2, type = "wave", formation = "v", x = 683, count = 5},
  {time = 8, type = "wave", formation = "line", x = 683, count = 4},
  {time = 15, type = "wave", formation = "v", x = 512, count = 5},
  {time = 20, type = "wave", formation = "v", x = 854, count = 5},
  {time = 25, type = "callout", message = "triggerEnemyWarning"},
  {time = 30, type = "turret", x = 341},
  {time = 32, type = "turret", x = 1025},
  {time = 35, type = "wave", formation = "line", x = 683, count = 6},
  {time = 40, type = "turret", x = 683},
  {time = 45, type = "callout", message = "triggerBossWarning"},
  {time = 47, type = "midboss"},
  {time = 65, type = "wave", formation = "v", x = 683, count = 7},
  {time = 70, type = "turret", x = 256},
  {time = 70, type = "turret", x = 1110},
  {time = 75, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 80, type = "callout", message = "triggerCover"},
  {time = 85, type = "wave", formation = "v", x = 512, count = 5},
  {time = 85, type = "wave", formation = "v", x = 854, count = 5},
  {time = 95, type = "callout", message = "triggerBossWarning"},
  {time = 100, type = "finalboss"}
}

M.AREA6 = {
  -- Intense opening - wave after wave
  {time = 2, type = "wave", formation = "v", x = 683, count = 7},
  {time = 5, type = "wave", formation = "line", x = 683, count = 6},
  {time = 8, type = "capitalship", x = 683},
  {time = 9, type = "wave", formation = "v", x = 512, count = 5},
  {time = 12, type = "wave", formation = "v", x = 854, count = 5},
  {time = 15, type = "callout", message = "triggerEnemyWarning"},
  {time = 16, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 19, type = "turret", x = 256},
  {time = 19, type = "turret", x = 1110},
  {time = 22, type = "wave", formation = "line", x = 683, count = 7},

  -- Second capital ship wave
  {time = 25, type = "capitalship", x = 512},
  {time = 26, type = "wave", formation = "v", x = 854, count = 6},
  {time = 29, type = "wave", formation = "v", x = 341, count = 5},
  {time = 29, type = "wave", formation = "v", x = 1025, count = 5},
  {time = 32, type = "turret", x = 683},
  {time = 35, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 38, type = "callout", message = "triggerCover"},
  {time = 40, type = "wave", formation = "line", x = 512, count = 6},
  {time = 40, type = "wave", formation = "line", x = 854, count = 6},

  -- Third capital ship - flanking
  {time = 45, type = "capitalship", x = 341},
  {time = 46, type = "capitalship", x = 1025},
  {time = 48, type = "wave", formation = "v", x = 683, count = 8},
  {time = 51, type = "turret", x = 341},
  {time = 51, type = "turret", x = 683},
  {time = 51, type = "turret", x = 1025},
  {time = 54, type = "wave", formation = "wave", x = 683, count = 9},
  {time = 57, type = "wave", formation = "v", x = 512, count = 6},
  {time = 57, type = "wave", formation = "v", x = 854, count = 6},

  -- Final push before boss
  {time = 60, type = "callout", message = "triggerEnemyWarning"},
  {time = 62, type = "capitalship", x = 683},
  {time = 63, type = "wave", formation = "line", x = 683, count = 8},
  {time = 66, type = "wave", formation = "v", x = 683, count = 7},
  {time = 69, type = "wave", formation = "wave", x = 683, count = 10},
  {time = 72, type = "wave", formation = "v", x = 427, count = 5},
  {time = 72, type = "wave", formation = "v", x = 940, count = 5},

  -- Area 6 Boss
  {time = 75, type = "callout", message = "triggerBossWarning"},
  {time = 80, type = "area6boss"}
}

M.MACBETH = {
  -- 7 groups of enemies in different formations
  {time = 2, type = "wave", formation = "v", x = 598, count = 6},
  {time = 8, type = "wave", formation = "line", x = 683, count = 7},
  {time = 14, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 20, type = "callout", message = "triggerRivalWarning"},
  {time = 22, type = "rival", hp = 35, variant = "teleport"},
  {time = 28, type = "wave", formation = "v", x = 512, count = 5},
  {time = 34, type = "wave", formation = "v", x = 854, count = 5},
  {time = 40, type = "wave", formation = "line", x = 683, count = 6},
  {time = 50, type = "wave", formation = "v", x = 683, count = 7},
  {time = 58, type = "callout", message = "triggerBossWarning"},
  {time = 60, type = "finalboss"}
}

M.SECTORY = {
  -- Sector Y: Continuous waves of 10 enemies in a line every 5 seconds
  -- This level has infinite special attacks enabled
  {time = 2, type = "wave", formation = "line", x = 683, count = 10},
  {time = 7, type = "wave", formation = "line", x = 683, count = 10},
  {time = 12, type = "wave", formation = "line", x = 683, count = 10},
  {time = 17, type = "wave", formation = "line", x = 683, count = 10},
  {time = 22, type = "wave", formation = "line", x = 683, count = 10},
  {time = 27, type = "wave", formation = "line", x = 683, count = 10},
  {time = 32, type = "wave", formation = "line", x = 683, count = 10},
  {time = 37, type = "wave", formation = "line", x = 683, count = 10},
  {time = 42, type = "wave", formation = "line", x = 683, count = 10},
  {time = 47, type = "wave", formation = "line", x = 683, count = 10},
  {time = 52, type = "wave", formation = "line", x = 683, count = 10},
  {time = 57, type = "wave", formation = "line", x = 683, count = 10},
  {time = 62, type = "wave", formation = "line", x = 683, count = 10},
  {time = 67, type = "wave", formation = "line", x = 683, count = 10},
  {time = 72, type = "wave", formation = "line", x = 683, count = 10},
  {time = 77, type = "wave", formation = "line", x = 683, count = 10},
  {time = 82, type = "callout", message = "triggerBossWarning"},
  {time = 87, type = "finalboss"}
}

M.KATINA = {
  -- Bill's squadron arrives
  {time = 0, type = "callout", message = "triggerAlliesInbound"},
  {time = 2, type = "allies"},

  -- Mothership descends
  {time = 5, type = "mothership", x = 683},

  -- Initial enemy waves
  {time = 8, type = "wave", formation = "v", x = 683, count = 5},
  {time = 12, type = "wave", formation = "line", x = 512, count = 4},
  {time = 12, type = "wave", formation = "line", x = 854, count = 4},

  -- Intensifying
  {time = 18, type = "wave", formation = "v", x = 598, count = 6},
  {time = 22, type = "wave", formation = "v", x = 769, count = 6},
  {time = 25, type = "callout", message = "triggerHelp"},

  -- Heavy assault
  {time = 28, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 33, type = "wave", formation = "v", x = 512, count = 5},
  {time = 33, type = "wave", formation = "v", x = 854, count = 5},

  -- Mid-battle callout
  {time = 38, type = "callout", message = "triggerMothershipWarning"},
  {time = 40, type = "wave", formation = "line", x = 683, count = 6},

  -- Final push
  {time = 45, type = "wave", formation = "v", x = 683, count = 7},
  {time = 50, type = "wave", formation = "wave", x = 683, count = 10},
  {time = 55, type = "wave", formation = "v", x = 512, count = 5},
  {time = 55, type = "wave", formation = "v", x = 854, count = 5},

  -- Continuous waves (mothership spawns fighters throughout)
  {time = 60, type = "callout", message = "triggerCover"},
  {time = 62, type = "wave", formation = "line", x = 683, count = 8},
  {time = 68, type = "wave", formation = "v", x = 683, count = 6}
}

M.METEO = {
  -- Opening - asteroids and first portal
  {time = 0, type = "callout", message = "triggerWarpRings"},
  {time = 3, type = "wave", formation = "line", x = 683, count = 4},
  {time = 5, type = "portal", x = 683},  -- Portal 1

  {time = 8, type = "wave", formation = "v", x = 512, count = 5},
  {time = 10, type = "wave", formation = "v", x = 854, count = 5},
  {time = 13, type = "portal", x = 427},  -- Portal 2

  {time = 16, type = "wave", formation = "wave", x = 683, count = 6},
  {time = 20, type = "capitalship", x = 683},
  {time = 22, type = "portal", x = 940},  -- Portal 3

  -- Mid-section intensifies
  {time = 25, type = "wave", formation = "v", x = 683, count = 7},
  {time = 28, type = "wave", formation = "line", x = 512, count = 5},
  {time = 28, type = "wave", formation = "line", x = 854, count = 5},
  {time = 32, type = "portal", x = 683},  -- Portal 4

  {time = 35, type = "wave", formation = "v", x = 598, count = 6},
  {time = 38, type = "wave", formation = "v", x = 769, count = 6},
  {time = 40, type = "capitalship", x = 427},
  {time = 40, type = "capitalship", x = 940},
  {time = 44, type = "portal", x = 512},  -- Portal 5

  -- Final stretch
  {time = 48, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 52, type = "wave", formation = "v", x = 683, count = 8},
  {time = 55, type = "portal", x = 854},  -- Portal 6

  {time = 58, type = "wave", formation = "line", x = 683, count = 6},
  {time = 60, type = "wave", formation = "v", x = 512, count = 5},
  {time = 60, type = "wave", formation = "v", x = 854, count = 5},
  {time = 64, type = "portal", x = 683},  -- Portal 7 (final)

  -- Normal ending - boss if portals not collected
  {time = 70, type = "callout", message = "triggerBossWarning"},
  {time = 75, type = "midboss"}
}

M.BOLSE = {
  -- Opening fighter waves
  {time = 2, type = "wave", formation = "v", x = 683, count = 5},
  {time = 6, type = "wave", formation = "line", x = 683, count = 4},
  {time = 10, type = "wave", formation = "v", x = 512, count = 5},
  {time = 10, type = "wave", formation = "v", x = 854, count = 5},

  -- Station appears
  {time = 15, type = "callout", message = "triggerBossWarning"},
  {time = 18, type = "bolsestation"},

  -- Continuous fighter support while station active
  {time = 25, type = "wave", formation = "line", x = 683, count = 4},
  {time = 32, type = "wave", formation = "v", x = 512, count = 4},
  {time = 32, type = "wave", formation = "v", x = 854, count = 4},
  {time = 40, type = "wave", formation = "wave", x = 683, count = 6},

  -- Rival appears mid-fight
  {time = 45, type = "callout", message = "triggerRivalWarning"},
  {time = 48, type = "rival"},

  -- More waves
  {time = 55, type = "wave", formation = "v", x = 683, count = 5},
  {time = 62, type = "wave", formation = "line", x = 512, count = 4},
  {time = 62, type = "wave", formation = "line", x = 854, count = 4},
  {time = 70, type = "wave", formation = "wave", x = 683, count = 6},
  {time = 78, type = "wave", formation = "v", x = 683, count = 5},
  {time = 85, type = "wave", formation = "v", x = 512, count = 4},
  {time = 85, type = "wave", formation = "v", x = 854, count = 4}
}

M.SECTORX = {
  -- Eerie opening - enemies emerge from darkness
  {time = 3, type = "wave", formation = "line", x = 683, count = 4},
  {time = 8, type = "wave", formation = "v", x = 512, count = 5},
  {time = 12, type = "wave", formation = "v", x = 854, count = 5},
  {time = 18, type = "wave", formation = "wave", x = 683, count = 6},
  {time = 25, type = "turret", x = 341},
  {time = 25, type = "turret", x = 1025},
  {time = 30, type = "wave", formation = "line", x = 683, count = 5},
  {time = 35, type = "wave", formation = "v", x = 598, count = 6},
  {time = 35, type = "wave", formation = "v", x = 769, count = 6},
  {time = 42, type = "capitalship", x = 683},
  {time = 48, type = "wave", formation = "wave", x = 683, count = 7},
  {time = 55, type = "wave", formation = "v", x = 512, count = 5},
  {time = 55, type = "wave", formation = "v", x = 854, count = 5},
  {time = 62, type = "turret", x = 512},
  {time = 62, type = "turret", x = 854},
  {time = 68, type = "wave", formation = "line", x = 683, count = 6},
  {time = 75, type = "capitalship", x = 427},
  {time = 75, type = "capitalship", x = 940},
  {time = 82, type = "wave", formation = "wave", x = 683, count = 8},
  {time = 90, type = "callout", message = "triggerBossWarning"},
  {time = 95, type = "midboss"}
}

M.VENOM = {
  -- Phase 1: Opening waves
  {time = 2, type = "wave", formation = "v", x = 683, count = 6},
  {time = 6, type = "wave", formation = "line", x = 683, count = 5},
  {time = 10, type = "wave", formation = "v", x = 512, count = 5},
  {time = 10, type = "wave", formation = "v", x = 854, count = 5},
  {time = 15, type = "capitalship", x = 683},
  {time = 18, type = "wave", formation = "wave", x = 683, count = 7},

  -- First Rival Encounter
  {time = 22, type = "callout", message = "triggerRivalWarning"},
  {time = 25, type = "rival", hp = 40},

  -- Phase 2: Waves during/after rival
  {time = 35, type = "wave", formation = "v", x = 683, count = 6},
  {time = 40, type = "wave", formation = "line", x = 512, count = 4},
  {time = 40, type = "wave", formation = "line", x = 854, count = 4},
  {time = 45, type = "capitalship", x = 427},
  {time = 45, type = "capitalship", x = 940},
  {time = 50, type = "wave", formation = "wave", x = 683, count = 8},

  -- Second Rival Encounter (boosted HP)
  {time = 55, type = "callout", message = "triggerRivalReturn"},
  {time = 58, type = "rival", hp = 50},

  -- Phase 3: Pre-maze waves
  {time = 68, type = "wave", formation = "v", x = 683, count = 7},
  {time = 72, type = "wave", formation = "line", x = 683, count = 6},
  {time = 75, type = "turret", x = 341},
  {time = 75, type = "turret", x = 1025},

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

M.FICHINA = {
  -- Opening - diamond formation
  {time = 2, type = "wave", formation = "diamond", x = 683, count = 4},
  {time = 8, type = "wave", formation = "diamond", x = 427, count = 4},
  {time = 8, type = "wave", formation = "diamond", x = 940, count = 4},

  -- Box formations
  {time = 14, type = "wave", formation = "box", x = 683, count = 5},
  {time = 20, type = "wave", formation = "box", x = 512, count = 5},
  {time = 20, type = "wave", formation = "box", x = 854, count = 5},

  -- Triangle formations
  {time = 26, type = "wave", formation = "triangle", x = 683, count = 5},
  {time = 32, type = "wave", formation = "triangle", x = 598, count = 5},
  {time = 32, type = "wave", formation = "triangle", x = 769, count = 5},

  -- Mixed assault
  {time = 38, type = "wave", formation = "diamond", x = 683, count = 4},
  {time = 42, type = "wave", formation = "box", x = 427, count = 5},
  {time = 42, type = "wave", formation = "box", x = 940, count = 5},

  -- Intense section
  {time = 48, type = "wave", formation = "triangle", x = 512, count = 5},
  {time = 50, type = "wave", formation = "triangle", x = 854, count = 5},
  {time = 54, type = "wave", formation = "diamond", x = 683, count = 4},

  -- Final waves before boss
  {time = 60, type = "wave", formation = "box", x = 598, count = 5},
  {time = 62, type = "wave", formation = "box", x = 769, count = 5},
  {time = 66, type = "wave", formation = "triangle", x = 683, count = 5},
  {time = 70, type = "wave", formation = "diamond", x = 512, count = 4},
  {time = 70, type = "wave", formation = "diamond", x = 854, count = 4},

  -- Boss
  {time = 75, type = "callout", message = "triggerBossWarning"},
  {time = 80, type = "finalboss"}
}

-- Inner Ring Boss: The Warden (id=19)
-- Guardian of the Near Reaches - defeat to claim the Mega Antenna
M.WARDEN = {
  -- Opening waves
  {time = 2, type = "wave", formation = "v", x = 683, count = 5},
  {time = 6, type = "wave", formation = "line", x = 512, count = 4},
  {time = 6, type = "wave", formation = "line", x = 854, count = 4},
  {time = 12, type = "wave", formation = "wave", x = 683, count = 6},

  -- First turret defense
  {time = 18, type = "turret", x = 341},
  {time = 18, type = "turret", x = 1025},
  {time = 22, type = "wave", formation = "v", x = 683, count = 7},

  -- Mid-battle intensity
  {time = 28, type = "wave", formation = "diamond", x = 598, count = 4},
  {time = 28, type = "wave", formation = "diamond", x = 769, count = 4},
  {time = 34, type = "capitalship", x = 683},
  {time = 38, type = "wave", formation = "line", x = 683, count = 6},

  -- Second turret wave
  {time = 44, type = "turret", x = 512},
  {time = 44, type = "turret", x = 854},
  {time = 48, type = "wave", formation = "wave", x = 683, count = 8},

  -- Boss warning and spawn
  {time = 55, type = "callout", message = "triggerBossWarning"},
  {time = 60, type = "wardenboss"}
}

-- Middle Ring Boss: The Sentinel (id=20)
-- Guardian of the Middle Marches - defeat to claim the Power Amplifier
M.SENTINEL = {
  -- Intense opening - rapid assault
  {time = 2, type = "wave", formation = "v", x = 683, count = 6},
  {time = 5, type = "wave", formation = "line", x = 683, count = 5},
  {time = 8, type = "wave", formation = "v", x = 512, count = 5},
  {time = 8, type = "wave", formation = "v", x = 854, count = 5},

  -- Capital ship with escort
  {time = 14, type = "capitalship", x = 683},
  {time = 16, type = "wave", formation = "diamond", x = 512, count = 4},
  {time = 16, type = "wave", formation = "diamond", x = 854, count = 4},

  -- Heavy turret defense
  {time = 22, type = "turret", x = 256},
  {time = 22, type = "turret", x = 683},
  {time = 22, type = "turret", x = 1110},
  {time = 26, type = "wave", formation = "wave", x = 683, count = 8},

  -- Dual capital ships
  {time = 32, type = "capitalship", x = 427},
  {time = 32, type = "capitalship", x = 940},
  {time = 36, type = "wave", formation = "v", x = 683, count = 7},

  -- Box formation assault
  {time = 42, type = "wave", formation = "box", x = 598, count = 5},
  {time = 42, type = "wave", formation = "box", x = 769, count = 5},
  {time = 48, type = "turret", x = 341},
  {time = 48, type = "turret", x = 1025},

  -- Triangle formation finale
  {time = 54, type = "wave", formation = "triangle", x = 512, count = 5},
  {time = 54, type = "wave", formation = "triangle", x = 854, count = 5},
  {time = 60, type = "wave", formation = "wave", x = 683, count = 10},

  -- Boss warning and spawn
  {time = 68, type = "callout", message = "triggerBossWarning"},
  {time = 73, type = "sentinelboss"}
}

-- Sector Z: Extreme difficulty gauntlet before 7-phase Elden Ring boss
M.SECTORZ = {
  -- Wave 1: Aggressive opening - no warmup
  {time = 1, type = "wave", formation = "v", x = 683, count = 8},
  {time = 3, type = "wave", formation = "line", x = 512, count = 6},
  {time = 3, type = "wave", formation = "line", x = 854, count = 6},

  -- Wave 2: Triple capital ships
  {time = 7, type = "capitalship", x = 341},
  {time = 7, type = "capitalship", x = 683},
  {time = 7, type = "capitalship", x = 1025},
  {time = 9, type = "wave", formation = "diamond", x = 512, count = 4},
  {time = 9, type = "wave", formation = "diamond", x = 854, count = 4},

  -- Wave 3: Turret gauntlet
  {time = 13, type = "turret", x = 200},
  {time = 13, type = "turret", x = 400},
  {time = 13, type = "turret", x = 600},
  {time = 13, type = "turret", x = 800},
  {time = 13, type = "turret", x = 1000},
  {time = 15, type = "wave", formation = "v", x = 683, count = 10},

  -- Wave 4: Flanking assault
  {time = 19, type = "wave", formation = "triangle", x = 300, count = 5},
  {time = 19, type = "wave", formation = "triangle", x = 683, count = 5},
  {time = 19, type = "wave", formation = "triangle", x = 1066, count = 5},
  {time = 22, type = "wave", formation = "wave", x = 683, count = 12},

  -- Wave 5: Rival encounter
  {time = 26, type = "callout", message = "triggerRivalWarning"},
  {time = 28, type = "rival", hp = 60, variant = "teleport"},

  -- Wave 6: Continuous pressure during/after rival
  {time = 32, type = "wave", formation = "v", x = 512, count = 7},
  {time = 32, type = "wave", formation = "v", x = 854, count = 7},
  {time = 36, type = "capitalship", x = 427},
  {time = 36, type = "capitalship", x = 940},

  -- Wave 7: Box formation assault
  {time = 40, type = "wave", formation = "box", x = 400, count = 5},
  {time = 40, type = "wave", formation = "box", x = 683, count = 5},
  {time = 40, type = "wave", formation = "box", x = 966, count = 5},

  -- Wave 8: Diamond storm
  {time = 45, type = "wave", formation = "diamond", x = 341, count = 4},
  {time = 45, type = "wave", formation = "diamond", x = 683, count = 4},
  {time = 45, type = "wave", formation = "diamond", x = 1025, count = 4},
  {time = 48, type = "turret", x = 341},
  {time = 48, type = "turret", x = 683},
  {time = 48, type = "turret", x = 1025},

  -- Wave 9: Overwhelming numbers
  {time = 52, type = "wave", formation = "line", x = 683, count = 15},
  {time = 55, type = "wave", formation = "v", x = 512, count = 8},
  {time = 55, type = "wave", formation = "v", x = 854, count = 8},

  -- Wave 10: Final gauntlet
  {time = 60, type = "capitalship", x = 512},
  {time = 60, type = "capitalship", x = 854},
  {time = 62, type = "wave", formation = "triangle", x = 512, count = 5},
  {time = 62, type = "wave", formation = "triangle", x = 854, count = 5},
  {time = 65, type = "wave", formation = "wave", x = 683, count = 14},

  -- Boss warning - extended for dramatic effect
  {time = 70, type = "callout", message = "triggerEnemyWarning"},
  {time = 73, type = "wave", formation = "diamond", x = 683, count = 4},
  {time = 76, type = "callout", message = "triggerBossWarning"},
  {time = 80, type = "sectorzboss"}
}

function M.getEnemyCount(levelId)
  local waves = M.getWaves(levelId)
  local count = 0
  for _, wave in ipairs(waves) do
    if wave.type == "wave" then
      count = count + (wave.count or 0)
    elseif wave.type == "turret" or wave.type == "capitalship" or wave.type == "mothership"
        or wave.type == "midboss" or wave.type == "finalboss" or wave.type == "area6boss"
        or wave.type == "rival" or wave.type == "venomboss" or wave.type == "wardenboss"
        or wave.type == "sentinelboss" or wave.type == "sectorzboss" then
      count = count + 1
    elseif wave.type == "bolsestation" then
      count = count + 7
    end
  end
  return count
end

function M.getWaves(levelId)
  if levelId == 2 then
    return M.METEO
  elseif levelId == 3 then
    return M.SECTORY
  elseif levelId == 5 then
    return M.KATINA
  elseif levelId == 8 then
    return M.SECTORX
  elseif levelId == 10 then
    return M.MACBETH
  elseif levelId == 12 then
    return M.SECTORZ
  elseif levelId == 13 then
    return M.BOLSE
  elseif levelId == 14 then
    return M.AREA6
  elseif levelId == 15 then
    return M.FICHINA
  elseif levelId == 18 then
    return M.VENOM
  elseif levelId == 19 then
    return M.WARDEN
  elseif levelId == 20 then
    return M.SENTINEL
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
    [18] = "VENOM",
    [19] = "THE WARDEN",
    [20] = "THE SENTINEL"
  }
  return names[levelId] or "CORNERIA"
end

return M

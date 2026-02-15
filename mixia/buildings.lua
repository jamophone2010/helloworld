-- mixia/buildings.lua
-- Interior layouts for buildings across all levels of Mixia city planet

local M = {}

M.GRID_SIZE = 32

M.interiors = {
  -- ═══════════════════════════════════════
  -- LEVEL 0: ANCIENT CITADEL (Indiana Jones Maze)
  -- ═══════════════════════════════════════
  ancient_citadel_maze = {
    name = "Ancient Citadel",
    width = 40, height = 30,
    exitX = 2, exitY = 28,
    isMaze = true,
    -- Maze layout: 1 = wall, 0 = path, 2 = dart trap, 3 = spike pit, 4 = swinging blade,
    -- 5 = crumbling floor, 6 = fire jet, 7 = boulder trigger, 8 = treasure chest
    mazeMap = {
      -- Row 0 (top wall)
      {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
      -- Row 1
      {1,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1},
      -- Row 2
      {1,0,1,0,1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1,0,1},
      -- Row 3
      {1,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1},
      -- Row 4
      {1,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,0,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,0,1},
      -- Row 5
      {1,0,0,0,0,0,1,0,0,2,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1},
      -- Row 6
      {1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,0,1,1,1,0,1},
      -- Row 7
      {1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,1,0,1},
      -- Row 8
      {1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,1,0,1,0,1,0,1,0,1},
      -- Row 9
      {1,0,1,0,0,0,0,0,1,0,0,3,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,4,0,0,0,1,0,1,0,0,0,1},
      -- Row 10
      {1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,1,0,1,0,1,1,1,1,1},
      -- Row 11
      {1,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1},
      -- Row 12
      {1,1,1,0,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0,1},
      -- Row 13
      {1,0,0,0,0,0,1,0,0,0,0,5,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1},
      -- Row 14
      {1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,0,1,0,1},
      -- Row 15 (boulder corridor zone)
      {1,0,0,0,0,0,0,0,0,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,1},
      -- Row 16
      {1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,1,0,1,1,1,0,1},
      -- Row 17
      {1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1},
      -- Row 18
      {1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,0,1,1,1,1},
      -- Row 19
      {1,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1},
      -- Row 20
      {1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1},
      -- Row 21
      {1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,2,0,0,0,0,0,0,0,1,0,1},
      -- Row 22
      {1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,0,1},
      -- Row 23 (boulder trigger row)
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,1},
      -- Row 24
      {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1},
      -- Row 25
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      -- Row 26
      {1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1},
      -- Row 27
      {1,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      -- Row 28
      {1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
      -- Row 29 (bottom wall)
      {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    },
    -- Obstacle definitions with timing patterns
    obstacles = {
      -- Dart traps (type 2): fire projectiles periodically
      {type = "dart", gridX = 9, gridY = 5, direction = "down", interval = 2.0, speed = 6},
      {type = "dart", gridX = 11, gridY = 9, direction = "right", interval = 2.5, speed = 5},
      {type = "dart", gridX = 29, gridY = 21, direction = "left", interval = 1.8, speed = 7},
      -- Spike pits (type 3): pop up periodically
      {type = "spikes", gridX = 11, gridY = 9, interval = 3.0, activeTime = 1.5},
      -- Swinging blades (type 4): swing back and forth
      {type = "blade", gridX = 29, gridY = 9, swingSpeed = 2.5},
      {type = "blade", gridX = 5, gridY = 19, swingSpeed = 3.0},
      -- Crumbling floor (type 5): collapses briefly after stepping on
      {type = "crumble", gridX = 11, gridY = 13, reformTime = 4.0},
      -- Fire jets (type 6): burst periodically
      {type = "fire", gridX = 9, gridY = 15, interval = 2.5, activeTime = 1.0, direction = "up"},
    },
    -- Boulder chase configuration (triggered at cell 7)
    boulderChase = {
      triggerX = 38, triggerY = 23,
      boulderStartX = 38, boulderStartY = 23,
      chaseDirection = "left",  -- boulder rolls left
      boulderSpeed = 3.5,
      escapeX = 1, escapeY = 25,  -- safe zone
    },
    -- Treasure chest at the end
    treasureChest = {
      x = 3, y = 27,
      reward = 50000,
      rewardType = "notes",
    },
    -- Entrance position (player spawns here)
    entranceX = 2, entranceY = 28,
  },

  -- ═══════════════════════════════════════
  -- LEVEL 1: THE SURFACE (Jungle Night Market)
  -- ═══════════════════════════════════════
  surface_cantina = {
    name = "Mos Eisley Cantina",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Pool Table", x = 14, y = 6, game = "pooltable", color = {0.1, 0.55, 0.3}}
    },
    npcs = {
      {name = "Bartender Kex", x = 6, y = 3, dialogue = "What'll it be? We got Corellian whiskey, Bespin fizz, or something that'll melt your insides. Your call.", gender = "male", design = 3},
      {name = "Captain Rho", x = 12, y = 6, dialogue = "Buy me a drink and I'll tell you about the Kessel shortcut. Real one, not the tourist version.", gender = "male", design = 5},
      {name = "Twi'lek Singer", x = 4, y = 8, dialogue = "~singing~ The stars are cold but the cantina's warm... Requests are 10 credits.", gender = "female", design = 1},
      {name = "Wookiee Bouncer", x = 15, y = 10, dialogue = "*growls approvingly* (Translation: Welcome. No blasters at the bar.)", gender = "male", design = 6}
    }
  },
  smugglers_den = {
    name = "Smuggler's Den",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    portals = {
      {name = "Black Market Shop", x = 8, y = 4, game = "shop", color = {0.1, 0.7, 1.0}}
    },
    npcs = {
      {name = "Fence", x = 5, y = 4, dialogue = "No serial numbers, no questions. That's how legends do business.", gender = "male", design = 5},
      {name = "Navigator Tress", x = 12, y = 6, dialogue = "I've mapped routes the Imperium doesn't even know exist. Need a shortcut?", gender = "female", design = 6},
      {name = "Arms Dealer Voss", x = 6, y = 8, dialogue = "Modified blasters, ion disruptors, thermal charges. All top quality. Mostly.", gender = "male", design = 6}
    }
  },
  smugglers_shack = {
    name = "Smugglers' Shack",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Guild Master Sable", x = 6, y = 3, dialogue = "Every bounty posted here is verified. We're professionals, not thugs. Big difference.", gender = "female", design = 6},
      {name = "Veteran Hunter", x = 10, y = 5, dialogue = "Thirty years, two hundred bounties. Never lost a target. You want tips? Earn them.", gender = "male", design = 6}
    }
  },
  xeno_bazaar = {
    name = "Xeno Bazaar",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Exotic Goods", x = 9, y = 5, game = "shop", color = {0.8, 0.2, 0.9}}
    },
    npcs = {
      {name = "Insectoid Merchant", x = 5, y = 5, dialogue = "*clicks mandibles* Crystals from the Void Nebula. Very rare. Very expensive. Very worth it.", gender = "male"},
      {name = "Droid Trader", x = 13, y = 7, dialogue = "UNIT TX-88 HAS PREMIUM DROIDS FOR SALE. PERSONALITY CHIPS INCLUDED. SATISFACTION PROBABLE.", gender = "male"},
      {name = "Jellyfish Being", x = 7, y = 10, dialogue = "~bioluminescent pulse~ (Translation: I sell memories. Other people's. Fascinating ones.)", gender = "female"}
    }
  },
  golden_vault_casino = {
    name = "The Golden Vault",
    width = 28, height = 18,
    exitX = 13, exitY = 17,
    portals = {
      {name = "High Roller Slots", x = 6, y = 5, game = "slotmachine", color = {0.85, 0.7, 0.2}},
      {name = "VIP Blackjack", x = 12, y = 5, game = "blackjack", color = {0.85, 0.7, 0.2}},
      {name = "Elite Roulette", x = 20, y = 5, game = "roulette", color = {0.85, 0.7, 0.2}},
      {name = "Cashier", x = 21, y = 10, game = "casino_exchange", color = {1, 0.85, 0.3}},
    },
    npcs = {
      {name = "Pit Boss Aurelius", x = 13, y = 4, dialogue = "The Golden Vault. Minimum bet: 1,000 credits. If that's too rich for your blood, there's always the Commerce Level.", gender = "male", design = 5},
      {name = "VIP Host", x = 22, y = 4, dialogue = "Welcome to the high table. Complimentary drinks for anyone betting over 10k.", gender = "female", design = 1},
      {name = "High Roller", x = 8, y = 8, dialogue = "I just put 50,000 on black. Again. The thrill is the whole point, isn't it?", gender = "male", design = 5},
      {name = "Security Chief", x = 4, y = 12, dialogue = "Concealed weapons are fine — everyone here carries one. Just don't draw.", gender = "male", design = 3},
    },
    zones = {
      {name = "entrance", x1 = 0, y1 = 0, x2 = 27, y2 = 2, floor = "black_marble"},
      {name = "gaming", x1 = 3, y1 = 3, x2 = 24, y2 = 8, floor = "carpet_gold"},
      {name = "vip_lounge", x1 = 0, y1 = 9, x2 = 17, y2 = 13, floor = "black_marble"},
      {name = "cashier", x1 = 18, y1 = 9, x2 = 24, y2 = 11, floor = "black_marble"},
      {name = "bar", x1 = 0, y1 = 14, x2 = 27, y2 = 16, floor = "carpet_dark"},
      {name = "exit", x1 = 11, y1 = 17, x2 = 16, y2 = 17, floor = "black_marble"}
    },
    decorations = {
      {type = "fountain_gold", x = 2, y = 5, collision = true},
      {type = "sculpture_gold", x = 3, y = 14, collision = true},
      {type = "sculpture_gold", x = 22, y = 14, collision = true},
      {type = "counter_gold", x = 4, y = 10, w = 5, collision = true},
      {type = "slots", x = 5, y = 5, w = 3, h = 2},
      {type = "blackjack_table", x = 11, y = 5, w = 3, h = 2},
      {type = "roulette_table", x = 19, y = 5, w = 4, h = 3}
    },
    -- Casino-specific config
    minBet = 1000,
    colorScheme = "black_gold",  -- Black and gold palette (Golden Nugget style)
  },
  surface_mechanic = {
    name = "Wrench & Thruster Garage",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Mechanic Grease", x = 5, y = 4, dialogue = "Your ship's making a funny noise? They all do. 500 credits and I'll make it purr.", gender = "male", design = 6},
      {name = "Astromech Droid", x = 10, y = 6, dialogue = "*beeps enthusiastically* (Translation: I can fix anything! Well, almost anything.)", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- LEVEL 2: INDUSTRIAL ZONE
  -- ═══════════════════════════════════════
  factory_a = {
    name = "Droid Assembly Plant",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Shift Supervisor", x = 6, y = 5, dialogue = "500 units a day. That's the target. No excuses.", gender = "male", design = 3},
      {name = "Assembly Worker", x = 12, y = 7, dialogue = "Same motion, thousand times a day. I dream about droid parts.", gender = "male"},
      {name = "Quality Inspector", x = 8, y = 10, dialogue = "Reject rate is up. Upper District is complaining again.", gender = "female", design = 4}
    }
  },
  factory_b = {
    name = "Vehicle Manufacturing",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Floor Manager", x = 7, y = 5, dialogue = "Speeders, transports, cargo haulers. We build them all.", gender = "male"},
      {name = "Welder", x = 14, y = 8, dialogue = "Safety goggles? Those cost extra. I've adapted.", gender = "male", design = 6}
    }
  },
  worker_housing = {
    name = "Block 7 Housing",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Tired Mother", x = 5, y = 4, dialogue = "Three shifts to afford this tiny room. The kids barely see me.", gender = "female"},
      {name = "Off-Shift Worker", x = 10, y = 6, dialogue = "Six hours to sleep before next shift. Life of a factory worker.", gender = "male"}
    }
  },
  power_plant = {
    name = "Central Power Station",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Chief Engineer", x = 6, y = 4, dialogue = "The reactors power the whole city. Millions depend on us.", gender = "male", design = 3},
      {name = "Technician", x = 12, y = 7, dialogue = "Radiation levels are... acceptable. Mostly. Don't stay too long.", gender = "female", design = 2}
    }
  },
  cargo_hub = {
    name = "Freight Distribution Center",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Logistics Chief", x = 7, y = 4, dialogue = "Every crate tracked, every shipment logged. Efficiency is everything.", gender = "male"},
      {name = "Loader Droid", x = 12, y = 7, dialogue = "UNIT LD-9. PROCESSING SHIPMENT 47,293 OF TODAY. 12,707 REMAINING.", gender = "male"}
    }
  },
  refinery = {
    name = "Fuel Refinery",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Refinery Boss", x = 6, y = 5, dialogue = "Tibanna gas, hyperfuel, starship coolant. We process it all.", gender = "male", design = 3},
      {name = "Safety Officer", x = 11, y = 7, dialogue = "One spark in the wrong place and... boom. Stay alert.", gender = "female", design = 4}
    }
  },

  -- ═══════════════════════════════════════
  -- LEVEL 3: COMMERCE LEVEL
  -- ═══════════════════════════════════════
  grand_bazaar = {
    name = "Grand Bazaar of Mixia",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    portals = {
      {name = "Shop", x = 10, y = 5, game = "shop", color = {0.9, 0.8, 0.5}}
    },
    npcs = {
      {name = "Master Merchant", x = 6, y = 6, dialogue = "Goods from a hundred worlds! Best prices in the sector!", gender = "male"},
      {name = "Exotic Dealer", x = 14, y = 7, dialogue = "Looking for something rare? I have... connections.", gender = "female", design = 1},
      {name = "Haggler", x = 8, y = 10, dialogue = "Never pay asking price. First rule of the Bazaar.", gender = "male"}
    }
  },
  tech_emporium = {
    name = "Galactic Tech Emporium",
    width = 18, height = 12,
    exitX = 9, exitY = 11,
    portals = {
      {name = "Tech Shop", x = 9, y = 4, game = "shop", color = {0.5, 0.7, 0.9}}
    },
    npcs = {
      {name = "Tech Salesman", x = 6, y = 5, dialogue = "Latest holopads, droids, ship upgrades. Cutting edge!", gender = "male"},
      {name = "Repair Tech", x = 13, y = 7, dialogue = "Bring me anything broken. I'll have it running better than new.", gender = "female", design = 2}
    }
  },
  entertainment_hub = {
    name = "Starlight Entertainment Center",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Showrunner", x = 7, y = 4, dialogue = "Holotheaters, arcades, VR suites. Fun for the whole family!", gender = "male"},
      {name = "Performer", x = 11, y = 7, dialogue = "Catch my show at eight! Comedy and music, guaranteed laughs!", gender = "female", design = 1}
    }
  },
  restaurant_row = {
    name = "Restaurant Row",
    width = 18, height = 12,
    exitX = 9, exitY = 11,
    npcs = {
      {name = "Head Chef", x = 6, y = 4, dialogue = "Cuisine from fifty worlds! Today's special: Alderaanian stew.", gender = "male"},
      {name = "Food Critic", x = 12, y = 6, dialogue = "The noodles here are acceptable. The Upper District has better.", gender = "female", design = 3},
      {name = "Happy Diner", x = 8, y = 8, dialogue = "Best food outside the government quarter. And affordable!", gender = "male"}
    }
  },
  mission_control = {
    name = "Mixia Mission Hub",
    width = 20, height = 15,
    exitX = 10, exitY = 14,
    portals = {
      {name = "Asteroids", x = 6, y = 6, game = "asteroids", color = {0.5, 0.65, 0.85}},
      {name = "StarFox", x = 10, y = 6, game = "starfox", color = {0.5, 0.7, 0.9}},
      {name = "Planet Map", x = 14, y = 6, game = "planetmap", color = {0.7, 0.5, 0.8}}
    },
    npcs = {
      {name = "Flight Commander", x = 10, y = 3, dialogue = "The Planet Map shows all navigable systems and stations.", gender = "male"},
      {name = "Navigator", x = 16, y = 8, dialogue = "Plan your route carefully. The galaxy is vast and dangerous.", gender = "female", design = 4}
    }
  },
  bank = {
    name = "Bank of Mixia",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    portals = {
      {name = "Exchange", x = 8, y = 4, game = "casino_exchange", color = {0.85, 0.75, 0.45}}
    },
    npcs = {
      {name = "Bank Manager", x = 6, y = 5, dialogue = "Secure vaults, competitive rates. Your credits are safe with us.", gender = "male"},
      {name = "Teller", x = 11, y = 5, dialogue = "Deposits, withdrawals, currency exchange. How may I help?", gender = "female", design = 4}
    }
  },

  -- ═══════════════════════════════════════
  -- LEVEL 4: UPPER DISTRICT
  -- ═══════════════════════════════════════
  senate_hall = {
    name = "Mixia Senate Hall",
    width = 20, height = 16,
    exitX = 10, exitY = 15,
    npcs = {
      {name = "Senator Vorn", x = 8, y = 5, dialogue = "The Lower Districts need reform. But votes are... complicated.", gender = "male", design = 5},
      {name = "Senator Kira", x = 12, y = 5, dialogue = "Stability comes first. Change too fast and everything falls apart.", gender = "female", design = 4},
      {name = "Senate Guard", x = 10, y = 10, dialogue = "Official business only. No tourists in the Senate chamber.", gender = "male"},
      {name = "Lobbyist", x = 16, y = 8, dialogue = "I represent... certain interests. Everyone does. Don't be naive.", gender = "male"}
    }
  },
  luxury_apartments = {
    name = "Skyview Luxury Residences",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Concierge", x = 8, y = 3, dialogue = "Welcome to Skyview. May I arrange a speeder? A reservation?", gender = "male"},
      {name = "Wealthy Resident", x = 12, y = 6, dialogue = "The views from my penthouse are magnificent. Worth every credit.", gender = "female", design = 1}
    }
  },
  embassy = {
    name = "Galactic Embassy Quarter",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Ambassador", x = 7, y = 4, dialogue = "Diplomatic relations require... delicacy. And patience.", gender = "male", design = 5},
      {name = "Attaché", x = 12, y = 6, dialogue = "The Ambassador's schedule is full. Perhaps next month?", gender = "female", design = 4}
    }
  },
  grand_hotel = {
    name = "The Grand Mixian",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Hotel Manager", x = 8, y = 4, dialogue = "Five-star service, guaranteed. Our guests expect the finest.", gender = "male"},
      {name = "Bellhop", x = 5, y = 7, dialogue = "Your bags, sir? The penthouse suite is prepared.", gender = "male"},
      {name = "VIP Guest", x = 14, y = 8, dialogue = "I travel the galaxy and this remains my favorite hotel.", gender = "female", design = 1}
    }
  },
  museum = {
    name = "Mixia Historical Museum",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Curator", x = 7, y = 4, dialogue = "Ten thousand years of history. From the surface era to today.", gender = "female", design = 4},
      {name = "Docent", x = 12, y = 7, dialogue = "This artifact is from the Surface. Before the city rose above...", gender = "male"}
    }
  },
  opera_house = {
    name = "Mixia Opera House",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Opera Director", x = 8, y = 5, dialogue = "Tonight's performance: The Fall of Taris. A classic tragedy.", gender = "male", design = 5},
      {name = "Prima Donna", x = 13, y = 7, dialogue = "My voice carries to every seat. Perfection takes decades.", gender = "female", design = 1}
    }
  },

  -- ═══════════════════════════════════════
  -- LEVEL 5: SKYLINE TERRACE
  -- ═══════════════════════════════════════
  observation_deck = {
    name = "Skyline Observation Deck",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Tourist", x = 7, y = 4, dialogue = "You can see the whole city from here! All the way down to... well, you can't see the bottom.", gender = "female", design = 3},
      {name = "Philosopher", x = 12, y = 6, dialogue = "From up here, the lower levels seem so small. Perspective changes everything.", gender = "male"}
    }
  },
  hangar = {
    name = "Skyline Hangar Bay",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Ship Selection", x = 8, y = 5, game = "hangar", color = {0.5, 0.6, 0.75}}
    },
    npcs = {
      {name = "Hangar Chief", x = 6, y = 6, dialogue = "Clear skies, premium fuel, expert mechanics. Best hangar on Mixia.", gender = "male"},
      {name = "Pilot", x = 14, y = 8, dialogue = "The approach to Mixia is beautiful. Sunlight on the spires...", gender = "female", design = 2}
    }
  },
  sky_lounge = {
    name = "Cloud Nine Lounge",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Bartender", x = 6, y = 3, dialogue = "Our specialty: Sunrise Fizz. Best enjoyed watching the dawn.", gender = "male"},
      {name = "Elite Guest", x = 10, y = 5, dialogue = "Only the highest level. Only the finest company. This is living.", gender = "female", design = 1}
    }
  },
  weather_station = {
    name = "Climate Control Center",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Climate Controller", x = 6, y = 4, dialogue = "We maintain perfect weather. 22 degrees, light clouds. Always.", gender = "male"},
      {name = "Technician", x = 9, y = 6, dialogue = "The satellites keep the climate stable. Without us? Chaos.", gender = "female", design = 2}
    }
  },
  rooftop_gardens = {
    name = "Celestial Gardens",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Master Gardener", x = 7, y = 4, dialogue = "Real plants. Real soil. The only greenery for a hundred levels.", gender = "female", design = 6},
      {name = "Botanist", x = 12, y = 7, dialogue = "We preserve species from the surface era. Living history.", gender = "male"}
    }
  },
  control_tower = {
    name = "Traffic Control Tower",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Air Traffic Controller", x = 7, y = 3, dialogue = "Thousands of ships, every day. One mistake and... well, we don't make mistakes.", gender = "male"},
      {name = "Radar Operator", x = 10, y = 5, dialogue = "Clear skies. Light traffic. Perfect conditions for landing.", gender = "female", design = 4}
    }
  },
}

-- Create collision map for an interior
function M.createInteriorCollisionMap(interiorId)
  local interior = M.interiors[interiorId]
  if not interior then return {} end

  -- Maze interiors use mazeMap for collision
  if interior.isMaze and interior.mazeMap then
    local map = {}
    for y = 0, interior.height - 1 do
      map[y] = {}
      for x = 0, interior.width - 1 do
        local row = interior.mazeMap[y + 1]
        if row then
          local cell = row[x + 1]
          -- Wall (1) is solid, everything else is walkable
          map[y][x] = (cell == 1)
        else
          map[y][x] = true
        end
      end
    end
    return map
  end

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

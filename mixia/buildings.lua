-- mixia/buildings.lua
-- Interior layouts for buildings across all levels of Mixia city planet

local M = {}

M.GRID_SIZE = 32

M.interiors = {
  -- ═══════════════════════════════════════
  -- LEVEL 0: THE SURFACE (Secret)
  -- ═══════════════════════════════════════
  ancient_temple = {
    name = "Ancient Temple",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Temple Guardian", x = 9, y = 4, dialogue = "This temple stood before the city rose above. We guard its secrets."},
      {name = "Archaeologist", x = 14, y = 8, dialogue = "The inscriptions speak of a time when the surface saw daylight..."}
    }
  },
  outcast_camp = {
    name = "Outcast Camp",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Camp Leader", x = 6, y = 4, dialogue = "We were exiled. Criminals, they call us. But we're survivors."},
      {name = "Scavenger", x = 10, y = 6, dialogue = "Found this in the ruins. Pre-city tech. Worth a fortune up top."}
    }
  },
  buried_vault = {
    name = "Buried Vault",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Ancient Cache", x = 7, y = 3, game = "shop", color = {0.5, 0.4, 0.3}}
    },
    npcs = {
      {name = "Vault Keeper", x = 5, y = 5, dialogue = "Artifacts from the old world. Take what you need. Credits are meaningless here."}
    }
  },

  -- ═══════════════════════════════════════
  -- LEVEL 1: LOWER DISTRICT
  -- ═══════════════════════════════════════
  lower_cantina = {
    name = "The Rusty Pipe Cantina",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Bartender", x = 6, y = 3, dialogue = "What'll it be? We got synth-ale, engine cleaner, or... the strong stuff."},
      {name = "Drunk Patron", x = 12, y = 6, dialogue = "I used to work the Upper District. Now look at me... *hic*"},
      {name = "Information Broker", x = 4, y = 8, dialogue = "I know things. For the right price, I might share."}
    }
  },
  black_market = {
    name = "The Underground Exchange",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Black Market Shop", x = 7, y = 3, game = "shop", color = {0.6, 0.4, 0.3}}
    },
    npcs = {
      {name = "Fence", x = 5, y = 4, dialogue = "No questions asked. That's how we operate. What are you buying?"},
      {name = "Smuggler", x = 10, y = 6, dialogue = "I can get anything past the checkpoints. Anything."}
    }
  },
  gang_hq = {
    name = "Vulkar Territory",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Gang Boss", x = 6, y = 3, dialogue = "You're either with us or against us. Choose wisely, offworlder."},
      {name = "Enforcer", x = 9, y = 5, dialogue = "The boss doesn't like strangers. State your business."}
    }
  },
  flophouse = {
    name = "No-Name Inn",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Innkeeper", x = 5, y = 3, dialogue = "10 credits a night. Bed might have bugs. Take it or leave it."},
      {name = "Shady Guest", x = 9, y = 6, dialogue = "...I wasn't here. You didn't see me. Understood?"}
    }
  },
  pawn_shop = {
    name = "Last Chance Pawn",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Pawn Exchange", x = 6, y = 3, game = "casino_exchange", color = {0.65, 0.5, 0.35}}
    },
    npcs = {
      {name = "Pawnbroker", x = 4, y = 4, dialogue = "Everything has value. Even your dignity. What are you pawning today?"}
    }
  },
  lower_clinic = {
    name = "Doc's Place",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Back-Alley Doc", x = 6, y = 4, dialogue = "No license, no records, no judgments. 50 credits and I fix you up."},
      {name = "Patient", x = 9, y = 6, dialogue = "Don't ask about the wound. Just... don't."}
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
      {name = "Shift Supervisor", x = 6, y = 5, dialogue = "500 units a day. That's the target. No excuses."},
      {name = "Assembly Worker", x = 12, y = 7, dialogue = "Same motion, thousand times a day. I dream about droid parts."},
      {name = "Quality Inspector", x = 8, y = 10, dialogue = "Reject rate is up. Upper District is complaining again."}
    }
  },
  factory_b = {
    name = "Vehicle Manufacturing",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Floor Manager", x = 7, y = 5, dialogue = "Speeders, transports, cargo haulers. We build them all."},
      {name = "Welder", x = 14, y = 8, dialogue = "Safety goggles? Those cost extra. I've adapted."}
    }
  },
  worker_housing = {
    name = "Block 7 Housing",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Tired Mother", x = 5, y = 4, dialogue = "Three shifts to afford this tiny room. The kids barely see me."},
      {name = "Off-Shift Worker", x = 10, y = 6, dialogue = "Six hours to sleep before next shift. Life of a factory worker."}
    }
  },
  power_plant = {
    name = "Central Power Station",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Chief Engineer", x = 6, y = 4, dialogue = "The reactors power the whole city. Millions depend on us."},
      {name = "Technician", x = 12, y = 7, dialogue = "Radiation levels are... acceptable. Mostly. Don't stay too long."}
    }
  },
  cargo_hub = {
    name = "Freight Distribution Center",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Logistics Chief", x = 7, y = 4, dialogue = "Every crate tracked, every shipment logged. Efficiency is everything."},
      {name = "Loader Droid", x = 12, y = 7, dialogue = "UNIT LD-9. PROCESSING SHIPMENT 47,293 OF TODAY. 12,707 REMAINING."}
    }
  },
  refinery = {
    name = "Fuel Refinery",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Refinery Boss", x = 6, y = 5, dialogue = "Tibanna gas, hyperfuel, starship coolant. We process it all."},
      {name = "Safety Officer", x = 11, y = 7, dialogue = "One spark in the wrong place and... boom. Stay alert."}
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
      {name = "Master Merchant", x = 6, y = 6, dialogue = "Goods from a hundred worlds! Best prices in the sector!"},
      {name = "Exotic Dealer", x = 14, y = 7, dialogue = "Looking for something rare? I have... connections."},
      {name = "Haggler", x = 8, y = 10, dialogue = "Never pay asking price. First rule of the Bazaar."}
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
      {name = "Tech Salesman", x = 6, y = 5, dialogue = "Latest holopads, droids, ship upgrades. Cutting edge!"},
      {name = "Repair Tech", x = 13, y = 7, dialogue = "Bring me anything broken. I'll have it running better than new."}
    }
  },
  entertainment_hub = {
    name = "Starlight Entertainment Center",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Showrunner", x = 7, y = 4, dialogue = "Holotheaters, arcades, VR suites. Fun for the whole family!"},
      {name = "Performer", x = 11, y = 7, dialogue = "Catch my show at eight! Comedy and music, guaranteed laughs!"}
    }
  },
  restaurant_row = {
    name = "Restaurant Row",
    width = 18, height = 12,
    exitX = 9, exitY = 11,
    npcs = {
      {name = "Head Chef", x = 6, y = 4, dialogue = "Cuisine from fifty worlds! Today's special: Alderaanian stew."},
      {name = "Food Critic", x = 12, y = 6, dialogue = "The noodles here are acceptable. The Upper District has better."},
      {name = "Happy Diner", x = 8, y = 8, dialogue = "Best food outside the government quarter. And affordable!"}
    }
  },
  mission_control = {
    name = "Mixia Mission Hub",
    width = 20, height = 15,
    exitX = 10, exitY = 14,
    portals = {
      {name = "Asteroids", x = 7, y = 6, game = "asteroids", color = {0.5, 0.65, 0.85}},
      {name = "StarFox", x = 13, y = 6, game = "starfox", color = {0.5, 0.7, 0.9}}
    },
    npcs = {
      {name = "Mission Commander", x = 10, y = 3, dialogue = "Pilots wanted! The sector needs defenders. Ready to fly?"},
      {name = "Intel Officer", x = 16, y = 8, dialogue = "Multiple contacts in nearby sectors. We could use your help."}
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
      {name = "Bank Manager", x = 6, y = 5, dialogue = "Secure vaults, competitive rates. Your credits are safe with us."},
      {name = "Teller", x = 11, y = 5, dialogue = "Deposits, withdrawals, currency exchange. How may I help?"}
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
      {name = "Senator Vorn", x = 8, y = 5, dialogue = "The Lower Districts need reform. But votes are... complicated."},
      {name = "Senator Kira", x = 12, y = 5, dialogue = "Stability comes first. Change too fast and everything falls apart."},
      {name = "Senate Guard", x = 10, y = 10, dialogue = "Official business only. No tourists in the Senate chamber."},
      {name = "Lobbyist", x = 16, y = 8, dialogue = "I represent... certain interests. Everyone does. Don't be naive."}
    }
  },
  luxury_apartments = {
    name = "Skyview Luxury Residences",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Concierge", x = 8, y = 3, dialogue = "Welcome to Skyview. May I arrange a speeder? A reservation?"},
      {name = "Wealthy Resident", x = 12, y = 6, dialogue = "The views from my penthouse are magnificent. Worth every credit."}
    }
  },
  embassy = {
    name = "Galactic Embassy Quarter",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Ambassador", x = 7, y = 4, dialogue = "Diplomatic relations require... delicacy. And patience."},
      {name = "Attaché", x = 12, y = 6, dialogue = "The Ambassador's schedule is full. Perhaps next month?"}
    }
  },
  grand_hotel = {
    name = "The Grand Mixian",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Hotel Manager", x = 8, y = 4, dialogue = "Five-star service, guaranteed. Our guests expect the finest."},
      {name = "Bellhop", x = 5, y = 7, dialogue = "Your bags, sir? The penthouse suite is prepared."},
      {name = "VIP Guest", x = 14, y = 8, dialogue = "I travel the galaxy and this remains my favorite hotel."}
    }
  },
  museum = {
    name = "Mixia Historical Museum",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Curator", x = 7, y = 4, dialogue = "Ten thousand years of history. From the surface era to today."},
      {name = "Docent", x = 12, y = 7, dialogue = "This artifact is from the Surface. Before the city rose above..."}
    }
  },
  opera_house = {
    name = "Mixia Opera House",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Opera Director", x = 8, y = 5, dialogue = "Tonight's performance: The Fall of Taris. A classic tragedy."},
      {name = "Prima Donna", x = 13, y = 7, dialogue = "My voice carries to every seat. Perfection takes decades."}
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
      {name = "Tourist", x = 7, y = 4, dialogue = "You can see the whole city from here! All the way down to... well, you can't see the bottom."},
      {name = "Philosopher", x = 12, y = 6, dialogue = "From up here, the lower levels seem so small. Perspective changes everything."}
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
      {name = "Hangar Chief", x = 6, y = 6, dialogue = "Clear skies, premium fuel, expert mechanics. Best hangar on Mixia."},
      {name = "Pilot", x = 14, y = 8, dialogue = "The approach to Mixia is beautiful. Sunlight on the spires..."}
    }
  },
  sky_lounge = {
    name = "Cloud Nine Lounge",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Bartender", x = 6, y = 3, dialogue = "Our specialty: Sunrise Fizz. Best enjoyed watching the dawn."},
      {name = "Elite Guest", x = 10, y = 5, dialogue = "Only the highest level. Only the finest company. This is living."}
    }
  },
  weather_station = {
    name = "Climate Control Center",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Climate Controller", x = 6, y = 4, dialogue = "We maintain perfect weather. 22 degrees, light clouds. Always."},
      {name = "Technician", x = 9, y = 6, dialogue = "The satellites keep the climate stable. Without us? Chaos."}
    }
  },
  rooftop_gardens = {
    name = "Celestial Gardens",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Master Gardener", x = 7, y = 4, dialogue = "Real plants. Real soil. The only greenery for a hundred levels."},
      {name = "Botanist", x = 12, y = 7, dialogue = "We preserve species from the surface era. Living history."}
    }
  },
  control_tower = {
    name = "Traffic Control Tower",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Air Traffic Controller", x = 7, y = 3, dialogue = "Thousands of ships, every day. One mistake and... well, we don't make mistakes."},
      {name = "Radar Operator", x = 10, y = 5, dialogue = "Clear skies. Light traffic. Perfect conditions for landing."}
    }
  },
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

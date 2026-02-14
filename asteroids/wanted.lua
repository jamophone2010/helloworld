-- Wanted system for Asteroids police patrol
local M = {}

local patrol = require("asteroids.patrol")

-- Wanted state (persistent across tiles)
M.stars = 0
M.patrols = {}  -- active patrol robots
M.destroyedNormal = 0
M.destroyedBig = 0
M.destroyedMega = 0
M.totalHitsOnPatrols = 0  -- cumulative hits on any patrol (for triggering 1 star)
M.warningGiven = false  -- whether player got the "warning" dialogue
M.doubledDown = false  -- player chose "Sayonara!"
M.postWarningShot = false  -- player shot patrol after clearing with apology
M.bustedState = nil  -- nil, "busted_msg", "fade_white", "fade_from_white", "dialogue"
M.bustedTimer = 0
M.bustedBy = nil  -- which patrol caught the player
M.sentenceTimer = 0  -- 2 minute countdown for mega bust
M.sentenceActive = false
M.fineAnimation = nil  -- {total = N, paid = 0, timer = 0, perTick = 10, popups = {}}
M.agentActive = false
M.agentSayonara = false
M.agentSayonaraTimer = 0
M.agentWarpTimer = 0
M.warningCatch = false  -- true when caught at 1-2 stars (in-game dialogue, not Police HQ)
M.sendToMixiaPD = false  -- true when busted sequence ends and player should spawn at Mixia PD HQ

-- Dialogue state
M.dialogueActive = false
M.dialogueLines = {}
M.dialogueIndex = 1
M.dialogueChoices = nil
M.dialogueChoiceIndex = 1
M.dialogueCallback = nil
M.dialogueSpeaker = ""

function M.reset()
  M.stars = 0
  M.patrols = {}
  M.destroyedNormal = 0
  M.destroyedBig = 0
  M.destroyedMega = 0
  M.totalHitsOnPatrols = 0
  M.warningGiven = false
  M.doubledDown = false
  M.postWarningShot = false
  M.bustedState = nil
  M.bustedTimer = 0
  M.bustedBy = nil
  M.sentenceTimer = 0
  M.sentenceActive = false
  M.fineAnimation = nil
  M.agentActive = false
  M.agentSayonara = false
  M.agentSayonaraTimer = 0
  M.agentWarpTimer = 0
  M.dialogueActive = false
  M.warningCatch = false
  M.sendToMixiaPD = false
end

function M.trySpawnOnTileLoad(width, height)
  -- 1/10 chance to spawn a patrol on tile load (only if no active patrols and 0 stars)
  if M.stars == 0 and #M.patrols == 0 then
    if math.random() <= 0.1 then
      local side = math.random(1, 4)
      local x, y
      if side == 1 then x = math.random(100, width - 100); y = 50
      elseif side == 2 then x = math.random(100, width - 100); y = height - 50
      elseif side == 3 then x = 50; y = math.random(100, height - 100)
      else x = width - 50; y = math.random(100, height - 100) end
      local p = patrol.new(x, y, patrol.TYPE_NORMAL)
      p.state = "patrol"
      table.insert(M.patrols, p)
    end
  end
end

function M.spawnPatrol(x, y, patrolType, warpIn)
  local p = patrol.new(x, y, patrolType or patrol.TYPE_NORMAL)
  if warpIn then
    p.state = "warping_in"
    p.warpTimer = 0
  else
    p.state = "patrol"
  end
  table.insert(M.patrols, p)
  return p
end

function M.spawnOffScreen(width, height, patrolType, warpIn)
  local side = math.random(1, 4)
  local x, y
  if side == 1 then x = math.random(100, width - 100); y = -60
  elseif side == 2 then x = math.random(100, width - 100); y = height + 60
  elseif side == 3 then x = -60; y = math.random(100, height - 100)
  else x = width + 60; y = math.random(100, height - 100) end
  return M.spawnPatrol(x, y, patrolType, warpIn)
end

function M.setAllChasing()
  for _, p in ipairs(M.patrols) do
    if not p.dead and p.state ~= "warping_in" and p.state ~= "caught" then
      p.state = "chase"
    end
  end
end

function M.onPatrolHit(hitPatrol, width, height)
  -- Called when player shoots a patrol robot
  M.totalHitsOnPatrols = M.totalHitsOnPatrols + 1
  hitPatrol.hitCount = hitPatrol.hitCount + 1

  if M.stars == 0 then
    -- First star: 3 hits total on any patrol
    if M.totalHitsOnPatrols >= 3 then
      M.stars = 1
      M.setAllChasing()
    end
  elseif M.stars == 1 then
    if M.postWarningShot then
      -- If they shot a patrol after being warned, instant 3 stars
      M.escalateTo(3, width, height)
    else
      -- 7 more hits after getting 1 star = 2 stars (total 10)
      if M.totalHitsOnPatrols >= 10 then
        M.escalateTo(2, width, height)
      end
    end
  end
end

function M.onPatrolDestroyed(destroyedPatrol, width, height)
  if destroyedPatrol.patrolType == patrol.TYPE_NORMAL then
    M.destroyedNormal = M.destroyedNormal + 1
  elseif destroyedPatrol.patrolType == patrol.TYPE_BIG then
    M.destroyedBig = M.destroyedBig + 1
  elseif destroyedPatrol.patrolType == patrol.TYPE_MEGA then
    M.destroyedMega = M.destroyedMega + 1
  elseif destroyedPatrol.patrolType == patrol.TYPE_AGENT then
    -- Destroying the agent clears wanted!
    M.stars = 0
    M.reset()
    return
  end

  if M.stars == 1 then
    -- Destroying a patrol at 1 star -> 2 stars
    M.escalateTo(2, width, height)
  elseif M.stars == 2 then
    -- Count living patrols
    local livingNormals = 0
    for _, p in ipairs(M.patrols) do
      if not p.dead and p.patrolType == patrol.TYPE_NORMAL then
        livingNormals = livingNormals + 1
      end
    end
    -- If both patrols destroyed at 2 stars -> 3 stars
    if livingNormals == 0 then
      M.escalateTo(3, width, height)
    end
  elseif M.stars == 3 then
    -- Check if big patrol or 2 normals destroyed
    local livingBig = 0
    local livingNormals = 0
    for _, p in ipairs(M.patrols) do
      if not p.dead then
        if p.patrolType == patrol.TYPE_BIG then livingBig = livingBig + 1 end
        if p.patrolType == patrol.TYPE_NORMAL then livingNormals = livingNormals + 1 end
      end
    end
    if livingBig == 0 and livingNormals <= 0 then
      M.escalateTo(4, width, height)
    end
  elseif M.stars == 4 then
    -- Check if mega patrols destroyed
    local livingMega = 0
    for _, p in ipairs(M.patrols) do
      if not p.dead and p.patrolType == patrol.TYPE_MEGA then
        livingMega = livingMega + 1
      end
    end
    if livingMega == 0 then
      M.escalateTo(5, width, height)
    end
  end
end

function M.escalateTo(newStars, width, height)
  M.stars = newStars

  if newStars == 2 then
    -- Spawn a 2nd patrol from offscreen
    M.spawnOffScreen(width, height, patrol.TYPE_NORMAL, true)
    M.setAllChasing()

  elseif newStars == 3 then
    -- Spawn Big Patrol Robot + 2 companions
    local big = M.spawnOffScreen(width, height, patrol.TYPE_BIG, true)
    big.warpDuration = 2.0  -- Fancier warp
    M.spawnOffScreen(width, height, patrol.TYPE_NORMAL, true)
    M.spawnOffScreen(width, height, patrol.TYPE_NORMAL, true)
    M.setAllChasing()

  elseif newStars == 4 then
    -- Spawn 2 Mega Patrol Robots
    local mega1 = M.spawnOffScreen(width, height, patrol.TYPE_MEGA, true)
    mega1.warpDuration = 2.5  -- Even fancier
    local mega2 = M.spawnOffScreen(width, height, patrol.TYPE_MEGA, true)
    mega2.warpDuration = 2.5
    M.setAllChasing()

  elseif newStars == 5 then
    -- Agent of the Machine boss
    M.agentActive = true
    local agent = M.spawnOffScreen(width, height, patrol.TYPE_AGENT, true)
    agent.warpDuration = 3.0
    M.setAllChasing()
  end
end

function M.startBusted(caughtByPatrol)
  M.bustedState = "busted_msg"
  M.bustedTimer = 0
  M.bustedBy = caughtByPatrol
end

-- For 1-2 stars: skip BUSTED! sequence and go directly to warning dialogue in-game
function M.startWarningCatch(caughtByPatrol)
  M.bustedBy = caughtByPatrol
  M.bustedState = "dialogue"  -- go straight to dialogue phase
  M.bustedTimer = 0
  M.warningCatch = true  -- flag so draw code knows to show in-game overlay, not Police HQ
  M.startWarningDialogue()
end

function M.updateBusted(dt, notes)
  if not M.bustedState then return notes end

  M.bustedTimer = M.bustedTimer + dt

  if M.bustedState == "busted_msg" then
    if M.bustedTimer >= 3.0 then
      M.bustedState = "fade_white"
      M.bustedTimer = 0
    end
  elseif M.bustedState == "fade_white" then
    if M.bustedTimer >= 1.0 then
      M.bustedState = "fade_from_white"
      M.bustedTimer = 0
    end
  elseif M.bustedState == "fade_from_white" then
    if M.bustedTimer >= 1.0 then
      M.bustedState = "dialogue"
      M.bustedTimer = 0
      -- Start appropriate dialogue based on star level
      if M.stars <= 2 then
        M.startWarningDialogue()
      elseif M.stars <= 4 then
        M.startFineDialogue(notes)
      end
    end
  end

  -- Update fine animation
  if M.fineAnimation then
    M.fineAnimation.timer = M.fineAnimation.timer + dt
    local tickInterval = 0.4
    if M.fineAnimation.timer >= tickInterval and M.fineAnimation.paid < M.fineAnimation.total then
      M.fineAnimation.timer = 0
      local deduct = math.min(M.fineAnimation.perTick, M.fineAnimation.total - M.fineAnimation.paid)
      deduct = math.min(deduct, notes)
      if deduct <= 0 then
        -- Player is broke, mark fine as done (paid what they could)
        M.fineAnimation.playerBroke = true
        M.fineAnimation.paid = M.fineAnimation.total
      else
        M.fineAnimation.paid = M.fineAnimation.paid + deduct
        notes = math.max(0, notes - deduct)
        table.insert(M.fineAnimation.popups, {
          amount = deduct,
          timer = 0,
          maxTimer = 1.5,
          y = 0
        })
      end
    end
    -- Update popups
    for i = #M.fineAnimation.popups, 1, -1 do
      local pop = M.fineAnimation.popups[i]
      pop.timer = pop.timer + dt
      pop.y = pop.y - 40 * dt
      if pop.timer >= pop.maxTimer then
        table.remove(M.fineAnimation.popups, i)
      end
    end
  end

  -- Update sentence countdown
  if M.sentenceActive then
    M.sentenceTimer = M.sentenceTimer - dt
    if M.sentenceTimer <= 0 then
      M.sentenceActive = false
      M.sentenceTimer = 0
    end
  end

  return notes
end

function M.startWarningDialogue()
  M.dialogueActive = true
  M.dialogueSpeaker = "Galaxy PD Officer"

  if M.stars <= 1 then
    M.dialogueLines = { "This is a warning. Do not fire on GPD patrol units." }
  else
    M.dialogueLines = { "This is your second warning. Stand down immediately." }
  end

  M.dialogueIndex = 1
  M.dialogueChoices = {
    { text = "Oops, sorry about that.", callback = "apologize" },
    { text = "Sayonara!", callback = "double_down" },
  }
  M.dialogueChoiceIndex = 1
end

function M.startFineDialogue(notes)
  M.dialogueActive = true
  M.dialogueSpeaker = "Galaxy PD Officer"

  local fineTotal = M.destroyedNormal * 10 + M.destroyedBig * 20 + M.destroyedMega * 40

  M.dialogueLines = {
    "You are charged with damaging GPD property totaling the amount of " .. fineTotal .. " Notes."
  }
  M.dialogueIndex = 1
  M.dialogueChoices = nil
  M.dialogueChoiceIndex = 1

  -- Start fine deduction animation
  M.fineAnimation = {
    total = fineTotal,
    paid = 0,
    timer = 0,
    perTick = 10,
    popups = {},
  }
end

function M.advanceDialogue(width, height, notes)
  if not M.dialogueActive then return notes end

  -- Block advancing if sentence countdown is active
  if M.sentenceActive and M.sentenceTimer > 0 then
    return notes
  end

  -- If sentence just finished, auto-advance to next line
  if M.sentenceActive and M.sentenceTimer <= 0 then
    M.sentenceActive = false
    if M.dialogueCallback then
      local cb = M.dialogueCallback
      M.dialogueCallback = nil
      cb()
    end
    return notes
  end

  if M.dialogueChoices then
    local choice = M.dialogueChoices[M.dialogueChoiceIndex]
    if choice.callback == "apologize" then
      -- Clear wanted
      M.dialogueActive = false
      M.dialogueChoices = nil
      M.warningGiven = true
      M.postWarningShot = true  -- Next shot = instant 3 stars

      -- Show response
      M.dialogueActive = true
      M.dialogueSpeaker = "Galaxy PD Officer"
      M.dialogueLines = { "Don't let it happen again." }
      M.dialogueIndex = 1
      M.dialogueChoices = nil
      M.dialogueCallback = function()
        M.stars = 0
        M.clearAllPatrols()
        M.bustedState = nil
        M.dialogueActive = false
        M.postWarningShot = true
        M.warningCatch = false
      end

    elseif choice.callback == "double_down" then
      -- Sayonara - instant 3 stars
      M.dialogueActive = false
      M.dialogueChoices = nil
      M.doubledDown = true
      M.warningCatch = false

      M.dialogueActive = true
      M.dialogueSpeaker = "Player"
      M.dialogueLines = { "Sayonara!" }
      M.dialogueIndex = 1
      M.dialogueChoices = nil
      M.dialogueCallback = function()
        M.bustedState = nil
        M.dialogueActive = false
        M.escalateTo(3, width, height)
      end
    end
  elseif M.dialogueCallback then
    local cb = M.dialogueCallback
    M.dialogueCallback = nil
    cb()
  else
    -- Check if fine animation is done
    if M.fineAnimation and M.fineAnimation.paid >= M.fineAnimation.total then
      -- Fine paid (or player went broke), continue dialogue
      if M.stars >= 4 then
          -- Mega bust - 2 minute sentence
          M.dialogueActive = true
          M.dialogueSpeaker = "Galaxy PD Officer"
          M.dialogueLines = { "These Mega Patrol Robots are expensive. This deserves a more severe sentence." }
          M.dialogueIndex = 1
          M.dialogueChoices = nil
          M.sentenceActive = true
          M.sentenceTimer = 120  -- 2 minutes
          M.dialogueCallback = function()
            M.dialogueActive = true
            M.dialogueSpeaker = "Galaxy PD Officer"
            M.dialogueLines = { "You are reeeealllly pushing your luck. Don't let it happen again...or else." }
            M.dialogueIndex = 1
            M.dialogueChoices = nil
            M.dialogueCallback = function()
              M.stars = 0
              M.clearAllPatrols()
              M.bustedState = nil
              M.dialogueActive = false
              M.sentenceActive = false
              M.sendToMixiaPD = true
            end
          end
        else
          M.dialogueActive = true
          M.dialogueSpeaker = "Galaxy PD Officer"

          if M.fineAnimation.playerBroke then
            M.dialogueLines = { "Well, we'll let you off this time. But if you continue there will be consequences." }
          else
            M.dialogueLines = { "You are free to go. Don't let it happen again." }
          end
          M.dialogueIndex = 1
          M.dialogueChoices = nil
          M.dialogueCallback = function()
            M.stars = 0
            M.clearAllPatrols()
            M.bustedState = nil
            M.dialogueActive = false
            M.sendToMixiaPD = true
          end
        end
    elseif M.fineAnimation then
      -- Still paying, skip
    else
      -- Simple advance
      M.dialogueIndex = M.dialogueIndex + 1
      if M.dialogueIndex > #M.dialogueLines then
        if M.dialogueCallback then
          local cb = M.dialogueCallback
          M.dialogueCallback = nil
          cb()
        else
          M.dialogueActive = false
          M.bustedState = nil
        end
      end
    end
  end

  return notes
end

function M.clearAllPatrols()
  M.patrols = {}
  M.destroyedNormal = 0
  M.destroyedBig = 0
  M.destroyedMega = 0
  M.totalHitsOnPatrols = 0
  M.postWarningShot = false
  M.warningGiven = false
  M.doubledDown = false
  M.agentActive = false
end

function M.clearWantedOnLand()
  M.stars = 0
  M.clearAllPatrols()
  M.bustedState = nil
  M.dialogueActive = false
  M.warningCatch = false
  M.sendToMixiaPD = false
end

function M.onAgentDestroyedPlayer(agentPatrol)
  M.agentSayonara = true
  M.agentSayonaraTimer = 0
  M.agentWarpTimer = 0
end

function M.updateAgentSayonara(dt)
  if not M.agentSayonara then return false end
  M.agentSayonaraTimer = M.agentSayonaraTimer + dt

  if M.agentSayonaraTimer > 2.0 then
    -- Start warp out
    M.agentWarpTimer = M.agentWarpTimer + dt
    if M.agentWarpTimer > 1.5 then
      M.agentSayonara = false
      -- Clear agent
      for i = #M.patrols, 1, -1 do
        if M.patrols[i].patrolType == patrol.TYPE_AGENT then
          table.remove(M.patrols, i)
        end
      end
      return true  -- done
    end
  end
  return false
end

-- Get total fine amount
function M.getFineTotal()
  return M.destroyedNormal * 10 + M.destroyedBig * 20 + M.destroyedMega * 40
end

return M

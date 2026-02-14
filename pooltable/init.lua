-- pooltable/init.lua
-- 8-Ball Pool minigame (casino-style, matching Blackjack/Roulette pattern)
-- States: betting → racking → aiming → shooting → evaluating → (opponent_turn →) → game_over

local M = {}

local poolTable = require("pooltable.table")
local ballsMod = require("pooltable.balls")
local physics = require("pooltable.physics")
local cueMod = require("pooltable.cue")
local creditsMod = require("pooltable.credits")
local audio = require("pooltable.audio")
local ui = require("pooltable.ui")
local winFx = require("casino_win_fx")

local SCREEN_W = 1366
local SCREEN_H = 768

local gameState = {}

-- AI opponent timing
local AI_THINK_MIN = 1.0
local AI_THINK_MAX = 2.5
local AI_POWER_MIN = 0.3
local AI_POWER_MAX = 0.85

function M.load(startingCredits)
  math.randomseed(os.time())
  math.random(); math.random(); math.random()

  gameState.table = poolTable.new()
  gameState.balls = {}
  gameState.cue = cueMod.new()
  gameState.bank = creditsMod.new(startingCredits or 1000)
  gameState.state = "betting"
  gameState.result = nil
  gameState.payout = 0
  gameState.isPlayerTurn = true
  gameState.playerType = nil     -- "solids" or "stripes" (assigned on first pocket)
  gameState.opponentType = nil
  gameState.firstPocket = true   -- true until first ball is pocketed (assignment pending)
  gameState.shotCount = 0
  gameState.betAmount = 0
  gameState.foulThisTurn = false
  gameState.consecutivePlayerPockets = 0

  -- AI opponent state
  gameState.aiTimer = 0
  gameState.aiAimed = false
  gameState.aiAngle = 0
  gameState.aiPower = 0

  audio.load()
  ui.load()
end

function M.getCredits()
  return gameState.bank.balance
end

-- ─── GAME LOGIC ──────────────────────────────────────────────

local function rackNewGame()
  gameState.balls = ballsMod.rackBalls(gameState.table)
  gameState.cue = cueMod.new()
  gameState.state = "aiming"
  gameState.isPlayerTurn = true
  gameState.playerType = nil
  gameState.opponentType = nil
  gameState.firstPocket = true
  gameState.result = nil
  gameState.payout = 0
  gameState.shotCount = 0
  gameState.foulThisTurn = false
  gameState.consecutivePlayerPockets = 0
  audio.playRack()
end

local function assignBallType(pocketedBall)
  if gameState.isPlayerTurn then
    if ballsMod.isSolid(pocketedBall.id) then
      gameState.playerType = "solids"
      gameState.opponentType = "stripes"
    else
      gameState.playerType = "stripes"
      gameState.opponentType = "solids"
    end
  else
    if ballsMod.isSolid(pocketedBall.id) then
      gameState.opponentType = "solids"
      gameState.playerType = "stripes"
    else
      gameState.opponentType = "stripes"
      gameState.playerType = "solids"
    end
  end
  gameState.firstPocket = false
end

local function isPlayerBall(ballId)
  if not gameState.playerType then return false end
  if gameState.playerType == "solids" then
    return ballsMod.isSolid(ballId)
  else
    return ballsMod.isStripe(ballId)
  end
end

local function isOpponentBall(ballId)
  if not gameState.opponentType then return false end
  if gameState.opponentType == "solids" then
    return ballsMod.isSolid(ballId)
  else
    return ballsMod.isStripe(ballId)
  end
end

local function canShoot8Ball()
  -- Player can only shoot the 8-ball when all their balls are pocketed
  if not gameState.playerType then return false end
  return ballsMod.allPocketed(gameState.balls, gameState.playerType)
end

local function handlePocketedBalls(pocketed)
  local cueBallPocketed = false
  local eightBallPocketed = false
  local playerPocketed = false
  local opponentPocketed = false

  for _, b in ipairs(pocketed) do
    audio.playPocket()

    if ballsMod.isCueBall(b.id) then
      cueBallPocketed = true
    elseif ballsMod.is8Ball(b.id) then
      eightBallPocketed = true
    else
      -- Assign ball types on first pocket
      if gameState.firstPocket then
        assignBallType(b)
      end

      if isPlayerBall(b.id) then
        if gameState.isPlayerTurn then
          playerPocketed = true
        end
      elseif isOpponentBall(b.id) then
        if not gameState.isPlayerTurn then
          playerPocketed = true  -- opponent pocketed their own ball
        else
          opponentPocketed = true  -- player pocketed opponent's ball (foul-like)
        end
      end
    end
  end

  -- Handle 8-ball being pocketed
  if eightBallPocketed then
    if gameState.isPlayerTurn then
      if cueBallPocketed then
        -- Scratch on 8-ball = loss
        gameState.result = "Scratch on the 8-ball! You lose!"
        gameState.state = "game_over"
        audio.playLose()
        return
      end
      if canShoot8Ball() then
        -- Player sank 8-ball legally = WIN!
        local multiplier = 2
        gameState.payout = gameState.betAmount * multiplier
        creditsMod.addWinnings(gameState.bank, gameState.payout)
        gameState.result = "You sank the 8-ball! You win!"
        gameState.state = "game_over"
        audio.playWin()
        winFx.startWin(gameState.payout, gameState.betAmount,
          gameState.bank.balance - gameState.payout, SCREEN_W / 2, SCREEN_H / 2 - 80)
        return
      else
        -- Premature 8-ball = loss
        gameState.result = "8-ball pocketed too early! You lose!"
        gameState.state = "game_over"
        audio.playLose()
        return
      end
    else
      -- Opponent sank 8-ball
      if canShoot8Ball() then
        -- Opponent won (player loses)
        gameState.result = "Opponent sank the 8-ball. You lose!"
        gameState.state = "game_over"
        audio.playLose()
        return
      else
        -- Opponent foul: sank 8-ball early = player wins!
        local multiplier = 2
        gameState.payout = gameState.betAmount * multiplier
        creditsMod.addWinnings(gameState.bank, gameState.payout)
        gameState.result = "Opponent sank 8-ball early! You win!"
        gameState.state = "game_over"
        audio.playWin()
        winFx.startWin(gameState.payout, gameState.betAmount,
          gameState.bank.balance - gameState.payout, SCREEN_W / 2, SCREEN_H / 2 - 80)
        return
      end
    end
  end

  -- Handle cue ball pocketed (scratch)
  if cueBallPocketed then
    gameState.foulThisTurn = true
    -- Reset cue ball for placement
    local cueBall = ballsMod.getCueBall(gameState.balls)
    if cueBall then
      cueBall.active = true
      cueBall.pocketed = false
      cueBall.vx = 0
      cueBall.vy = 0
      -- Will be placed by other player
    end
  end

  -- Track consecutive pockets for turn continuation
  if playerPocketed and gameState.isPlayerTurn and not cueBallPocketed then
    gameState.consecutivePlayerPockets = gameState.consecutivePlayerPockets + 1
  end
end

local function switchTurn()
  if gameState.foulThisTurn then
    -- Foul: other player gets ball-in-hand
    gameState.isPlayerTurn = not gameState.isPlayerTurn
    gameState.state = "placing_cue"
    gameState.foulThisTurn = false
    gameState.consecutivePlayerPockets = 0
  elseif gameState.consecutivePlayerPockets > 0 and gameState.isPlayerTurn then
    -- Player pocketed their ball(s), gets to go again
    gameState.state = "aiming"
    gameState.consecutivePlayerPockets = 0
    gameState.cue = cueMod.new()
  else
    -- Normal turn switch
    gameState.isPlayerTurn = not gameState.isPlayerTurn
    gameState.consecutivePlayerPockets = 0

    if gameState.isPlayerTurn then
      gameState.state = "aiming"
      gameState.cue = cueMod.new()
    else
      gameState.state = "opponent_turn"
      gameState.aiTimer = AI_THINK_MIN + math.random() * (AI_THINK_MAX - AI_THINK_MIN)
      gameState.aiAimed = false
    end
  end
end

local function aiTakeShot()
  -- Simple AI: aim at a random active target ball
  local cueBall = ballsMod.getCueBall(gameState.balls)
  if not cueBall or not cueBall.active then return end

  local targets = {}
  for _, b in ipairs(gameState.balls) do
    if b.active and b.id ~= 0 then
      if gameState.opponentType then
        -- Prefer opponent's own balls
        if (gameState.opponentType == "solids" and ballsMod.isSolid(b.id)) or
           (gameState.opponentType == "stripes" and ballsMod.isStripe(b.id)) then
          table.insert(targets, b)
        end
        -- If all own balls pocketed, target 8-ball
        if ballsMod.allPocketed(gameState.balls, gameState.opponentType) and ballsMod.is8Ball(b.id) then
          targets = {b}
          break
        end
      else
        -- No assignment yet, target any non-8 ball
        if not ballsMod.is8Ball(b.id) then
          table.insert(targets, b)
        end
      end
    end
  end

  if #targets == 0 then
    -- Fallback: aim at any active ball
    for _, b in ipairs(gameState.balls) do
      if b.active and b.id ~= 0 then
        table.insert(targets, b)
      end
    end
  end

  if #targets > 0 then
    local target = targets[math.random(#targets)]
    -- Add slight inaccuracy
    local dx = target.x - cueBall.x
    local dy = target.y - cueBall.y
    local angle = math.atan2(dy, dx) + (math.random() - 0.5) * 0.15
    local power = AI_POWER_MIN + math.random() * (AI_POWER_MAX - AI_POWER_MIN)

    physics.shoot(cueBall, power, angle)
    audio.playHit()
    gameState.shotCount = gameState.shotCount + 1
    gameState.state = "shooting"
  end
end

-- ─── UPDATE ──────────────────────────────────────────────────

function M.update(dt)
  winFx.update(dt)

  if gameState.state == "shooting" then
    -- Update physics
    local pocketed = physics.update(gameState.balls, gameState.table, dt)

    -- Handle newly pocketed balls
    if #pocketed > 0 then
      handlePocketedBalls(pocketed)
      if gameState.state == "game_over" then
        return
      end
    end

    -- Check if all balls stopped
    if not ballsMod.anyMoving(gameState.balls) then
      switchTurn()
    end

  elseif gameState.state == "aiming" and gameState.isPlayerTurn then
    local cueBall = ballsMod.getCueBall(gameState.balls)
    local mx, my = love.mouse.getPosition()
    cueMod.update(gameState.cue, dt, cueBall, mx, my)

  elseif gameState.state == "opponent_turn" then
    gameState.aiTimer = gameState.aiTimer - dt
    if gameState.aiTimer <= 0 then
      aiTakeShot()
    end

  elseif gameState.state == "placing_cue" then
    -- Waiting for cue ball placement (handled in mousepressed)
  end
end

-- ─── DRAW ────────────────────────────────────────────────────

function M.draw()
  love.graphics.setBackgroundColor(0.02, 0.08, 0.03)

  local shakeX, shakeY = winFx.getScreenShake()
  love.graphics.push()
  love.graphics.translate(shakeX, shakeY)

  winFx.drawGlow()

  ui.drawGameUI(gameState)

  winFx.drawParticles()
  if winFx.isActive() then
    winFx.drawWinText(SCREEN_W / 2, SCREEN_H / 2 - 80)
  end

  love.graphics.pop()
end

-- ─── INPUT ───────────────────────────────────────────────────

function M.keypressed(key)
  if key == "space" and winFx.isActive() then
    winFx.skip()
    return
  end

  if key == "up" then
    creditsMod.nextChip(gameState.bank)
  elseif key == "down" then
    creditsMod.prevChip(gameState.bank)
  end

  if gameState.state == "aiming" and gameState.isPlayerTurn then
    if key == "space" then
      cueMod.startCharge(gameState.cue)
    end
  end
end

function M.keyreleased(key)
  if gameState.state == "aiming" and gameState.isPlayerTurn then
    if key == "space" and gameState.cue.charging then
      local power = cueMod.releaseCharge(gameState.cue)
      if power > 0.02 then
        local cueBall = ballsMod.getCueBall(gameState.balls)
        if cueBall and cueBall.active then
          physics.shoot(cueBall, power, gameState.cue.angle)
          audio.playHit()
          gameState.shotCount = gameState.shotCount + 1
          gameState.state = "shooting"
          gameState.cue.visible = false
        end
      end
    end
  end
end

function M.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Check button clicks first
  local buttonName = ui.checkButtonClick(x, y)
  if buttonName then
    if buttonName == "play" then
      if creditsMod.placeBet(gameState.bank) then
        gameState.betAmount = gameState.bank.currentBet
        rackNewGame()
      end
    elseif buttonName == "betUp" then
      creditsMod.increaseBet(gameState.bank)
    elseif buttonName == "betDown" then
      creditsMod.decreaseBet(gameState.bank)
    elseif buttonName == "newGame" then
      gameState.state = "betting"
      gameState.bank.currentBet = 0
      gameState.result = nil
      gameState.payout = 0
    elseif buttonName == "quit" then
      -- Will be handled by escape key in main.lua
    end
    return
  end

  -- Cue ball placement
  if gameState.state == "placing_cue" then
    local tbl = gameState.table
    -- Only allow placement behind head string (first quarter)
    local headStringX = tbl.playX + tbl.playW * 0.25
    if x >= tbl.playX + ballsMod.BALL_RADIUS and x <= headStringX and
       y >= tbl.playY + ballsMod.BALL_RADIUS and y <= tbl.playY + tbl.playH - ballsMod.BALL_RADIUS then
      -- Check no ball overlaps
      local canPlace = true
      for _, b in ipairs(gameState.balls) do
        if b.active and b.id ~= 0 then
          local dx = x - b.x
          local dy = y - b.y
          if math.sqrt(dx * dx + dy * dy) < ballsMod.BALL_RADIUS * 2.5 then
            canPlace = false
            break
          end
        end
      end

      if canPlace then
        local cueBall = ballsMod.getCueBall(gameState.balls)
        if cueBall then
          cueBall.x = x
          cueBall.y = y
          cueBall.active = true
          cueBall.pocketed = false
          gameState.state = "aiming"
          gameState.cue = cueMod.new()
          gameState.cue.visible = true
        end
      end
    end
    return
  end

  -- Shot via mouse click (alternative to space bar)
  if gameState.state == "aiming" and gameState.isPlayerTurn then
    if not gameState.cue.charging then
      cueMod.startCharge(gameState.cue)
    else
      local power = cueMod.releaseCharge(gameState.cue)
      if power > 0.02 then
        local cueBall = ballsMod.getCueBall(gameState.balls)
        if cueBall and cueBall.active then
          physics.shoot(cueBall, power, gameState.cue.angle)
          audio.playHit()
          gameState.shotCount = gameState.shotCount + 1
          gameState.state = "shooting"
          gameState.cue.visible = false
        end
      end
    end
  end
end

return M

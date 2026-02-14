-- pooltable/audio.lua
-- Sound effect stubs for pool table game

local M = {}

function M.load()
  -- Audio would be loaded here (cue hit, ball collision, pocket, etc.)
end

function M.playHit()
  -- Cue strikes cue ball
end

function M.playCollision()
  -- Ball-to-ball collision
end

function M.playPocket()
  -- Ball drops into pocket
end

function M.playWin()
  -- Player wins the game
end

function M.playLose()
  -- Player loses (scratch on 8-ball, etc.)
end

function M.playRack()
  -- Balls being racked
end

return M

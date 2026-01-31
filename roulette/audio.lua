local M = {}

local sounds = {}

function M.load()
  -- Uncomment when audio assets are available:
  -- sounds.spin = love.audio.newSource("assets/roulette_spin.wav", "static")
  -- sounds.ball = love.audio.newSource("assets/ball_roll.wav", "static")
  -- sounds.win = love.audio.newSource("assets/win.wav", "static")
  -- sounds.place = love.audio.newSource("assets/chip_place.wav", "static")
end

function M.playSpin()
  -- if sounds.spin then sounds.spin:play() end
end

function M.playBall()
  -- if sounds.ball then sounds.ball:play() end
end

function M.playWin()
  -- if sounds.win then sounds.win:play() end
end

function M.playPlace()
  -- if sounds.place then sounds.place:play() end
end

return M

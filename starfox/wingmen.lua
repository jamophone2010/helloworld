local M = {}
local screen = require("starfox.screen")
M.wingmen = {}

local CALLOUT_DURATION = 3

function M.reset()
  M.callouts = {}
  M.wingmen = {
    {name = "Falco", x = 150, y = screen.HEIGHT - 80, message = nil},
    {name = "Slippy", x = screen.WIDTH - 150, y = screen.HEIGHT - 80, message = nil}
  }
end

function M.addCallout(speaker, message)
  table.insert(M.callouts, {
    speaker = speaker,
    message = message,
    timer = CALLOUT_DURATION
  })
end

function M.update(dt, playerX, playerY)
  for _, wingman in ipairs(M.wingmen) do
    local targetX = wingman == M.wingmen[1] and playerX - 100 or playerX + 100
    local targetY = playerY + 30

    wingman.x = wingman.x + (targetX - wingman.x) * dt * 2
    wingman.y = wingman.y + (targetY - wingman.y) * dt * 2

    wingman.x = math.max(30, math.min(screen.WIDTH - 30, wingman.x))
    wingman.y = math.max(100, math.min(screen.HEIGHT - 30, wingman.y))
  end

  for i = #M.callouts, 1, -1 do
    M.callouts[i].timer = M.callouts[i].timer - dt

    if M.callouts[i].timer <= 0 then
      table.remove(M.callouts, i)
    end
  end
end

function M.getCurrentCallout()
  if #M.callouts > 0 then
    return M.callouts[1]
  end
  return nil
end

function M.triggerEnemyWarning()
  local speakers = {"Falco", "Slippy"}
  M.addCallout(speakers[math.random(#speakers)], "Enemy approaching!")
end

function M.triggerBossWarning()
  M.addCallout("Falco", "Watch out, Fox!")
end

function M.triggerHelp()
  M.addCallout("Slippy", "He's on my tail!")
end

function M.triggerCover()
  M.addCallout("Falco", "I'll cover you!")
end

function M.triggerAlliesInbound()
  M.addCallout("Bill", "Fox! We're on our way!")
end

function M.triggerMothershipWarning()
  M.addCallout("Bill", "Take out that mothership!")
end

function M.triggerWarpRings()
  M.addCallout("Slippy", "Fox! There are warp rings ahead!")
end

function M.triggerWarpProgress()
  M.addCallout("Falco", "Keep going through those rings!")
end

function M.triggerWarpAlmost()
  M.addCallout("Slippy", "Just one more ring, Fox!")
end

function M.triggerWarpReady()
  M.addCallout("Falco", "Warp zone activated!")
end

function M.triggerRivalWarning()
  M.addCallout("Falco", "Star Wolf! Watch your six, Fox!")
end

function M.triggerCoreExposed()
  M.addCallout("Slippy", "The core is exposed! Hit it now!")
end

function M.triggerRivalReturn()
  M.addCallout("Falco", "Wolf's back! Don't let him escape!")
end

function M.triggerMazeWarning()
  M.addCallout("Slippy", "Careful Fox! Tight corridors ahead!")
end

function M.triggerVenomBossWarning()
  M.addCallout("Falco", "That's Andross's weapon! Take it out!")
end

return M

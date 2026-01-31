local M = {}

M.callouts = {}
M.wingmen = {}

local CALLOUT_DURATION = 3

function M.reset()
  M.callouts = {}
  M.wingmen = {
    {name = "Falco", x = 150, y = 520, message = nil},
    {name = "Slippy", x = 650, y = 520, message = nil}
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

    wingman.x = math.max(30, math.min(770, wingman.x))
    wingman.y = math.max(100, math.min(570, wingman.y))
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

return M

local M = {}

M.NOTES_TO_CREDITS = 100

function M.save(notes)
  local success, message = love.filesystem.write("save.dat", tostring(notes))
  if not success then
    print("Failed to save notes: " .. message)
  end
end

function M.load()
  local contents, _ = love.filesystem.read("save.dat")
  if contents then
    return tonumber(contents) or 0
  end
  return 0
end

function M.convertNotesToCredits(notes, amount)
  if notes >= amount then
    return notes - amount, amount * M.NOTES_TO_CREDITS
  end
  return notes, 0
end

return M

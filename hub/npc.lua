local M = {}

function M.new(name, x, y, dialogue)
  return {
    name = name,
    x = x,
    y = y,
    dialogue = dialogue,
    width = 24,
    height = 24
  }
end

return M

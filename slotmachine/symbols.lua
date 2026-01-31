local M = {}

M.SYMBOLS = {
  {id = "cherry", value = 1, color = {0.9, 0.1, 0.2}},
  {id = "lemon", value = 2, color = {1, 1, 0}},
  {id = "orange", value = 3, color = {1, 0.5, 0}},
  {id = "plum", value = 4, color = {0.5, 0, 0.5}},
  {id = "bar", value = 5, color = {0.3, 0.3, 0.3}},
  {id = "seven", value = 6, color = {1, 0, 0}},
  {id = "diamond", value = 7, color = {0, 0.8, 1}}
}

M.PAYLINES = {
  {name = "center", positions = {{1,2}, {2,2}, {3,2}}},
  {name = "top", positions = {{1,1}, {2,1}, {3,1}}},
  {name = "bottom", positions = {{1,3}, {2,3}, {3,3}}},
  {name = "diag_down", positions = {{1,1}, {2,2}, {3,3}}},
  {name = "diag_up", positions = {{1,3}, {2,2}, {3,1}}}
}

function M.getPayout(symbolId, betAmount)
  local multipliers = {
    cherry = 5,
    lemon = 10,
    orange = 10,
    plum = 10,
    bar = 25,
    seven = 50,
    diamond = 100
  }

  return (multipliers[symbolId] or 0) * betAmount
end

return M

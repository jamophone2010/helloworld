# Love2D + Lua Guidelines

## Architecture

- One responsibility per file
- `local M = {} ... return M` pattern
- Group related data in tables
- Simple state machines for screens
- main.lua: wire components only

## Code Style

- Default `local`, expose via return table
- Callbacks: `love.load`, `love.update(dt)`, `love.draw`, `love.keypressed(key)`
- Delta time: always multiply movement by `dt`
- Assets: load once in `love.load`, never in `update`/`draw`

## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.
-- `:checkhealth config`: every external tool this config leans on, probed
-- afresh, one section for the editor-wide features and one for the languages.
-- The table lives in config.deps; this is only its rendering. It replaced a
-- startup sweep that blocked for ~170 ms half a second after every launch.
local M = {}

local advice = {
  "Install it on PATH (mise, flox, or a system package); README.md, LSP installs, has the Mason names.",
}

local function render(title, entries)
  vim.health.start(title)
  for _, entry in ipairs(entries) do
    if entry.ok then
      vim.health.ok(entry.line)
    else
      vim.health.warn(entry.line, advice)
    end
  end
end

function M.check()
  local report = require("config.deps").report()
  render("Editor-wide tools", report.core)
  render("Language tools", report.languages)
end

return M

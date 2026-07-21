-- Headless test for the <leader>gm diff-base cycle in plugins/git.lua.
-- Run: nvim --headless -u NONE -l nvim/test/git_base_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/git_base_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local failures = {}
local function check(name, cond, detail)
  if cond then
    io.write("ok   - " .. name .. "\n")
  else
    io.write("FAIL - " .. name .. " :: " .. tostring(detail) .. "\n")
    table.insert(failures, name)
  end
end

-- Stub gitsigns: record every change_base call. plugins/git.lua only touches
-- change_base on this code path, so nothing else is needed.
local bases = {}
package.preload["gitsigns"] = function()
  return {
    change_base = function(ref, _)
      table.insert(bases, ref == nil and "<index>" or ref)
    end,
  }
end

-- Silence/capture notifications.
local notes = {}
vim.notify = function(msg)
  table.insert(notes, msg)
end

-- Scratch repo: commit A is the fake origin/master, commit B is a local
-- commit directly on master (the unpushed-commits scenario).
local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")
local function sh(args)
  local out = vim.fn.systemlist(args)
  assert(vim.v.shell_error == 0, table.concat(args, " ") .. " failed: " .. table.concat(out, "\n"))
  return out
end
local function git(args)
  return sh(vim.list_extend({ "git", "-C", repo }, args))
end
git({ "init", "-q", "-b", "master" })
git({ "config", "user.email", "t@t" })
git({ "config", "user.name", "t" })
sh({ "touch", repo .. "/f" })
git({ "add", "f" })
git({ "commit", "-q", "-m", "A" })
local sha_a = git({ "rev-parse", "HEAD" })[1]
git({ "update-ref", "refs/remotes/origin/master", sha_a })
git({ "commit", "-q", "--allow-empty", "-m", "B" })
local sha_b = git({ "rev-parse", "HEAD" })[1]
vim.cmd.cd(repo)

-- Pull the mapped functions out of the lazy spec's keys table.
local function load_maps()
  package.loaded["plugins.git"] = nil
  local spec = require("plugins.git")
  local maps = {}
  for _, k in ipairs(spec.keys) do
    maps[k[1]] = k[2]
  end
  return maps
end

-- On master with unpushed commits: smart first press goes straight to
-- origin/master, then the fixed cycle index -> merge-base -> origin -> index.
do
  local maps = load_maps()
  local gm = maps["<leader>gm"]

  gm()
  check("smart first press on master -> origin/master", bases[1] == "origin/master", bases[1])
  gm()
  check("second press -> index", bases[2] == "<index>", bases[2])
  gm()
  check("third press -> merge-base (HEAD on master)", bases[3] == sha_b, bases[3])
  gm()
  check("fourth press -> origin/master", bases[4] == "origin/master", bases[4])
  gm()
  check("fifth press -> index", bases[5] == "<index>", bases[5])
end

-- gM prompt: prefills origin/master at index on master; accepting a manual
-- ref applies it, and the next gm press restarts the cycle at index.
do
  local maps = load_maps()
  local prompted
  vim.ui.input = function(opts, cb)
    prompted = opts.default
    cb("v1.0")
  end
  bases = {}
  maps["<leader>gM"]()
  check("gM prefills origin/master on master", prompted == "origin/master", prompted)
  check("gM applies the entered ref", bases[1] == "v1.0", bases[1])
  maps["<leader>gm"]()
  check("gm after manual base -> index", bases[2] == "<index>", bases[2])
end

-- On a feature branch: smart first press goes to the merge-base with master.
do
  git({ "checkout", "-q", "-b", "feature" })
  git({ "commit", "-q", "--allow-empty", "-m", "C" })
  local maps = load_maps()
  bases = {}
  maps["<leader>gm"]()
  check("smart first press on feature -> merge-base sha", bases[1] == sha_b, bases[1])
end

if #failures > 0 then
  vim.cmd("cquit 1")
end
vim.cmd("quit")

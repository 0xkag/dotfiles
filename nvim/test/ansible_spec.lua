-- Headless test for config.ansible: which YAML files are tagged yaml.ansible.
-- Run: nvim/test/run.sh ansible
--
-- ansiblels only attaches to `yaml.ansible`, which nothing in Neovim sets, so
-- playbooks opened as plain `yaml` and the server never started. Files are
-- tagged by where Ansible lays them out; other YAML in the same repo must stay
-- `yaml` so yamlls and its schemas keep it.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/ansible_spec.lua$", "")
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

local ansible = require("config.ansible")
ansible.setup()

local root = vim.fn.tempname()
local function touch(rel)
  local path = root .. "/" .. rel
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ "---" }, path)
  return path
end

local function filetype_of(rel)
  return vim.filetype.match({ filename = touch(rel) })
end

touch("ansible.cfg")

for _, rel in ipairs({
  "playbooks/site.yml",
  "playbook/deploy.yaml",
  "roles/web/tasks/main.yml",
  "roles/web/handlers/main.yaml",
  "roles/web/defaults/main.yml",
  "roles/web/vars/main.yml",
  "roles/web/meta/main.yml",
  "group_vars/all",
  "group_vars/web.yml",
  "host_vars/db1/vars.yml",
  "site.yml",
}) do
  check(rel .. " is yaml.ansible", filetype_of(rel) == "yaml.ansible", filetype_of(rel))
end

for _, rel in ipairs({
  ".github/workflows/ci.yml",
  "roles/web/templates/config.yml",
  "docs/compose.yaml",
}) do
  check(rel .. " stays yaml", filetype_of(rel) == "yaml", filetype_of(rel))
end

-- Without an ansible.cfg beside it, a top-level YAML file is just YAML.
do
  local elsewhere = vim.fn.tempname() .. "/site.yml"
  vim.fn.mkdir(vim.fs.dirname(elsewhere), "p")
  vim.fn.writefile({ "---" }, elsewhere)
  local ft = vim.filetype.match({ filename = elsewhere })
  check("site.yml without ansible.cfg stays yaml", ft == "yaml", ft)
end

check("treesitter parses yaml.ansible as yaml", vim.treesitter.language.get_lang("yaml.ansible") == "yaml", vim.treesitter.language.get_lang("yaml.ansible"))

local linters = require("config.linters")
local picked = linters.for_filetype("yaml.ansible", function()
  return true
end)
check("yaml.ansible gets yamllint", vim.deep_equal(picked, { "yamllint" }), vim.inspect(picked))

vim.fn.delete(root, "rf")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end

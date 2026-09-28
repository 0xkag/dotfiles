-- Ansible YAML detection. ansiblels only attaches to the `yaml.ansible`
-- filetype and nothing in Neovim sets it, so playbooks and roles opened as
-- plain `yaml` and the server never started. Only files where Ansible lays
-- them out are tagged: a role's tasks/handlers/defaults/vars/meta, anything
-- under playbooks/, group_vars/ or host_vars/, and a YAML file sitting next to
-- an ansible.cfg (the usual place for top-level playbooks). Other YAML in an
-- Ansible repo (CI config, compose files) stays `yaml` for yamlls. Treesitter
-- maps `yaml.ansible` to the yaml parser on its own.
local M = {}

local uv = vim.uv or vim.loop

local role_dirs = { "tasks", "handlers", "defaults", "vars", "meta" }

-- Whether `path` (absolute) is an Ansible file by where it lives.
function M.is_ansible(path)
  path = vim.fs.normalize(path)
  if path:find("/group_vars/", 1, true) or path:find("/host_vars/", 1, true) then
    return true
  end
  if not path:match("%.ya?ml$") then
    return false
  end
  if path:find("/playbooks?/") then
    return true
  end
  for _, dir in ipairs(role_dirs) do
    if path:find("/roles/[^/]+/" .. dir .. "/") then
      return true
    end
  end
  return uv.fs_stat(vim.fs.joinpath(vim.fs.dirname(path), "ansible.cfg")) ~= nil
end

local function detect(path)
  if M.is_ansible(path) then
    return "yaml.ansible"
  end
end

function M.setup()
  -- A function returning nil falls through to the normal detection, so YAML
  -- that is not Ansible stays `yaml`. group_vars/host_vars files often have no
  -- extension, hence the patterns of their own.
  vim.filetype.add({
    pattern = {
      [".*%.ya?ml"] = detect,
      [".*/group_vars/.*"] = detect,
      [".*/host_vars/.*"] = detect,
    },
  })
end

return M

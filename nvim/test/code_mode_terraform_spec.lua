-- Headless test harness for config.code_mode.terraform pure helpers
-- (interpolation expansion and candidate-path resolution). Run:
--   nvim --headless -u NONE -l nvim/test/code_mode_terraform_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/code_mode_terraform_spec.lua$", "")
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

local tf = require("config.code_mode.terraform")

local ctx = {
  module_dir = "/repo/modules/backups",
  root = "/repo",
}

-- expand_interpolations(): resolves the static path.* refs, tolerates inner
-- whitespace, and bails on anything dynamic.
do
  check(
    "expand path.module",
    tf.expand_interpolations("${path.module}/policies/kms.tftpl", ctx)
      == "/repo/modules/backups/policies/kms.tftpl",
    tf.expand_interpolations("${path.module}/policies/kms.tftpl", ctx)
  )
  check(
    "expand path.root",
    tf.expand_interpolations("${path.root}/modules/foo/main.tf", ctx)
      == "/repo/modules/foo/main.tf"
  )
  check(
    "expand path.cwd as root",
    tf.expand_interpolations("${path.cwd}/x.json", ctx) == "/repo/x.json"
  )
  check(
    "expand tolerates inner whitespace",
    tf.expand_interpolations("${ path.module }/a.txt", ctx) == "/repo/modules/backups/a.txt"
  )
  check("expand leaves plain relative untouched", tf.expand_interpolations("./data/x.json", ctx) == "./data/x.json")
  check("expand bails on dynamic var", tf.expand_interpolations("${var.name}.json", ctx) == nil)
end

-- resolve_candidate(): module-dir first, then root; absolute as-is; only
-- existing files. stat is faked so no real filesystem is touched.
do
  -- existing maps path -> type ("file"/"directory"); a list entry defaults to
  -- "file".
  local function faker(existing)
    local types = {}
    for k, v in pairs(existing) do
      if type(k) == "number" then
        types[v] = "file"
      else
        types[k] = v
      end
    end
    return function(p)
      if types[p] then
        return { type = types[p] }
      end
      return nil
    end
  end

  -- Relative path that exists under the module dir.
  local got = tf.resolve_candidate(
    "policies/kms.tftpl",
    ctx,
    faker({ "/repo/modules/backups/policies/kms.tftpl" })
  )
  check("resolve relative under module dir", got == "/repo/modules/backups/policies/kms.tftpl", got)

  -- Relative path that exists only under the root (module-dir miss).
  got = tf.resolve_candidate("shared/vars.tf", ctx, faker({ "/repo/shared/vars.tf" }))
  check("resolve relative falls back to root", got == "/repo/shared/vars.tf", got)

  -- Absolute path taken as-is.
  got = tf.resolve_candidate("/etc/hosts", ctx, faker({ "/etc/hosts" }))
  check("resolve absolute", got == "/etc/hosts", got)

  -- Nothing exists -> nil.
  got = tf.resolve_candidate("nope/missing.tf", ctx, faker({}))
  check("resolve missing -> nil", got == nil, tostring(got))

  -- A module source resolving to a directory is returned with its type, so the
  -- caller can open the module's entry file.
  local dir, kind = tf.resolve_candidate(
    "../shared-module",
    ctx,
    faker({ ["/repo/modules/shared-module"] = "directory" })
  )
  check("resolve returns directory path", dir == "/repo/modules/shared-module", dir)
  check("resolve reports directory type", kind == "directory", tostring(kind))

  -- A file resolves with type "file".
  local _, ftype = tf.resolve_candidate("policies/kms.tftpl", ctx, faker({ "/repo/modules/backups/policies/kms.tftpl" }))
  check("resolve reports file type", ftype == "file", tostring(ftype))
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end

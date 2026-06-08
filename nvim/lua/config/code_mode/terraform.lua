-- Terraform code-mode helpers: validate, lint, fmt-check.
local M = {}

local shared = require("config.code_mode.shared")

function M.terraform_validate()
  shared.project_command("terraform validate", "terraform validate -no-color", {
    last_key = "terraform_validate",
  })
end

function M.terraform_lint()
  shared.project_command("tflint", "tflint --format compact", {
    last_key = "terraform_lint",
  })
end

function M.terraform_fmt_check()
  shared.project_command("terraform fmt", "terraform fmt -check -diff=false", {
    last_key = "terraform_fmt",
  })
end

return M

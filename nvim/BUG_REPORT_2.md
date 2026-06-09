# Bug Report 2 — terraform-ls

File at: https://github.com/hashicorp/terraform-ls/issues/new/choose (use the
"Bug report" form)

**Title:** terraform-ls emits a semantic token with a negative/out-of-range
`deltaStart` (encoded as uint32 `4294967253`)

## Language Server Version

`0.32.7` (linux/amd64, go1.21.5)

## Terraform Version

`Terraform v1.13.2 on linux_amd64`

## Client Version

Neovim 0.12.2, built-in `vim.lsp` client with native semantic-token support
(`vim.lsp.semantic_tokens`). No third-party LSP plugin.

## Terraform Configuration

```terraform
# Occurs in a large monorepo opening many module files at once
# (~88 .tf/.tfvars/.tftpl files across ~14 modules under a single workspace
# root). Not reduced to a single minimal .tf yet — the malformed token
# appears in the full-document semantic-tokens response for the workspace;
# happy to share a sanitized config/ZIP if helpful for narrowing it down.
```

## Steps to Reproduce

1. Open a large terraform workspace (many modules under one root) in an LSP
   client that requests `textDocument/semanticTokens/full` and renders the
   response.
2. Let terraform-ls return semantic tokens for a `.tf` document.
3. Inspect the returned token `data` array (groups of 5 ints:
   `deltaLine, deltaStartChar, length, tokenType, tokenModifiers`).

## Expected Behavior

Every token's `deltaStartChar` and `length` should be valid non-negative
offsets within the document, per the
[LSP semantic tokens spec](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_semanticTokens)
(deltas are relative and tokens must not span lines).

## Actual Behavior

At least one token is emitted with `deltaStartChar = 4294967253`, which is
`2^32 - 43` — i.e. a small negative delta (`-43`) that has wrapped around as an
unsigned 32-bit integer. A spec-compliant `deltaStartChar` can never
legitimately be ~4.29 billion. This looks like a signed->unsigned encoding bug
(or an unclamped negative relative offset) in the semantic-tokens encoder.

Captured directly from the wire by logging the `data` array in the client's
`semanticTokens/full` response handler:

```
n_tokens=363
max_delta_start=4294967253   worst tuple: {dl=0, ds=4294967253, len=3, type=8, mod=0}
max_length=93                (lengths look fine; deltaStart is the bad field)
buf_lines=272
```

Downstream impact: this wrapped value causes Neovim's
`vim.lsp.semantic_tokens` to spin its range-extension loop billions of times
and hang the editor (reporting that separately to Neovim, since it should also
bound the loop). But the root cause here is terraform-ls emitting an
out-of-range delta.

## Gist

(Optional — can attach a `-log-file` debug log and the raw token array via Gist
on request; omitted pending confirmation of which document/region produces the
bad token.)

## Workarounds

Client-side: clamp each token's `deltaStartChar`/`length` to the buffer's
longest line before processing, which neutralizes the wrapped value without
disabling semantic tokens.

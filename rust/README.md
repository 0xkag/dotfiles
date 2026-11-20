# rust

Rust comes from mise: `rust` in `mise/config.toml` installs the latest
stable toolchain through rustup, with the `rust-analyzer` component (for
editors and Claude Code's rust-analyzer-lsp plugin).  `cargo`, `rustc`,
`rustup` and `rust-analyzer` run through mise shims; `~/.cargo/bin` is not
on PATH.

## Projects that pin a toolchain

A project's `rust-toolchain.toml` (rustup's counterpart to
`.python-version`) is ignored here.  The mise shims set `RUSTUP_TOOLCHAIN`
to the global version, and rustup ranks that variable above
`rust-toolchain.toml`, so a plain `cargo build` uses the global toolchain.
A project that needs nightly then fails with errors like "feature may not
be used on the stable release channel".

For a one-off command, name the toolchain; `+toolchain` outranks
`RUSTUP_TOOLCHAIN`:

    cargo +nightly-2026-11-01 build

To make the pin stick for every shim, rust-analyzer included, give the
project a local mise config with the `channel` from its
`rust-toolchain.toml`, then lock and install it from the project root:

    cat > mise.local.toml <<'EOF'
    [tools]
    rust = { version = "nightly-2026-11-01", components = "rust-analyzer" }
    EOF
    mise trust mise.local.toml
    mise-lock
    mise install

`mise-lock` without `-g` writes `mise.local.lock` next to it.  Keep both
files out of the project's history: add them to `.git/info/exclude` unless
the project already ignores them.

Do not turn on mise's own `rust-toolchain.toml` support
(`idiomatic_version_file_enable_tools`) instead.  With `paranoid = true`
and `locked = true`, every project with the file would then need
`mise trust` and its own lockfile before any Rust command works.

# AtCoder C++ (Nix Flake)

A contest-only C++ environment. All tooling is exposed through a single `ac`
dispatcher so the workflow is the same whether you use `nix develop` or direnv.

## Setup

1. `cd /path/to/atcoder`
2. `direnv allow` (first time only), or run `nix develop` directly
3. `oj login https://atcoder.jp/ --check`

The `ac` command and zsh/bash completion are set up by the `devShell`
`shellHook`, so use `nix develop` (or direnv), not plain `nix shell`.

## Commands

Everything goes through `ac <command>`. Run `ac --help` for the list.

- `ac new <contest> [task]` — create task directories. Omit `<task>` to fetch
  **all** tasks for the contest automatically (non-existent URLs skipped);
  specify a task label to create a single task.
- `ac build [src]` — build only (no tests). Shortcut for `ac test --build-only`.
- `ac test [src]` — build and run `oj` tests. Debug build (`-g -O0`) is the
  default; on a runtime error it re-runs the failing case under `gdb` and
  prints a backtrace (`bt`). Use `--full` for variable dumps (`bt full`).
- `ac submit [src] [url]` — submit the current task. Default backend is
  `--auto` (`oj` first, then direct HTTP fallback).
- `ac submit-direct [src] [url]` — submit via direct HTTP using `cookie.jar`.
- `ac cookie-import [cookies.txt] [cookie.jar]` — convert Netscape
  `cookies.txt` into an `oj`-compatible `cookie.jar`.

### Common flags (build / test)

- `--debug` build with `-g -O0` (default)
- `--release` build with `-O2`
- `--build-only` build only, skip `oj` tests
- `--full` print full gdb backtrace (`bt full`) on runtime error

## Recommended contest flow

```bash
# 1) create all tasks at the start
ac new abc452

# 2) solve each task
cd work/abc452/a
ac test          # build + run samples; shows a gdb backtrace on runtime error
ac submit

cd ../b
ac test
ac submit
```

There is intentionally no `ac test-all` / `ac submit-all`: testing and
submitting are done per task.

## Shell completion

`nix develop` launches zsh (wrapping your `~/.zshrc`) and prepends the
project's `completions/` directory to `fpath` before `compinit` runs, so
`ac <Tab>` completes subcommands and `ac test --<Tab>` completes options.

A bash completion script is also provided at `completions/ac.bash` for users
who source it manually.

## AtCoder Library

The dev shell includes AtCoder Library (`ac-library`):

```cpp
#include <atcoder/all>
using namespace atcoder;
```

`ac test`, `ac build`, and clangd inherit the include path from
`nix develop` / direnv.

## Project layout

- `bin/ac` — the dispatcher entry point (on `$PATH`)
- `libexec/ac-*` — per-command implementations (not on `$PATH`)
- `completions/` — `_ac` (zsh) and `ac.bash` completion
- `config/nvim-atcoder/init.lua` — contest-mode Neovim config (installed to
  `~/.config/nvim-atcoder/` by the dev shell)
- `template/main.cpp` — source template copied into new task dirs
- `patches/oj/sitecustomize.py` — runtime workaround for `oj` submission
- `flake.nix` — dev shell definition

## Contest operation

- Use only this shell/directory during the contest.
- Keep AI code generation and AI completion disabled.
- Use only non-AI tools (`g++`, `oj`, shell scripts).

## Notes

- `ac submit` includes a runtime workaround for AtCoder's memory unit notation
  (`MiB`/`KiB`) so submission works with the currently packaged
  `online-judge-api-client`.
- `ac submit-direct` default language selection is fixed to C++ (GCC family).
- `ac submit-direct` can be run without arguments in a task directory
  (`main.cpp` + `.task-url`); `--dry-run` checks parsing/language selection
  without posting.
- If AtCoder injects Cloudflare Turnstile on submit, pure terminal HTTP submit
  is blocked because a browser-issued Turnstile token is required.
- To force one backend, use `ac submit --oj` or `ac submit --direct` (or
  `AC_SUBMIT_BACKEND=oj|direct|auto`).
- If direct submit fails due to authentication/challenge, export browser
  cookies (`cookies.txt`) and run `ac cookie-import` to refresh `cookie.jar`.

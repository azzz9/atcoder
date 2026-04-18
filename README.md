# AtCoder C++ (Nix Flake)

This directory provides a contest-only C++ environment.

## Setup

1. `cd /path/to/atcoder`
2. `direnv allow` (first time only)
3. `nix develop` (if direnv is not active)
4. `oj login https://atcoder.jp/ --check`

`ac-*` commands are added by `devShell`'s `shellHook`, so use `nix develop` (or direnv), not plain `nix shell`.

## Commands

- `ac-new <contest> <task> [dir]` (create one task)
- `ac-new-all <contest> [auto|count|tasks] [base_dir]`
- `ac-test [src]` (run for current task only)
- `ac-submit [--auto|--oj|--direct] [src] [url]` (submit current task only)
- `ac-cookie-import [cookies.txt] [cookie.jar]` (Netscape cookies.txt -> oj cookie.jar)

## ac-new-all

Default (`auto`) tries to detect existing task labels from AtCoder and creates only those.

```bash
ac-new-all abc452
```

If auto detection fails or you want manual control, specify count or labels:

```bash
ac-new-all abc452 6            # a..f
ac-new-all abc452 a,b,c,d,e,f  # explicit list
```

## Recommended contest flow

```bash
# 1) create all tasks at start
ac-new-all abc452

# 2) solve each task separately
cd work/abc452/a
ac-test
ac-submit

cd ../b
ac-test
ac-submit
```

Note:

- There is intentionally no `ac-test-all` / `ac-submit-all`.
- Test and submit are expected to be done per task.

## Contest operation

- Use only this shell/directory during the contest.
- Keep AI code generation and AI completion disabled.
- Use only non-AI tools (`g++`, `oj`, shell scripts).

## Notes

- `ac-submit` includes a runtime workaround for AtCoder's memory unit notation (`MiB`/`KiB`) so submission works with the currently packaged `online-judge-api-client`.
- `ac-submit` default backend is `--auto`: it tries `oj submit` first, and if that fails it falls back to direct HTTP submission (`ac-submit-direct`).
- `ac-submit-direct` default language selection is fixed to C++ (GCC family).
- `ac-submit-direct` can be run without arguments in a task directory (`main.cpp` + `.task-url`), and `--dry-run` checks parsing/language selection without posting.
- If AtCoder injects Cloudflare Turnstile on submit, pure terminal HTTP submit is blocked because a browser-issued Turnstile token (`cf-turnstile-response`) is required.
- To force one backend, use `ac-submit --oj` or `ac-submit --direct` (or `AC_SUBMIT_BACKEND=oj|direct|auto`).
- If direct submit fails due authentication/challenge, export browser cookies (`cookies.txt`) and run `ac-cookie-import` to refresh `cookie.jar`.

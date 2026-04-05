# AtCoder C++ (Nix Flake)

This directory provides a contest-only C++ environment.

## Setup

1. `cd /path/to/atcoder`
2. `direnv allow` (first time only)
3. `nix develop` (if direnv is not active)
4. `oj login https://atcoder.jp/ --check`

## Commands

- `ac-new <contest> <task> [dir]` (create one task)
- `ac-new-all <contest> [auto|count|tasks] [base_dir]`
- `ac-test [src]` (run for current task only)
- `ac-submit [src] [url]` (submit current task only)
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

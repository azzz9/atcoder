{
  description = "AtCoder C++ workspace";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gcc
              gdb
              clang-tools
              gnumake
              ac-library
              python3
              python3Packages.online-judge-tools
              jq
            ];

            shellHook = ''
              # Resolve root relative to this flake so commands also work when
              # entering the shell from outside the repository directory.
              export ATCODER_ROOT="${toString ./.}"
              if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                export ATCODER_ROOT="$git_root"
              fi
              export CXX=${pkgs.gcc}/bin/g++
              export ATCODER_ACL_INCLUDE="${pkgs.ac-library}/include"
              export CPLUS_INCLUDE_PATH="$ATCODER_ACL_INCLUDE''${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
              export CPATH="$ATCODER_ACL_INCLUDE''${CPATH:+:$CPATH}"
              export CXXFLAGS="-std=gnu++20 -O2 -I$ATCODER_ACL_INCLUDE -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion"
              export CXXFLAGS_DEBUG="-std=gnu++20 -g -O0 -I$ATCODER_ACL_INCLUDE -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion"
              export CONTEST_MODE=1
              export NVIM_APPNAME=nvim-atcoder
              export ATCODER_TEMPLATE="$ATCODER_ROOT/template/main.cpp"
              export PATH="$ATCODER_ROOT/bin:$PATH"

              # Disable AI integrations explicitly in contest shell.
              unset OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_API_KEY

              mkdir -p "$HOME/.config/nvim-atcoder"
              cat > "$HOME/.config/nvim-atcoder/init.lua" <<'LUA'
local home = os.getenv("HOME") or ""
local base_init = home .. "/.config/nvim/init.lua"
local ok, err = pcall(dofile, base_init)
if not ok then
  vim.api.nvim_err_writeln("nvim-atcoder: failed to load base init.lua: " .. tostring(err))
end

-- Show diagnostics while typing in contest mode.
pcall(vim.diagnostic.config, {
  update_in_insert = true,
})

-- Simplified DAP config for contest builds.
pcall(function()
  local dap = require("dap")

  local function first_readable(paths)
    for _, path in ipairs(paths) do
      if path ~= "" and vim.fn.filereadable(path) == 1 then
        return path
      end
    end
    return nil
  end

  local function task_dir()
    local file_dir = vim.fn.expand("%:p:h")
    if file_dir ~= "" then
      return file_dir
    end
    return vim.fn.getcwd()
  end

  local function current_build_output()
    local dir = task_dir()
    local stem = vim.fn.expand("%:t:r")
    local candidates = {}
    if stem ~= "" then
      table.insert(candidates, dir .. "/" .. stem .. ".out")
    end
    table.insert(candidates, dir .. "/main.out")
    table.insert(candidates, dir .. "/a.out")
    return first_readable(candidates)
  end

  local function collect_stdin_candidates(cwd)
    local candidates = {}
    local seen = {}
    for _, pattern in ipairs({ "test/**/*.in", "test/*.in", "*.in", "input.txt", "stdin.txt" }) do
      for _, path in ipairs(vim.fn.globpath(cwd, pattern, false, true)) do
        if vim.fn.filereadable(path) == 1 and not seen[path] then
          seen[path] = true
          table.insert(candidates, path)
        end
      end
    end
    table.sort(candidates)
    return candidates
  end

  local function pick_stdin_file()
    local dir = task_dir()
    local candidates = collect_stdin_candidates(dir)
    if #candidates == 0 then
      local typed = vim.fn.input("stdin file (empty: none): ", dir .. "/", "file")
      return typed ~= "" and typed or nil
    end

    local lines = { "stdin file:" }
    lines[#lines + 1] = "1. (none)"
    for i, path in ipairs(candidates) do
      lines[#lines + 1] = (i + 1) .. ". " .. vim.fn.fnamemodify(path, ":~:.")
    end
    local manual_index = #candidates + 2
    lines[#lines + 1] = manual_index .. ". Enter path manually"

    local selected = vim.fn.inputlist(lines)
    if selected == 1 then
      return nil
    end
    if selected == manual_index then
      local typed = vim.fn.input("stdin file (empty: none): ", dir .. "/", "file")
      return typed ~= "" and typed or nil
    end
    return candidates[selected - 1]
  end

  for _, lang in ipairs({ "c", "cpp" }) do
    dap.configurations[lang] = {
      {
        name = "Launch current build output",
        type = "codelldb",
        request = "launch",
        program = function()
          local program = current_build_output()
          if program then
            return program
          end
          local typed = vim.fn.input("Executable: ", task_dir() .. "/", "file")
          if typed == "" then
            return dap.ABORT
          end
          return typed
        end,
        stdio = function()
          local stdin_file = pick_stdin_file()
          if stdin_file == nil or stdin_file == "" then
            return nil
          end
          return { stdin_file, nil, nil }
        end,
        cwd = task_dir,
        stopOnEntry = false,
      },
    }
  end
end)
LUA

              echo "[atcoder] contest shell loaded"
              echo "[atcoder] commands: ac-new, ac-new-all, ac-test, ac-build, ac-submit"
              echo "[atcoder] nvim: base config (AI plugins not installed in dotfiles)"

              # Prefer zsh for interactive `nix develop` sessions.
              # Keep non-interactive `nix develop -c ...` behavior unchanged.
              # Run this at the end so PATH/setup above is preserved.
              if [[ -t 0 && -t 1 && -z "''${ZSH_VERSION:-}" && -z "''${ATCODER_NIX_ZSH_BOOTSTRAPPED:-}" ]]; then
                export ATCODER_NIX_ZSH_BOOTSTRAPPED=1
                export SHELL=${pkgs.zsh}/bin/zsh
                exec ${pkgs.zsh}/bin/zsh -l
              fi
            '';
          };
        }
      );
    };
}

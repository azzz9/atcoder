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
local ok, err = pcall(dofile, home .. "/.config/nvim/init.lua")
if not ok then
  vim.api.nvim_err_writeln("nvim-atcoder: failed to load base init.lua: " .. tostring(err))
end

-- Contest-mode diagnostics + DAP override.
pcall(vim.diagnostic.config, { update_in_insert = true })

pcall(function()
  local dap = require("dap")
  local helpers = require("dap.codelldb_helpers")

  local function task_dir()
    local file_dir = vim.fn.expand("%:p:h")
    return file_dir ~= "" and file_dir or vim.fn.getcwd()
  end

  local function first_build_output(dir)
    local stem = vim.fn.expand("%:t:r")
    for _, path in ipairs({
      dir .. "/" .. stem .. ".out",
      dir .. "/main.out",
      dir .. "/a.out",
    }) do
      if vim.fn.filereadable(path) == 1 then
        return path
      end
    end
    return nil
  end

  for _, lang in ipairs({ "c", "cpp" }) do
    dap.configurations[lang] = {
      {
        name = "Launch current build output",
        type = "codelldb",
        request = "launch",
        program = function()
          local dir = task_dir()
          local program = first_build_output(dir)
          if program then return program end
          local typed = vim.fn.input("Executable: ", dir .. "/", "file")
          if typed == "" then return dap.ABORT end
          return typed
        end,
        stdio = function()
          local dir = task_dir()
          local stdin_file = helpers.pick_path_from_candidates(
            "stdin file (empty: none): ",
            helpers.collect_stdin_candidates(dir),
            dir .. "/",
            true
          )
          if stdin_file == nil or stdin_file == "" then return nil end
          return { stdin_file, nil, nil }
        end,
        cwd = task_dir,
        stopOnEntry = false,
        _adapterSettings = helpers.adapter_settings,
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

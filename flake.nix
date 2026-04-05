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
              python3
              python3Packages.online-judge-tools
              jq
            ];

            shellHook = ''
              export ATCODER_ROOT=${./.}
              export CXX=${pkgs.gcc}/bin/g++
              export CXXFLAGS="-std=gnu++20 -O2 -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion"
              export CONTEST_MODE=1
              export NVIM_APPNAME=nvim-atcoder
              export ATCODER_TEMPLATE="${./template/main.cpp}"
              export PATH="${./bin}:$PATH"

              # Disable AI integrations explicitly in contest shell.
              unset OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_API_KEY

              mkdir -p "$HOME/.config/nvim-atcoder"
              cat > "$HOME/.config/nvim-atcoder/init.lua" <<'LUA'
local noop = function() end

-- Stub AI-related modules in AtCoder mode.
package.preload["copilot"] = function()
  return { setup = noop }
end
package.preload["copilot_cmp"] = function()
  return { setup = noop }
end
package.preload["CopilotChat"] = function()
  return {
    setup = noop,
    toggle = noop,
    chat = { visible = function() return false end, winnr = -1 },
  }
end
package.preload["CopilotChat.config"] = function()
  return {
    mappings = {
      accept_diff = { callback = noop },
    },
  }
end
package.preload["CopilotChat.config.prompts"] = function()
  return {
    Commit = { prompt = "" },
  }
end
package.preload["CopilotChat.select"] = function()
  return {
    gitdiff = noop,
  }
end
package.preload["CopilotChat.completion"] = function()
  return {
    enable = noop,
    omnifunc = function() return -2 end,
  }
end

local home = os.getenv("HOME") or ""
local base_init = home .. "/.config/nvim/init.lua"
local ok, err = pcall(dofile, base_init)
if not ok then
  vim.api.nvim_err_writeln("nvim-atcoder: failed to load base init.lua: " .. tostring(err))
end

-- Remove copilot source from cmp if present.
vim.schedule(function()
  local ok_cmp, cmp = pcall(require, "cmp")
  if not ok_cmp then
    return
  end
  local cfg = cmp.get_config()
  local filtered = {}
  for _, src in ipairs(cfg.sources or {}) do
    if src.name ~= "copilot" then
      table.insert(filtered, src)
    end
  end
  cfg.sources = filtered
  cmp.setup(cfg)
end)
LUA

              echo "[atcoder] contest shell loaded"
              echo "[atcoder] commands: ac-new, ac-new-all, ac-test, ac-submit"
              echo "[atcoder] nvim: base config + AI integrations disabled"
            '';
          };
        }
      );
    };
}

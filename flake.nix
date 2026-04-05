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
              # Prefer zsh for interactive `nix develop` sessions.
              # Keep non-interactive `nix develop -c ...` behavior unchanged.
              if [[ -t 0 && -t 1 && -z "''${ZSH_VERSION:-}" && -z "''${ATCODER_NIX_ZSH_BOOTSTRAPPED:-}" ]]; then
                export ATCODER_NIX_ZSH_BOOTSTRAPPED=1
                export SHELL=${pkgs.zsh}/bin/zsh
                exec ${pkgs.zsh}/bin/zsh -l
              fi

              if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                export ATCODER_ROOT="$git_root"
              else
                export ATCODER_ROOT="$PWD"
              fi
              export CXX=${pkgs.gcc}/bin/g++
              export CXXFLAGS="-std=gnu++20 -O2 -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion"
              export CONTEST_MODE=1
              export NVIM_APPNAME=nvim-atcoder
              export ATCODER_TEMPLATE="$ATCODER_ROOT/template/main.cpp"
              export PATH="$ATCODER_ROOT/bin:$PATH"

              # Disable AI integrations explicitly in contest shell.
              unset OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_API_KEY

              mkdir -p "$HOME/.config/nvim-atcoder"
              cat > "$HOME/.config/nvim-atcoder/init.lua" <<'LUA'
local noop = function() end

local function is_ai_name(name)
  local lower = string.lower(name or "")
  return lower:find("copilot", 1, true)
    or lower:find("codeium", 1, true)
    or lower:find("tabnine", 1, true)
    or lower:find("supermaven", 1, true)
    or lower:find("avante", 1, true)
end

local function disable_copilot_buffer(bufnr)
  pcall(function()
    vim.b[bufnr].copilot_enabled = false
    vim.b[bufnr].copilot_suggestion_hidden = true
  end)
end

local function filter_ai_sources(sources)
  local filtered = {}
  for _, src in ipairs(sources or {}) do
    local name = ""
    if type(src) == "table" then
      name = src.name or ""
    end
    if not is_ai_name(name) then
      table.insert(filtered, src)
    end
  end
  return filtered
end

local function stop_ai_clients(bufnr)
  if not (vim.lsp and vim.lsp.get_clients) then
    return
  end
  local opts = {}
  if bufnr then
    opts.bufnr = bufnr
  end
  for _, client in ipairs(vim.lsp.get_clients(opts)) do
    if is_ai_name(client.name) then
      pcall(function()
        client:stop(true)
      end)
    end
  end
end

vim.g.copilot_enabled = false
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true
vim.g.copilot_filetypes = { ["*"] = false }
vim.g.codeium_disable_bindings = 1

-- Stub AI-related modules in AtCoder mode.
package.preload["copilot"] = function()
  return {
    setup = noop,
    teardown = noop,
    enable = noop,
    disable = noop,
  }
end
package.preload["copilot_cmp"] = function()
  return { setup = noop }
end
package.preload["copilot.client"] = function()
  return { setup = noop, teardown = noop }
end
package.preload["copilot.suggestion"] = function()
  return {
    setup = noop,
    teardown = noop,
    dismiss = noop,
    hide = noop,
    next = noop,
    prev = noop,
    accept = noop,
    is_visible = function() return false end,
  }
end
package.preload["copilot.panel"] = function()
  return {
    setup = noop,
    teardown = noop,
    open = noop,
    close = noop,
    jump_next = noop,
    jump_prev = noop,
    accept = noop,
  }
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

-- Force-disable copilot even if base config enables it.
pcall(vim.cmd, "silent! Copilot disable")
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  disable_copilot_buffer(bufnr)
end
vim.api.nvim_create_autocmd({ "BufEnter", "InsertEnter", "FileType" }, {
  callback = function(args)
    disable_copilot_buffer(args.buf)
    pcall(vim.cmd, "silent! Copilot disable")
  end,
})

-- Enable C/C++ LSP in contest shell.
local clangd_enabled_via_core = false
pcall(function()
  if vim.lsp and vim.lsp.enable and vim.lsp.config and vim.lsp.config["clangd"] then
    vim.lsp.enable({ "clangd" })
    clangd_enabled_via_core = true
  end
end)

local function ensure_clangd(bufnr)
  if not (vim.lsp and vim.lsp.start and vim.lsp.get_clients) then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].buftype ~= "" then
    return
  end
  local ft = vim.bo[bufnr].filetype
  if ft ~= "c" and ft ~= "cpp" and ft ~= "objc" and ft ~= "objcpp" then
    return
  end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == "clangd" then
      return
    end
  end
  local exepath = vim.fn.exepath("clangd")
  if exepath == "" then
    return
  end
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local root = nil
  if vim.fs and vim.fs.root then
    root = vim.fs.root(filename, { ".git", "compile_commands.json", "compile_flags.txt" })
  end
  if not root or root == "" then
    root = vim.fn.getcwd()
  end
  pcall(vim.lsp.start, {
    name = "clangd",
    cmd = { exepath },
    root_dir = root,
  })
end
if not clangd_enabled_via_core then
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    callback = function(args)
      ensure_clangd(args.buf)
    end,
  })
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    disable_copilot_buffer(args.buf)
    stop_ai_clients(args.buf)
  end,
})
vim.schedule(function()
  pcall(vim.cmd, "silent! Copilot disable")
  stop_ai_clients()
end)

-- Remove copilot source from cmp if present.
vim.schedule(function()
  local ok_cmp, cmp = pcall(require, "cmp")
  if not ok_cmp then
    return
  end
  local cfg = cmp.get_config()
  cfg.sources = filter_ai_sources(cfg.sources)
  cmp.setup(cfg)
end)

-- Show diagnostics while typing in contest mode.
pcall(vim.diagnostic.config, {
  update_in_insert = true,
})
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

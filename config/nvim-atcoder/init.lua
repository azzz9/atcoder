-- nvim-atcoder: contest-mode config.
-- Loaded via NVIM_APPNAME=nvim-atcoder. Sources the user's base init.lua first,
-- then applies contest-mode diagnostics + a DAP configuration that launches
-- the current task's build output (main.out / a.out) under codelldb.

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

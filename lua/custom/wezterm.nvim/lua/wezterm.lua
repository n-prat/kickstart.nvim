-------------------------------------------------------------------------------
--- Control Wezterm from inside Neovim
---
--- https://github.com/willothy/wezterm.nvim
--- -> way too complicated
---https://github.com/letieu/wezterm-move.nvim/blob/master/lua/wezterm-move/init.lua
--- -> good starting point, but only handle "activate-pane-direction" and we want Tab switching

local M = {}

local function wezterm_exec(cmd)
  local command = vim.deepcopy(cmd)
  if vim.fn.executable 'wezterm.exe' == 1 then
    table.insert(command, 1, 'wezterm.exe')
  else
    table.insert(command, 1, 'wezterm')
  end
  table.insert(command, 2, 'cli')
  return vim.fn.system(command)
end

-- NOTE that one is pretty useless b/c there is not point in programatically having a keybind that does the same thing than
-- a default keybind
-- @param direction: eg 1, or -1, etc.
local function wezterm_activate_tab_relative(opts)
  if #opts.fargs ~= 1 then
    vim.notify('wezterm_activate_tab_relative: require ONE parameter: eg: -1,1,etc.', vim.log.levels.INFO)
    return
  end

  relative_dir = tonumber(opts.fargs[1])

  wezterm_exec { 'activate-tab', '--tab-relative', relative_dir }
end

M.setup = function(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command('WeztermActivateTabRel', wezterm_activate_tab_relative, { nargs = '*' })
end

return M

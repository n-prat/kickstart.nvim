-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------
-- --                SHARED LLM MODEL LOGIC (for codecompanion & avante)
-- -------------------------------------------------------------------------------
--
-- -- === TIER 1: GLOBAL MODEL (Persisted in shada) ===
-- local hardcoded_default_model = 'openai/gpt-oss-120b'
-- -- Load persisted global model from shada, or fall back to the hardcoded one
-- local global_model = vim.g.codecompanion_global_model or hardcoded_default_model
--
-- -- === TIER 2: SESSION/WORKSPACE MODEL (Persisted in session file by persisted.nvim) ===
-- -- We initialize this to nil on startup. persisted.nvim will populate it when it loads a session.
-- vim.g.codecompanion_session_model_override = nil
--
-- -- A pre-defined list of common models for convenience in the UI selector.
-- local available_models = {
--   'openai/gpt-oss-120b',
--   'openai/gpt-oss-20b',
-- }
-- -- Ensure the global model is in the list for easy re-selection
-- if not vim.tbl_contains(available_models, global_model) then
--   table.insert(available_models, global_model)
-- end
--
-- --- Returns the currently active model, prioritizing the session override.
-- -- This function is the single source of truth for all LLM plugins.
-- local function get_current_llm_model()
--   return vim.g.codecompanion_session_model_override or global_model
-- end
--
-- --- Prompts to select a model and sets it on a global variable for session persistence.
-- local function select_and_persist_session_model()
--   -- Add any dynamically set session model to the list if it's not there
--   if vim.g.codecompanion_session_model_override and not vim.tbl_contains(available_models, vim.g.codecompanion_session_model_override) then
--     table.insert(available_models, vim.g.codecompanion_session_model_override)
--   end
--
--   local selection_list = vim.deepcopy(available_models)
--   table.insert(selection_list, 1, '[Clear Override - Use Global: ' .. global_model .. ']')
--
--   vim.ui.select(selection_list, {
--     prompt = 'Select Model for this Session (persisted by session manager):',
--   }, function(choice)
--     if not choice then
--       return vim.notify('Selection cancelled.', vim.log.levels.WARN)
--     end
--
--     if choice:match '^%[Clear Override' then
--       vim.g.codecompanion_session_model_override = nil -- Clear the override
--       vim.notify('Session override cleared. Using global model: ' .. get_current_llm_model(), vim.log.levels.INFO)
--     else
--       vim.g.codecompanion_session_model_override = choice -- Set the override
--       vim.notify('Session model set to: ' .. get_current_llm_model(), vim.log.levels.INFO)
--     end
--   end)
-- end
--
-- --- Prompts to set a new global default model, persisted in shada.
-- local function set_global_model()
--   vim.ui.input({
--     prompt = 'Enter new GLOBAL default model name:',
--     default = global_model,
--   }, function(input)
--     if input and input ~= '' then
--       global_model = input
--       vim.g.codecompanion_global_model = input
--       if not vim.tbl_contains(available_models, input) then
--         table.insert(available_models, input)
--       end
--       vim.notify('Global default model set to: ' .. input, vim.log.levels.INFO)
--     else
--       vim.notify('Global model change cancelled.', vim.log.levels.WARN)
--     end
--   end)
-- end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

return {
  -------------------------------------------------------------------------------
  -- https://github.com/olimorris/persisted.nvim
  -- NOTE "By design, the plugin will not autoload a session when any arguments are passed to Neovim" eg `nvim .`
  -- Why persisted was replaced? cf below
  -- FAIL Shatur/neovim-session-manager: no way to list all sessions so useless in the end... ALSO issues with harpoon cf github
  {
    'olimorris/persisted.nvim',
    config = function()
      require('persisted').setup {
        autoload = true,
        on_autoload_no_session = function()
          vim.notify 'No existing session to load.'
        end,
        -- Disable saving Snacks.terminal
        -- cf https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md#terminal to check the filetype
        -- - 1: b/c without this after restoring a session, then opening a new terminal: it adds a second one instead of reopening
        -- - 2: with the keymap to open a terminal, we don't really need to save/restore it; we can just toggle it when needed
        --    (also we are usually inside a Zellij session so we have proper history etc)
        should_save = function()
          -- vim.notify('filetype : ' .. vim.inspect(vim.bo.filetype))
          -- return vim.bo.filetype ~= 'snacks_terminal'
          -- Above check DOES NOT work; so use PersistedSavePre event instead
          -- or more precisely: it works, but that essentially make this plugin do nothing;
          -- which then defaults to Neovim's default behavior, which is saving everything???
          return true
        end,
      }

      -- This work as intended: it DELETEs the buffer when saving
      -- which is not really what we want...
      -- TODO See also `QuitPre`??? Doing both seems redundant
      vim.api.nvim_create_autocmd('User', {
        pattern = 'PersistedSavePre',
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            vim.notify('filetype : ' .. vim.inspect(vim.bo[buf].filetype))
            if vim.bo[buf].filetype == 'snacks_terminal' or vim.bo[buf].filetype == 'terminal' then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
        end,
      })
    end,
  },

  -------------------------------------------------------------------------------
  -------------------------------------------------------------------------------
  --- Handle cwd change when opening files from another "project"
  ---https://github.com/notjedi/nvim-rooter.lua
  --- NOTE this is needed in COMBINATION with eg persisted.nvim
  --- FAIL does not handle submodules... even when trying with .gitignore in rooter_patterns
  ---   indeed, it works only when opening a folder which is a subdir of the submodule, which is not good
  ---
  ---  TRY2 using telescope-project.nvim
  ---  FAIL b/c no synergy with persisted
  ---  TRY3 use ONLY neovim-session-manager instead of persisted, cf above
  --
  -----------------------------------------------------------------------------
  --- https://github.com/ThePrimeagen/harpoon/tree/harpoon2?tab=readme-ov-file#-installation
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local harpoon = require 'harpoon'

      -- REQUIRED
      harpoon:setup()
      -- REQUIRED

      -- NOTE: he is using DVORAK layout so this is converted to qwerty (on azerty hardware)
      -- cf remap.lua for the conversion
      vim.keymap.set('n', '<C-e>', function()
        -- toggle_telescope(harpoon:list())
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = 'Open harpoon window' })

      vim.keymap.set('n', '<C-a>', function()
        harpoon:list():add()
      end)
      vim.keymap.set('n', '<C-e>', function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end)

      vim.keymap.set('n', '<C-h>', function()
        harpoon:list():select(1)
      end)
      vim.keymap.set('n', '<C-j>', function()
        harpoon:list():select(2)
      end)
      vim.keymap.set('n', '<C-k>', function()
        harpoon:list():select(3)
      end)
      vim.keymap.set('n', '<C-l>', function()
        harpoon:list():select(4)
      end)

      -- Toggle previous & next buffers stored within Harpoon list
      vim.keymap.set('n', '<C-L-R>', function()
        harpoon:list():prev()
      end)
      vim.keymap.set('n', '<C-L-K>', function()
        harpoon:list():next()
      end)
    end,
  },
  -----------------------------------------------------------------------------
  --- VCS: jj
  --- requires https://github.com/Cretezy/lazyjj
  --- and obviously Jujutsu https://github.com/jj-vcs/jj
  ---
  --- NOTE: if the popup flashes and closes immediately, it probably just b/c "Error: No jj repository found in"
  --- CHECK and try to run `lazyjj` on the command line
  {
    'swaits/lazyjj.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    opts = {
      mapping = '<leader>jj',
    },
  },
  -----------------------------------------------------------------------------
  --- Terminal
  -- DID TRY   'akinsho/toggleterm.nvim but UX is not much better than vanilla terminal
  --    also: running sessionizer in FTerm causes a message "process exited with 0" to be shown when returning
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = {
        --
      },
      input = {
        --
      },
      --- VCS: Git and/or LazyGit
      --- ALTERNATIVE Neogit: ok-ish but UI sucks, and UX is weird
      --- ALTERNATIVE fugitive: NOT tried
      --- ALTERNATIVE kdheepak/lazygit.nvim: Ok, but interactions b/w the floating window for lazygit is Neovim are weird
      --- CURRENT https://github.com/folke/snacks.nvim/blob/main/docs/lazygit.md
      ---
      --- windows: `winget install lazygit`
      --- linux: `sudo pacman -Syu lazygit`
      ---
      --- NOTE if submodule support is needed: https://github.com/kdheepak/lazygit.nvim?tab=readme-ov-file#telescope-plugin
      lazygit = {
        -- win = {
        --   -- style = 'lazygit', -- n-prat: default so not needed?
        --   height = 0.8,
        --   width = 0.8,
        -- },
      },
      notifier = {
        --
      },
      picker = {
        --
        win = {
          -- input window
          input = {
            keys = {
              -- DEFAULT below, but that conflicts with Zellij
              -- ['<a-d>'] = { 'inspect', mode = { 'n', 'i' } },
              -- ['<a-m>'] = { 'toggle_maximize', mode = { 'i', 'n' } },
              -- ['<a-p>'] = { 'toggle_preview', mode = { 'i', 'n' } },
              -- ['<a-w>'] = { 'cycle_win', mode = { 'i', 'n' } },
              -- ["<c-g>"] = { "toggle_live", mode = { "i", "n" } },
              -- ['<a-i>'] = { 'toggle_ignored', mode = { 'i', 'n' } },
              -- ['<a-h>'] = { 'toggle_hidden', mode = { 'i', 'n' } },
              -- ['<a-f>'] = { 'toggle_follow', mode = { 'i', 'n' } },
              --
              -- n-prat:
              ['<c-a-d>'] = { 'inspect', mode = { 'n', 'i' } },
              ['<c-a-m>'] = { 'toggle_maximize', mode = { 'i', 'n' } },
              ['<c-a-p>'] = { 'toggle_preview', mode = { 'i', 'n' } },
              ['<c-a-w>'] = { 'cycle_win', mode = { 'i', 'n' } },
              ['<c-a-g>'] = { 'toggle_live', mode = { 'i', 'n' } },
              ['<c-a-i>'] = { 'toggle_ignored', mode = { 'i', 'n' } },
              ['<c-H>'] = { 'toggle_hidden', mode = { 'i', 'n' } },
              ['<c-a-f>'] = { 'toggle_follow', mode = { 'i', 'n' } },

              -- https://github.com/folke/sidekick.nvim#snacksnvim-picker-integration
              ['<a-a>'] = {
                'sidekick_send',
                mode = { 'n', 'i' },
              },
            },
          },
        },
        -- https://github.com/folke/sidekick.nvim#snacksnvim-picker-integration
        actions = {
          sidekick_send = function(...)
            return require('sidekick.cli.picker.snacks').send(...)
          end,
        },
      },
      quickfile = {
        --
      },
      terminal = {
        -- win = {
        --   -- style = 'terminal' -- n-prat: default so not needed?
        --   -- apparently that's how Snack.terminal is styled
        --   height = 0.3,
        --   width = 0.3,
        -- },
        -- styles = {
        --   split = {
        --     position = 'bottom',
        --     height = 0.3,
        --     width = 0.3,
        --   },
        -- },
      },
      -- n-prat not sure if there is a better way to style the Terminal
      -- WARNING: when changing a style: retest all: Terminal, LazyGit, Sessionizer
      -- b/c it is easy to mess up all of them b/c the styles seem to share some things
      styles = {
        split = {
          position = 'bottom',
          height = 0.3,
          width = 0.3,
        },
      },
    },
    keys = {

      -- https://github.com/LazyVim/LazyVim/blob/d1529f650fdd89cb620258bdeca5ed7b558420c7/lua/lazyvim/config/keymaps.lua#L150
      {
        '<leader>gg',
        function()
          Snacks.lazygit()
        end,
        desc = 'Lazygit',
      },
      -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#-examples
      {
        '<leader>,',
        function()
          Snacks.picker.buffers()
        end,
        desc = 'Buffers',
      },
      {
        '<leader>/',
        function()
          Snacks.picker.grep()
        end,
        desc = 'Grep',
      },
      {
        '<leader>:',
        function()
          Snacks.picker.command_history()
        end,
        desc = 'Command History',
      },
      {
        '<leader><space>',
        function()
          Snacks.picker.files()
        end,
        desc = 'Find Files',
      },
      -- find
      {
        '<leader>fb',
        function()
          Snacks.picker.buffers()
        end,
        desc = 'Buffers',
      },
      {
        '<leader>fc',
        function()
          Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
        end,
        desc = 'Find Config File',
      },
      {
        '<leader>ff',
        function()
          Snacks.picker.files()
        end,
        desc = 'Find Files',
      },
      {
        '<leader>fg',
        function()
          Snacks.picker.git_files()
        end,
        desc = 'Find Git Files',
      },
      {
        '<leader>fr',
        function()
          Snacks.picker.recent()
        end,
        desc = 'Recent',
      },
      -- git
      {
        '<leader>gc',
        function()
          Snacks.picker.git_log()
        end,
        desc = 'Git Log',
      },
      {
        '<leader>gs',
        function()
          Snacks.picker.git_status()
        end,
        desc = 'Git Status',
      },
      -- Grep
      {
        '<leader>sb',
        function()
          Snacks.picker.lines()
        end,
        desc = 'Buffer Lines',
      },
      {
        '<leader>sB',
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = 'Grep Open Buffers',
      },
      {
        '<leader>sg',
        function()
          Snacks.picker.grep()
        end,
        desc = 'Grep',
      },
      {
        '<leader>sw',
        function()
          Snacks.picker.grep_word()
        end,
        desc = 'Visual selection or word',
        mode = { 'n', 'x' },
      },
      -- search
      {
        '<leader>s"',
        function()
          Snacks.picker.registers()
        end,
        desc = 'Registers',
      },
      {
        '<leader>sa',
        function()
          Snacks.picker.autocmds()
        end,
        desc = 'Autocmds',
      },
      {
        '<leader>sc',
        function()
          Snacks.picker.command_history()
        end,
        desc = 'Command History',
      },
      {
        '<leader>sC',
        function()
          Snacks.picker.commands()
        end,
        desc = 'Commands',
      },
      {
        '<leader>sd',
        function()
          Snacks.picker.diagnostics()
        end,
        desc = 'Diagnostics',
      },
      {
        '<leader>sh',
        function()
          Snacks.picker.help()
        end,
        desc = 'Help Pages',
      },
      {
        '<leader>sH',
        function()
          Snacks.picker.highlights()
        end,
        desc = 'Highlights',
      },
      {
        '<leader>sj',
        function()
          Snacks.picker.jumps()
        end,
        desc = 'Jumps',
      },
      {
        '<leader>sk',
        function()
          Snacks.picker.keymaps()
        end,
        desc = 'Keymaps',
      },
      {
        '<leader>sl',
        function()
          Snacks.picker.loclist()
        end,
        desc = 'Location List',
      },
      {
        '<leader>sM',
        function()
          Snacks.picker.man()
        end,
        desc = 'Man Pages',
      },
      {
        '<leader>sm',
        function()
          Snacks.picker.marks()
        end,
        desc = 'Marks',
      },
      {
        '<leader>sR',
        function()
          Snacks.picker.resume()
        end,
        desc = 'Resume',
      },
      {
        '<leader>sq',
        function()
          Snacks.picker.qflist()
        end,
        desc = 'Quickfix List',
      },
      -- {
      --   '<leader>uC',
      --   function()
      --     Snacks.picker.colorschemes()
      --   end,
      --   desc = 'Colorschemes',
      -- },
      {
        '<leader>qp',
        function()
          Snacks.picker.projects()
        end,
        desc = 'Projects',
      },
      -- LSP (using gr* pattern to match nvim-nightly 0.12)
      {
        'gd',
        function()
          Snacks.picker.lsp_definitions()
        end,
        desc = '[snacks.picker] Goto Definition',
      },
      {
        'grr',
        function()
          Snacks.picker.lsp_references()
        end,
        nowait = true,
        desc = '[snacks.picker] References',
      },
      {
        'gri',
        function()
          Snacks.picker.lsp_implementations()
        end,
        desc = '[snacks.picker] Goto Implementation',
      },
      {
        'grt',
        function()
          Snacks.picker.lsp_type_definitions()
        end,
        desc = '[snacks.picker] Goto Type Definition',
      },
      {
        'gO',
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = '[snacks.picker] Document Symbols',
      },
      {
        'gra',
        function()
          Snacks.picker.lsp_code_actions()
        end,
        mode = { 'n', 'x' },
        desc = '[snacks.picker] Code Actions',
      },
      -- n-prat: custom Snacks.picker
      {
        '<leader>u',
        function()
          Snacks.picker.undo()
        end,
        desc = 'Undo',
      },
      -- https://github.com/LazyVim/LazyVim/blob/d1529f650fdd89cb620258bdeca5ed7b558420c7/lua/lazyvim/config/keymaps.lua#L174
      -- n-prat: want to have it floating, so MUST have a command
      {
        -- NOTE: that means CTRL + / NOT _
        -- cf https://github.com/neovim/neovim/issues/20881 and linked issues
        '<C-_>',
        function()
          Snacks.terminal()
        end,
        desc = 'Toggle Terminal',
      },
    },
  },

  -----------------------------------------------------------------------------
  --- NOTE this is the only "auto focus" and switch to INSERT mode that works
  --- `persist_mode` MUST apparently be false; the rest does not seem to matter?
  --- cf https://github.com/akinsho/toggleterm.nvim/issues/473
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      -- Automatically close terminals when Neovim exits
      close_on_exit = true,
      -- This makes the layout more stable when toggling
      auto_scroll = false,
      -- NOTE: start_in_insert is the default, and now that fish behaves
      -- correctly, this will work as expected.
      start_in_insert = true,
      persist_mode = false,
      -- -- AUTO-ENTER INSERT MODE when opening terminal
      -- on_open = function(term)
      --   vim.cmd 'startinsert!'
      -- end,
      -- This is the definitive fix for fish shell's vi-mode.
      -- It runs after the terminal is opened and the shell has initialized.
      -- on_open = function(term)
      --   -- We still defer slightly to ensure the channel is ready.
      --   vim.defer_fn(function()
      --     -- Send the 'i' character directly to the terminal's pty.
      --     -- This is the programmatic equivalent of pressing the 'i' key.
      --     vim.api.nvim_chan_send(term.channel, 'i')
      --   end, 0)
      -- end,
    },
    config = function(_, opts)
      require('toggleterm').setup(opts)

      local Terminal = require('toggleterm.terminal').Terminal

      local terminal_test = Terminal:new {
        id = 1,
        display_name = 'Test Runner',
        direction = 'vertical',
        size = 50, -- Actual constraints enforced by WinResized autocmd in init.lua
        hidden = true,
      }

      local terminal_git = Terminal:new {
        id = 2,
        display_name = 'Git/jj CLI',
        direction = 'vertical',
        hidden = true,
      }

      --- Opens both terminals and focuses the target one.
      local function open_and_focus(target_term)
        if target_term:is_open() then
          vim.fn.win_gotoid(target_term.window)
          return
        end

        -- Check space before opening (45 = min terminal width)
        if _G.NvimLayout and type(_G.NvimLayout.can_open_new_split) == 'function' and _G.NvimLayout.LAYOUT then
          local can_open, reason = _G.NvimLayout.can_open_new_split(_G.NvimLayout.LAYOUT.min_terminal)
          if not can_open then
            vim.notify('Warning: ' .. reason .. ' - Opening anyway', vim.log.levels.WARN)
          end
          -- Shrink existing windows to make room
          _G.NvimLayout.shrink_to_minimums()
        end

        -- Open both; WinResized autocmd in init.lua enforces layout constraints
        terminal_test:open()
        terminal_git:open()

        vim.defer_fn(function()
          if target_term:is_open() then
            vim.fn.win_gotoid(target_term.window)
          end
        end, 10)
      end

      vim.keymap.set('n', '<leader>tt', function()
        open_and_focus(terminal_test)
      end, { desc = 'Layout & Focus [T]est' })

      vim.keymap.set('n', '<leader>tg', function()
        open_and_focus(terminal_git)
      end, { desc = 'Layout & Focus [G]it' })

      vim.keymap.set('n', '<leader>tq', function()
        -- NOTE: using `close` here was making the switch to INSERT mode after closing the terminals???
        terminal_test:toggle()
        terminal_git:toggle()
        -- This is the crucial command that forces Neovim back to Normal Mode
        -- after the terminals have been destroyed.
        vim.cmd 'stopinsert'
      end, { desc = '[T]erminal [Q]uit Layout' })

      --   -- Keymaps to send commands (The "wow" factor)
      --   vim.keymap.set('n', '<leader>tr', function()
      -- -- Runs 'cargo test' in the Test Runner terminal.
      -- -- The terminal will open automatically if it's hidden.
      -- test_runner:send('clear && cargo test', true)
      --   end, { desc = '[T]est [R]un (all)' })
      --
      --   vim.keymap.set('n', '<leader>tf', function()
      --     -- Runs the test for the current file.
      --     test_runner:send('clear && cargo test --test ' .. vim.fn.expand '%:t:r', true)
      --   end, { desc = '[T]est [F]ile' })
      --
      --   vim.keymap.set('n', '<leader>gp', function()
      --     -- Runs 'git push --force' in the Git CLI terminal
      --     git_cli:send('git push --force', true)
      --   end, { desc = '[G]it [P]ush --force' })
    end,
  },

  -----------------------------------------------------------------------------
  --- https://github.com/pocco81/auto-save.nvim -> good stars and contribs, but last activity 3 years ago
  --- https://github.com/okuuva/auto-save.nvim -> fork of pocco81
  --- TODO n-prat: see also basic https://neovim.io/doc/user/options.html#'autowrite' and autowriteall
  {
    'okuuva/auto-save.nvim',
    version = '^1.0.0', -- see https://devhints.io/semver, alternatively use '*' to use the latest tagged release
    cmd = 'ASToggle', -- optional for lazy loading on command
    event = { 'InsertLeave', 'TextChanged' }, -- optional for lazy loading on trigger events
    opts = {
      enabled = true, -- DEFAULT start auto-save when the plugin is loaded (i.e. when your package manager loads it)
      trigger_events = { -- DEFAULT See :h events
        immediate_save = { 'BufLeave', 'FocusLost', 'QuitPre', 'VimSuspend' }, -- vim events that trigger an immediate save
        defer_save = { 'InsertLeave', 'TextChanged', 'TextChangedI' }, -- n-prat: default is InsertLeave and TextChanged, but added TextChangedI to also handle INSERT mode changes
        cancel_deferred_save = { 'InsertEnter' }, -- vim events that cancel a pending deferred save
      },
      condition = function(buf)
        -- don't save for special-buffers
        -- n-prat: docs cf https://neovim.io/doc/user/options.html#'buftype'
        -- a normal buffer is buftype is ""
        if vim.fn.getbufvar(buf, '&buftype') ~= '' then
          return false
        end
        return true
      end,
      -- DEFAULT is 1000 but that is relative to trigger_events!
      -- n-prat: as we added TextChangedI,we can bump this a lot
      debounce_delay = 10000,
    },
    config = function(_, opts)
      -- having BOTH opts and config need this!
      -- cf https://github.com/folke/lazy.nvim/discussions/1652
      require('auto-save').setup(opts)

      local group = vim.api.nvim_create_augroup('autosave', {})

      vim.api.nvim_create_autocmd('User', {
        pattern = 'AutoSaveWritePost',
        group = group,
        callback = function(opts2)
          if opts2.data.saved_buffer ~= nil then
            local filename = vim.api.nvim_buf_get_name(opts2.data.saved_buffer)
            vim.notify('AutoSave: saved ' .. filename .. ' at ' .. vim.fn.strftime '%H:%M:%S', vim.log.levels.INFO)
          end
        end,
      })
    end,
  },
  -----------------------------------------------------------------------------
  --- https://github.com/debugloop/telescope-undo.nvim
  --- ALTERNATIVE to older undotree
  --- REPLACED/INTEGRATED by snacks.picker
  -------------------------------------------------------------------------------
  --- https://github.com/nvim-treesitter/nvim-treesitter-context
  --- Shows which class/function/enum/etc we are inside at the top of the screen
  {
    'nvim-treesitter/nvim-treesitter-context',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('treesitter-context').setup()
    end,
  },
  -------------------------------------------------------------------------------
  --- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  --- Simplified to match nvim-nightly 0.12 config (only af/if textobjects)
  --- Removed: ac/ic, as, swap, move, ts_repeat_move
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = 'VeryLazy',
    -- MUST use same cond than treesitter itself; or could be cleverer about loading cf linked lazyvim config
    cond = not jit.os:find 'Windows',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter.configs').setup {
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              -- Only af/if to match nvim-nightly 0.12
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
            },
            selection_modes = {
              ['@function.outer'] = 'V', -- linewise
            },
            include_surrounding_whitespace = true,
          },
        },
        -- swap/move removed to match nvim-nightly 0.12
      }

      -- Incremental selection (matches nvim-nightly 0.12)
      vim.keymap.set('n', '<C-space>', function()
        require('nvim-treesitter.incremental_selection').init_selection()
      end, { desc = 'Treesitter: init selection' })
      vim.keymap.set('x', '<C-space>', function()
        require('nvim-treesitter.incremental_selection').node_incremental()
      end, { desc = 'Treesitter: increment selection' })
      vim.keymap.set('x', '<bs>', function()
        require('nvim-treesitter.incremental_selection').node_decremental()
      end, { desc = 'Treesitter: decrement selection' })

      -- NOTE: ts_repeat_move removed - using vanilla ;/, for f/t repeat
    end,
  },
  -------------------------------------------------------------------------------
  --- https://github.com/RRethy/nvim-treesitter-textsubjects
  --- DISABLED: Not compatible with treesitter main branch (used in nvim-nightly 0.12)
  --- Keeping disabled for parity with nvim-nightly config
  -- {
  --   'RRethy/nvim-treesitter-textsubjects',
  --   event = 'VeryLazy',
  --   cond = not jit.os:find 'Windows',
  --   dependencies = { 'nvim-treesitter/nvim-treesitter' },
  --   config = function()
  --     require('nvim-treesitter.configs').setup {
  --       textsubjects = {
  --         enable = true,
  --         prev_selection = ',',
  --         keymaps = {
  --           ['.'] = 'textsubjects-smart',
  --           [';'] = 'textsubjects-container-outer',
  --           ['i;'] = { 'textsubjects-container-inner', desc = 'Select inside containers' },
  --         },
  --       },
  --     }
  --   end,
  -- },
  ------------------------------------------------------------------------------
  -- https://github.com/toppair/peek.nvim
  -- Markdown preview:
  -- NOTE require "deno"; can be installed via pacman/etc on Linux, or choco/winget on Windows
  -- WARNING install deno BEFORE else: https://github.com/toppair/peek.nvim/issues/65
  -- (could probably rerun the build task if eg PeekOpen fails)
  -- FAIL: does not seem to work on Windows or via SSH
  -- {
  --   'toppair/peek.nvim',
  --   event = { 'VeryLazy' },
  --   build = 'deno task --quiet build:fast',
  --   config = function()
  --     require('peek').setup {
  --       app = 'webview',
  --     }
  --     vim.api.nvim_create_user_command('PeekOpen', require('peek').open, {})
  --     vim.api.nvim_create_user_command('PeekClose', require('peek').close, {})
  --   end,
  -- },
  ------------------------------------------------------------------------------
  --- iamcco/markdown-preview.nvim: Ok, but does the preview in a browser (scroll auto, etc), so not that great of a flow
  -- SHOULD probably call `:call mkdp#util#install()` after install
  -- TODO try and replace with https://github.com/OXY2DEV/markview.nvim
  {
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    ft = { 'markdown' },
    build = function()
      vim.fn['mkdp#util#install']()
    end,
    init = function()
      vim.g.mkdp_open_to_the_world = 1
      vim.g.mkdp_echo_preview_url = 1
    end,
  },
  -- TODO? TRY https://github.com/OXY2DEV/markview.nvim which should sort of be the same than below
  -- cf https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/271 and other threads on reddit etc
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'echasnovski/mini.nvim',
      -- NOTE: this is NOT how the README does it; this comes from https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/310
      -- {
      --   'saghen/blink.cmp',
      --   module = false,
      --   opts = function(_, opts)
      --     -- PUSH(opts.sources.default, 'markdown')
      --     -- cf https://github.com/Saghen/blink.cmp/issues/1015 for how adding sources works
      --     opts = {
      --       sources = { default = { 'markdown' } },
      --       providers = {
      --         markdown = {
      --           name = 'RenderMarkdown',
      --           module = 'render-markdown.integ.blink',
      --           fallbacks = { 'lsp' },
      --         },
      --       },
      --     }
      --   end,
      -- },
    }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      preview = {
        filetypes = { 'markdown', 'codecompanion' },
        ignore_buftypes = {},
      },
    },
  },
  -------------------------------------------------------------------------------
  --- https://github.com/3rd/image.nvim
  --- PREREQ: imagemagick and ideally luarocks
  --- on windows: winget install ImageMagick.Q16
  --- NOTE: even with imagemagick on windows we get: https://github.com/3rd/image.nvim/issues/115
  {
    '3rd/image.nvim',
    -- build = false, -- so that it doesn't build the rock https://github.com/3rd/image.nvim/issues/91#issuecomment-2453430239
    -- Disabled on windows cf NOTE above
    cond = not jit.os:find 'Windows',
  },
  -------------------------------------------------------------------------------
  --- https://github.com/max397574/better-escape.nvim
  --- n-prat: remove jj, only keep jk everywhere
  {
    'max397574/better-escape.nvim',
    config = function()
      require('better_escape').setup {
        timeout = vim.o.timeoutlen,
        default_mappings = false,
        mappings = {
          i = {
            j = {
              k = '<Esc>',
            },
          },
          c = {
            j = {
              k = '<Esc>',
            },
          },
          t = {
            j = {
              k = '<C-\\><C-n>',
            },
          },
          v = {
            j = {
              k = '<Esc>',
            },
          },
          s = {
            j = {
              k = '<Esc>',
            },
          },
        },
      }
    end,
  },

  -------------------------------------------------------------------------------
  ---
  {
    'sindrets/diffview.nvim',
  },

  -------------------------------------------------------------------------------
  ---
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    opts = {
      presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
      },
    },
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      'MunifTanjim/nui.nvim',
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      'rcarriga/nvim-notify',
    },
  },

  -- -------------------------------------------------------------------------------
  -- --- AI/LLM etc
  -- ---
  -- --- https://codecompanion.olimorris.dev/installation.html
  -- ---
  -- --- CUSTOM[nprak]
  -- --- -- === TIER 1: GLOBAL MODEL (Persisted in shada) ===
  -- --- -- === TIER 2: SESSION/WORKSPACE MODEL (Persisted in session file) ===
  --
  -- NOTE[2025-08-15] still not clear what purpose they all have...
  -- Comparing eg:
  -- - opencode + mphub + opencode.nvim
  -- - VS opencode + opencode.vim
  -- - VS opencode + mcphub
  -- - VS opencode directly eg a Neovim tab
  -- - ???
  --
  -- ALTERNATIVE https://github.com/sudo-tee/opencode.nvim
  -- {
  --   'NickvanDyke/opencode.nvim',
  --   dependencies = { 'folke/snacks.nvim' },
  --   ---@type opencode.Config
  --   opts = {
  --     -- Your configuration, if any
  --   },
  -- -- stylua: ignore
  -- keys = {
  --   { '<leader>ot', function() require('opencode').toggle() end, desc = 'Toggle embedded opencode', },
  --   -- { '<leader>oa', function() require('opencode').ask() end, desc = 'Ask opencode', mode = 'n', },
  --   -- { '<leader>oa', function() require('opencode').ask('@selection: ') end, desc = 'Ask opencode about selection', mode = 'v', },
  --   -- { '<leader>op', function() require('opencode').select_prompt() end, desc = 'Select prompt', mode = { 'n', 'v', }, },
  --   -- { '<leader>on', function() require('opencode').command('session_new') end, desc = 'New session', },
  --   { '<leader>oy', function() require('opencode').command('messages_copy') end, desc = 'Copy last message', },
  --   { '<S-C-u>',    function() require('opencode').command('messages_half_page_up') end, desc = 'Scroll messages up', },
  --   { '<S-C-d>',    function() require('opencode').command('messages_half_page_down') end, desc = 'Scroll messages down', },
  -- },
  -- },
  --

  -- ---
  -- --- See also: https://github.com/olimorris/codecompanion.nvim/discussions/1013
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'ravitemer/codecompanion-history.nvim',
      -- installed with `uv tool install "vectorcode[lsp,mcp]<1.0.0"`
      -- cf https://github.com/Davidyz/VectorCode/blob/main/docs/cli.md#installation
      -- WARNING: when using `claude_code` ACP adapter, you can NOT use tools
      -- In this case: `claude mcp add --scope user --transport stdio "vectorcode-mcp-server" vectorcode-mcp-server`
      -- and Claude Code will be able to use vectorcode via MCP on its own
      {
        'Davidyz/VectorCode',
        version = '*',
        build = 'uv tool upgrade vectorcode', -- This helps keeping the CLI up-to-date
        -- build = "pipx upgrade vectorcode", -- If you used pipx to install the CLI
        dependencies = { 'nvim-lua/plenary.nvim' },
      },
    },
    config = function()
      require('codecompanion').setup {
        strategies = {
          chat = { adapter = 'claude_code' },
          inline = { adapter = 'claude_code' },
          cmd = { adapter = 'claude_code' },
        },
        adapters = {
          openrouter = function()
            local openrouter_api_key = vim.env.OPENROUTER_API_KEY
            if not openrouter_api_key then
              vim.notify('OPENROUTER_API_KEY not set for codecompanion.nvim.', vim.log.levels.WARN)
            end
            return require('codecompanion.adapters').extend('openai_compatible', {
              env = {
                url = 'https://openrouter.ai/api',
                api_key = openrouter_api_key,
                chat_url = '/v1/chat/completions',
              },
              schema = {
                model = {
                  default = 'moonshotai/kimi-k2-thinking',
                  -- default = get_current_llm_model,
                },
              },
            })
          end,
          -- https://codecompanion.olimorris.dev/configuration/acp#setup-claude-code
          -- NOTE: `claude-code` installed with AUR (paru) and then `npm install -g @zed-industries/claude-code-acp`
          acp = {
            claude_code = function()
              local claude_token = vim.env.CLAUDE_CODE_OAUTH_TOKEN
              if not claude_token then
                vim.notify('CLAUDE_CODE_OAUTH_TOKEN not set for codecompanion.nvim.', vim.log.levels.WARN)
              end
              return require('codecompanion.adapters').extend('claude_code', {
                env = {
                  CLAUDE_CODE_OAUTH_TOKEN = claude_token,
                },
              })
            end,
          },
        },

        extensions = {
          history = {
            enabled = true,
            opts = {
              --   -- Keymap to open history from chat buffer (default: gh)
              --   keymap = 'gh',
              --   -- Keymap to save the current chat manually (when auto_save is disabled)
              --   save_chat_keymap = 'sc',
              --   -- Save all chats by default (disable to save only manually using 'sc')
              --   auto_save = true,
              -- Number of days after which chats are automatically deleted (0 to disable)
              expiration_days = 30,
              --   -- Picker interface (auto resolved to a valid picker)
              --   picker = 'telescope', --- ("telescope", "snacks", "fzf-lua", or "default")
              --   ---Optional filter function to control which chats are shown when browsing
              --   chat_filter = nil, -- function(chat_data) return boolean end
              --   -- Customize picker keymaps (optional)
              --   picker_keymaps = {
              --     rename = { n = 'r', i = '<M-r>' },
              --     delete = { n = 'd', i = '<M-d>' },
              --     duplicate = { n = '<C-y>', i = '<C-y>' },
              --   },
              --   ---Automatically generate titles for new chats
              --   auto_generate_title = true,
              title_generation_opts = {
                ---Adapter for generating titles (defaults to current chat adapter)
                adapter = 'openrouter', -- "copilot"
                ---Model for generating titles (defaults to current chat model)
                model = 'moonshotai/kimi-k2-thinking', -- "gpt-4o"
                -- model = 'haiku', -- "gpt-4o"
                --     ---Number of user prompts after which to refresh the title (0 to disable)
                --     refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
                --     ---Maximum number of times to refresh the title (default: 3)
                --     max_refreshes = 3,
                --     format_title = function(original_title)
                --       -- this can be a custom function that applies some custom
                --       -- formatting to the title.
                --       return original_title
                --     end,
              },
              ---On exiting and entering neovim, loads the last chat on opening chat
              --- pratn: restoring seems to hang/freeze the UI for a while so restore manually...
              continue_last_chat = false,
              --   ---When chat is cleared with `gx` delete the chat from history
              --   delete_on_clearing_chat = false,
              --   ---Directory path to save the chats
              --   dir_to_save = vim.fn.stdpath 'data' .. '/codecompanion-history',
              --   ---Enable detailed logging for history extension
              --   enable_logging = false,
              --
              --   -- Summary system
              --   summary = {
              --     -- Keymap to generate summary for current chat (default: "gcs")
              --     create_summary_keymap = 'gcs',
              --     -- Keymap to browse summaries (default: "gbs")
              --     browse_summaries_keymap = 'gbs',
              --
              --     generation_opts = {
              --       adapter = nil, -- defaults to current chat adapter
              --       model = nil, -- defaults to current chat model
              --       context_size = 90000, -- max tokens that the model supports
              --       include_references = true, -- include slash command content
              --       include_tool_outputs = true, -- include tool execution results
              --       system_prompt = nil, -- custom system prompt (string or function)
              --       format_summary = nil, -- custom function to format generated summary e.g to remove <think/> tags from summary
              --     },
            },
            --
            --   -- Memory system (requires VectorCode CLI)
            --   memory = {
            --     -- Automatically index summaries when they are generated
            --     auto_create_memories_on_summary_generation = true,
            --     -- Path to the VectorCode executable
            --     vectorcode_exe = 'vectorcode',
            --     -- Tool configuration
            --     tool_opts = {
            --       -- Default number of memories to retrieve
            --       default_num = 10,
            --     },
            --     -- Enable notifications for indexing progress
            --     notify = true,
            --     -- Index all existing memories on startup
            --     -- (requires VectorCode 0.6.12+ for efficient incremental indexing)
            --     index_on_startup = false,
            --   },
            -- },
          },
          vectorcode = {
            enabled = true,
            opts = {
              tool_group = {
                -- this will register a tool group called `@vectorcode_toolbox` that contains all 3 tools
                enabled = true,
                -- a list of extra tools that you want to include in `@vectorcode_toolbox`.
                -- if you use @vectorcode_vectorise, it'll be very handy to include
                -- `file_search` here.
                extras = {},
                collapse = true, -- whether the individual tools should be shown in the chat
              },
              tool_opts = {
                ---@type VectorCode.CodeCompanion.ToolOpts
                ['*'] = { use_lsp = true },
                ---@type VectorCode.CodeCompanion.LsToolOpts
                ls = {},
                ---@type VectorCode.CodeCompanion.VectoriseToolOpts
                vectorise = {},
                ---@type VectorCode.CodeCompanion.QueryToolOpts
                query = {
                  max_num = { chunk = -1, document = -1 },
                  default_num = { chunk = 50, document = 10 },
                  include_stderr = false,
                  use_lsp = false,
                  no_duplicate = true,
                  chunk_mode = false,
                  ---@type VectorCode.CodeCompanion.SummariseOpts
                  summarise = {
                    ---@type boolean|(fun(chat: CodeCompanion.Chat, results: VectorCode.QueryResult[]):boolean)|nil
                    enabled = false,
                    adapter = nil,
                    query_augmented = true,
                  },
                },
                files_ls = {},
                files_rm = {},
              },
            },
          },
        },
      }

      -- -- Keymaps for codecompanion actions and shared model selection
      -- vim.keymap.set({ 'n', 'v' }, '<leader>AK', '<cmd>CodeCompanionActions<cr>', { noremap = true, silent = true, desc = 'CodeCompanion Actions' })
      -- vim.keymap.set({ 'n', 'v' }, '<leader>AA', '<cmd>CodeCompanionChat Toggle<cr>', { noremap = true, silent = true, desc = 'CodeCompanion Toggle Chat' })
      -- -- These now call the shared functions defined at the top
      -- vim.keymap.set('n', '<leader>AS', select_and_persist_session_model, { desc = 'LLM: Set [S]ession Model' })
      -- vim.keymap.set('n', '<leader>AG', set_global_model, { desc = 'LLM: Set [G]lobal Model' })
    end,
  },

  {
    'folke/sidekick.nvim',
    opts = {
      cli = {
        mux = {
          backend = 'tmux',
          enabled = true,
          split = {
            vertical = true,
            size = 50, -- Actual constraints enforced by WinResized autocmd in init.lua
          },
        },
        win = {
          layout = 'right',
          split = {
            width = 0,
          },
          -- Magic Hook for initial sizing; constraints enforced by WinResized autocmd in init.lua
          config = function(terminal)
            local width = math.floor(vim.o.columns * 0.40)
            local target_cols = math.min(60, math.max(40, width))
            terminal.opts.split.width = target_cols
          end,
        },
      },
      -- NES = Next Edit Suggestions: requires Copilot
      nes = { enabled = false },
    },
    keys = {
      {
        '<tab>',
        function()
          -- if there is a next edit, jump to it, otherwise apply it if any
          if not require('sidekick').nes_jump_or_apply() then
            return '<Tab>' -- fallback to normal tab
          end
        end,
        expr = true,
        desc = 'Goto/Apply Next Edit Suggestion',
      },
      {
        '<c-.>',
        function()
          -- Check space before opening (only when opening, not closing)
          local cli = require('sidekick.cli')
          if _G.NvimLayout and type(_G.NvimLayout.can_open_new_split) == 'function' and _G.NvimLayout.LAYOUT then
            local can_open, reason = _G.NvimLayout.can_open_new_split(_G.NvimLayout.LAYOUT.min_sidekick)
            if not can_open then
              vim.notify('Warning: ' .. reason .. ' - Opening anyway', vim.log.levels.WARN)
            end
            _G.NvimLayout.shrink_to_minimums()
          end
          cli.toggle()
        end,
        desc = 'Sidekick Toggle',
        mode = { 'n', 't', 'i', 'x' },
      },
      {
        '<leader>aa',
        function()
          local cli = require('sidekick.cli')
          if _G.NvimLayout and type(_G.NvimLayout.can_open_new_split) == 'function' and _G.NvimLayout.LAYOUT then
            local can_open, reason = _G.NvimLayout.can_open_new_split(_G.NvimLayout.LAYOUT.min_sidekick)
            if not can_open then
              vim.notify('Warning: ' .. reason .. ' - Opening anyway', vim.log.levels.WARN)
            end
            _G.NvimLayout.shrink_to_minimums()
          end
          cli.toggle()
        end,
        desc = 'Sidekick Toggle CLI',
      },
      {
        '<leader>as',
        function()
          require('sidekick.cli').select()
        end,
        -- Or to select only installed tools:
        -- require("sidekick.cli").select({ filter = { installed = true } })
        desc = 'Select CLI',
      },
      {
        '<leader>ad',
        function()
          require('sidekick.cli').close()
        end,
        desc = 'Detach a CLI Session',
      },
      {
        '<leader>at',
        function()
          require('sidekick.cli').send { msg = '{this}' }
        end,
        mode = { 'x', 'n' },
        desc = 'Send This',
      },
      {
        '<leader>af',
        function()
          require('sidekick.cli').send { msg = '{file}' }
        end,
        desc = 'Send File',
      },
      {
        '<leader>av',
        function()
          require('sidekick.cli').send { msg = '{selection}' }
        end,
        mode = { 'x' },
        desc = 'Send Visual Selection',
      },
      {
        '<leader>ap',
        function()
          require('sidekick.cli').prompt()
        end,
        mode = { 'n', 'x' },
        desc = 'Sidekick Select Prompt',
      },
      {
        '<leader>ac',
        function()
          local cli = require('sidekick.cli')
          if _G.NvimLayout and type(_G.NvimLayout.can_open_new_split) == 'function' and _G.NvimLayout.LAYOUT then
            local can_open, reason = _G.NvimLayout.can_open_new_split(_G.NvimLayout.LAYOUT.min_sidekick)
            if not can_open then
              vim.notify('Warning: ' .. reason .. ' - Opening anyway', vim.log.levels.WARN)
            end
            _G.NvimLayout.shrink_to_minimums()
          end
          cli.toggle { name = 'claude', focus = true }
        end,
        desc = 'Sidekick Toggle Claude',
      },
    },
  },

  --- Avante (newly added, also uses shared logic)
  -- {
  --   'yetone/avante.nvim',
  --   build = vim.fn.has 'win32' ~= 0 and 'powershell -ExecutionPolicy Bypass -File Build.ps1' or 'make',
  --   event = 'VeryLazy',
  --   version = false,
  --   opts = function()
  --     local openrouter_api_key = vim.env.CODECOMPANION_OPENROUTER_API_KEY
  --     if not openrouter_api_key then
  --       vim.notify('CODECOMPANION_OPENROUTER_API_KEY not set for avante.nvim.', vim.log.levels.WARN)
  --     end
  --
  --     return {
  --       provider = 'openrouter',
  --       providers = {
  --         openrouter = {
  --           __inherited_from = 'openai',
  --           endpoint = 'https://openrouter.ai/api/v1',
  --           api_key_name = 'CODECOMPANION_OPENROUTER_API_KEY',
  --           timeout = 30000,
  --           -- model = get_current_llm_model(), -- SORT of works, but probably not dynamic
  --           -- does nothing
  --           -- models = {
  --           --   list = available_models,
  --           -- },
  --           -- model = function() -- same as previous
  --           --   return get_current_llm_model()
  --           -- end,
  --           -- models = available_models, -- does nothing
  --           -- models_list = available_models, -- does nothing
  --           --
  --           -- VVV THE DYNAMIC SOLUTION VVV
  --           -- 1. REMOVE the top-level 'model' key. We will set it dynamically.
  --
  --           -- 2. This function is called JUST BEFORE every API request.
  --           --    avante merges the result into the JSON body.
  --           --    FAIL: E5108: Error executing lua: ...re/nvim/lazy/avante.nvim/lua/avante/providers/openai.lua:522: attempt to index local 'request_body' (a function value)
  --           -- extra_request_body = function()
  --           --   return {
  --           --     model = get_current_llm_model(), -- Call the function here
  --           --   }
  --           -- end,
  --           --
  --           -- TRY: https://github.com/yetone/avante.nvim/issues/2557
  --           is_env_set = function()
  --             return true
  --           end,
  --         },
  --         -- Hide all other providers from model selector
  --         copilot = {
  --           hide_in_model_selector = true,
  --         },
  --         -- openai = {
  --         --   hide_in_model_selector = true,
  --         -- },
  --         azure = {
  --           hide_in_model_selector = true,
  --         },
  --         bedrock = {
  --           hide_in_model_selector = true,
  --         },
  --         gemini = {
  --           hide_in_model_selector = true,
  --         },
  --         vertex = {
  --           hide_in_model_selector = true,
  --         },
  --         cohere = {
  --           hide_in_model_selector = true,
  --         },
  --         ollama = {
  --           hide_in_model_selector = true,
  --         },
  --         vertex_claude = {
  --           hide_in_model_selector = true,
  --         },
  --       },
  --       file_selector = {
  --         provider = 'mini.pick',
  --       },
  --       -- system_prompt as function ensures LLM always has latest MCP server state
  --       -- This is evaluated for every message, even in existing chats
  --       system_prompt = function()
  --         local hub = require('mcphub').get_hub_instance()
  --         return hub and hub:get_active_servers_prompt() or ''
  --       end,
  --       -- Using function prevents requiring mcphub before it's loaded
  --       custom_tools = function()
  --         return {
  --           require('mcphub.extensions.avante').mcp_tool(),
  --         }
  --       end,
  --     }
  --   end,
  --   config = function(_, opts)
  --     require('avante').setup(opts)
  --
  --     -- Add keymaps for the shared model selection functions
  --     vim.keymap.set('n', '<leader>AS', select_and_persist_session_model, { desc = 'LLM: Set [S]ession Model (Avante)' })
  --     vim.keymap.set('n', '<leader>AG', set_global_model, { desc = 'LLM: Set [G]lobal Model (Avante)' })
  --   end,
  --   dependencies = {
  --     'nvim-lua/plenary.nvim',
  --     'MunifTanjim/nui.nvim',
  --     'echasnovski/mini.pick',
  --     'hrsh7th/nvim-cmp',
  --     'ibhagwan/fzf-lua',
  --     'stevearc/dressing.nvim',
  --     'folke/snacks.nvim',
  --     'nvim-tree/nvim-web-devicons',
  --     {
  --       'HakonHarnes/img-clip.nvim',
  --       event = 'VeryLazy',
  --       opts = {
  --         default = {
  --           embed_image_as_base64 = false,
  --           prompt_for_file_name = false,
  --           drag_and_drop = { insert_mode = true },
  --           use_absolute_path = true,
  --         },
  --       },
  --     },
  --     {
  --       'MeanderingProgrammer/render-markdown.nvim',
  --       opts = { file_types = { 'markdown', 'Avante' } },
  --       ft = { 'markdown', 'Avante' },
  --     },
  --   },
  -- },

  -- https://ravitemer.github.io/mcphub.nvim/installation.html
  -- ALTERNATIVE? https://github.com/bigcodegen/mcp-neovim-server
  --
  -- {
  --   'ravitemer/mcphub.nvim',
  --   dependencies = {
  --     'nvim-lua/plenary.nvim',
  --   },
  --   build = 'npm install -g mcp-hub@latest', -- Installs `mcp-hub` node binary globally
  --   config = function()
  --     require('mcphub').setup {
  --       extensions = {
  --         avante = {
  --           make_slash_commands = true, -- make /slash commands from MCP server prompts
  --         },
  --       },
  --       -- This sets vim.g.mcphub_auto_approve to true by default (can also be toggled from the HUB UI with `ga`)
  --       auto_approve = true,
  --     }
  --   end,
  -- },

  ------------------------------------------------------------------------------
  --- Just try to prevent eg opening Neovim for `git commit` when already inside a Neovim session [terminal]
  {
    'brianhuster/unnest.nvim',
  },

  -------------------------------------------------------------------------------
  --- Movement training plugins (match nvim-nightly 0.12)
  --- Nudges away from overusing w, b, hjkl toward f, t, /, *, etc.
  {
    'm4xshen/hardtime.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      max_count = 3, -- allow 3 repeated motions before blocking
      max_time = 3000, -- 3 second window (default 1s is too easy to game)
      disable_mouse = false,
      hint = true, -- show "Try using f/t//" hints
      notification = true,
      enabled = true, -- start enabled
      restricted_keys = {
        ['h'] = { 'n', 'x' }, -- blocked
        ['j'] = {}, -- allowed (vertical nav is ok)
        ['k'] = {}, -- allowed (vertical nav is ok)
        ['l'] = { 'n', 'x' }, -- blocked
        ['w'] = { 'n', 'x' }, -- blocked (use f/t instead)
        ['b'] = { 'n', 'x' }, -- blocked (use F/T instead)
      },
    },
    keys = {
      { '<leader>tH', '<cmd>Hardtime toggle<cr>', desc = 'Toggle Hardtime' },
    },
  },
  {
    'tris203/precognition.nvim',
    event = 'VeryLazy', -- Load at startup, not deferred by keys
    opts = {
      startVisible = true,
      showBlankVirtLine = false,
      highlightColor = { fg = '#1abc9c', bg = '#1f2335' }, -- teal fg + darker than cursorline
    },
    config = function(_, opts)
      require('precognition').setup(opts)
      vim.keymap.set('n', '<leader>tp', function()
        require('precognition').toggle()
      end, { desc = 'Toggle Precognition hints' })
    end,
  },

  -------------------------------------------------------------------------------
  -------------------------------------------------------------------------------
  --- NOTE DIY plugins require both:
  --- - ~~call to require ... at the end of the main init.lua~~ NO!
  --- - corresponding Lazy setup here
  {
    dir = vim.fn.stdpath 'config' .. '/lua/custom/wezterm.nvim/',
    opts = {},
  },
}

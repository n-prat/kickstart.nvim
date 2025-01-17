-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
pcall(require('telescope').load_extension, 'persisted')

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
      vim.api.nvim_create_autocmd('User', {
        pattern = 'PersistedSavePre',
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            vim.notify('filetype : ' .. vim.inspect(vim.bo[buf].filetype))
            if vim.bo[buf].filetype == 'snacks_terminal' then
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

      -- basic telescope configuration
      local conf = require('telescope.config').values
      local function toggle_telescope(harpoon_files)
        local file_paths = {}
        for _, item in ipairs(harpoon_files.items) do
          table.insert(file_paths, item.value)
        end

        require('telescope.pickers')
          .new({}, {
            prompt_title = 'Harpoon',
            finder = require('telescope.finders').new_table {
              results = file_paths,
            },
            previewer = conf.file_previewer {},
            sorter = conf.generic_sorter {},
          })
          :find()
      end

      -- NOTE: he is using DVORAK layout so this is converted to qwerty (on azerty hardware)
      -- cf remap.lua for the conversion
      vim.keymap.set('n', '<C-e>', function()
        toggle_telescope(harpoon:list())
      end, { desc = 'Open harpoon window' })

      vim.keymap.set('n', '<leader>a', function()
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
  --- Terminal
  -- DID TRY   'akinsho/toggleterm.nvim but UX is not much better than vanilla terminal
  --    also: running sessionizer in FTerm causes a message "process exited with 0" to be shown when returning
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
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
      --- Git and/or LazyGit
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
      bigfile = {
        --
      },
      quickfile = {
        --
      },
      notifier = {
        --
      },
      input = {
        --
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
  {
    'debugloop/telescope-undo.nvim',
    dependencies = { -- note how they're inverted to above example
      {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
      },
    },
    keys = {
      { -- lazy style key map
        '<leader>u',
        '<cmd>Telescope undo<cr>',
        desc = 'undo history',
      },
    },
    opts = {
      -- don't use `defaults = { }` here, do this in the main telescope spec
      extensions = {
        undo = {
          -- telescope-undo.nvim config, see below
        },
        -- no other extensions here, they can have their own spec too
      },
    },
    config = function(_, opts)
      -- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
      -- configs for us. We won't use data, as everything is in it's own namespace (telescope
      -- defaults, as well as each extension).
      require('telescope').setup(opts)
      require('telescope').load_extension 'undo'
    end,
  },
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
  --- TODO see https://github.com/LazyVim/LazyVim/blob/d0c366e4d861b848bdc710696d5311dca2c6d540/lua/lazyvim/plugins/treesitter.lua#L76
  --- for alternative keymaps
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

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              -- You can optionally set descriptions to the mappings (used in the desc parameter of
              -- nvim_buf_set_keymap) which plugins like which-key display
              ['ic'] = { query = '@class.inner', desc = 'Select inner part of a class region' },
              -- You can also use captures from other query groups like `locals.scm`
              ['as'] = { query = '@local.scope', query_group = 'locals', desc = 'Select language scope' },
            },
            -- You can choose the select mode (default is charwise 'v')
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * method: eg 'v' or 'o'
            -- and should return the mode ('v', 'V', or '<c-v>') or a table
            -- mapping query_strings to modes.
            selection_modes = {
              ['@parameter.outer'] = 'v', -- charwise
              ['@function.outer'] = 'V', -- linewise
              ['@class.outer'] = '<c-v>', -- blockwise
            },
            -- If you set this to `true` (default is `false`) then any textobject is
            -- extended to include preceding or succeeding whitespace. Succeeding
            -- whitespace has priority in order to act similarly to eg the built-in
            -- `ap`.
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * selection_mode: eg 'v'
            -- and should return true or false
            include_surrounding_whitespace = true,
          },
        },

        swap = {
          enable = true,
          swap_next = {
            ['<leader>a'] = '@parameter.inner',
          },
          swap_previous = {
            ['<leader>A'] = '@parameter.inner',
          },
        },

        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          -----------------------------------------------------------
          --- Official README bindings
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = { query = '@class.outer', desc = 'Next class start' },
            --
            -- You can use regex matching (i.e. lua pattern) and/or pass a list in a "query" key to group multiple queries.
            [']o'] = '@loop.*',
            -- ["]o"] = { query = { "@loop.inner", "@loop.outer" } }
            --
            -- You can pass a query group to use query from `queries/<lang>/<query_group>.scm file in your runtime path.
            -- Below example nvim-treesitter's `locals.scm` and `folds.scm`. They also provide highlights.scm and indent.scm.
            [']s'] = { query = '@local.scope', query_group = 'locals', desc = 'Next scope' },
            [']z'] = { query = '@fold', query_group = 'folds', desc = 'Next fold' },
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
          },
          -----------------------------------------------------------
          --- LazyVim bindings
          -- goto_next_start = {
          --   [']f'] = '@function.outer',
          --   [']c'] = '@class.outer',
          --   --
          --   [']a'] = '@parameter.inner',
          -- },
          -- goto_next_end = { --
          --   [']F'] = '@function.outer',
          --   [']C'] = '@class.outer',
          --   [']A'] = '@parameter.inner',
          -- },
          -- goto_previous_start = { --
          --   ['[f'] = '@function.outer',
          --   ['[c'] = '@class.outer',
          --   ['[a'] = '@parameter.inner',
          -- },
          -- goto_previous_end = { --
          --   ['[F'] = '@function.outer',
          --   ['[C'] = '@class.outer',
          --   ['[A'] = '@parameter.inner',
          -- },
          -----------------------------------------------------------
          -- Below will go to either the start or the end, whichever is closer.
          -- Use if you want more granular movements
          -- Make it even more gradual by adding multiple queries and regex.
          goto_next = {
            [']d'] = '@conditional.outer',
          },
          goto_previous = {
            ['[d'] = '@conditional.outer',
          },
        },
      }

      local ts_repeat_move = require 'nvim-treesitter.textobjects.repeatable_move'

      -- Repeat movement with ; and ,
      -- ensure ; goes forward and , goes backward regardless of the last direction
      vim.keymap.set({ 'n', 'x', 'o' }, ';', ts_repeat_move.repeat_last_move_next)
      vim.keymap.set({ 'n', 'x', 'o' }, ',', ts_repeat_move.repeat_last_move_previous)

      -- vim way: ; goes to the direction you were moving.
      -- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
      -- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

      -- Optionally, make builtin f, F, t, T also repeatable with ; and ,
      vim.keymap.set({ 'n', 'x', 'o' }, 'f', ts_repeat_move.builtin_f_expr, { expr = true })
      vim.keymap.set({ 'n', 'x', 'o' }, 'F', ts_repeat_move.builtin_F_expr, { expr = true })
      vim.keymap.set({ 'n', 'x', 'o' }, 't', ts_repeat_move.builtin_t_expr, { expr = true })
      vim.keymap.set({ 'n', 'x', 'o' }, 'T', ts_repeat_move.builtin_T_expr, { expr = true })
    end,
  },
  -------------------------------------------------------------------------------
  --- https://github.com/RRethy/nvim-treesitter-textsubjects
  --- Basically a simplified textobjects + move
  {
    'RRethy/nvim-treesitter-textsubjects',
    event = 'VeryLazy',
    -- MUST use same cond than treesitter itself; or could be cleverer about loading cf linked lazyvim config
    cond = not jit.os:find 'Windows',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter.configs').setup {
        textsubjects = {
          enable = true,
          prev_selection = ',', -- (Optional) keymap to select the previous selection
          keymaps = {
            ['.'] = 'textsubjects-smart',
            [';'] = 'textsubjects-container-outer',
            ['i;'] = { 'textsubjects-container-inner', desc = 'Select inside containers (classes, functions, etc.)' },
          },
        },
      }
    end,
  },
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
  -------------------------------------------------------------------------------
  --- NOTE DIY plugins require both:
  --- - ~~call to require ... at the end of the main init.lua~~ NO!
  --- - corresponding Lazy setup here
  {
    dir = vim.fn.stdpath 'config' .. '/lua/custom/wezterm.nvim/',
    opts = {},
  },
}

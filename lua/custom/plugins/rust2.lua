return {
  ------------------------------------------------------------------------------
  -- pratn use "rustaceanvim" instead of Rust config built into lspconfig
  -- see also LazyVim config: https://github.com/LazyVim/LazyVim/blob/d0c366e4d861b848bdc710696d5311dca2c6d540/lua/lazyvim/plugins/extras/lang/rust.lua
  {
    'mrcjkb/rustaceanvim',
    version = '^6', -- Recommended
    lazy = false, -- This plugin is already lazy
    -- Disabled on windows b/c there we mostly use neovim to edit markdown
    -- Could work; but requires Rust Analyzer so not that relevant
    -- cond = not jit.os:find 'Windows',
    config = function(_, opts)
      -- n-prat: commented out if statement
      --if LazyVim.has("mason.nvim") then
      local package_path = require('mason-registry').get_package('codelldb'):get_install_path()
      local codelldb = package_path .. '/extension/adapter/codelldb'
      local library_path = package_path .. '/extension/lldb/lib/liblldb.dylib'
      local uname = io.popen('uname'):read '*l'
      if uname == 'Linux' then
        library_path = package_path .. '/extension/lldb/lib/liblldb.so'
      end
      opts.dap = {
        adapter = require('rustaceanvim.config').get_codelldb_adapter(codelldb, library_path),
      }
      -- end
      vim.g.rustaceanvim = vim.tbl_deep_extend('keep', vim.g.rustaceanvim or {}, opts or {})
      if vim.fn.executable 'rust-analyzer' == 0 then
        vim.api.nvim_err_writeln '**rust-analyzer** not found in PATH, please install it.\n'
      end
    end,
  },

  -- cf LazyVim config
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'rustaceanvim.neotest',
        },
      }
    end,
    -- Use LazyVim keybinds b/c why not
    -- https://github.com/LazyVim/LazyVim/blob/d0c366e4d861b848bdc710696d5311dca2c6d540/lua/lazyvim/plugins/extras/test/core.lua#L107
    keys = {
      { '<leader>t', '', desc = '+test' },
      {
        '<leader>tt',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = 'Run File (Neotest)',
      },
      {
        '<leader>tT',
        function()
          require('neotest').run.run(vim.uv.cwd())
        end,
        desc = 'Run All Test Files (Neotest)',
      },
      {
        '<leader>tr',
        function()
          require('neotest').run.run()
        end,
        desc = 'Run Nearest (Neotest)',
      },
      {
        '<leader>tl',
        function()
          require('neotest').run.run_last()
        end,
        desc = 'Run Last (Neotest)',
      },
      {
        '<leader>ts',
        function()
          require('neotest').summary.toggle()
        end,
        desc = 'Toggle Summary (Neotest)',
      },
      {
        '<leader>to',
        function()
          require('neotest').output.open { enter = true, auto_close = true }
        end,
        desc = 'Show Output (Neotest)',
      },
      {
        '<leader>tO',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = 'Toggle Output Panel (Neotest)',
      },
      {
        '<leader>tS',
        function()
          require('neotest').run.stop()
        end,
        desc = 'Stop (Neotest)',
      },
      {
        '<leader>tw',
        function()
          require('neotest').watch.toggle(vim.fn.expand '%')
        end,
        desc = 'Toggle Watch (Neotest)',
      },
    },
  },
}

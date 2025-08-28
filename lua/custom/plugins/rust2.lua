return {
  ------------------------------------------------------------------------------
  -- pratn use "rustaceanvim" instead of Rust config built into lspconfig
  -- see also LazyVim config: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/rust.lua
  -- last checked rev: c20c402
  {
    'mrcjkb/rustaceanvim',
    version = '^6', -- Recommended
    ft = { 'rust' },
    lazy = false, -- This plugin is already lazy
    opts = {
      server = {
        -- cf notes-wiki Rust.md for the rational
        cmd = { '/usr/bin/rust-analyzer' },
        auto_attach = function(bufnr)
          return not vim.g.rustacean_disabled
        end,
        on_attach = function(_, bufnr)
          vim.keymap.set('n', '<leader>cA', function()
            vim.cmd.RustLsp 'codeAction' -- supports rust-analyzer's grouping
            -- or vim.lsp.buf.codeAction() if you don't want grouping.
          end, { silent = true, buffer = bufnr, desc = 'rust-analyzer: [C]ode [A]ction' })
          vim.keymap.set(
            'n',
            'K', -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
            function()
              vim.cmd.RustLsp { 'hover', 'actions' }
            end,
            { silent = true, buffer = bufnr, desc = 'rust-analyzer: hover' }
          )
          vim.keymap.set('n', '<leader>co', function()
            vim.cmd.RustLsp 'openCargo'
          end, { silent = true, buffer = bufnr, desc = 'rust-analyzer: [C]ode [O]pen Cargo' })

          -- pratn custom: add a command to temp disable `rust-analyzer` etc
          vim.api.nvim_create_user_command('RustAnalyzerDisableProject', function()
            -- Stop current rust-analyzer clients
            for _, client in ipairs(vim.lsp.get_clients { name = 'rust-analyzer' }) do
              client.stop()
            end

            -- Set global disable flag
            vim.g.rustacean_disabled = true
            vim.notify('rust-analyzer disabled. Restart with `RustAnalyzer start` to re-enable.', vim.log.levels.INFO)
          end, { desc = 'Disable rust-analyzer for current project' })
        end,
        default_settings = {
          -- rust-analyzer language server configuration
          ['rust-analyzer'] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },
            -- Add clippy lints for Rust if using rust-analyzer
            checkOnSave = true,
            -- Enable diagnostics if using rust-analyzer
            diagnostics = {
              enable = true,
            },
            procMacro = {
              enable = true,
              ignored = {
                ['async-trait'] = { 'async_trait' },
                ['napi-derive'] = { 'napi' },
                ['async-recursion'] = { 'async_recursion' },
              },
            },
            files = {
              excludeDirs = {
                '.direnv',
                '.git',
                '.github',
                '.gitlab',
                'bin',
                'node_modules',
                'target',
                'venv',
                '.venv',
              },
            },
          },
        },
      },
    },
    config = function(_, opts)
      -- NOTE: there is a codelldb DAP config in debug.lua
      -- According to https://github.com/mrcjkb/rustaceanvim#using-codelldb-for-debugging
      -- -> if `codelldb` in the PATH [which it SHOULD be when correctly setup with mason] then it will be used
      vim.g.rustaceanvim = vim.tbl_deep_extend('keep', vim.g.rustaceanvim or {}, opts or {})

      -- Disabled on windows b/c there we mostly use neovim to edit markdown
      -- Could work; but requires Rust Analyzer so not that relevant
      -- cond = not jit.os:find 'Windows',
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

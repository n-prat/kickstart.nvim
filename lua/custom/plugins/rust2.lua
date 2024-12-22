return {
  ------------------------------------------------------------------------------
  -- pratn use "rustaceanvim" instead of Rust config built into lspconfig
  -- see also LazyVim config: https://github.com/LazyVim/LazyVim/blob/d0c366e4d861b848bdc710696d5311dca2c6d540/lua/lazyvim/plugins/extras/lang/rust.lua
  {
    'mrcjkb/rustaceanvim',
    version = '^5', -- Recommended
    lazy = false, -- This plugin is already lazy
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
        LazyVim.error('**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/', { title = 'rustaceanvim' })
      end
    end,
  },
}

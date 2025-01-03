-- https://github.com/ThePrimeagen/init.lua/blob/d92308a63554db8bf8d75de5d41403cc2ddd692a/lua/theprimeagen/remap.lua
-- https://youtu.be/w7i4amO_zaE?t=1474
--

-- open Directory listing?
vim.keymap.set('n', '<leader>pv', vim.cmd.Ex)

-- Move text up down (directly without needing to cut/copy/paste)
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- "join" lines? remove CR/LN?
vim.keymap.set('n', 'J', 'mzJ`z')
-- standard "half page jump" BUT keep the cursor in the middle of the screen
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
-- same principle, but for search previous/next
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- greatest remap ever
-- allow to paste over text WHILE keeping cut-ed text the buffer
vim.keymap.set('x', '<leader>p', [["_dP]])

-- next greatest remap ever : asbjornHaland
-- Y will yank into VIM buffer, y into system clipboard
vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]])
vim.keymap.set('n', '<leader>Y', [["+Y]])

-- delete to void register instead of cutting
vim.keymap.set({ 'n', 'v' }, '<leader>d', '"_d')

-- This is going to get me cancelled
vim.keymap.set('i', '<C-c>', '<Esc>')

vim.keymap.set('n', 'Q', '<nop>')
-- n-prat: tmux not set up for now
-- vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
-- n-prat: already set
-- vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- quick fix navigation
vim.keymap.set('n', '<C-k>', '<cmd>cnext<CR>zz')
vim.keymap.set('n', '<C-j>', '<cmd>cprev<CR>zz')
vim.keymap.set('n', '<leader>k', '<cmd>lnext<CR>zz')
vim.keymap.set('n', '<leader>j', '<cmd>lprev<CR>zz')

-- search and replace current work
vim.keymap.set('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
-- make current file executable
vim.keymap.set('n', '<leader>x', '<cmd>!chmod +x %<CR>', { silent = true })

-- various macro for TypeScript?
-- vim.keymap.set('n', '<leader>ee', 'oif err != nil {<CR>}<Esc>Oreturn err<Esc>')
-- vim.keymap.set('n', '<leader>ea', 'oassert.NoError(err, "")<Esc>F";a')
-- vim.keymap.set('n', '<leader>ef', 'oif err != nil {<CR>}<Esc>Olog.Fatalf("error: %s\\n", err.Error())<Esc>jj')
-- vim.keymap.set('n', '<leader>el', 'oif err != nil {<CR>}<Esc>O.logger.Error("error", "error", err)<Esc>F.;i')
--

-- save and source?
-- https://github.com/ThePrimeagen/init.lua/pull/96/files
-- vim.keymap.set('n', '<leader><leader>', function()
--   vim.cmd 'so'
-- end)
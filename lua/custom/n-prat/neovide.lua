-- Neovide docs suggest eg `nvim --headless --listen localhost:9876` but this would skip the config using `if vim.g.neovide` cf https://github.com/neovide/neovide/issues/1868 and https://github.com/neovim/neovim/issues/29634
-- so instead:
--
-- - use ~~`nvim --embed --listen localhost:9876`~~
--   - FAIL b/c that captures stdin which makes Neovide completely useless
-- - `nvim --headless --listen localhost:9876 --cmd 'let g:neovide = true'`
--   - FAIL `E121: Undefined variable: true`
-- - so for now just remove `if vim.g.neovide` and always set the global vars; which is fine FOR NOW but could break in the future if/when Neovide change the way they handle config
--

-- if vim.g.neovide then
-- Put anything you want to happen only in Neovide here
-- https://neovide.dev/configuration.html
vim.g.neovide_scroll_animation_length = 0.1
vim.g.neovide_scroll_animation_far_lines = 0
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_trail_size = 0
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_cursor_smooth_blink = false
vim.g.neovide_cursor_vfx_mode = ''

-- Default font and size of the Windows Terminal
vim.o.guifont = 'Cascadia Mono:h12'
-- end

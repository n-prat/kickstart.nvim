if vim.g.neovide then
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
end

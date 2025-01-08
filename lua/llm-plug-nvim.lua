local M = {}

function M.setup()
  vim.api.nvim_set_keymap('n', '<Leader>gl', ":lua print('Plugin initialized and keybinding works!')<CR>")
end

return M

local M = {}

function M.setup()
  vim.api.nvim_set_keymap('n', '<Leader>gl', ":lua print('Plugin initialized and keybinding works!')<CR>", { noremap = true, silent = false })
end

return M

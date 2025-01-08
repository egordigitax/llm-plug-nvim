local M = {}



-- Function to create the floating window for prompt input
local function create_prompt_window()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local height = 3
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'prompt')
  vim.fn.prompt_setprompt(buf, 'Enter prompt: ')
  return buf
end

-- Function to make the HTTP request to LLM API
local function request_llm(prompt, callback)
  print(prompt)
  local url = "http://localhost:3000/" -- Replace with your actual API endpoint
  local api_key = "YOUR_API_KEY" -- Replace with your API key
  local headers = "-H 'Content-Type: application/json' -H 'Authorization: Bearer " .. api_key .. "'"
  local data = vim.fn.json_encode({ prompt = prompt })

  local cmd = string.format("curl -s -X POST %s -d '%s' '%s'", headers, data, url)
  local response = vim.fn.system(cmd)

    callback(response)
end

-- Main function to handle text selection, input, and API call
function M.replace_with_llm()
  local mode = vim.fn.mode()

  -- Ensure we're in visual mode
  if mode ~= 'v' and mode ~= 'V' then
    print("Please select text in visual mode first!")
    return
  end

  -- Get visual selection
  local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
  local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))

  -- Adjust end_col for line-wise visual mode
  if mode == 'V' then
    start_col = 0
    end_col = #vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1]
  end

  -- Retrieve the selected text
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  if #lines == 0 then
    print("No text selected!")
    return
  end

  -- Concatenate lines into a single string for processing
  local selected_text = table.concat(lines, "\n")

  -- Debugging output
  print("Selected text: " .. selected_text)

  -- Create the prompt window
  local buf = create_prompt_window()

  -- Set up the callback to handle the API response
  local function on_prompt_submit()
    local prompt = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1]
    vim.api.nvim_buf_delete(buf, { force = true })

    if prompt and #prompt > 0 then
      request_llm(prompt, function(response)
        -- Split response into lines
        local response_lines = vim.split(response, "\n", { plain = true })

        -- Replace the selected text with the response
        vim.api.nvim_buf_set_text(0, start_row - 1, start_col, end_row - 1, end_col, response_lines)
        print("Response inserted!")
      end)
    else
      print("Prompt was empty. Aborting.")
    end
  end

  -- Bind <Enter> key in the prompt buffer to submit
  vim.api.nvim_buf_set_keymap(buf, 'i', '<CR>', '', {
    callback = on_prompt_submit,
    noremap = true,
    silent = true,
  })
end

function M.setup()
  vim.api.nvim_set_keymap('n', '<Leader>test', ":lua print('Plugin initialized and keybinding works!')<CR>", { noremap = true, silent = false })
  vim.api.nvim_set_keymap('v', 'gl', ":lua require('llm-plug-nvim').replace_with_llm()<CR>", { noremap = true, silent = true })
end

M.setup()

return M

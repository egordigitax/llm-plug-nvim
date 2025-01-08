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
  local url = "https://api.example.com/v1/llm" -- Replace with your actual API endpoint
  local api_key = "YOUR_API_KEY" -- Replace with your API key
  local headers = "-H 'Content-Type: application/json' -H 'Authorization: Bearer " .. api_key .. "'"
  local data = vim.fn.json_encode({ prompt = prompt })

  local cmd = string.format("curl -s -X POST %s -d '%s' '%s'", headers, data, url)
  local response = vim.fn.system(cmd)

  -- Parse the response
  local success, parsed_response = pcall(vim.fn.json_decode, response)
  if success and parsed_response.choices and parsed_response.choices[1] then
    callback(parsed_response.choices[1].text)
  else
    callback("Error: Unable to parse LLM response")
  end
end

-- Main function to handle text selection, input, and API call
function M.replace_with_llm()
  print('enter func')

  -- Get the selected text
  local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
  local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local selected_text = table.concat(lines, "\n")

  -- Create the prompt window
  local buf = create_prompt_window()

  -- Set up the callback to handle the API response
  local function on_prompt_submit()
    local prompt = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1]
    vim.api.nvim_buf_delete(buf, { force = true })

    if prompt and #prompt > 0 then
      request_llm(prompt, function(response)
        -- Replace the selected text with the response
        vim.api.nvim_buf_set_text(0, start_row - 1, start_col - 1, end_row - 1, end_col, { response })
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

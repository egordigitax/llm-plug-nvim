local M = {}


local opts = {
  llm_url = "https://api.openai.com/v1/chat/completions", -- Default LLM URL
  api_key = "YOUR_API_KEY", -- Default API Key
  model = "gpt-4o-mini",
}

-- Function to configure the plugin
function M.setup(user_opts)
  -- Merge user-provided options with defaults
  opts = vim.tbl_extend("force", opts, user_opts or {})

  -- Debugging output to confirm setup
  print("LLM Plugin configured with URL: " .. opts.llm_url)

  -- Keymap setup
  vim.keymap.set('v', 'gl', function()
    M.replace_with_llm()
  end, { noremap = true, silent = true })
end


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
  -- JSON payload
  local data = vim.fn.json_encode({
    model = opts.model,
    messages = {
      { role = 'user', content = prompt },
    },
  })

  -- Construct curl command
  local cmd = string.format(
    "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '%s' '%s'",
    opts.api_key,
    data:gsub("'", "\\'"), -- Escape single quotes for shell compatibility
    opts.llm_url
  )

  callback(cmd)

  -- Execute the curl command and get the response
  local response = vim.fn.system(cmd)

  -- Parse the JSON response
  local success, parsed_response = pcall(vim.fn.json_decode, response)
  if not success then
    print("Failed to decode response: " .. response)
    callback(response)
    return
  end

  -- Extract the result from `choices`
  if parsed_response and parsed_response.choices and parsed_response.choices[1] then
    callback(parsed_response.choices[1].text)
  else
    print("Unexpected API response: " .. vim.inspect(parsed_response))
    callback(response)
  end
end

-- Main function to handle text selection, input, and API call
function M.replace_with_llm()
  local mode = vim.fn.mode()

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

return M

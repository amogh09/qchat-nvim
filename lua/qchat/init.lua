-- QChat Neovim Plugin

local M = {}

-- Default configuration
local config = {
  window_width = 80,
  window_position = 'right'
}

-- State variables
local state = {
  buffer = nil,
  term_id = nil
}

-- Open Q Chat in a side window
function M.open()
  -- Check if Q Chat is already running
  if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
    vim.notify("Q Chat is already running", vim.log.levels.INFO)
    return
  end

  -- Create a new buffer for Q Chat
  local position = config.window_position == 'right' and 'vertical botright' or 'vertical topleft'
  vim.cmd(position .. ' ' .. config.window_width .. 'new')
  
  -- Set buffer name
  vim.cmd('file Q\\ Chat')
  
  -- Store the buffer number
  state.buffer = vim.api.nvim_get_current_buf()
  
  -- Configure the buffer
  local buffer_options = {
    bufhidden = 'hide',
    swapfile = false,
    buflisted = false,
    filetype = 'qchat',
    number = false,
    relativenumber = false,
    signcolumn = 'no'
  }
  
  for option, value in pairs(buffer_options) do
    vim.api.nvim_buf_set_option(state.buffer, option, value)
  end
  
  -- Start Q Chat in a terminal buffer
  state.term_id = vim.fn.termopen('q chat', {
    on_exit = function(job_id, exit_code, event_type)
      state.term_id = nil
      vim.notify("Q Chat process exited with code " .. exit_code, vim.log.levels.INFO)
    end
  })
  
  -- Enter insert mode to start typing
  vim.cmd('startinsert')
end

-- Close Q Chat
function M.close()
  if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
    -- Send the quit command to Q Chat
    if state.term_id then
      vim.fn.chansend(state.term_id, "/quit\n")
    end
    
    -- Close the buffer
    vim.cmd('bdelete! ' .. state.buffer)
    state.buffer = nil
    state.term_id = nil
  end
end

-- Setup function to configure the plugin
function M.setup(user_config)
  -- Merge user config with defaults
  if user_config then
    for key, value in pairs(user_config) do
      config[key] = value
    end
  end
  
  -- Create commands using the idiomatic Lua approach
  vim.api.nvim_create_user_command('QChatOpen', function()
    M.open()
  end, {})
  
  vim.api.nvim_create_user_command('QChatClose', function()
    M.close()
  end, {})
end

return M

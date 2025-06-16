-- QChat Neovim Plugin

local M = {}

-- Default configuration
local config = {
  window_width = 80,
  window_position = 'right',
  login_command = 'q login',  -- Command to use for login
  debug = false  -- Set to true to enable debug messages
}

-- State variables
local state = {
  status_buffer = nil,  -- Buffer for status messages
  term_buffer = nil,    -- Buffer for terminal
  window = nil,         -- Window ID
  term_id = nil         -- Terminal job ID
}

-- Custom logging function that respects debug setting
local function log(message, level)
  level = level or vim.log.levels.DEBUG

  -- Only show debug messages if debug mode is enabled
  if level == vim.log.levels.DEBUG and not config.debug then
    return
  end

  -- Use silent notification for non-error messages to avoid "Press ENTER" prompts
  if level < vim.log.levels.ERROR then
    vim.cmd('echom "[QChat] ' .. message .. '"')
  else
    vim.notify("[QChat] " .. message, level)
  end
end

-- Update status buffer with message
local function update_status(message_lines)
  if not (state.status_buffer and vim.api.nvim_buf_is_valid(state.status_buffer)) then
    return
  end

  -- Ensure message_lines is a table
  if type(message_lines) == "string" then
    message_lines = {message_lines}
  end

  -- Update buffer content
  vim.api.nvim_buf_set_option(state.status_buffer, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.status_buffer, 0, -1, false, message_lines)
  vim.api.nvim_buf_set_option(state.status_buffer, 'modifiable', false)
end

-- Check if user is logged in to Amazon Q CLI
function M.check_login()
  -- Run a command that requires authentication
  local handle = io.popen("q whoami 2>&1")
  if not handle then
    return false, "Failed to execute Q CLI command"
  end

  local result = handle:read("*a")
  handle:close()

  -- Check if the output contains an authentication error
  if result:match("Not logged in") or result:match("authentication") or result:match("log in") then
    log("Login check failed - " .. result)
    return false, "Not logged in to Amazon Q CLI"
  end

  log("Login check passed")
  return true, "Logged in"
end

-- Asynchronously check login status
function M.check_login_async()
  -- Buffer for collecting output
  local output = ""
  local error_output = ""

  -- Update status message
  update_status({
    "Amazon Q Chat",
    "-------------",
    "",
    "Checking authentication status...",
    "Please wait..."
  })

  -- Start the job to check login status
  local job_id = vim.fn.jobstart("q whoami", {
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            output = output .. line .. "\n"
          end
        end
      end
    end,

    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            error_output = error_output .. line .. "\n"
          end
        end
      end
    end,

    on_exit = function(_, exit_code, _)
      -- Process the results
      if exit_code == 0 then
        log("Authentication check passed")
        M.start_qchat_session()
      else
        log("Authentication check failed: " .. error_output, vim.log.levels.WARN)
        M.show_login_options()
      end
    end,

    -- Detach the process from Neovim
    detach = 0
  })

  if job_id <= 0 then
    -- Job creation failed, show error and fallback
    log("Failed to start authentication check process", vim.log.levels.ERROR)
    M.show_login_options()
  end
end

-- Attempt to login to Amazon Q CLI
function M.attempt_login()
  log("Starting login process", vim.log.levels.INFO)

  -- Close the current window if it exists
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_win_close(state.window, true)
    state.window = nil
  end

  -- Clean up buffers
  if state.status_buffer and vim.api.nvim_buf_is_valid(state.status_buffer) then
    vim.api.nvim_buf_delete(state.status_buffer, {force = true})
    state.status_buffer = nil
  end

  if state.term_buffer and vim.api.nvim_buf_is_valid(state.term_buffer) then
    vim.api.nvim_buf_delete(state.term_buffer, {force = true})
    state.term_buffer = nil
  end

  -- Create a temporary buffer for login
  local login_buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Configure buffer options for terminal use
  vim.api.nvim_buf_set_option(login_buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(login_buf, 'buftype', 'nofile')

  -- Open a floating window for login with title
  local login_win = vim.api.nvim_open_win(login_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = 'Amazon Q Login',
    title_pos = 'center'
  })

  -- Start login process in terminal directly
  local login_term_id = vim.fn.termopen(config.login_command, {
    on_exit = function(job_id, exit_code, event_type)
      log("Login process exited with code " .. exit_code)
      -- Close the login window after completion
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(login_win) then
          vim.api.nvim_win_close(login_win, true)
        end

        -- Reopen the Q Chat window
        vim.defer_fn(function() M.open() end, 500)
      end, 1000)
    end
  })

  -- Enter insert mode to interact with login prompt
  vim.cmd('startinsert')

  return login_term_id ~= 0
end

-- Open Q Chat in a side window
function M.open()
  log("Opening chat window")

  -- Check if Q Chat is already running
  if state.term_buffer and vim.api.nvim_buf_is_valid(state.term_buffer) then
    log("Q Chat is already running")
    return
  end

  -- Create a new buffer for status messages
  state.status_buffer = vim.api.nvim_create_buf(false, true)

  -- Configure the status buffer
  vim.api.nvim_buf_set_option(state.status_buffer, 'modifiable', true)
  vim.api.nvim_buf_set_option(state.status_buffer, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(state.status_buffer, 'swapfile', false)
  vim.api.nvim_buf_set_option(state.status_buffer, 'buflisted', false)
  vim.api.nvim_buf_set_option(state.status_buffer, 'filetype', 'qchat-status')
  vim.api.nvim_buf_set_option(state.status_buffer, 'number', false)
  vim.api.nvim_buf_set_option(state.status_buffer, 'relativenumber', false)
  vim.api.nvim_buf_set_option(state.status_buffer, 'signcolumn', 'no')

  -- Create a new window for the status buffer
  local position = config.window_position == 'right' and 'vertical botright' or 'vertical topleft'
  vim.cmd(position .. ' ' .. config.window_width .. 'new')

  -- Store the window ID
  state.window = vim.api.nvim_get_current_win()

  -- Set the status buffer in the window
  vim.api.nvim_win_set_buf(state.window, state.status_buffer)

  -- Set window name
  vim.cmd('file Q\\ Chat')

  -- Show initial loading message
  update_status({
    "Amazon Q Chat",
    "-------------",
    "",
    "Initializing...",
    "Please wait..."
  })

  -- Check login status asynchronously
  vim.defer_fn(function()
    M.check_login_async()
  end, 10)
end

-- Close Q Chat
function M.close()
  -- Send the quit command to Q Chat if terminal is active
  if state.term_id then
    vim.fn.chansend(state.term_id, "/quit\n")
  end

  -- Close the window if it exists
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_win_close(state.window, true)
    state.window = nil
  end

  -- Clean up buffers
  if state.status_buffer and vim.api.nvim_buf_is_valid(state.status_buffer) then
    vim.api.nvim_buf_delete(state.status_buffer, {force = true})
    state.status_buffer = nil
  end

  if state.term_buffer and vim.api.nvim_buf_is_valid(state.term_buffer) then
    vim.api.nvim_buf_delete(state.term_buffer, {force = true})
    state.term_buffer = nil
  end

  state.term_id = nil
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

-- Show login options in the status buffer
function M.show_login_options()
  if not (state.status_buffer and vim.api.nvim_buf_is_valid(state.status_buffer)) then
    return
  end

  -- Update buffer with login options
  update_status({
    "Amazon Q Chat - Authentication Required",
    "--------------------------------------",
    "",
    "You need to log in to use Amazon Q Chat.",
    "",
    "Press 'l' to log in now",
    "Press 'q' to quit"
  })

  -- Set up keymaps for the buffer
  vim.api.nvim_buf_set_keymap(state.status_buffer, 'n', 'l',
    ':lua require("qchat").attempt_login()<CR>',
    {noremap = true, silent = true})
  vim.api.nvim_buf_set_keymap(state.status_buffer, 'n', 'q',
    ':lua require("qchat").close()<CR>',
    {noremap = true, silent = true})
end

-- Start Q Chat session in a new terminal buffer
function M.start_qchat_session()
  -- Create a new buffer for the terminal
  state.term_buffer = vim.api.nvim_create_buf(false, true)

  -- Configure the terminal buffer
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
    vim.api.nvim_buf_set_option(state.term_buffer, option, value)
  end

  -- Replace the status buffer with the terminal buffer in the window
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_win_set_buf(state.window, state.term_buffer)
  end

  -- Start Q Chat in the terminal buffer
  state.term_id = vim.fn.termopen('q chat', {
    on_exit = function(job_id, exit_code, event_type)
      state.term_id = nil
      log("Q Chat process exited with code " .. exit_code)
    end
  })

  -- Enter insert mode to start typing
  vim.cmd('startinsert')
end

return M
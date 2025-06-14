-- QChat Neovim Plugin

local M = {}

-- Default configuration
local config = {
  window_width = 80,
  window_position = 'right',
  login_command = 'q login'  -- Command to use for login
}

-- State variables
local state = {
  buffer = nil,
  term_id = nil
}

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
    vim.notify("QChat: Login check failed - " .. result, vim.log.levels.DEBUG)
    return false, "Not logged in to Amazon Q CLI"
  end

  vim.notify("QChat: Login check passed", vim.log.levels.DEBUG)
  return true, "Logged in"
end

-- Attempt to login to Amazon Q CLI
function M.attempt_login()
  vim.notify("QChat: Starting login process", vim.log.levels.INFO)

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
      vim.notify("QChat: Login process exited with code " .. exit_code, vim.log.levels.INFO)
      -- Close the login window after completion
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(login_win) then
          vim.api.nvim_win_close(login_win, true)
        end

        -- Check login status again
        local is_logged_in, _ = M.check_login()
        if is_logged_in then
          vim.notify("Successfully logged in to Amazon Q CLI", vim.log.levels.INFO)
          -- Try opening Q Chat again
          vim.defer_fn(function() M.open() end, 500)
        else
          vim.notify("Login failed. Please try again manually with 'q login'", vim.log.levels.ERROR)
        end
      end, 1000)
    end
  })

  -- Enter insert mode to interact with login prompt
  vim.cmd('startinsert')

  return login_term_id ~= 0
end

-- Open Q Chat in a side window
function M.open()
  vim.notify("QChat: Opening chat window", vim.log.levels.INFO)

  -- Check if Q Chat is already running
  if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
    vim.notify("Q Chat is already running", vim.log.levels.INFO)
    return
  end

  vim.notify("QChat: Checking login status", vim.log.levels.INFO)
  -- Check login status before proceeding
  local is_logged_in, message = M.check_login()
  if not is_logged_in then
    vim.notify("QChat: Not logged in, attempting login", vim.log.levels.WARN)
    -- Always attempt to login automatically
    M.attempt_login()
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

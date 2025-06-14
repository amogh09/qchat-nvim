# QChat Neovim Plugin

A simple Neovim plugin for interacting with Amazon Q Chat in a side window.

## Features

- Open Amazon Q Chat in a side window within Neovim
- Close the Q Chat window with a simple command
- Configurable window position and width
- Automatic login handling when not authenticated

## Installation

### Manual Installation

Clone this repository to your Neovim packages directory:

```bash
mkdir -p ~/.local/share/nvim/site/pack/local/start/
git clone https://github.com/yourusername/qchat-nvim.git ~/.local/share/nvim/site/pack/local/start/qchat-nvim
```

### With Home Manager (Nix)

Add the following to your Home Manager configuration:

```nix
{ config, pkgs, ... }:

{
  programs.neovim = {
    # Your existing Neovim configuration...

    plugins = [
      # Your existing plugins...

      # Add the local QChat plugin
      {
        plugin = pkgs.vimUtils.buildVimPlugin {
          name = "qchat-nvim";
          src = ~/stuff/development/qchat-nvim;
        };
      }
    ];
  };
}
```

## Usage

The plugin provides two commands:

- `:QChatOpen` - Opens a new side window with Q Chat (automatically handles login if needed)
- `:QChatClose` - Closes the Q Chat window and terminates the session

## Configuration

You can configure the plugin by setting these variables in your init.lua:

```lua
-- Configure QChat plugin
require('qchat').setup({
  window_width = 100,  -- Set custom width
  window_position = 'left',  -- 'left' or 'right'
  login_command = 'q login'  -- Custom login command if needed
})

-- Key mappings for QChat
vim.keymap.set('n', '<leader>qo', '<cmd>QChatOpen<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>qc', '<cmd>QChatClose<CR>', { noremap = true, silent = true })
```

## Requirements

- Neovim 0.5.0 or later
- Amazon Q CLI installed and configured

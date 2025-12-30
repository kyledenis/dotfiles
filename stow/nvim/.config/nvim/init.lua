-- ============================================================================
-- init.lua - Neovim Configuration
-- ============================================================================

-- General Settings
-- ============================================================================
vim.opt.number = true                  -- Show line numbers
vim.opt.relativenumber = true          -- Show relative line numbers
vim.opt.mouse = 'a'                    -- Enable mouse support
vim.opt.clipboard = 'unnamedplus'      -- Use system clipboard
vim.opt.expandtab = true               -- Use spaces instead of tabs
vim.opt.shiftwidth = 4                 -- Number of spaces for auto indent
vim.opt.tabstop = 4                    -- Number of spaces per tab
vim.opt.softtabstop = 4                -- Number of spaces in tab when editing
vim.opt.smartindent = true             -- Smart indent
vim.opt.wrap = false                   -- Disable line wrap
vim.opt.swapfile = false               -- No swap files
vim.opt.backup = false                 -- No backup files
vim.opt.undofile = true                -- Enable persistent undo
vim.opt.undodir = os.getenv("HOME") .. "/.config/nvim/undo"
vim.opt.hlsearch = true                -- Highlight search results
vim.opt.incsearch = true               -- Incremental search
vim.opt.ignorecase = true              -- Case insensitive search
vim.opt.smartcase = true               -- Case sensitive if uppercase present
vim.opt.termguicolors = true           -- Enable true colors
vim.opt.scrolloff = 8                  -- Keep 8 lines above/below cursor
vim.opt.sidescrolloff = 8              -- Keep 8 columns left/right of cursor
vim.opt.signcolumn = "yes"             -- Always show sign column
vim.opt.updatetime = 50                -- Faster completion
vim.opt.colorcolumn = "80,120"         -- Show column markers
vim.opt.cursorline = true              -- Highlight current line
vim.opt.splitbelow = true              -- Horizontal splits below
vim.opt.splitright = true              -- Vertical splits to the right

-- Create undo directory if it doesn't exist
local undo_dir = vim.fn.expand("~/.config/nvim/undo")
if vim.fn.isdirectory(undo_dir) == 0 then
    vim.fn.mkdir(undo_dir, "p", 0700)
end

-- Leader Key
-- ============================================================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Key Mappings
-- ============================================================================

-- Quick save
vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" })

-- Quick quit
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })

-- Clear search highlighting
vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })

-- Navigate splits
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom split" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top split" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })

-- Resize splits
vim.keymap.set("n", "<leader>+", ":vertical resize +5<CR>", { desc = "Increase split width" })
vim.keymap.set("n", "<leader>-", ":vertical resize -5<CR>", { desc = "Decrease split width" })

-- Move lines up/down
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Better indenting in visual mode
vim.keymap.set("v", "<", "<gv", { desc = "Indent left" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- Plugin Manager (lazy.nvim)
-- ============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
-- ============================================================================
require("lazy").setup({
  -- Color scheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme tokyonight-night]])
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup()
      vim.keymap.set("n", "<leader>n", ":NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
      vim.keymap.set("n", "<leader>f", ":NvimTreeFindFile<CR>", { desc = "Find file in explorer" })
    end,
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>p", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>g", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "Find buffers" })
    end,
  },

  -- Git integration
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
        },
      })
    end,
  },

  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "python", "javascript", "typescript", "html", "css", "bash" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },

  -- Commentary
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  -- Surround
  {
    "kylechui/nvim-surround",
    config = function()
      require("nvim-surround").setup()
    end,
  },

  -- Which-key (shows keybindings)
  {
    "folke/which-key.nvim",
    config = function()
      require("which-key").setup()
    end,
  },
})

-- Auto commands
-- ============================================================================

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})

-- File type specific settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "typescript", "html", "css", "yaml" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

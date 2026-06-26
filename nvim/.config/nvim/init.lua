vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Options (migrated from init.vim)
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.hlsearch = true
vim.opt.listchars = { tab = ">-", trail = "-" }
vim.opt.list = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.textwidth = 80

-- Clipboard over SSH: this machine is headless (no X11/Wayland), so tools
-- like xclip cannot work. OSC 52 sends yanked text through the terminal
-- escape sequences to the local machine's clipboard instead.
if vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
end

-- Bootstrap lazy.nvim (auto-installs if not present)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Colorscheme: https://github.com/catppuccin/nvim
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd("colorscheme catppuccin")
    end,
  },
  -- File explorer: https://github.com/nvim-tree/nvim-tree.lua
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        sort_by = "case_sensitive",
        view = {
          width = 30,
          number = true,
        },
        filters = {
          git_ignored = false,
          dotfiles = false,
        },
      })
    end,
  },
  {
    "gelguy/wilder.nvim",
    build = ":UpdateRemotePlugins",
    config = function()
      local wilder = require("wilder")
      wilder.setup({ modes = { ":", "/", "?" } })
      wilder.set_option("pipeline", {
        wilder.branch(
          wilder.cmdline_pipeline({ language = "vim", fuzzy = 1 }),
          wilder.vim_search_pipeline()
       ),
      })
    end,
  },
  -- Comfy line numbers: https://github.com/mluders/comfy-line-numbers.nvim
  {
    "mluders/comfy-line-numbers.nvim",
    config = function()
      require("comfy-line-numbers").setup({
        labels = {
          '1', '2', '3', '4', '5', '11', '12', '13', '14', '15', '21', '22', '23',
          '24', '25', '31', '32', '33', '34', '35', '41', '42', '43', '44', '45',
          '51', '52', '53', '54', '55', '111', '112', '113', '114', '115', '121',
          '122', '123', '124', '125', '131', '132', '133', '134', '135', '141',
          '142', '143', '144', '145', '151', '152', '153', '154', '155', '211',
          '212', '213', '214', '215', '221', '222', '223', '224', '225', '231',
          '232', '233', '234', '235', '241', '242', '243', '244', '245', '251',
          '252', '253', '254', '255',
        },
        up_key = 'k',
        down_key = 'j',
        hidden_file_types = { 'undotree' },
        hidden_buffer_types = { 'terminal', 'nofile' },
      })
    end,
  },

  {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {},
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
    { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Help tags" },
  },
},

  {
    "weatherwolf/comment-toggle",
    config = function()
      require("comment_toggle").setup()
    end,
  },
  -- Fuzzy finder: https://github.com/nvim-telescope/telescope.nvim
  {
    'nvim-telescope/telescope.nvim', version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      -- optional but recommended
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
      require("telescope").setup({})
      -- Load the native C sorter that was built above (build = 'make')
      require("telescope").load_extension("fzf")
    end,
    keys = {
      { "<leader>tf", "<cmd>Telescope find_files<cr>", desc = "Telescope find files" },
      { "<leader>tg", "<cmd>Telescope live_grep<cr>",  desc = "Telescope live grep" },
      { "<leader>tb", "<cmd>Telescope buffers<cr>",    desc = "Telescope buffers" },
      { "<leader>th", "<cmd>Telescope help_tags<cr>",  desc = "Telescope help tags" },
    },
  },
}, {
  performance = {
    rtp = {
      -- Keep the distro's parser dir (vimdoc.so etc.) in the runtimepath;
      -- lazy.nvim's rtp reset drops it, which breaks treesitter in :help
      paths = { "/usr/lib/nvim" },
    },
  },
})

-- Open file explorer on startup
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("NvimTreeToggle")
  end,
})

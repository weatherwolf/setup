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

-- <leader>log: open a line below with a timestamp, ready to type a log entry
vim.keymap.set("n", "<leader>lo", function()
return "o" .. os.date("[%d-%m-%Y %H:%M:%S] ")
end, { expr = true, desc = "Insert timestamped log line" })

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
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {
		parsers = {
			css=true,
			names= {
				enable = false
			}
		}
	},
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      -- Transparency is owned by the terminal, not by nvim: wezterm sets
      -- window_background_opacity 0.8 + macos_window_background_blur, so the
      -- blurred wallpaper is meant to show through. Any solid background nvim
      -- paints covers that up, so ask catppuccin to leave the background
      -- unset (bg = NONE) everywhere and inherit the terminal's instead.
      --
      -- float.transparent stays at its default false: popups (fzf-lua, lazy,
      -- wilder) keep a solid mantle background so they read as a layer above
      -- the buffer rather than as text floating over the wallpaper.
      -- Folder names and icons are chrome, not meaning: they carry structure,
      -- not pass/fail, so by the two-families rule in palettes/glacier-wave.md
      -- they belong to glacier rather than to catppuccin. Left alone they are
      -- catppuccin blue, and the expand arrows sit on overlay0 at 3.36:1,
      -- which that doc already flags as too low.
      --
      -- custom_highlights rather than a bare nvim_set_hl, so the values are
      -- reapplied whenever the colorscheme reloads instead of being lost.
      -- These hexes are palette roles, so update_palette.sh rewrites them on a
      -- swap; its target list is derived by grep, so this file is picked up
      -- automatically without the script needing to know about it.
      require("catppuccin").setup({
        transparent_background = true,
        custom_highlights = {
          -- Folders are reserve_1, 8.33:1, one step darker than the files
          -- below them: lightness 0.746 against 0.820, same hue. reserve_1 was
          -- chosen over accent_soft, which sits at almost the same lightness,
          -- because accent_soft already paints wezterm's brights[5] and
          -- Claude's permission colour and would have been overloaded. This
          -- promotes a reserve into a real job, which is what the reserves are
          -- for; the palette files record that reserve_1 is no longer spare.
          --
          -- The icon takes the folder colour too, so a folder row reads as one
          -- unit. Colour now carries the folder/file distinction, which until
          -- now rested on the icon and the arrow alone.
          NvimTreeFolderName = { fg = "#9EB687" },
          NvimTreeOpenedFolderName = { fg = "#9EB687" },
          NvimTreeEmptyFolderName = { fg = "#9EB687" },
          NvimTreeSymlinkFolderName = { fg = "#9EB687" },
          NvimTreeFolderIcon = { fg = "#9EB687" },
          -- accent_bright, 10.68:1. Files are the brighter of the pair.
          NvimTreeNormal = { fg = "#BDCAA7" },
          NvimTreeImageFile = { fg = "#BDCAA7" },
          -- A plain file gets no highlight group and falls through to
          -- NvimTreeNormal, but these four have their own and would otherwise
          -- stay catppuccin: executables, special files (README, Makefile),
          -- symlinks and open buffers. In a dotfiles repo that is most of the
          -- tree. Symlinks keep their underline, which is the only thing left
          -- distinguishing them from a plain file, since all four share the
          -- file colour.
          NvimTreeExecFile = { fg = "#BDCAA7" },
          NvimTreeSpecialFile = { fg = "#BDCAA7" },
          NvimTreeSymlink = { fg = "#BDCAA7", underline = true },
          NvimTreeOpenedFile = { fg = "#BDCAA7" },
          -- text_bright: 15.02:1, so the root path outranks the tree below it.
          NvimTreeRootFolder = { fg = "#F8F3EF" },
          -- text_dim: 5.46:1, replacing overlay0's 3.36:1. Left as-is: the
          -- arrows are a third, dimmer level below both folders and files.
          NvimTreeFolderArrowClosed = { fg = "#819171" },
          NvimTreeFolderArrowOpen = { fg = "#819171" },
        },
      })
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
  opts = {
    file_ignore_patterns = { "^logs/", "/logs/", "^docs/", "/docs/", "^.venv/", "/.venv/" },
    grep = {
      rg_opts = "--column --line-number --no-heading --color=always --smart-case "
        .. "--hidden --no-ignore --glob '!.git/' --max-columns=4096 -e",
    },
  },
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
--  -- Fuzzy finder: https://github.com/nvim-telescope/telescope.nvim
--  {
--    'nvim-telescope/telescope.nvim', version = '*',
--    dependencies = {
--      'nvim-lua/plenary.nvim',
--      -- optional but recommended
--      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
--    },
--    config = function()
--      require("telescope").setup({})
--      -- Load the native C sorter that was built above (build = 'make')
--      require("telescope").load_extension("fzf")
--    end,
--    keys = {
--      { "<leader>tf", "<cmd>Telescope find_files<cr>", desc = "Telescope find files" },
--      { "<leader>tg", "<cmd>Telescope live_grep<cr>",  desc = "Telescope live grep" },
--      { "<leader>tb", "<cmd>Telescope buffers<cr>",    desc = "Telescope buffers" },
--      { "<leader>th", "<cmd>Telescope help_tags<cr>",  desc = "Telescope help tags" },
--    },
--  },
  -- Git diff/merge viewer: https://github.com/sindrets/diffview.nvim
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    keys = {
      { "<leader>dv", "<cmd>DiffviewOpen<cr>", desc = "Diffview open" },
      { "<leader>ds", "<cmd>DiffviewOpen --staged<cr>", desc = "Diffview staged" },
      { "<leader>dc", "<cmd>DiffviewClose<cr>", desc = "Diffview close" },
      { "<leader>dh", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview file history" },
    },
    config = function()
      require("diffview").setup({})
    end,
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

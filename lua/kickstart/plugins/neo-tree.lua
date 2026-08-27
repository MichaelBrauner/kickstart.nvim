-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

require('neo-tree').setup {
  -- The defaults are Nerd Font glyphs from the private use area. Without a
  -- Nerd Font they only render because some fallback font happens to cover
  -- those codepoints -- see `vim.g.have_nerd_font`.
  default_component_configs = {
    git_status = {
      symbols = {
        added = '+',
        deleted = '-',
        modified = '~',
        renamed = '>',
        untracked = '?',
        ignored = 'i',
        unstaged = '*',
        staged = '=',
        conflict = '!',
      },
    },
  },
  filesystem = {
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
}

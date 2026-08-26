-- ============================================================
-- Darstellung ohne Nerd Font
--
-- neo-tree bringt eigene Symbole mit und richtet sich nicht nach
-- vim.g.have_nerd_font. Ohne passende Schrift erscheinen sie als
-- Ersatzkaestchen mit Hex-Codes.
--
-- Diese Datei ersetzt sie durch schlichte Zeichen, die jede Schrift
-- darstellen kann. Kommt spaeter eine Nerd Font dazu, genuegt es,
-- diese Datei zu loeschen und have_nerd_font in init.lua auf true zu
-- setzen.
-- ============================================================

vim.api.nvim_create_autocmd('User', {
  pattern = 'NeoTreeSetup',
  callback = function() end,
})

require('neo-tree').setup {
  default_component_configs = {
    icon = {
      folder_closed = '▸',
      folder_open = '▾',
      folder_empty = '▹',
      -- Ein Leerzeichen statt eines Dateisymbols: die Namen bleiben
      -- buendig untereinander, ohne Platzhalterzeichen.
      default = ' ',
    },
    git_status = {
      symbols = {
        added = '+',
        modified = '~',
        deleted = '-',
        renamed = '>',
        untracked = '?',
        ignored = ' ',
        unstaged = '*',
        staged = '+',
        conflict = '!',
      },
    },
  },
  window = {
    width = 32,
  },
}

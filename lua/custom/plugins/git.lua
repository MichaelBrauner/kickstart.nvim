-- ============================================================
-- Git-Oberflaeche
--
-- Deckt die beiden Arbeitsablaeufe ab, die in PhpStorm auf
-- Strg+K und Alt+9 liegen:
--
--   Neogit    -- Statusansicht: was ist geaendert, was ist vorgemerkt,
--                stagen, unstagen, committen, pushen. Entspricht dem
--                Commit-Fenster (Strg+K).
--   Diffview  -- Nebeneinander-Vergleich und Verlauf einer Datei oder
--                des ganzen Projekts. Entspricht dem Git-Werkzeugfenster
--                (Alt+9).
--
-- Die Randmarkierungen und das Stagen einzelner Bloecke kommen von
-- gitsigns, das kickstart bereits mitbringt.
-- ============================================================

local function gh(repo)
  return 'https://github.com/' .. repo
end

vim.pack.add {
  gh 'nvim-lua/plenary.nvim', -- Abhaengigkeit von Neogit
  gh 'sindrets/diffview.nvim',
  gh 'NeogitOrg/neogit',
}

require('diffview').setup {
  enhanced_diff_hl = true, -- kraeftigere Farben im Vergleich
  view = {
    merge_tool = {
      layout = 'diff3_mixed', -- bei Konflikten: beide Seiten plus Ergebnis
    },
  },
}

require('neogit').setup {
  graph_style = 'unicode', -- huebscherer Commit-Graph
  integrations = {
    diffview = true, -- `d` in der Statusansicht oeffnet Diffview
    telescope = true, -- Branch-/Commit-Auswahl ueber Telescope
  },
  signs = {
    section = { '', '' },
    item = { '', '' },
  },
}

-- ------------------------------------------------------------
-- Tastenkuerzel
--
-- <C-k> und <M-9> bilden die PhpStorm-Gewohnheit ab.
--
-- <C-k> kommt ueberall an. <M-9> faengt GNOME Terminal dagegen selbst ab
-- (dort wechselt es den Tab), waehrend es in kitty, alacritty und wezterm
-- funktioniert -- das Mapping bleibt deshalb fuer andere Maschinen stehen.
-- Der Weg, der ueberall funktioniert, ist <leader>gl.
-- ------------------------------------------------------------
local map = function(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { desc = desc, silent = true })
end

-- Statusansicht / Commit -- PhpStorm: Strg+K
map('<C-k>', function() require('neogit').open() end, 'Git: Statusansicht (Commit)')
map('<leader>gs', function() require('neogit').open() end, '[G]it: [S]tatusansicht')
map('<leader>gc', function() require('neogit').open { 'commit' } end, '[G]it: [C]ommit')

-- Verlauf -- PhpStorm: Alt+9
map('<M-9>', '<cmd>DiffviewFileHistory<cr>', 'Git: Projektverlauf')
map('<leader>gl', '<cmd>DiffviewFileHistory<cr>', '[G]it: Ver[l]auf des Projekts')
map('<leader>gL', '<cmd>DiffviewFileHistory %<cr>', '[G]it: Verlauf dieser Datei')

-- Aenderungen ansehen
map('<leader>gd', '<cmd>DiffviewOpen<cr>', '[G]it: [D]iff der Arbeitskopie')
map('<leader>gD', '<cmd>DiffviewOpen origin/HEAD...HEAD<cr>', '[G]it: [D]iff gegen origin')
map('<leader>gb', '<cmd>Gitsigns blame<cr>', '[G]it: [B]lame')

-- In Diffview- und Neogit-Fenstern schliesst q die Ansicht.
vim.api.nvim_create_autocmd('FileType', {
  desc = 'q schliesst Git-Fenster',
  group = vim.api.nvim_create_augroup('custom-git-close', { clear = true }),
  pattern = { 'DiffviewFiles', 'DiffviewFileHistory', 'NeogitStatus', 'NeogitLogView' },
  callback = function(ev)
    vim.keymap.set('n', 'q', '<cmd>tabclose<cr>', { buffer = ev.buf, silent = true })
  end,
})

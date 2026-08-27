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
  -- Ohne Nerd Font (vim.g.have_nerd_font) fehlt nvim-web-devicons.
  -- Diffview verlangt es sonst und warnt bei jedem Oeffnen.
  use_icons = false,
  signs = { fold_closed = '▸', fold_open = '▾', done = '✓' },
  enhanced_diff_hl = true, -- kraeftigere Farben im Vergleich
  view = {
    merge_tool = {
      layout = 'diff3_mixed', -- bei Konflikten: beide Seiten plus Ergebnis
    },
  },
  file_panel = {
    -- 35 waere Default -- zu schmal, Dateinamen brechen dann ab.
    win_config = { width = 45 },
  },
  keymaps = {
    -- Enter liegt per Default auf select_entry: oeffnet den Diff, laesst den
    -- Cursor aber im Panel stehen. focus_entry springt mit hinein.
    file_panel = {
      { 'n', '<cr>', function() require('diffview.actions').focus_entry() end, { desc = 'Diff oeffnen und hineinspringen' } },
      { 'n', '<C-l>', function() require('diffview.actions').focus_entry() end, { desc = 'Diff oeffnen und hineinspringen' } },
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

-- ------------------------------------------------------------
-- Naechste/vorige Aenderung -- PhpStorm: F7 / Umschalt+F7
--
-- ]c und [c koennen das nur innerhalb einer Datei und melden am letzten
-- Hunk gar nichts -- es sieht dann aus, als waere die Taste kaputt.
-- Diese Variante springt weiter zur naechsten Datei im Diff und findet
-- das Diff-Fenster auch, wenn der Cursor noch im Dateipanel steht.
-- ------------------------------------------------------------
local function focus_diff()
  if vim.wo.diff then return true end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if vim.wo[win].diff and not name:match '/%.git/' then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end
  return false
end

local function jump_change(motion, entry, landing)
  if not focus_diff() then
    return vim.notify('Kein Diff-Fenster in diesem Tab', vim.log.levels.WARN)
  end

  local before = vim.api.nvim_win_get_cursor(0)[1]
  vim.cmd('normal! ' .. motion)
  if vim.api.nvim_win_get_cursor(0)[1] ~= before then return end

  -- Cursor steht schon am letzten Hunk der Datei: eine Datei weiter.
  require('diffview.actions')[entry]()
  vim.schedule(function()
    if not focus_diff() then return end
    vim.cmd('normal! ' .. landing)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    if vim.fn.diff_hlID(line, 1) == 0 then vim.cmd('normal! ' .. motion) end
  end)
end

-- Terminals schicken fuer Umschalt+F7 die Sequenz aus kf19 -- Neovim sieht
-- also <F19>, nie <S-F7>. Beide mappen: <S-F7> greift in GUIs.
local prev_change = function() jump_change('[c', 'select_prev_entry', 'G') end

map('<F7>', function() jump_change(']c', 'select_next_entry', 'gg') end, 'Git: naechste Aenderung')
map('<F19>', prev_change, 'Git: vorige Aenderung')
map('<S-F7>', prev_change, 'Git: vorige Aenderung')

-- In Diffview- und Neogit-Fenstern schliesst q die Ansicht.
vim.api.nvim_create_autocmd('FileType', {
  desc = 'q schliesst Git-Fenster',
  group = vim.api.nvim_create_augroup('custom-git-close', { clear = true }),
  pattern = { 'DiffviewFiles', 'DiffviewFileHistory', 'NeogitStatus', 'NeogitLogView' },
  callback = function(ev)
    vim.keymap.set('n', 'q', '<cmd>tabclose<cr>', { buffer = ev.buf, silent = true })
  end,
})

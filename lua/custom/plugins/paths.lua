-- ============================================================
-- Pfad der aktuellen Datei ins Clipboard
--
-- Entspricht "Copy Path/Reference..." aus PhpStorm.
--
-- Als Projekt-Root gilt das naechste Verzeichnis mit composer.json
-- oder .git -- bei einem Symfony-Projekt also der Symfony-Root,
-- unabhaengig davon, in welchem Unterverzeichnis Neovim gestartet
-- wurde. `%` waere relativ zum cwd und damit unzuverlaessig.
--
-- Strg+Umschalt+> laesst sich im Terminal nicht nachbauen: Umschalt
-- wird bei Strg-Kombinationen gar nicht uebertragen. Daher <leader>y.
-- ============================================================

local function projekt_root()
  return vim.fs.root(0, { 'composer.json', '.git' }) or assert(vim.uv.cwd())
end

-- Alle Varianten des Pfads der aktuellen Datei, oder nil in Buffern
-- ohne Datei (Panels, Hilfe, Terminals).
local function pfade()
  local absolut = vim.api.nvim_buf_get_name(0)
  if absolut == '' or vim.bo.buftype ~= '' then
    return nil
  end

  local relativ = vim.fs.relpath(projekt_root(), absolut) or absolut

  return {
    { name = 'Pfad ab Projekt-Root', wert = relativ },
    { name = 'Pfad mit Zeile', wert = relativ .. ':' .. vim.api.nvim_win_get_cursor(0)[1] },
    { name = 'Verzeichnis ab Projekt-Root', wert = vim.fs.dirname(relativ) },
    { name = 'Absoluter Pfad', wert = absolut },
    { name = 'Absolutes Verzeichnis', wert = vim.fs.dirname(absolut) },
    { name = 'Dateiname', wert = vim.fs.basename(absolut) },
  }
end

local function kopieren(wert)
  vim.fn.setreg('+', wert)
  vim.notify(wert)
end

-- Kopiert die Variante an dieser Position direkt.
local function kopiere_variante(position)
  return function()
    local varianten = pfade()
    if not varianten then
      return vim.notify('Dieser Buffer hat keine Datei', vim.log.levels.WARN)
    end

    kopieren(varianten[position].wert)
  end
end

-- Popup mit allen Varianten -- das Gegenstueck zu PhpStorms Auswahlliste.
local function kopiere_mit_auswahl()
  local varianten = pfade()
  if not varianten then
    return vim.notify('Dieser Buffer hat keine Datei', vim.log.levels.WARN)
  end

  vim.ui.select(varianten, {
    prompt = 'Pfad kopieren',
    format_item = function(variante) return variante.name .. ':  ' .. variante.wert end,
  }, function(variante)
    if variante then kopieren(variante.wert) end
  end)
end

local map = function(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { desc = desc, silent = true })
end

map('<leader>yy', kopiere_variante(1), '[Y]ank: Pfad ab Projekt-Root')
map('<leader>yl', kopiere_variante(2), '[Y]ank: Pfad mit Zei[l]e')
map('<leader>yd', kopiere_variante(3), '[Y]ank: [D]irectory ab Projekt-Root')
map('<leader>yY', kopiere_variante(4), '[Y]ank: absoluter Pfad')
map('<leader>yD', kopiere_variante(5), '[Y]ank: absolutes [D]irectory')
map('<leader>yn', kopiere_variante(6), '[Y]ank: [N]ame der Datei')
map('<leader>yp', kopiere_mit_auswahl, '[Y]ank: [P]fad auswaehlen')

pcall(function() require('which-key').add { { '<leader>y', group = '[Y]ank Pfad' } } end)

-- ============================================================
-- Sitzungen und Projektwechsel
--
-- In Neovim gibt es kein "Projekt oeffnen": das Arbeitsverzeichnis,
-- in dem du nvim startest, ist das Projekt. Was dabei fehlt, ist der
-- Komfort von PhpStorm -- zuletzt geoeffnete Projekte und der
-- wiederhergestellte Zustand.
--
-- Genau das ergaenzt auto-session: Beim Verlassen wird der Zustand
-- des Arbeitsverzeichnisses gespeichert (offene Dateien, Fenster-
-- aufteilung, Cursorpositionen), beim naechsten Start im selben
-- Verzeichnis automatisch wiederhergestellt.
-- ============================================================

local function gh(repo)
  return 'https://github.com/' .. repo
end

vim.pack.add { gh 'rmagatti/auto-session' }

-- Was in einer Sitzung gespeichert wird.
--
-- `localoptions` ist wichtig: ohne den Eintrag gehen puffereigene
-- Einstellungen verloren -- etwa die vier Leerzeichen Einrueckung, die
-- fuer PHP gesetzt sind.
--
-- `blank` und `terminal` bleiben bewusst draussen: leere Puffer und
-- Terminalfenster will man beim naechsten Start selten zurueck.
vim.o.sessionoptions = 'buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions'

require('auto-session').setup {
  -- Verzeichnisse, fuer die keine Sitzung angelegt wird. Im
  -- Home-Verzeichnis oder in /tmp zu speichern stiftet nur Verwirrung.
  suppressed_dirs = { '~/', '~/Downloads', '~/Desktop', '/tmp', '/' },

  -- Beim Start ohne Argumente nicht automatisch die letzte Sitzung
  -- laden. `nvim` bleibt damit ein leerer Editor; eine Sitzung kommt
  -- nur, wenn du im Projektverzeichnis startest.
  auto_restore_last_session = false,

  -- Neo-tree muss vor dem Speichern geschlossen werden, sonst wird der
  -- Dateibaum als normaler Puffer wiederhergestellt und zeigt beim
  -- naechsten Start nur Unsinn an.
  pre_save_cmds = { 'Neotree close' },

  session_lens = {
    load_on_setup = true, -- Auswahlliste ueber Telescope
  },
}

-- ------------------------------------------------------------
-- Tastenkuerzel
--
-- <leader>pp entspricht am ehesten "Recent Projects": eine Liste der
-- gespeicherten Sitzungen, auswaehlen, fertig -- samt Zustand.
-- ------------------------------------------------------------
local map = function(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { desc = desc, silent = true })
end

map('<leader>pp', '<cmd>SessionSearch<cr>', '[P]rojekte: zuletzt geoeffnete')
map('<leader>ps', '<cmd>SessionSave<cr>', '[P]rojekt: Sitzung [s]peichern')
map('<leader>pd', '<cmd>SessionDelete<cr>', '[P]rojekt: Sitzung [l]oeschen')

-- ------------------------------------------------------------
-- Projektverzeichnis wechseln, ohne Neovim zu verlassen
--
-- Sucht Projekte anhand von Markern (.git, composer.json) unterhalb
-- der ueblichen Ablageorte und wechselt das Arbeitsverzeichnis dorthin.
-- Die laufende Sitzung wird vorher gespeichert, die des Ziels geladen.
-- ------------------------------------------------------------
local PROJEKT_WURZELN = {
  vim.fn.expand '~/Dev/Projects',
  vim.fn.expand '~/Dev',
}

-- Projekte anhand von .git bzw. composer.json finden.
--
-- Ueber vim.fs.find zu suchen ist hier keine Option: ~/Dev enthaelt
-- rund 171.000 Verzeichnisse, davon 129.000 in vendor/ und
-- node_modules/. Ein vollstaendiger Durchlauf dauert knapp 12 Sekunden,
-- in denen Neovim steht.
--
-- fd ueberspringt die uninteressanten Zweige und ist damit um
-- Groessenordnungen schneller. Es gehoert ohnehin zu den
-- Voraussetzungen dieser Konfiguration; fehlt es doch einmal, greift
-- weiter unten ein einfacher Rueckfallweg.
local function projekte_finden()
  local gefunden, gesehen = {}, {}

  local function aufnehmen(dir)
    if dir and dir ~= '' and not gesehen[dir] then
      gesehen[dir] = true
      table.insert(gefunden, dir)
    end
  end

  for _, wurzel in ipairs(PROJEKT_WURZELN) do
    if vim.uv.fs_stat(wurzel) then
      if vim.fn.executable 'fd' == 1 then
        local treffer = vim.system({
          'fd',
          '--hidden',
          '--max-depth', '3',
          '--prune', -- gefundene Zweige nicht weiter durchsuchen
          '--exclude', 'vendor',
          '--exclude', 'node_modules',
          '--exclude', 'var',
          '--absolute-path',
          '^(\\.git|composer\\.json)$',
          wurzel,
        }, { text = true }):wait()

        for _, pfad in ipairs(vim.split(treffer.stdout or '', '\n', { trimempty = true })) do
          aufnehmen(vim.fs.dirname((pfad:gsub('/$', ''))))
        end
      else
        -- Rueckfallweg ohne fd: nur zwei Ebenen tief schauen.
        for name, typ in vim.fs.dir(wurzel, { depth = 2 }) do
          if typ == 'directory' or typ == 'file' then
            local dir = vim.fs.joinpath(wurzel, name)
            local eltern = vim.fs.dirname(dir)
            if vim.fs.basename(dir) == '.git' or vim.fs.basename(dir) == 'composer.json' then aufnehmen(eltern) end
          end
        end
      end
    end
  end

  table.sort(gefunden)
  return gefunden
end

vim.api.nvim_create_user_command('Projekt', function()
  vim.ui.select(projekte_finden(), {
    prompt = 'Projekt wechseln:',
    format_item = function(pfad)
      return pfad:gsub('^' .. vim.pesc(vim.fn.expand '~'), '~')
    end,
  }, function(auswahl)
    if not auswahl then
      return
    end
    require('auto-session').SaveSession()
    vim.cmd.cd(auswahl)
    require('auto-session').RestoreSession(auswahl)
    vim.notify('Projekt: ' .. auswahl, vim.log.levels.INFO)
  end)
end, { desc = 'Projektverzeichnis wechseln' })

map('<leader>pw', '<cmd>Projekt<cr>', '[P]rojekt [w]echseln')

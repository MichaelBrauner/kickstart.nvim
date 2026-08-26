-- ============================================================
-- Symfony Language Tools (offizieller Symfony-LSP, Beta)
--
-- Ergaenzt intelephense, ersetzt es nicht: intelephense versteht PHP
-- als Sprache, dieser Server versteht Symfony als Framework -- also
-- Route-Namen, Service-IDs, Template-Pfade, Uebersetzungsschluessel,
-- Umgebungsvariablen, Messenger, Doctrine, Forms und Security.
--
-- https://github.com/symfony/language-tools
-- ============================================================

-- ------------------------------------------------------------
-- Welches PHP der Server benutzt
--
-- Der Server bootet den Symfony-Kernel, um den kompilierten Container
-- auszulesen -- daher stammt seine Treffsicherheit. Dafuer braucht er
-- ein PHP mit den ueblichen Extensions (dom, xml, mbstring, intl ...).
--
-- Auf diesem Rechner ist `php` die Version 8.4 und praktisch ohne
-- Extensions installiert; damit scheitert jeder Kernel-Boot an
-- "Extension DOM is required". Der Server meldet dann nur
-- "could not initialize runtime metadata" und faellt still auf rein
-- statische Analyse zurueck -- Route-Vervollstaendigung liefert
-- kommentarlos null Ergebnisse.
--
-- php8.3 ist vollstaendig ausgestattet und bootet die Projekte.
--
-- Dauerhafte Alternative -- die fehlenden Extensions nachruesten:
--   sudo apt install php8.4-{xml,mbstring,intl,curl,zip,mysql}
-- Danach kann hier wieder 'php' stehen.
-- ------------------------------------------------------------
local PHP = { 'php8.3' }

-- ------------------------------------------------------------
-- Nur in echten Symfony-Anwendungen starten
--
-- Die mitgelieferten root_markers sind `composer.json` und `.git`.
-- Damit wuerde der Server in jedem PHP-Projekt anspringen -- auch in
-- Laravel-Apps, in Legacy-Code und in Bundles, die gar keine
-- Anwendung sind. Deshalb suchen wir gezielt nach Markern, die es nur
-- in einer lauffaehigen Symfony-Anwendung gibt:
--
--   symfony.lock  -> von Symfony Flex angelegt
--   bin/console   -> die Konsole der Anwendung
--
-- Beides fehlt in Bundles (kein bin/console) und in Laravel
-- (dort heisst die Konsole `artisan`).
-- ------------------------------------------------------------
local function find_symfony_root(bufnr, on_dir)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == '' then
    return
  end

  local root = vim.fs.root(fname, function(name, path)
    if name == 'symfony.lock' then
      return true
    end
    -- bin/console zaehlt nur, wenn daneben auch eine composer.json liegt
    return name == 'composer.json' and vim.uv.fs_stat(vim.fs.joinpath(path, 'bin', 'console')) ~= nil
  end)

  if root then
    on_dir(root)
  end
end

vim.lsp.config('symfony_lsp', {
  root_dir = find_symfony_root,

  init_options = {
    phpCommand = PHP,

    -- workspaceTrust entscheidet, ob der Server Anwendungscode
    -- ausfuehren darf:
    --
    --   true          -> Kernel wird gebootet, volle Genauigkeit
    --   false         -> nur statische Analyse
    --   nicht gesetzt -> der Server fragt beim ersten Mal nach
    --
    -- Bewusst nicht gesetzt: In ~/Dev liegen neben eigenen Projekten
    -- auch fremde Bundles und Reproducer. Bei denen soll nicht
    -- ungefragt Projektcode laufen. Die Antwort gilt pro
    -- Server-Prozess, also einmal je Neovim-Sitzung.
    --
    -- Fuer Projekte, denen du dauerhaft vertraust: siehe unten.
    trace = 'off',
  },

  -- WICHTIG: phpCommand muss auch hier stehen. Der Server liest die
  -- Laufzeiteinstellungen aus `settings`, nicht aus `init_options` --
  -- steht es nur oben, benutzt er weiterhin `php` und der
  -- Kernel-Boot scheitert.
  settings = {
    symfonyLsp = {
      phpCommand = PHP,
      environment = 'dev',
      debug = true,
      runtimeIndexing = true,
      -- Diagnosen fuer fehlende Uebersetzungsschluessel: standardmaessig
      -- aus, weil sie in mehrsprachigen Projekten schnell rauschen.
      translationDiagnostics = false,
    },
  },

  -- Grosse Projekte sprengen PHPs Standard-Speichergrenze.
  cmd_env = { SYMFONY_LSP_MEMORY_LIMIT = '2G' },
})

vim.lsp.enable 'symfony_lsp'

-- ------------------------------------------------------------
-- Projektbezogenes Vertrauen
--
-- Mit `exrc` liest Neovim eine .nvim.lua aus dem Projektverzeichnis --
-- allerdings erst, nachdem du sie einmal bestaetigt hast. Neovim merkt
-- sich die Entscheidung ueber eine Pruefsumme; aendert sich die Datei,
-- wird erneut gefragt.
--
-- In einem Projekt, dem du vertraust:
--
--   -- <projekt>/.nvim.lua
--   vim.lsp.config('symfony_lsp', {
--     init_options = { workspaceTrust = true },
--   })
--
-- .nvim.lua gehoert in .gitignore, wenn sie nicht ins Projekt-Repo soll.
-- ------------------------------------------------------------
vim.o.exrc = true

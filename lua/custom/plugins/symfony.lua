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
-- auszulesen -- daher stammt seine Treffsicherheit. Scheitert das,
-- meldet er nur "could not initialize runtime metadata" und faellt
-- still auf rein statische Analyse zurueck: Vervollstaendigung von
-- Route-Namen und Service-IDs liefert dann kommentarlos nichts.
--
-- Auf diesem Rechner gibt es zwei PHP-Versionen mit gegenlaeufigen
-- Schwaechen:
--
--   php8.3  vollstaendig ausgestattet, aber zu alt fuer Projekte,
--           die >= 8.4 verlangen
--   php8.4  aktuell, aber ohne Extensions -- es fehlen dom, xml,
--           mbstring, intl, curl und zip. Projekte, die XML-Konfiguration
--           laden, scheitern daran mit "Extension DOM is required"
--
-- Ein fester Wert passt deshalb nicht: michaelbrauner braucht 8.4,
-- trackmycash braucht die Extensions von 8.3. Die Auswahl richtet sich
-- daher nach der Anforderung in der composer.json des Projekts.
--
-- Sauberer waere, php8.4 zu vervollstaendigen:
--   sudo apt install php8.4-{xml,mbstring,intl,curl,zip,mysql}
-- Danach genuegt schlicht 'php', und diese Fallunterscheidung kann weg.
-- ------------------------------------------------------------

-- Kleinste PHP-Version, die ein Projekt laut composer.json verlangt.
-- Liefert z. B. 8.4 oder nil, wenn nichts angegeben ist.
local function geforderte_php_version(root)
  local datei = vim.fs.joinpath(root, 'composer.json')
  local ok, inhalt = pcall(vim.fn.readfile, datei)
  if not ok then
    return nil
  end

  local gelungen, daten = pcall(vim.json.decode, table.concat(inhalt, '\n'))
  if not gelungen or type(daten) ~= 'table' then
    return nil
  end

  local anforderung = (daten.require or {})['php']
  if type(anforderung) ~= 'string' then
    return nil
  end

  -- Aus Ausdruecken wie ">=8.4", "^8.3.10" oder ">= 8.2 <8.5" die
  -- erste Versionsangabe herausziehen.
  local major, minor = anforderung:match '(%d+)%.(%d+)'
  if not major then
    return nil
  end

  return tonumber(major), tonumber(minor)
end

-- ------------------------------------------------------------
-- Warum hier kein PHP aus dem Docker-Container benutzt wird
--
-- Naheliegend waere es: Die Projekte laufen in Containern, deren PHP
-- die passende Version und alle Extensions mitbringt. Die offizielle
-- Doku beschreibt das auch (docs/docker.rst) -- phpCommand auf
-- "docker compose exec -T php php" setzen, containerProjectRoot auf
-- den Pfad im Container.
--
-- Am 26.08.2026 mit Version 0.16.0 durchgetestet und nicht zum Laufen
-- gebracht. Geprueft und in Ordnung befunden:
--
--   * Container laeuft, Projekt ist unter /srv/app gemountet
--   * Das Hilfsskript des Servers (var/symfony-lsp/<v>/<hash>/bridge.php)
--     liegt im gemounteten var/ und ist im Container sichtbar
--   * Von Hand im Container aufgerufen liefert es gueltiges JSON
--   * containerProjectRoot wirkt -- der Server ruft bereits mit
--     /srv/app/... auf, nicht mit dem Host-Pfad
--   * --project-directory ergaenzt, weil `docker compose` sonst mit
--     "no configuration file provided" abbricht (der Server laeuft
--     nicht im Projektverzeichnis)
--
-- Trotzdem bleibt es bei "could not initialize runtime metadata".
-- Da der Server das Scheitern nicht naeher begruendet, endet die
-- Diagnose hier. Mit lokalem PHP funktioniert dasselbe Projekt.
--
-- Wieder aufgreifen, wenn Symfony Language Tools die Beta verlaesst.
-- ------------------------------------------------------------

local function php_fuer(root)
  local major, minor = geforderte_php_version(root)

  -- Kandidaten von der aeltesten brauchbaren aufwaerts. php8.3 zuerst,
  -- weil dort die Extensions vollstaendig sind.
  local kandidaten = {
    { cmd = 'php8.3', major = 8, minor = 3 },
    { cmd = 'php8.4', major = 8, minor = 4 },
  }

  for _, k in ipairs(kandidaten) do
    local passt = not major or (k.major > major) or (k.major == major and k.minor >= minor)
    if passt and vim.fn.executable(k.cmd) == 1 then
      return { k.cmd }
    end
  end

  -- Nichts Passendes gefunden: dem Server das Standard-php geben und
  -- ihn selbst entscheiden lassen.
  return { 'php' }
end

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

  -- before_init bekommt das ermittelte Wurzelverzeichnis und kann die
  -- Konfiguration daran anpassen -- hier: das passende PHP eintragen,
  -- bevor der Server startet.
  before_init = function(params, config)
    local root = config.root_dir or (params.workspaceFolders and params.workspaceFolders[1] and vim.uri_to_fname(params.workspaceFolders[1].uri))
    if not root then
      return
    end

    local php = php_fuer(root)
    config.init_options = vim.tbl_deep_extend('force', config.init_options or {}, { phpCommand = php })
    config.settings = vim.tbl_deep_extend('force', config.settings or {}, { symfonyLsp = { phpCommand = php } })
    -- params traegt die init_options, die tatsaechlich gesendet werden
    params.initializationOptions = config.init_options
  end,

  init_options = {

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

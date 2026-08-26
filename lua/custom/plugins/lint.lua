-- ============================================================
-- Linting: nur ausfuehren, was auch installiert ist
--
-- kickstart.plugins.lint traegt markdownlint fuer Markdown ein, ohne
-- zu pruefen, ob das Programm existiert. Fehlt es, meldet nvim-lint
-- bei jedem Oeffnen einer .md-Datei "Error running markdownlint:
-- ENOENT" -- eine Fehlermeldung fuer ein Werkzeug, das man nie
-- bestellt hat.
--
-- Diese Datei wird nach kickstart.plugins.lint geladen und wirft alle
-- Linter raus, deren Programm nicht auffindbar ist.
-- ============================================================

local lint = require 'lint'

for ft, linters in pairs(lint.linters_by_ft) do
  local available = {}

  for _, name in ipairs(linters) do
    local def = lint.linters[name]
    -- Manche Linter sind als Funktion hinterlegt, die erst beim
    -- Aufruf die Definition liefert.
    if type(def) == 'function' then
      local ok, resolved = pcall(def)
      def = ok and resolved or nil
    end

    local cmd = type(def) == 'table' and def.cmd or name
    if type(cmd) == 'string' and vim.fn.executable(cmd) == 1 then
      table.insert(available, name)
    end
  end

  lint.linters_by_ft[ft] = #available > 0 and available or nil
end

-- ------------------------------------------------------------
-- Linter nachruesten
--
-- Willst du Markdown pruefen lassen:
--   :MasonInstall markdownlint
-- Danach greift der Eintrag von kickstart wieder automatisch.
--
-- Fuer PHP lohnt eher PHPStan aus dem Projekt selbst, weil er die
-- Konfiguration und das Autoloading des Projekts braucht. nvim-lint
-- ruft standardmaessig ein globales Programm auf; um vendor/bin zu
-- benutzen, den Linter hier ueberschreiben:
--
--   lint.linters.phpstan.cmd = 'vendor/bin/phpstan'
--   lint.linters_by_ft.php = { 'phpstan' }
--
-- Ohne passende phpstan.neon im Projekt erzeugt das allerdings mehr
-- Rauschen als Nutzen -- deshalb bewusst nicht voreingestellt.
-- ------------------------------------------------------------

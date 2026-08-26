-- ============================================================
-- PHP-Umfeld: Blade, Twig und projekttypische Kleinigkeiten
--
-- Diese Datei liegt bewusst unter lua/custom/plugins/. kickstart
-- sagt fuer dieses Verzeichnis zu, keine Merge-Konflikte zu
-- erzeugen -- eigene Anpassungen ueberleben hier ein `git pull
-- upstream master` unbeschadet.
-- ============================================================

-- ------------------------------------------------------------
-- Blade-Templates
--
-- Neovim erkennt *.blade.php bereits als Dateityp `blade`, es gibt
-- aber keinen offiziellen Treesitter-Parser dafuer. Blade ist im
-- Kern HTML mit @-Direktiven, deshalb ist der HTML-Parser die beste
-- verfuegbare Naeherung: Tags, Attribute und Text werden korrekt
-- eingefaerbt, nur @if/@foreach bleiben ungefaerbt.
-- ------------------------------------------------------------
vim.treesitter.language.register('html', 'blade')

-- ------------------------------------------------------------
-- Kommentarzeichen
--
-- `gcc` kommentiert die aktuelle Zeile aus. Ohne diese Angabe
-- benutzt Neovim in Templates das falsche Zeichen.
-- ------------------------------------------------------------
vim.api.nvim_create_autocmd('FileType', {
  desc = 'Passende Kommentarzeichen fuer Template-Sprachen',
  group = vim.api.nvim_create_augroup('custom-php-commentstring', { clear = true }),
  pattern = { 'blade', 'twig' },
  callback = function(ev)
    local commentstring = {
      blade = '{{-- %s --}}',
      twig = '{# %s #}',
    }
    vim.bo[ev.buf].commentstring = commentstring[vim.bo[ev.buf].filetype]
  end,
})

-- ------------------------------------------------------------
-- Dateitypen, die in PHP-Projekten vorkommen, aber nicht
-- automatisch erkannt werden.
-- ------------------------------------------------------------
vim.filetype.add {
  filename = {
    ['.php_cs'] = 'php',
    ['.php-cs-fixer.php'] = 'php',
    ['.php-cs-fixer.dist.php'] = 'php',
  },
  pattern = {
    -- .env.local, .env.test, .env.production ...
    ['%.env%.[%w_.-]+'] = 'sh',
  },
}

-- ------------------------------------------------------------
-- PHP-Dateien: PSR-12 schreibt 4 Leerzeichen Einrueckung vor.
-- kickstart stellt global 2 ein, was fuer Lua passt, fuer PHP aber
-- gegen jeden Coding-Standard laeuft.
-- ------------------------------------------------------------
vim.api.nvim_create_autocmd('FileType', {
  desc = 'PSR-12: vier Leerzeichen Einrueckung in PHP',
  group = vim.api.nvim_create_augroup('custom-php-indent', { clear = true }),
  pattern = 'php',
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true
  end,
})

-- ------------------------------------------------------------
-- php-cs-fixer ohne Projekt-Regelsatz
--
-- Symfony- und Laravel-Projekte bringen meist eine eigene
-- .php-cs-fixer.dist.php mit -- die hat immer Vorrang. Fehlt sie
-- (typisch bei Legacy-Code), wendet php-cs-fixer von Haus aus nur
-- Minimalregeln an. Dann geben wir PSR-12 vor, damit `<leader>f`
-- auch dort etwas Sinnvolles tut.
-- ------------------------------------------------------------
require('conform').formatters.php_cs_fixer = function(bufnr)
  local root = vim.fs.root(bufnr, {
    '.php-cs-fixer.php',
    '.php-cs-fixer.dist.php',
    '.php_cs',
    '.php_cs.dist',
  })

  -- Projekt bringt eigene Konfiguration mit: unveraendert lassen.
  if root then
    return {}
  end

  return {
    prepend_args = { '--rules=@PSR12' },
  }
end

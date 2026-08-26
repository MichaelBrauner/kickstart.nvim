# Neovim für PHP — Einrichtung

Fork von [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim), erweitert um
PHP (Symfony, Laravel, Legacy) und Frontend (JS/TS/CSS).

## Neue Maschine

```bash
git clone https://github.com/MichaelBrauner/kickstart.nvim ~/.config/nvim
~/.config/nvim/install.sh
nvim
```

`install.sh` installiert alles nach `~/.local` — kein `sudo`, kein Eingriff ins System.
Voraussetzung: `~/.local/bin` steht in `PATH` **vor** `/usr/bin`.

```bash
# falls nicht, in ~/.bashrc ergänzen:
export PATH="$HOME/.local/bin:$PATH"
```

## Voraussetzungen

| Werkzeug | Wofür | Pflicht |
|---|---|---|
| Neovim ≥ 0.12 | Konfiguration nutzt `vim.pack` | ja |
| tree-sitter-CLI | übersetzt die Syntax-Parser | ja |
| ripgrep | Volltextsuche im Projekt | ja |
| fd | Dateisuche | ja |
| git, curl, tar | Plugin- und Werkzeug-Installation | ja |
| node | Grundlage der meisten Language Server | ja |

Die Distribution von Ubuntu 24.04 liefert Neovim 0.9.5 — zu alt. `install.sh` legt
eine aktuelle Version daneben, das Systempaket bleibt unberührt.

## Was eingerichtet ist

**Language Server** (installiert Mason automatisch)

| Server | Zuständig für |
|---|---|
| `intelephense` | PHP |
| `ts_ls` | JavaScript, TypeScript |
| `cssls` | CSS, SCSS, LESS |
| `html`, `jsonls` | HTML, JSON |
| `emmet_language_server` | Emmet, auch in Twig und Blade |
| `lua_ls` | die Konfiguration selbst |

**Formatierung** über `<leader>f` (Leertaste, dann `f`)

- PHP: Pint aus dem Projekt, sonst `php-cs-fixer`. Bringt das Projekt eine
  `.php-cs-fixer.dist.php` mit, hat sie Vorrang; fehlt sie, gilt PSR-12.
- Alles andere: Prettier.

Formatieren beim Speichern ist bewusst **aus** — `php-cs-fixer` braucht dafür zu lange.
Einschalten in `init.lua` unter `format_on_save`.

**Templates**

`.twig` und `.blade.php` werden von Neovim von sich aus erkannt. Blade hat keinen
eigenen Treesitter-Parser, deshalb übernimmt der HTML-Parser die Einfärbung —
`@if`/`@foreach` bleiben dabei ungefärbt. Kommentarzeichen und PSR-12-Einrückung
(4 Leerzeichen) sind in `lua/custom/plugins/php.lua` gesetzt.

## Aufbau

```
init.lua                        angepasste kickstart-Konfiguration
lua/custom/plugins/php.lua      eigene PHP-Ergänzungen (konfliktfrei bei Updates)
lua/kickstart/plugins/          optionale Module von kickstart
install.sh                      Einrichtung auf neuen Maschinen
```

Eigene Anpassungen gehören nach `lua/custom/plugins/`. kickstart sagt für dieses
Verzeichnis zu, dort keine Merge-Konflikte zu erzeugen.

## kickstart aktualisieren

```bash
cd ~/.config/nvim
git fetch upstream
git merge upstream/master
```

Konflikte sind nur in `init.lua` zu erwarten, an den angepassten Stellen:
LSP-Server, Treesitter-Parser, `formatters_by_ft`.

## Wichtige Tastenkürzel

Leader-Taste ist die **Leertaste**.

| Kürzel | Wirkung |
|---|---|
| `<leader>sf` | Datei suchen |
| `<leader>sg` | Volltextsuche im Projekt |
| `<leader>sh` | Hilfe durchsuchen |
| `<leader>f` | Puffer formatieren |
| `grn` | Symbol umbenennen |
| `grr` | Referenzen finden |
| `grd` | zur Definition springen |
| `K` | Dokumentation zum Symbol |
| `\` | Dateibaum öffnen |
| `<leader>q` | Diagnoseliste |

Vollständige Liste: `<leader>sk`, oder `:checkhealth` für den Systemzustand.

## Fehlersuche

```vim
:checkhealth        " Gesamtzustand
:Mason              " Language Server verwalten
:checkhealth lsp    " angehängte Server im aktuellen Puffer
```

`intelephense` braucht ein Projekt-Wurzelverzeichnis — erkannt an `composer.json`
oder `.git`. Ohne beides hängt sich der Server nicht an. Beim ersten Öffnen eines
großen Projekts indiziert er einige Sekunden lang.

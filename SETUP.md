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

**In `~/.bashrc`, nicht in `~/.profile`.** Ubuntu setzt `~/.local/bin` in `~/.profile`,
das aber nur bei der Anmeldung gelesen wird. Ein neuer Terminal-Tab ist keine
Login-Shell und findet das aktuelle Neovim dann nicht — stattdessen startet die
ältere Version aus `/usr/bin`, und die Konfiguration bricht ab.

### Icons

Ohne Nerd Font zeigt neo-tree Ersatzkästchen mit Hex-Codes. Diese Konfiguration
benutzt deshalb schlichte Textzeichen (`lua/custom/plugins/icons.lua`).

Mit Nerd Font: Datei löschen, `have_nerd_font` in `init.lua` auf `true` setzen und
die Terminal-Schrift auf eine **Mono**-Variante stellen (z. B. „JetBrainsMono Nerd
Font Mono"). Die Variante ohne „Mono" hat zwei Zellen breite Symbole — GNOME
Terminal leitet daraus die Zellenbreite für allen Text ab und zieht ihn
auseinander.

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
| `symfony_lsp` | Symfony-Framework (nur in Symfony-Apps) |
| `lua_ls` | die Konfiguration selbst |

**Symfony Language Tools**

Der offizielle Symfony-LSP läuft **neben** intelephense: der eine versteht PHP als
Sprache, der andere Symfony als Framework — Route-Namen, Service-IDs, Template-Pfade,
Übersetzungsschlüssel, Doctrine.

Er startet nur, wo `symfony.lock` oder `bin/console` liegt, also nicht in Laravel-,
Legacy- oder Bundle-Projekten.

Für die volle Genauigkeit bootet er den Symfony-Kernel, führt also Projektcode aus.
`workspaceTrust` steht deshalb fest auf `true` — ohne die Erlaubnis liefert er
schlicht nichts. Für fremden Code (geklonte Reproducer, fremde Repositories) lässt
sich das projektweise zurücknehmen, per `.nvim.lua` im Projektwurzelverzeichnis:

```lua
vim.lsp.config('symfony_lsp', {
  init_options = { workspaceTrust = false },
})
```

**Zur Meldung „could not initialize runtime metadata":** Die ist irreführend und wird
ausgefiltert. Gemessen an einem Symfony-7.4-Projekt (Version 0.16.0): mit
`workspaceTrust = false` kommen 0 Route-Vorschläge und keine Meldung, mit `true`
kommen 50 Vorschläge **und** die Meldung. Der erste Boot-Versuch scheitert also,
der zweite gelingt, und der Server nimmt seine Meldung nicht zurück.

**Docker wird nicht benutzt**, obwohl es naheliegt und offiziell dokumentiert ist —
mit Version 0.16.0 war es trotz korrekter Einrichtung nicht zum Laufen zu bringen.
Was geprüft wurde, steht in `lua/custom/plugins/symfony.lua`.

Wichtig: Er braucht ein PHP **mit** Extensions (dom, xml, mbstring, intl). Auf diesem
Rechner ist `php` die Version 8.4 ohne Extensions, deshalb ist `php8.3` fest
eingestellt. Fehlt das, meldet er nur „could not initialize runtime metadata" und
liefert stillschweigend keine Vorschläge mehr.

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

### Git

| Kürzel | Wirkung | PhpStorm |
|---|---|---|
| `<C-k>` | Statusansicht: stagen, committen | `Strg+K` |
| `<leader>gs` | dasselbe über Leader | |
| `<leader>gl` | Verlauf des Projekts | `Alt+9` |
| `<leader>gL` | Verlauf dieser Datei | Show History |
| `<leader>gd` | Diff der Arbeitskopie | |
| `<leader>gD` | Diff gegen `origin` | |
| `<leader>gb` | Blame | Annotate |

In der Statusansicht: `s` staged, `u` unstaged, `c c` committet, `p p` pusht,
`d` öffnet den Diff, `?` zeigt alle Tasten. `q` schließt Git-Fenster.

**Zum Verlauf:** `<leader>gl` ist der Weg, der überall funktioniert. `Alt+9` ist
zusätzlich belegt, wird in GNOME Terminal aber vom Tab-Wechsel abgefangen und kommt
gar nicht bei Neovim an — in kitty, alacritty oder wezterm dagegen schon. Das Mapping
bleibt deshalb für andere Maschinen bestehen.

Wer den Terminal-Shortcut doch freigeben will:

```bash
gsettings set org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/ \
  switch-to-tab-9 "'disabled'"
```

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

#!/usr/bin/env bash
#
# Richtet die Werkzeuge ein, die diese Neovim-Konfiguration voraussetzt.
#
# Alles landet unter ~/.local -- kein sudo, kein Eingriff ins System.
# Ein per Paketmanager installiertes Neovim bleibt unangetastet liegen;
# ~/.local/bin muss dafuer in PATH vor /usr/bin stehen.
#
# Aufruf auf einer neuen Maschine:
#   git clone https://github.com/MichaelBrauner/kickstart.nvim ~/.config/nvim
#   ~/.config/nvim/install.sh
#   nvim

set -euo pipefail

PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$BIN"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mAchtung:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mFehler:\033[0m %s\n' "$*" >&2; exit 1; }

for cmd in curl tar git; do
  command -v "$cmd" >/dev/null || die "'$cmd' wird benoetigt, ist aber nicht installiert."
done

case "$(uname -m)" in
  x86_64)  NVIM_ARCH=x86_64;  RUST_ARCH=x86_64;  TS_ARCH=x64 ;;
  aarch64) NVIM_ARCH=arm64;   RUST_ARCH=aarch64; TS_ARCH=arm64 ;;
  *) die "Nicht unterstuetzte Architektur: $(uname -m)" ;;
esac

# Neueste Release-Version eines GitHub-Repos ermitteln.
latest_tag() {
  curl -fsSL --max-time 30 "https://api.github.com/repos/$1/releases/latest" \
    | grep -o '"tag_name":[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4
}

# ---------------------------------------------------------------
# Neovim
#
# Muss mindestens 0.12 sein: Diese Konfiguration nutzt vim.pack,
# den ab 0.12 eingebauten Plugin-Manager. Distributionen liefern
# haeufig aeltere Versionen aus (Ubuntu 24.04 z. B. 0.9.5).
# ---------------------------------------------------------------
install_neovim() {
  local tag
  tag="$(latest_tag neovim/neovim)"
  info "Installiere Neovim $tag"
  curl -fsSL --max-time 300 -o "$TMP/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/download/$tag/nvim-linux-$NVIM_ARCH.tar.gz"
  tar xzf "$TMP/nvim.tar.gz" -C "$TMP"
  rm -rf "$PREFIX/nvim"
  mv "$TMP/nvim-linux-$NVIM_ARCH" "$PREFIX/nvim"
  ln -sf "$PREFIX/nvim/bin/nvim" "$BIN/nvim"
}

# ---------------------------------------------------------------
# ripgrep und fd: Volltextsuche und Dateisuche fuer Telescope.
# ---------------------------------------------------------------
install_from_tarball() {
  local repo="$1" pattern="$2" binary="$3" tag url
  tag="$(latest_tag "$repo")"
  info "Installiere $binary $tag"
  url="https://github.com/$repo/releases/download/$tag/${pattern//@TAG@/$tag}"
  curl -fsSL --max-time 300 -o "$TMP/$binary.tar.gz" "$url"
  tar xzf "$TMP/$binary.tar.gz" -C "$TMP"
  install -m755 "$(find "$TMP" -type f -name "$binary" -perm -u+x | head -1)" "$BIN/$binary"
}

# ---------------------------------------------------------------
# tree-sitter-CLI: nvim-treesitter (main-Branch) uebersetzt die
# Parser damit. Ohne sie schlaegt jede Parser-Installation fehl.
# ---------------------------------------------------------------
install_tree_sitter() {
  local tag
  tag="$(latest_tag tree-sitter/tree-sitter)"
  info "Installiere tree-sitter-CLI $tag"
  curl -fsSL --max-time 300 -o "$TMP/ts.gz" \
    "https://github.com/tree-sitter/tree-sitter/releases/download/$tag/tree-sitter-linux-$TS_ARCH.gz"
  gunzip -f "$TMP/ts.gz"
  install -m755 "$TMP/ts" "$BIN/tree-sitter"
}

# ---------------------------------------------------------------
# JetBrainsMono Nerd Font
#
# Ohne eine Nerd Font zeigen Dateibaum und Statuszeile ihre Symbole als
# Ersatzkaestchen mit Hex-Codes. Das komplette Release enthaelt ueber
# hundert Varianten -- gebraucht werden vier Schnitte.
#
# Wichtig ist dabei die Mono-Variante: In der gewoehnlichen "Nerd Font"
# belegen die Symbole zwei Zellen. GNOME Terminal leitet daraus die
# Zellenbreite fuer saemtliche Zeichen ab, wodurch der ganze Text
# auseinandergezogen wirkt. In "Nerd Font Mono" ist jedes Symbol
# genau eine Zelle breit.
#
# Die Schriftart des Terminals muss anschliessend von Hand umgestellt
# werden; welches Terminal im Einsatz ist, weiss dieses Skript nicht.
# ---------------------------------------------------------------
install_nerd_font() {
  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"

  if [ -f "$dir/JetBrainsMonoNerdFontMono-Regular.ttf" ]; then
    info "JetBrainsMono Nerd Font ist bereits installiert"
    return 0
  fi

  if ! command -v unzip >/dev/null; then
    warn "unzip fehlt -- Schriftart wird uebersprungen"
    return 0
  fi

  local tag
  tag="$(latest_tag ryanoasis/nerd-fonts)"
  info "Installiere JetBrainsMono Nerd Font $tag"
  curl -fsSL --max-time 600 -o "$TMP/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/JetBrainsMono.zip"

  mkdir -p "$dir" "$TMP/jbm"
  unzip -qo "$TMP/JetBrainsMono.zip" -d "$TMP/jbm"

  local schnitt src
  for schnitt in Regular Bold Italic BoldItalic; do
    src="$(find "$TMP/jbm" -name "JetBrainsMonoNerdFontMono-$schnitt.ttf" | head -1)"
    [ -n "$src" ] && cp "$src" "$dir/"
  done

  command -v fc-cache >/dev/null && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
  warn "Terminal-Schriftart noch auf 'JetBrainsMono Nerd Font Mono' umstellen."
}

install_neovim
install_nerd_font
install_from_tarball BurntSushi/ripgrep "ripgrep-@TAG@-${RUST_ARCH}-unknown-linux-musl.tar.gz" rg
install_from_tarball sharkdp/fd         "fd-@TAG@-${RUST_ARCH}-unknown-linux-musl.tar.gz"      fd
install_tree_sitter

# ---------------------------------------------------------------
# Language Server und Formatierer installiert Mason beim ersten
# Start selbst. Hier stossen wir das einmal ohne Oberflaeche an,
# damit der erste echte Start bereits vollstaendig ist.
# ---------------------------------------------------------------
info "Installiere Plugins, Parser und Language Server (das dauert einige Minuten)"
PATH="$BIN:$PATH" "$BIN/nvim" --headless "+MasonToolsInstall" \
  "+lua vim.wait(900000, function()
          local ok, reg = pcall(require, 'mason-registry')
          if not ok then return false end
          for _, p in ipairs(reg.get_all_packages()) do
            if p:is_installing() then return false end
          end
          return true
        end, 2000)" "+qa!" 2>&1 | grep -viE 'installing$' || true

# ---------------------------------------------------------------
# Abschliessende Pruefung
# ---------------------------------------------------------------
echo
info "Ergebnis"
for tool in nvim rg fd tree-sitter; do
  if [ -x "$BIN/$tool" ]; then
    printf '  %-14s %s\n' "$tool" "$("$BIN/$tool" --version 2>/dev/null | head -1)"
  else
    printf '  %-14s FEHLT\n' "$tool"
  fi
done

if [ -f "$HOME/.local/share/fonts/JetBrainsMonoNerdFont/JetBrainsMonoNerdFontMono-Regular.ttf" ]; then
  printf '  %-14s installiert (Terminal-Schriftart ggf. noch umstellen)\n' "Nerd Font"
else
  printf '  %-14s FEHLT\n' "Nerd Font"
fi

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) warn "$BIN liegt nicht in PATH. Ergaenze in ~/.bashrc bzw. ~/.zshrc:"
     warn '  export PATH="$HOME/.local/bin:$PATH"' ;;
esac

if command -v nvim >/dev/null && [ "$(command -v nvim)" != "$BIN/nvim" ]; then
  warn "Es wird $(command -v nvim) statt $BIN/nvim gefunden."
  warn "$BIN muss in PATH vor /usr/bin stehen."
fi

echo
info "Fertig. Starte Neovim mit: nvim"

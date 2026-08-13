#!/usr/bin/env bash
# ============================================================================
# backup-setup.sh — backup lengkap setup AI sebelum reinstal Arch
#
# Membuat satu archive .tar.gz berisi:
#   home/  → config & data user (~/.config/opencode, omniroute-desktop, hypr
#            [autostart router], fish, starship, .gitconfig, ~/.local/bin,
#            ~/.local/share/opencode, ~/.local/state/opencode-pick, dll)
#   srv/   → seluruh proyek di /srv/http
#   meta/  → daftar paket (pacman explicit + AUR), dump combo router, README
#
# Penggunaan:
#   backup-setup.sh [output-dir]      # default: direktori sekarang
#
# Env (untuk testing / penyesuaian):
#   BACKUP_HOME   # sumber config user (default $HOME)
#   BACKUP_SRV    # sumber proyek (default /srv/http)
#
# Setelah backup selesai, salin file .tar.gz ke disk lain (USB/HDD)!
# ============================================================================
set -uo pipefail

VERSION="1.0.1"

# help (sama seperti opencode-pick: dump header komentar)
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  awk 'NR==1 {next} /^# ====/ {if (++c == 2) exit; next} {sub(/^# ?/, ""); print}' "$0"
  exit 0
fi

OUT_DIR="${1:-$(pwd)}"
BACKUP_HOME="${BACKUP_HOME:-$HOME}"
BACKUP_SRV="${BACKUP_SRV:-/srv/http}"
LABEL="backup-ai-$(date +%Y%m%d-%H%M%S)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
UNCOMP="$STAGE/$LABEL.tar"

mkdir -p "$OUT_DIR"
echo "============================================================"
echo "  💾 backup-setup.sh v${VERSION} — setup AI"
echo "  Output : $OUT_DIR/$LABEL.tar.gz"
echo "  Home   : $BACKUP_HOME"
echo "  Proyek : $BACKUP_SRV"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1) HOME — config & data user
# ---------------------------------------------------------------------------
HOME_ITEMS=()
for d in \
  .config/opencode .config/omniroute-desktop .config/hypr .config/fish .config/starship.toml \
  .config/autostart .local/bin .local/share/opencode .local/state/opencode-pick
do
  [[ -e "$BACKUP_HOME/$d" ]] && HOME_ITEMS+=("$d")
done
for f in .bashrc .gitconfig .claude.json; do
  [[ -e "$BACKUP_HOME/$f" ]] && HOME_ITEMS+=("$f")
done

# opencode.db (riwayat sesi) di-snapshot terpisah via sqlite .backup agar
# konsisten walau opencode sedang berjalan. Exclude versi mentah dari tar.
EXCLUDES=(--exclude='*opencode.db*')
if pgrep -x opencode >/dev/null 2>&1; then
  echo "  ⚠️  opencode sedang berjalan — opencode.db di-snapshot via sqlite3 (aman)"
else
  echo "  ✅ opencode tidak berjalan — snapshot db normal"
fi

# inisialisasi archive kosong dulu (biar tar -rf aman walau tanpa item)
tar -cf "$UNCOMP" --files-from=/dev/null
if [[ ${#HOME_ITEMS[@]} -gt 0 ]]; then
  tar -rf "$UNCOMP" "${EXCLUDES[@]}" --transform 's,^,home/,' \
    -C "$BACKUP_HOME" "${HOME_ITEMS[@]}"
fi

# snapshot opencode.db yang konsisten (sqlite online backup)
DB_SRC="$BACKUP_HOME/.local/share/opencode"
if [[ -f "$DB_SRC/opencode.db" ]]; then
  mkdir -p "$STAGE/dbdir/.local/share/opencode"
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$DB_SRC/opencode.db" ".backup '$STAGE/dbdir/.local/share/opencode/opencode.db'" 2>/dev/null \
      || cp -a "$DB_SRC/opencode.db" "$STAGE/dbdir/.local/share/opencode/opencode.db"
  else
    # tanpa sqlite3: copy mentah — bisa tidak konsisten bila opencode berjalan
    if pgrep -x opencode >/dev/null 2>&1; then
      echo "  ⚠️  sqlite3 tidak ada & opencode berjalan — copy db bisa tidak konsisten"
    fi
    cp -a "$DB_SRC/opencode.db" "$STAGE/dbdir/.local/share/opencode/opencode.db"
  fi
  if [[ -f "$STAGE/dbdir/.local/share/opencode/opencode.db" ]]; then
    tar -rf "$UNCOMP" --transform 's,^,home/,' \
      -C "$STAGE/dbdir" .local/share/opencode/opencode.db
    echo "  ✅ opencode.db di-snapshot (riwayat sesi)"
  else
    echo "  ⚠️  GAGAL backup opencode.db (riwayat sesi) — periksa sqlite3"
  fi
fi

# ---------------------------------------------------------------------------
# 2) SRV — proyek
# ---------------------------------------------------------------------------
if [[ -d "$BACKUP_SRV" ]]; then
  echo "  📦 proyek: $BACKUP_SRV"
  # member archive: srv/<basename>/... → restore ke /srv/http (lihat restore-setup.sh)
  tar -rf "$UNCOMP" --exclude='*'"$LABEL"'*' --transform 's,^,srv/,' \
    -C "$(dirname "$BACKUP_SRV")" "$(basename "$BACKUP_SRV")"
fi

# ---------------------------------------------------------------------------
# 3) META — paket, combo router, README
# ---------------------------------------------------------------------------
META="$STAGE/meta"
mkdir -p "$META"

# pkgs-explicit = paket repo saja (BUKAN AUR). Pacman -Qe berisi campuran repo+
# AUR; comm -23 mengeluarkan yang ada di -Qm (foreign/AUR) supaya restore via
# `pacman -S` tidak gagal pada nama paket non-repo.
pacman -Qe 2>/dev/null | sort > "$META/pkgs-all-explicit.txt" || :
pacman -Qm 2>/dev/null | sort > "$META/pkgs-aur.txt" || :
comm -23 "$META/pkgs-all-explicit.txt" "$META/pkgs-aur.txt" > "$META/pkgs-explicit.txt" 2>/dev/null || :

# dump combo router (kalau router hidup) — pakai API key dari opencode.json
KEY=""
if [[ -f "$BACKUP_HOME/.config/opencode/opencode.json" ]]; then
  KEY=$(BACKUP_HOME="$BACKUP_HOME" python3 -c '
import json, os
try:
    d = json.load(open(os.path.join(os.environ["BACKUP_HOME"],
        ".config/opencode/opencode.json")))
    print(d.get("provider", {}).get("omniroute", {}).get("options", {}).get("apiKey", ""))
except Exception:
    print("")' 2>/dev/null || echo "")
fi
if curl -s -m 3 -o /dev/null "http://localhost:20128/v1/models"; then
  if [[ -n "$KEY" ]]; then
    curl -s -m 8 "http://localhost:20128/api/combos" -H "Authorization: Bearer $KEY" \
      > "$META/combos.json" 2>/dev/null || echo "{}" > "$META/combos.json"
    echo "  🔀 combo router di-dump ke meta/combos.json"
  else
    echo "  ⚠️  router hidup tapi API key tidak ditemukan — combo tidak di-dump"
  fi
else
  echo "  ℹ️  router tidak hidup — combo tersimpan di akun agentrouter.org (login ulang)"
fi

cat > "$META/README-restore.txt" <<EOF
=== RESTORE SETUP AI (dibuat: $(date) oleh backup-setup.sh v${VERSION}) ===

1) Install dasar + AUR helper:
   sudo pacman -S git nodejs npm pnpm python sqlite3 tmux eza fastfetch lolcat ripgrep
   git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

2) Restore otomatis (script ini disertakan di srv/http/ai-setup):
   restore-setup.sh $LABEL.tar.gz

3) Atau manual:
   tar -xzf $LABEL.tar.gz -C ~ --strip-components=1 home
   sudo mkdir -p /srv && sudo tar -xzf $LABEL.tar.gz -C /srv --strip-components=1 srv

4) Router: otomatis nyala saat login Hyprland (autostart custom/execs.lua).
   Kalau login non-desktop: jalankan manual 'omniroute' → login agentrouter.org
   → combo otomatis pulih
5) PATH ~/.local/bin sudah otomatis lewat config.fish (fish_add_path)

Isi archive:
  home/  : config & data user (opencode, omniroute-desktop, hypr [autostart
           router], shell, state)
  srv/   : proyek /srv/http
  meta/  : pkgs-explicit.txt, pkgs-aur.txt, combos.json, README ini
EOF

tar -rf "$UNCOMP" -C "$STAGE" meta

# ---------------------------------------------------------------------------
# 4) kompres + finalisasi
# ---------------------------------------------------------------------------
gzip -f "$UNCOMP"
mv "$UNCOMP.gz" "$OUT_DIR/$LABEL.tar.gz"

SIZE=$(du -h "$OUT_DIR/$LABEL.tar.gz" | cut -f1)
echo "============================================================"
echo "  ✅ Selesai: $OUT_DIR/$LABEL.tar.gz ($SIZE)"
echo ""
echo "  📋 Isi:"
echo "     home/  — config opencode + AGENTS-global, omniroute-desktop,"
 echo "              hypr (autostart router), fish/starship/.gitconfig/.bashrc,"
 echo "              ~/.local/bin (opencode-pick), opencode.db (riwayat sesi),"
 echo "              state tracker"
echo "     srv/   — semua proyek /srv/http"
echo "     meta/  — daftar paket (pacman + AUR), combo router, README-restore"
echo ""
echo "  ⚠️  SALIN file ini ke disk lain (USB/HDD) sebelum reinstall!"
echo "  ▶  Restore nanti:  restore-setup.sh $LABEL.tar.gz"
echo "============================================================"

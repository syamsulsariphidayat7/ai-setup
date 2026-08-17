#!/usr/bin/env bash
# ============================================================================
# restore-setup.sh — restore setup AI dari archive backup-setup.sh
#
# Penggunaan:
#   restore-setup.sh <backup-ai-*.tar.gz> [opsi]
#
# Opsi:
#   --skip-pkgs    jangan install ulang paket (pacman/yay)
#   --skip-srv     jangan restore /srv/http (butuh sudo)
#   --skip-home    jangan restore config ke $HOME
#   -y             non-interaktif (jalankan semua langkah tanpa konfirmasi)
#
# Yang dilakukan:
#   1. home/  → ekstrak ke $HOME (config opencode, omniroute-desktop, hypr
#      [autostart router], shell, ~/.local/bin, state) — termasuk opencode-pick
#   2. srv/   → ekstrak ke /srv/http (butuh sudo). CATATAN: restore srv
#      mengasumsikan layout default backup (BACKUP_SRV=/srv/http → member
#      srv/http/...). Jangan ubah BACKUP_SRV saat backup jika ingin restore
#      otomatis ini bekerja.
#   3. paket  → install ulang dari meta/pkgs-explicit.txt (pacman) dan
#      meta/pkgs-aur.txt (yay: opencode-bin, omniroute-bin, dll)
#   4. PATH   → pastikan ~/.local/bin ada di config.fish
#   5. combo  → jika router hidup, cek combo ops-* ada; kalau hilang, re-create
#      via API dari meta/combos.json — strategy SELALU priority (tidak peduli
#      isi backup lama), mengikuti keputusan global "semua combo priority"
#   6. verifikasi akhir
#
# Env:
#   RESTORE_HOME  # target config (default $HOME; dipakai utk testing)
# ============================================================================
set -uo pipefail

VERSION="1.0.1"
RESTORE_HOME="${RESTORE_HOME:-$HOME}"
SKIP_PKGS=0
SKIP_SRV=0
SKIP_HOME=0
YES=0

BACKUP=""
ARGS=("$@")
i=0
while [[ $i -lt ${#ARGS[@]} ]]; do
  a="${ARGS[$i]}"
  case "$a" in
    --skip-pkgs) SKIP_PKGS=1 ;;
    --skip-srv) SKIP_SRV=1 ;;
    --skip-home) SKIP_HOME=1 ;;
    -y) YES=1 ;;
    --help|-h)
      awk 'NR==1 {next} /^# ====/ {if (++c == 2) exit; next} {sub(/^# ?/, ""); print}' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$BACKUP" ]]; then BACKUP="$a"; else
        echo "❌ Argumen tidak dikenal: $a (lihat --help)" >&2; exit 1
      fi
      ;;
  esac
  i=$((i+1))
done

confirm() {
  # $1 = pertanyaan; jawab y → lanjut, selain itu berhenti
  [[ $YES -eq 1 ]] && return 0
  read -r -p "$1 [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

if [[ -z "$BACKUP" ]]; then
  echo "❌ Penggunaan: restore-setup.sh <backup-ai-*.tar.gz> [--skip-pkgs] [--skip-srv] [--skip-home] [-y]" >&2
  exit 1
fi
if [[ ! -f "$BACKUP" ]]; then
  echo "❌ Backup tidak ditemukan: $BACKUP" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# meta/ diekstrak sekali di awal — dipakai step 3 (paket) & step 5 (combo)
tar -xzf "$BACKUP" -C "$TMP" meta 2>/dev/null || true
META_DIR="$TMP/meta"
EXPMETA="$META_DIR/pkgs-explicit.txt"
AURMETA="$META_DIR/pkgs-aur.txt"
COMBOS_META="$META_DIR/combos.json"

echo "============================================================"
echo "  🔄 restore-setup.sh v${VERSION} — setup AI"
echo "  Backup : $BACKUP"
echo "  Target : HOME=$RESTORE_HOME · /srv/http"
echo "  Opsi   : pkgs=$( [ $SKIP_PKGS -eq 1 ] && echo SKIP || echo ya ) · srv=$( [ $SKIP_SRV -eq 1 ] && echo SKIP || echo ya ) · home=$( [ $SKIP_HOME -eq 1 ] && echo SKIP || echo ya )"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1) HOME — config & data user
# ---------------------------------------------------------------------------
if [[ $SKIP_HOME -eq 0 ]]; then
  echo ""
  echo "==> [1/5] Restore config ke \$HOME ($RESTORE_HOME)"
  mkdir -p "$RESTORE_HOME"
  tar -xzf "$BACKUP" -C "$RESTORE_HOME" --strip-components=1 home 2>/dev/null \
    || echo "  ⚠️  bagian home/ tidak ada atau gagal diekstrak"
  if command -v opencode-pick >/dev/null 2>&1; then
    echo "  ✅ opencode-pick tersedia: $(opencode-pick --version 2>/dev/null || echo ok)"
  else
    echo "  ⚠️  opencode-pick belum di PATH — pastikan ~/.local/bin masuk PATH"
  fi
else
  echo "  (home dilewati)"
fi

# ---------------------------------------------------------------------------
# 2) SRV — proyek (butuh sudo)
# ---------------------------------------------------------------------------
if [[ $SKIP_SRV -eq 0 ]]; then
  echo ""
  echo "==> [2/5] Restore proyek ke /srv/http (butuh sudo)"
  if tar -tzf "$BACKUP" 2>/dev/null | grep -q '^srv/'; then
    sudo mkdir -p /srv
    sudo tar -xzf "$BACKUP" -C /srv --strip-components=1 srv \
      && sudo chown -R "$(id -un):$(id -gn)" /srv/http
    echo "  ✅ /srv/http di-restore"
  else
    echo "  ⚠️  tidak ada bagian srv/ di archive"
  fi
else
  echo "  (srv dilewati)"
fi

# ---------------------------------------------------------------------------
# 3) PAKET — pacman + yay (AUR)
# ---------------------------------------------------------------------------
if [[ $SKIP_PKGS -eq 0 ]]; then
  echo ""
  echo "==> [3/5] Install ulang paket"

  if command -v pacman >/dev/null 2>&1; then
    if [[ -f "$EXPMETA" ]] && [[ -s "$EXPMETA" ]]; then
      N=$(wc -l < "$EXPMETA")
      if confirm "  Install $N paket repo (dari backup, --needed)? "; then
        sudo pacman -S --needed --noconfirm $(cut -d' ' -f1 "$EXPMETA") || {
          echo "  ⚠️  sebagian paket gagal — lanjut paket penting saja:"
          sudo pacman -S --needed --noconfirm git nodejs npm pnpm python sqlite3 tmux eza fastfetch lolcat ripgrep fish
        }
      else
        echo "  ℹ️  paket repo dilewati (manual: sudo pacman -S --needed \$(cut -d' ' -f1 meta/pkgs-explicit.txt))"
      fi
    else
      sudo pacman -S --needed --noconfirm git nodejs npm pnpm python sqlite3 tmux eza fastfetch lolcat ripgrep fish
    fi
  else
    echo "  ⚠️  pacman tidak ditemukan — install Arch base dulu"
  fi

  # AUR helper yay
  if ! command -v yay >/dev/null 2>&1; then
    if confirm "  Install yay (AUR helper)? "; then
      sudo pacman -S --needed --noconfirm base-devel git
      (cd "$TMP" && git clone https://aur.archlinux.org/yay.git 2>/dev/null \
        && cd yay && makepkg -si --noconfirm) \
        || echo "  ⚠️  gagal install yay — install manual"
    fi
  fi

  # paket kunci setup AI SELALU dicoba dulu (opencode-bin bisa berasal dari
  # chaotic-aur sehingga tidak tercatat di pacman -Qm; omniroute-bin dari AUR).
  # Sisanya (dari backup) menyusul.
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm opencode-bin omniroute-bin
    if [[ -f "$AURMETA" ]] && [[ -s "$AURMETA" ]]; then
      N=$(wc -l < "$AURMETA")
      if confirm "  Install $N paket AUR lain (dari backup, --needed)? "; then
        yay -S --needed --noconfirm $(cut -d' ' -f1 "$AURMETA") 2>/dev/null \
          || echo "  ⚠️  sebagian AUR lain gagal — lihat meta/pkgs-aur.txt untuk manual"
      else
        echo "  ℹ️  AUR lain dilewati — daftar ada di meta/pkgs-aur.txt"
      fi
    fi
  else
    echo "  ⚠️  yay tidak tersedia — install opencode-bin & omniroute-bin manual"
  fi
else
  echo "  (paket dilewati)"
fi

# ---------------------------------------------------------------------------
# 4) PATH — pastikan ~/.local/bin di config.fish (hanya jika home di-restore)
# ---------------------------------------------------------------------------
if [[ $SKIP_HOME -eq 0 ]]; then
  echo ""
  echo "==> [4/5] Pastikan ~/.local/bin di PATH (fish)"
  FISH_CFG="$RESTORE_HOME/.config/fish/config.fish"
  if [[ -f "$FISH_CFG" ]]; then
    if grep -q 'fish_add_path.*\.local/bin' "$FISH_CFG" 2>/dev/null; then
      echo "  ✅ sudah ada di config.fish"
    else
      mkdir -p "$(dirname "$FISH_CFG")"
      printf '\n# Tambahkan ~/.local/bin ke PATH (skrip user: opencode-pick, dll)\nfish_add_path ~/.local/bin\n' >> "$FISH_CFG"
      echo "  ➕ ditambahkan ke config.fish"
    fi
  else
    echo "  ℹ️  config.fish belum ada — lewat (buat manual: fish_add_path ~/.local/bin)"
  fi
else
  echo "  (PATH dilewati karena --skip-home)"
fi

# ---------------------------------------------------------------------------
# 5) COMBO — re-create jika router hidup & combo hilang
# ---------------------------------------------------------------------------
echo ""
echo "==> [5/5] Verifikasi combo router"
ROUTER="http://localhost:20128"
if curl -s -m 4 -o /dev/null "$ROUTER/v1/models"; then
  echo "  ✅ router hidup di $ROUTER"
  KEY=""
  CFG=""
  for f in opencode.json opencode.jsonc; do
    if [[ -f "$RESTORE_HOME/.config/opencode/$f" ]]; then CFG="$f"; break; fi
  done
  if [[ -n "$CFG" ]]; then
    KEY=$(RESTORE_HOME="$RESTORE_HOME" CFG="$CFG" python3 -c '
import json, os
p = os.path.join(os.environ["RESTORE_HOME"], ".config/opencode", os.environ["CFG"])
def jstrip(s):
    # buang komentar // dan /* */ di luar string (JSONC)
    r, i, n, q = [], 0, len(s), False
    while i < n:
        c = s[i]
        if q:
            r.append(c)
            if c == "\\" and i + 1 < n: r.append(s[i+1]); i += 2; continue
            if c == "\"": q = False
            i += 1; continue
        if c == "\"": q = True; r.append(c); i += 1; continue
        if c == "/" and i + 1 < n and s[i+1] == "/":
            while i < n and s[i] != "\n": i += 1
            continue
        if c == "/" and i + 1 < n and s[i+1] == "*":
            i += 2
            while i + 1 < n and not (s[i] == "*" and s[i+1] == "/"): i += 1
            i += 2; continue
        r.append(c); i += 1
    return "".join(r)
try:
    d = json.loads(jstrip(open(p).read()))
    print(d.get("provider", {}).get("omniroute", {}).get("options", {}).get("apiKey", ""))
except Exception:
    print("")' 2>/dev/null || echo "")
  fi
  if [[ -n "$KEY" ]]; then
    EXIST=$(curl -s -m 8 "$ROUTER/api/combos" -H "Authorization: Bearer $KEY" 2>/dev/null \
      | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(" ".join(c.get("name","") for c in d.get("combos",[])))
except Exception:
    print("")' 2>/dev/null)
    echo "  📋 combo di router: ${EXIST:-—}"
    if [[ -f "$COMBOS_META" ]] && [[ -s "$COMBOS_META" ]]; then
      # re-create combo yang ada di backup tapi belum ada di router
      RESTORE_HOME="$RESTORE_HOME" KEY="$KEY" ROUTER="$ROUTER" EXIST="$EXIST" \
      python3 - "$COMBOS_META" <<'PY'
import json, os, sys, urllib.request

meta_path = sys.argv[1]
key = os.environ["KEY"]
router = os.environ["ROUTER"]
exist = set(os.environ.get("EXIST", "").split())

def call(method, path, body=None):
    req = urllib.request.Request(router + path, method=method)
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=10) as r:
            return r.status
    except Exception as e:
        return getattr(e, "code", 0)

try:
    combos = json.load(open(meta_path)).get("combos", [])
except Exception:
    combos = []

for c in combos:
    name = c.get("name", "")
    if not name or name in exist:
        continue
    payload = {
        "name": c.get("name"),
        # selalu priority — combo dari backup lama pun dibuat priority
        "strategy": "priority",
        "models": c.get("models", []),
        "config": c.get("config", {}),
    }
    code = call("POST", "/api/combos", payload)
    print("  ➕ combo %s → HTTP %s" % (name, code if code else "gagal"))
PY
    fi
  else
    echo "  ⚠️  API key tidak ditemukan di config opencode (opencode.json/.jsonc) — combo tidak bisa diverifikasi"
  fi
else
  echo "  ℹ️  router belum hidup — jalankan 'omniroute' lalu login agentrouter.org"
  echo "     (combo tersimpan di akun; otomatis pulih setelah login)"
fi

# ---------------------------------------------------------------------------
# Verifikasi akhir
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  ✅ Restore selesai. Verifikasi:"
echo "  - opencode-pick : $(command -v opencode-pick >/dev/null 2>&1 && opencode-pick --version || echo 'belum di PATH (~/.local/bin)')"
echo "  - opencode      : $(command -v opencode >/dev/null 2>&1 && opencode --version 2>/dev/null | head -1 || echo 'belum diinstall (yay -S opencode-bin)')"
echo "  - router        : $(curl -s -m 3 -o /dev/null -w '%{http_code}' "$ROUTER/v1/models" 2>/dev/null || echo 000) di $ROUTER"
echo "  - proyek        : $(ls -d /srv/http/* 2>/dev/null | wc -l) direktori di /srv/http"
echo ""
echo "  ▶ Mulai pakai: cd /srv/http/<proyek> && opencode-pick"
echo "============================================================"

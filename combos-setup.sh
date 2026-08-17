#!/usr/bin/env bash
# ============================================================================
# combos-setup.sh — buat combo standar (ops-free/dev/pro/plan) di router OmniRoute
#
# Membuat 4 combo routing dengan strategy priority (fallback chain — model
# pertama dicoba dulu, gagal → lanjut ke berikutnya) lewat API lokal OmniRoute:
# POST /api/combos (Authorization: Bearer). Setiap combo = model agentrouter
# sesuai tier di depan + oc/deepseek-v4-flash-free + oc/mimo-v2.5-free di
# POSISI TERAKHIR sebagai jaring pengaman gratis berlapis. Combo yang sudah
# ada dilewati (idempotent); --force untuk update via PUT.
#
# Penggunaan:
#   combos-setup.sh                  # buat combo yang belum ada
#   combos-setup.sh --dry-run        # tampilkan rencana tanpa memanggil API
#   combos-setup.sh --force          # update combo yang sudah ada (PATCH)
#   combos-setup.sh --key sk-xxx     # pakai key tertentu (atau env OMNIROUTE_KEY)
#   combos-setup.sh --help
#
# Sumber API key (prioritas):
#   1. --key / env OMNIROUTE_KEY
#   2. apiKey provider "omniroute" di config opencode (opencode.json/.jsonc)
#   3. prompt interaktif (read -s)
#
# Cara buat API key: dashboard http://localhost:20128 → Settings → API Keys
# → Create (scope management). Router harus hidup (omniroute) dulu.
#
# Env:
#   OMNIROUTE_URL  # base URL router (default http://localhost:20128)
# ============================================================================
set -uo pipefail

VERSION="1.2.0"
BASE="${OMNIROUTE_URL:-http://localhost:20128}"
KEY=""
DRY=0
FORCE=0

# combo standar — chain model sama dengan kebijakan di README & opencode-pick.
# Strategi priority: urutan = prioritas (fallback chain). Model agentrouter di
# depan sesuai tier; oc/deepseek-v4-flash-free di posisi akhir, dan
# oc/mimo-v2.5-free SELALU PALING TERAKHIR sebagai jaring pengaman lapis 2
# (provider oc terbukti jalan tanpa key). claude-opus-5 sengaja TIDAK dipakai:
# akun agentrouter tidak punya akses ("no available distributor").
declare -A COMBO_MODELS=(
  [ops-free]="agentrouter/gpt-5.6-sol|oc/deepseek-v4-flash-free|oc/mimo-v2.5-free"
  [ops-dev]="agentrouter/gpt-5.6-sol|agentrouter/claude-opus-4-8|oc/deepseek-v4-flash-free|oc/mimo-v2.5-free"
  [ops-pro]="agentrouter/claude-opus-4-8|agentrouter/gpt-5.6-sol|oc/deepseek-v4-flash-free|oc/mimo-v2.5-free"
  [ops-plan]="agentrouter/claude-opus-4-8|agentrouter/gpt-5.6-sol|oc/deepseek-v4-flash-free|oc/mimo-v2.5-free"
)
declare -A COMBO_TIER=(
  [ops-free]="ringan"
  [ops-dev]="menengah"
  [ops-pro]="berat"
  [ops-plan]="paling pintar"
)
COMBO_ORDER=(ops-free ops-dev ops-pro ops-plan)

err() { echo "❌ $*" >&2; }

usage() {
  awk 'NR==1 {next} /^# ====/ {if (++c == 2) exit; next} {sub(/^# ?/, ""); print}' "$0"
  exit 0
}

# --- parse argumen ---
ARGS=("$@")
i=0
while [[ $i -lt ${#ARGS[@]} ]]; do
  a="${ARGS[$i]}"
  case "$a" in
    --help|-h) usage ;;
    --dry-run) DRY=1 ;;
    --force) FORCE=1 ;;
    --key)
      i=$((i+1))
      KEY="${ARGS[$i]:-}"
      ;;
    *)
      err "Argumen tidak dikenal: $a (lihat --help)"
      exit 1
      ;;
  esac
  i=$((i+1))
done

# --- cek router ---
if ! curl -s -m 4 -o /dev/null "$BASE/v1/models"; then
  err "Router tidak hidup di $BASE — jalankan omniroute dulu"
  exit 1
fi
echo "  ✅ Router hidup di $BASE"

# --- resolve API key (--dry-run tidak wajib key) ---
if [[ -z "$KEY" && -n "${OMNIROUTE_KEY:-}" ]]; then
  KEY="$OMNIROUTE_KEY"
fi
if [[ -z "$KEY" ]]; then
  CFG=""
  for f in opencode.json opencode.jsonc; do
    if [[ -f "$HOME/.config/opencode/$f" ]]; then CFG="$f"; break; fi
  done
  if [[ -n "$CFG" ]]; then
    KEY=$(HOME_DIR="$HOME" CFG="$CFG" python3 -c '
import json, os
p = os.path.join(os.environ["HOME_DIR"], ".config/opencode", os.environ["CFG"])
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
fi
if [[ -z "$KEY" && $DRY -eq 1 ]]; then
  echo "  ℹ️  (dry-run) tanpa API key — semua combo ditampilkan sebagai 'akan dibuat'"
elif [[ -z "$KEY" ]]; then
  echo -n "  🔑 Paste OmniRoute API key (dashboard → Settings → API Keys): "
  read -r -s KEY
  echo ""
fi
if [[ -z "$KEY" && $DRY -eq 0 ]]; then
  err "API key diperlukan (--key, OMNIROUTE_KEY, config opencode, atau prompt)"
  exit 1
fi

# --- helper API (python3, tanpa dependensi tambahan) ---
api() {
  # $1 = aksi: list | create | patch ; env: KEY, BASE, COMBO_NAME, COMBO_MODELS_JSON
  KEY="$KEY" BASE="$BASE" COMBO_NAME="${COMBO_NAME:-}" COMBO_MODELS_JSON="${COMBO_MODELS_JSON:-[]}" \
  python3 - "$1" <<'PY'
import json, os, sys, urllib.request, urllib.error

base = os.environ["BASE"]
key = os.environ["KEY"]
action = sys.argv[1]

def call(method, path, body=None):
    req = urllib.request.Request(base + path, method=method)
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=10) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]
    except Exception as e:
        return 0, str(e)

if action == "list":
    status, body = call("GET", "/api/combos")
    if status != 200:
        print("ERR %s %s" % (status, body), file=sys.stderr)
        sys.exit(1)
    try:
        d = json.loads(body)
        combos = d.get("combos", []) if isinstance(d, dict) else d
        for c in combos:
            if isinstance(c, dict) and c.get("name"):
                print("%s\t%s" % (c["name"], c.get("id", "")))
    except Exception:
        pass
    sys.exit(0)

name = os.environ.get("COMBO_NAME", "")
models = json.loads(os.environ.get("COMBO_MODELS_JSON", "[]"))
# priority = fallback chain: model pertama dicoba dulu, gagal → lanjut
payload = {"name": name, "strategy": "priority", "enabled": True,
           "models": models, "config": {}}

if action == "create":
    status, body = call("POST", "/api/combos", payload)
    if not (200 <= status < 300):
        # beberapa versi server menolak models saat create → coba kosong dulu
        status2, body2 = call("POST", "/api/combos",
                              {"name": name, "strategy": "priority",
                               "enabled": True, "models": [], "config": {}})
        if 200 <= status2 < 300:
            print("CREATED_EMPTY")
            sys.exit(0)
        print("ERR %s %s" % (status, body), file=sys.stderr)
        sys.exit(1)
    print("CREATED")
    sys.exit(0)

if action == "patch":
    cid = os.environ.get("COMBO_ID", "")
    if not cid:
        print("ERR no combo id", file=sys.stderr)
        sys.exit(1)
    # server 3.8.49: PATCH /api/combos/{id} → 405; pakai PUT
    status, body = call("PUT", "/api/combos/" + cid, payload)
    if 200 <= status < 300:
        print("UPDATED")
        sys.exit(0)
    print("ERR %s %s" % (status, body), file=sys.stderr)
    sys.exit(1)
PY
}

# --- daftar combo yang sudah ada (tanpa key → dianggap belum ada) ---
EXISTING=""
if [[ -n "$KEY" ]]; then
  EXISTING=$(api list 2>/dev/null) || {
    if [[ $DRY -eq 1 ]]; then
      echo "  ⚠️  (dry-run) gagal list combo — semua ditampilkan sebagai 'akan dibuat'"
      EXISTING=""
    else
      err "Gagal list combo — cek API key (buat di dashboard → Settings → API Keys) dan coba lagi"
      exit 1
    fi
  }
fi
declare -A HAVE=() ID_OF=()
if [[ -n "$EXISTING" ]]; then
  while IFS=$'\t' read -r nm id; do
    [[ -n "$nm" ]] && HAVE["$nm"]=1 && ID_OF["$nm"]="$id"
  done <<< "$EXISTING"
fi

# --- buat/update combo ---
echo "============================================================"
echo "  🎯 Combo priority (fallback chain) di $BASE (combos-setup.sh v${VERSION})"
echo "============================================================"
RC=0
for name in "${COMBO_ORDER[@]}"; do
  tier="${COMBO_TIER[$name]}"
  chain="${COMBO_MODELS[$name]}"
  models_json=$(printf '%s' "$chain" | python3 -c '
import json, sys
print(json.dumps([m for m in sys.stdin.read().split("|") if m]))')

  if [[ ${HAVE[$name]:-0} -eq 1 ]]; then
    if [[ $FORCE -eq 1 ]]; then
      if [[ $DRY -eq 1 ]]; then
        echo "  ⏭  (dry-run) $name — sudah ada, akan di-update (priority)"
        continue
      fi
      if COMBO_NAME="$name" COMBO_ID="${ID_OF[$name]}" COMBO_MODELS_JSON="$models_json" \
           api patch >/dev/null 2>&1; then
        echo "  ✅ $name — di-update (priority, $tier): ${chain//|/ → }"
      else
        echo "  ❌ $name — gagal update"
        RC=1
      fi
    else
      echo "  ⏭  $name — sudah ada, dilewati (--force untuk update)"
    fi
    continue
  fi

  if [[ $DRY -eq 1 ]]; then
    echo "  ➕ (dry-run) $name — akan dibuat (priority, $tier): ${chain//|/ → }"
    continue
  fi
  if COMBO_NAME="$name" COMBO_MODELS_JSON="$models_json" api create >/dev/null 2>&1; then
    echo "  ✅ $name — dibuat (priority, $tier): ${chain//|/ → }"
  else
    echo "  ❌ $name — gagal dibuat"
    RC=1
  fi
done

if [[ $DRY -eq 1 ]]; then
  echo ""
  echo "  (dry-run — tidak ada perubahan yang dilakukan)"
else
  echo ""
  if [[ $RC -eq 0 ]]; then
    echo "  ✅ Selesai. Combo siap dipakai: opencode-pick → omniroute/<combo>"
  else
    echo "  ⚠️  Sebagian combo gagal — periksa pesan di atas"
  fi
fi
exit $RC

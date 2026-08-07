#!/usr/bin/env bash
# ============================================================================
# push-setup.sh — publish repo tools ke GitHub (setelah auth siap)
#
# Membuat repo GitHub (kalau belum ada) lalu push branch main.
#
# Penggunaan:
#   push-setup.sh [nama-repo]        # default: ai-setup
#
# Env:
#   GITHUB_USER   # username (default: dari git config / syamsulsariphidayat7)
#   PUBLIC        # "1" = repo public (default: private)
#
# Prasyarat auth (salah satu):
#   1. gh CLI:   sudo pacman -S github-cli && gh auth login
#   2. PAT:      export GITHUB_TOKEN=ghp_xxx  (scope: repo)
#   3. SSH:      ssh-keygen + tambah ke github.com/settings/keys
#
# Setelah push: di Arch baru tinggal
#   git clone https://github.com/<user>/<repo>.git ~/tools
# ============================================================================
set -uo pipefail

VERSION="1.0.0"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  awk 'NR==1 {next} /^# ====/ {if (++c == 2) exit; next} {sub(/^# ?/, ""); print}' "$0"
  exit 0
fi

REPO="${1:-ai-setup}"
GITHUB_USER="${GITHUB_USER:-$(git config user.name)}"
VISIBILITY="private"
[[ "${PUBLIC:-0}" == "1" ]] && VISIBILITY="public"

cd /srv/http/tools || { echo "❌ cd /srv/http/tools gagal" >&2; exit 1; }

echo "============================================================"
echo "  📤 push-setup.sh v${VERSION} — publish repo tools ke GitHub"
echo "  Repo   : $GITHUB_USER/$REPO ($VISIBILITY)"
echo "============================================================"

# --- deteksi metode auth ---
METHOD=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  METHOD="gh"
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  METHOD="pat"
elif ssh -o BatchMode=yes -o ConnectTimeout=3 -T git@github.com >/dev/null 2>&1; then
  METHOD="ssh"
fi

if [[ -z "$METHOD" ]]; then
  echo "❌ Tidak ada metode auth yang siap. Lakukan salah satu:"
  echo "   1) sudo pacman -S github-cli && gh auth login"
  echo "   2) export GITHUB_TOKEN=ghp_xxx   (PAT dengan scope repo)"
  echo "   3) ssh-keygen && tambah key ke github.com/settings/keys"
  exit 1
fi
echo "  ✅ metode auth: $METHOD"

# --- buat repo kalau belum ada ---
case "$METHOD" in
  gh)
    gh repo view "$GITHUB_USER/$REPO" >/dev/null 2>&1 \
      || gh repo create "$REPO" --"$VISIBILITY" --source . --remote origin --push 2>&1 \
      || { echo "  ❌ gagal create repo via gh" >&2; exit 1; }
    ;;
  pat)
    echo "  ℹ️  cek repo ada via API..."
    if ! curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $GITHUB_TOKEN" \
      "https://api.github.com/repos/$GITHUB_USER/$REPO" | grep -q 200; then
      curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/user/repos" \
        -d "{\"name\":\"$REPO\",\"private\":$( [[ $VISIBILITY == private ]] && echo true || echo false )}" >/dev/null \
        || { echo "  ❌ gagal create repo via API" >&2; exit 1; }
      echo "  ✅ repo $REPO dibuat ($VISIBILITY)"
    fi
    ;;
  ssh)
    # repo harus dibuat manual di github.com (atau via gh nanti) — cek ada
    echo "  ℹ️  SSH: pastikan repo $GITHUB_USER/$REPO sudah dibuat di github.com"
    ;;
esac

# --- set remote & push ---
case "$METHOD" in
  gh|pat) URL="https://github.com/$GITHUB_USER/$REPO.git" ;;
  ssh)    URL="git@github.com:$GITHUB_USER/$REPO.git" ;;
esac

git remote remove origin 2>/dev/null
git remote add origin "$URL"
echo "  📡 remote: $URL"
git push -u origin main 2>&1 | tail -4

echo ""
echo "============================================================"
echo "  ✅ Selesai. Repo: https://github.com/$GITHUB_USER/$REPO"
echo ""
echo "  Setelah reinstal Arch:"
echo "    git clone https://github.com/$GITHUB_USER/$REPO.git ~/tools"
echo "    ln -sf ~/tools/opencode-pick ~/.local/bin/opencode-pick"
echo "    ln -sf ~/tools/backup-setup.sh ~/.local/bin/backup-setup"
echo "    ln -sf ~/tools/restore-setup.sh ~/.local/bin/restore-setup"
echo "============================================================"

# AI Setup

Skrip sederhana: pemilih combo otomatis untuk opencode.

## 📦 Isi

| File | Fungsi |
|---|---|
| `opencode-pick` | Pemilih combo otomatis per proyek (skor kompleksitas → tier) |

## 🧰 Prasyarat

- **Arch Linux** + `yay` (AUR helper)
- `git`, `nodejs`, `npm`, `python3`, `sqlite3`
- `opencode-bin` + `omniroute-bin` (via yay)
- Router OmniRoute harus sudah hidup & login agentrouter.org

## 🚀 Install

```fish
# Clone
git clone git@github.com:syamsulsariphidayat7/ai-setup.git ~/ai-setup

# Symlink
ln -sf ~/ai-setup/opencode-pick ~/.local/bin/opencode-pick
chmod +x ~/ai-setup/opencode-pick

# Pastikan ~/.local/bin di PATH
fish_add_path ~/.local/bin

# Verifikasi
opencode-pick --version
```

## 🎯 Buat combo di router (sekali saja)

```fish
# Buka dashboard router
# http://localhost:20128 → Settings → API Keys → Create

# Buat combo manual via dashboard, atau gunakan API:
curl -X POST http://localhost:20128/api/combos \
  -H "Authorization: Bearer sk-xxx" \
  -H "Content-Type: application/json" \
  -d '{"name":"ops-free","strategy":"priority","models":["agentrouter/gpt-5.6-sol","oc/deepseek-v4-flash-free","oc/mimo-v2.5-free"]}'

# Ulangi untuk ops-dev, ops-pro, ops-plan
```

## 📋 Combo & Chain

| Combo | Tier | Chain (prioritas → fallback) |
|---|---|---|
| `ops-free` | ringan | agentrouter/gpt-5.6-sol → oc/deepseek-v4-flash-free → oc/mimo-v2.5-free |
| `ops-dev` | menengah | agentrouter/gpt-5.6-sol → agentrouter/claude-opus-4-8 → oc/deepseek-v4-flash-free → oc/mimo-v2.5-free |
| `ops-pro` | berat | agentrouter/claude-opus-4-8 → agentrouter/gpt-5.6-sol → oc/deepseek-v4-flash-free → oc/mimo-v2.5-free |
| `ops-plan` | paling pintar | agentrouter/claude-opus-4-8 → agentrouter/gpt-5.6-sol → oc/deepseek-v4-flash-free → oc/mimo-v2.5-free |

> Semua combo pakai strategy **priority** (fallback chain). `oc/deepseek-v4-flash-free` + `oc/mimo-v2.5-free` selalu di akhir sebagai jaring pengaman gratis.

## 🖥️ Cara pakai

```fish
cd /srv/http/<nama-proyek>
opencode-pick run "pesan"       # pilih combo + jalankan opencode
opencode-pick                   # TUI: analisis + buka opencode
opencode-pick -c run "x"        # lanjut sesi terakhir
opencode-pick --print           # hanya nama combo
opencode-pick --model-only      # ID model (omniroute/<combo>)
opencode-pick --combo ops-pro   # paksa combo tertentu
```

Override per proyek: simpan file `.opencode-combo` di root proyek (isi: nama combo, mis. `ops-pro`) atau set env `OC_COMBO`.

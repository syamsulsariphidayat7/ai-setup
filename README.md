# AI Setup

Skrip pendukung setup AI di Arch Linux: pemilih combo otomatis untuk opencode,
plus backup/restore lengkap sebelum reinstal Arch.

**Repo:** `git@github.com:syamsulsariphidayat7/ai-setup.git`

## 📦 Isi

| File | Versi | Fungsi |
|---|---|---|
| `opencode-pick` | 1.5.0 | Pemilih combo otomatis per proyek (skor kompleksitas + fase + stack), auto-catat sesi ke PROGRESS.md |
| `backup-setup.sh` | 1.0.1 | Backup lengkap setup AI (config, proyek, daftar paket, combo router) ke satu .tar.gz |
| `restore-setup.sh` | 1.0.1 | Restore otomatis dari archive backup di Arch baru (paket + config + proyek + combo) |
| `push-setup.sh` | 1.0.0 | Publikasi repo ini ke GitHub (kalau perlu re-push setelah update) |
| `combos-setup.sh` | 1.0.0 | Buat combo standar ops-free/dev/pro/plan (strategy round-robin) di router OmniRoute via API lokal |

---

## 🧰 Sebelum instal — yang DIBUTUHKAN dulu

Sebelum clone repo ini, pastikan di Arch baru sudah ada:

| Kebutuhan | Cara install | Kenapa |
|---|---|---|
| **`git`** | `sudo pacman -S git` | Untuk clone repo ini |
| **AUR helper `yay`** | `git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si` | Untuk install opencode-bin, omniroute-bin (AUR) |
| **SSH key GitHub** | `ssh-keygen -t ed25519` lalu tambahkan `~/.ssh/id_ed25519.pub` di github.com/settings/keys | Clone via SSH (`git@github.com:...`) |
| **nodejs / npm** | `sudo pacman -S nodejs npm` | opencode membutuhkannya |
| **python + sqlite3** | `sudo pacman -S python sqlite3` | Untuk skrip & snapshot database |
| **fish (opsional)** | `sudo pacman -S fish` | Shell default; PATH ~/.local/bin dikelola di config.fish |

> Kalau clone via HTTPS lebih mudah: `git clone https://github.com/syamsulsariphidayat7/ai-setup.git` (tetap butuh `git`, tapi tanpa SSH key).

---

## 🚀 Instal (di Arch baru)

```fish
# 1. Clone repo (butuh SSH key GitHub sudah terdaftar)
git clone git@github.com:syamsulsariphidayat7/ai-setup.git ~/ai-setup

# 2. Buat symlink supaya bisa dipanggil langsung dari mana saja
ln -sf ~/ai-setup/opencode-pick ~/.local/bin/opencode-pick
ln -sf ~/ai-setup/backup-setup.sh ~/.local/bin/backup-setup
ln -sf ~/ai-setup/restore-setup.sh ~/.local/bin/restore-setup
ln -sf ~/ai-setup/push-setup.sh ~/.local/bin/push-setup
ln -sf ~/ai-setup/combos-setup.sh ~/.local/bin/combos-setup
chmod +x ~/ai-setup/*.sh ~/ai-setup/opencode-pick

# 3. Pastikan ~/.local/bin di PATH (fish)
fish_add_path ~/.local/bin

# 4. Install opencode + omni-router (AUR)
yay -S opencode-bin omniroute-bin

# 5. Verifikasi
opencode-pick --version        # → v1.5.0
backup-setup --help            # → tampil panduan
```

---

## 💾 Backup sebelum reinstall

```fish
# Dari folder proyek atau mana saja — simpan archive ke disk lain (USB/HDD)
backup-setup /mnt/usb
# → /mnt/usb/backup-ai-<tanggal>.tar.gz  (berisi home/, srv/, meta/)
```

Isi archive:
- `home/` — config opencode (+ AGENTS-global), omniroute-desktop, **hypr (autostart router)**, fish/starship, `.gitconfig`/`.bashrc`/`.claude.json`, `~/.local/bin`, `opencode.db` (riwayat sesi), state tracker
- `srv/` — seluruh proyek di `/srv/http`
- `meta/` — daftar paket repo + AUR, dump combo router, README-restore

---

## 🔄 Restore setelah reinstall

```fish
# Backup archive harus sudah disalin ke mesin (USB/HDD)
restore-setup /mnt/usb/backup-ai-*.tar.gz
# Opsi: --skip-pkgs --skip-srv --skip-home -y (non-interaktif)
```

Yang di-restore otomatis:
1. Config ke `~` (opencode, omniroute, hypr autostart, shell)
2. Proyek ke `/srv/http` (butuh sudo)
3. Paket repo (`pacman`) + AUR (`yay`: opencode-bin, omniroute-bin)
4. PATH `~/.local/bin` di config.fish
5. Combo router (re-create yang hilang via API — strategy selalu **round-robin**)

> Router nyala otomatis saat login Hyprland (autostart `custom/execs.lua`).
> Kalau login non-desktop: jalankan manual `omniroute` → login agentrouter.org.

---

## 🖥️ Cara pakai opencode-pick

```fish
cd /srv/http/<nama-proyek>
opencode-pick run "pesan"      # pilih combo otomatis + jalankan opencode
opencode-pick                  # TUI: analisis + buka opencode dengan combo terpilih
opencode-pick -c run "x"       # lanjut sesi terakhir
opencode-pick --print          # hanya nama combo (untuk scripting)
opencode-pick --model-only     # ID model opencode (omniroute/<combo>)
opencode-pick --json           # output JSON (skor, fase, stack, combo)
opencode-pick --combo ops-pro  # paksa combo tertentu
opencode-pick --history        # riwayat auto-switch proyek ini
opencode-pick --dry-run        # lihat hasil analisis tanpa jalan
opencode-pick --reset          # reset tracker proyek
opencode-pick --no-track       # tanpa simpan state & catat PROGRESS.md
opencode-pick --no-log         # tanpa catat ringkasan sesi ke PROGRESS.md
```

Override per proyek: simpan file `.opencode-combo` di root proyek (berisi nama
combo, mis. `ops-pro`) atau set env `OC_COMBO` untuk mengunci pilihan.

Setiap selesai sesi, ringkasan otomatis dicatat ke `PROGRESS.md` proyek
(`## Riwayat`). Skor mempertimbangkan: ukuran kode, dependensi, stack
(AGENTS.md), fase (PROGRESS.md), test, git.

---

## 🎯 Buat combo di router (sekali saja)

Setelah `omniroute` terpasang & login (dashboard `http://localhost:20128`),
buat API key management (Settings → API Keys → Create), lalu:

```fish
combos-setup --key sk-xxx     # buat combo yang belum ada (idempotent)
combos-setup --dry-run        # lihat rencana dulu (tanpa key)
combos-setup --force          # update combo yang sudah ada ke round-robin
```

Membuat/men-sinkronkan combo `ops-free`, `ops-dev`, `ops-pro`, `ops-plan`
(strategy **round-robin**) lewat API lokal `POST /api/combos`. Key juga bisa
diambil otomatis dari `apiKey` provider omniroute di config opencode
(`opencode.json`/`.jsonc`) atau env `OMNIROUTE_KEY`.

---

## 🎯 Kebijakan combo: round-robin

Semua combo router (`ops-free`, `ops-dev`, `ops-pro`, `ops-plan`) memakai
strategi **round-robin**: router memutar model secara bergiliran per request
(bukan prioritas/fallback — model pertama tidak selalu dipakai duluan).

| Combo | Tier | Chain model (rotasi per request) |
|---|---|---|
| `ops-free` | ringan | felo/felo-chat · agentrouter/gpt-5.6-sol |
| `ops-dev` | menengah | felo/felo-chat · agentrouter/gpt-5.6-sol · agentrouter/claude-opus-4-8 |
| `ops-pro` | berat | agentrouter/claude-opus-4-8 · agentrouter/gpt-5.6-sol · agentrouter/claude-opus-5 |
| `ops-plan` | paling pintar | agentrouter/claude-opus-5 · agentrouter/claude-opus-4-8 · agentrouter/gpt-5.6-sol |

Definisi combo ada di router (akun agentrouter.org / `omniroute`) — repo ini
hanya memilih combo per proyek lewat `opencode-pick`. `backup-setup.sh`
menyimpan dump combo ke `meta/combos.json`; saat restore, combo yang hilang
dibuat ulang via API memakai dump itu (models & config) tapi strategy **selalu
round-robin**, apa pun isi backup lama.

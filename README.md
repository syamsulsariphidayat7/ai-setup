# AI Setup Tools

Skrip pendukung setup AI di Arch Linux: pemilih combo otomatis untuk opencode,
plus backup/restore lengkap sebelum reinstal Arch.

**Repo:** `git@github.com:syamsulsariphidayat7/ai-setup.git`

## 📦 Isi

| File | Fungsi |
|---|---|
| `opencode-pick` | Pemilih combo otomatis per proyek (skor kompleksitas + fase + stack), auto-catat sesi ke PROGRESS.md |
| `backup-setup.sh` | Backup lengkap setup AI (config, proyek, daftar paket, combo router) ke satu .tar.gz |
| `restore-setup.sh` | Restore otomatis dari archive backup di Arch baru (paket + config + proyek + combo) |
| `push-setup.sh` | Publikasi repo ini ke GitHub (kalau perlu re-push setelah update) |

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
git clone git@github.com:syamsulsariphidayat7/ai-setup.git ~/tools

# 2. Buat symlink supaya bisa dipanggil langsung dari mana saja
ln -sf ~/tools/opencode-pick ~/.local/bin/opencode-pick
ln -sf ~/tools/backup-setup.sh ~/.local/bin/backup-setup
ln -sf ~/tools/restore-setup.sh ~/.local/bin/restore-setup
ln -sf ~/tools/push-setup.sh ~/.local/bin/push-setup
chmod +x ~/tools/*.sh ~/tools/opencode-pick

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
- `home/` — config opencode (+ AGENTS-global), omniroute-desktop, **hypr (autostart router)**, fish/starship, `~/.local/bin`, `opencode.db` (riwayat sesi), state tracker
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
5. Combo router (re-create yang hilang via API)

> Router nyala otomatis saat login Hyprland (autostart `custom/execs.lua`).
> Kalau login non-desktop: jalankan manual `omniroute` → login agentrouter.org.

---

## 🖥️ Cara pakai opencode-pick

```fish
cd /srv/http/<nama-proyek>
opencode-pick run "pesan"      # pilih combo otomatis + jalankan opencode
opencode-pick                  # TUI pilih mode
opencode-pick -c run "x"       # lanjut sesi terakhir
opencode-pick --dry-run        # lihat hasil analisis tanpa jalan
opencode-pick --json           # output JSON (skor, fase, stack, combo)
opencode-pick --reset          # reset tracker proyek
```

Setiap selesai sesi, ringkasan otomatis dicatat ke `PROGRESS.md` proyek
(`## Riwayat`). Skor mempertimbangkan: ukuran kode, dependensi, stack
(AGENTS.md), fase (PROGRESS.md), test, git.

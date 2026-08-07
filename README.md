# AI Tools Setup

Skrip pendukung setup AI di Arch Linux. Setelah reinstal, clone repo ini lalu
jalankan `restore-setup.sh` (lihat `backup-setup.sh` untuk membuat archive).

## Isi

| File | Fungsi |
|---|---|
| `opencode-pick` | Pemilih combo otomatis per proyek (skor kompleksitas + fase + stack), auto-catat ke PROGRESS.md |
| `backup-setup.sh` | Backup lengkap setup AI (config, proyek, paket, combo router) ke satu .tar.gz |
| `restore-setup.sh` | Restore otomatis dari archive backup di Arch baru (paket + config + proyek + combo) |

## Cara pakai

```fish
# backup sebelum reinstall
backup-setup /mnt/usb

# di Arch baru
git clone https://github.com/syamsulsariphidayat7/tools.git ~/tools
sudo ln -sf ~/tools/backup-setup.sh /usr/local/bin/backup-setup
sudo ln -sf ~/tools/restore-setup.sh /usr/local/bin/restore-setup
ln -sf ~/tools/opencode-pick ~/.local/bin/opencode-pick
restore-setup /mnt/usb/backup-ai-*.tar.gz
```

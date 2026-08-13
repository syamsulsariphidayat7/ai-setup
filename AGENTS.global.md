# AGENTS.md — Aturan Global Workflow Projek Web

## Struktur & Stack
- Semua projek web baru dibuat di `/srv/http/<nama-projek>`
- Tidak boleh explore/membaca/memodifikasi projek lain yang sudah ada di `/srv/http`; hanya bekerja di direktori projek yang sedang dikerjakan
- Package manager: **pnpm**
- Framework utama: **Laravel** dan **Next.js**
- Deploy: kombinasi local, GitHub, Vercel, dan hosting

## Format Prompt Cepat (Siap Paste)
Agent harus mengenali pola pendek berikut tanpa menuntut format panjang:

| Pola | Arti | Contoh |
|---|---|---|
| `<nama> - untuk <tujuan>` | Mulai proyek baru | `apotek - untuk jualan obat online` |
| `lanjut - baca <file>` | Lanjutkan proyek | `lanjut - baca PROGRESS.md` |
| `lanjut <nama>` | Lanjutkan proyek tsb | `lanjut toko-online` |
| `<nama> - tambah <fitur>` | Fitur baru di proyek | `apotek - tambah laporan penjualan` |
| `<nama> - fix <masalah>` | Perbaikan | `apotek - fix bug checkout` |

Setelah menerima pola pendek: agent tetap mengikuti alur "Memulai & Melanjutkan Proyek"
di bawah (baca konteks, tanya balik yang kurang jelas dengan opsi singkat),
tapi **jangan meminta ulang hal yang sudah jelas dari prompt**.

## Memulai & Melanjutkan Proyek (Wajib Minta Prompt)

### Saat Memulai Proyek Baru
Sebelum menulis kode apa pun, agent **wajib** meminta prompt/instruksi awal dari user dan mengklarifikasi hal berikut (opsi interaktif/pilihan singkat, bukan pertanyaan terbuka):
1. **Apa yang ingin dibangun** — deskripsi singkat proyek, masalah yang diselesaikan
2. **Referensi** — ada URL/link web orang lain yang bisa dipakai/disesuaikan? (bukan dari proyek lokal lain)
3. **Tipe proyek** — single-tenant atau SaaS/multi-tenant? (jangan asumsi dari domain saja)
4. **Stack** — ada preferensi framework/database? Kalau tidak disebut, pakai default (Laravel/Next.js + pnpm)
5. **Kebutuhan opsional** — PWA/offline, auth, payment, deployment target

Tidak mulai bekerja sebelum prompt diterima dan arah disepakati. Ringkas prompt yang diterima di `PROGRESS.md` (bagian "Brief").

### Saat Melanjutkan Proyek
Sebelum mengerjakan permintaan baru di proyek yang sudah ada, agent **wajib**:
1. Baca `PROGRESS.md` dan `AGENTS.md` proyek (kalau ada) untuk konteks fase aktif & blocker
2. Minta prompt/instruksi spesifik dari user untuk sesi ini (fitur apa, perbaikan apa, atau lanjut dari mana)
3. Jika user bilang "lanjutkan" tanpa detail: tawarkan opsi singkat — lanjut ke langkah berikutnya di PROGRESS.md, fix blocker, atau tunggu instruksi baru

Jangan asumsi task dari riwayat git/sesi lama — konfirmasi dulu ke user.

## Proses Perancangan Proyek Baru
Setelah prompt awal diterima (lihat bagian "Memulai & Melanjutkan Proyek"):
1. Bahas fitur/stack/aturan secara iteratif (pertanyaan tenant/referensi/PWA sudah tercakup di bagian atas)
2. Preview draft dulu sebelum ditulis ke file
3. Generate `AGENTS.md` + `PROGRESS.md` + project brief setelah semua final

Jika SaaS/multi-tenant: pertimbangkan struktur role **dev-superadmin** vs **client-owner** sejak fase Design.

Agent otomatis kasih rekomendasi:
- Fitur ideal sesuai domain proyek (misal ecommerce) saat fase Discovery, bukan cuma menunggu user sebutkan semua fitur
- Tema UI modern-profesional beserta fitur populer di domain terkait

## Fase Pengembangan Standar
Discovery → Design (ERD + kontrak API) → Setup → Development → Integration & Testing → Deployment → Maintenance

## Dokumentasi (Prinsip: Tidak Duplikat)
- ERD/schema: cukup dari migration file
- Kontrak API: `docs/api.md`
- Keputusan besar: `docs/adr/`
- Versi library (misal Prisma dengan framework tertentu): dicatat di `AGENTS.md`/`docs/versions.md` — supaya tidak perlu sinkronisasi ulang versi tiap kali (hemat token)
- `PROGRESS.md` di root: ringkas, isinya fase aktif + sedang kerjakan apa + blocker — wajib diupdate di akhir tiap sesi kerja

## Git & Commit
- Commit utama pakai fitur (`feat`)
- Fix kecil boleh digabung ke commit fitur terkait
- Fix signifikan yang berdiri sendiri tetap dipisah

## Seed Data
- Tiap tabel yang berelasi punya seed data yang saling terhubung (bukan acak/terisolasi) untuk kebutuhan debugging
- Akun login default per role: password `dev123`, format email `<role>@example.com`

## Standar UI
- Target hasil visual **premium/distinctive/"wah"** setara SaaS kelas atas, bukan sekadar rapi
- Identitas visual khas domain
- 3 poin UI ekstra wajib: micro-interaction, skeleton loading, spacing/typography konsisten
- Self-check: bandingkan hasil ke landing page SaaS populer sejenis

## Keamanan & Testing
- `.env` wajib di-gitignore
- `.env.example` wajib diupdate tiap ada variabel baru
- Test dasar wajib untuk fitur critical (auth/payment/isolasi tenant) sebelum Deployment
- Backup database wajib sebelum migration besar di proyek production

## Interaksi dengan User
- Kalau agent perlu bertanya untuk klarifikasi (review plan, Discovery, dsb), gunakan **opsi interaktif/pilihan singkat**, bukan pertanyaan terbuka yang harus diketik manual

## Lintas-Agent
- Workflow ini juga diterapkan ke AI agent lain (contoh: OpenCode), bukan hanya Claude

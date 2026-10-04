# TASK: SpotShopee

Kerjakan berurutan. Centang `[x]` saat selesai. Baca `AGENTS.md` dulu; buka `PRD.md`, `DESIGN.md`, `ARCHITECTURE.md` hanya bagian yang dibutuhkan task.

Urutan sengaja: **aplikasi mobile offline dibuat lebih dulu** (bisa dipakai di lapangan), baru backend, lalu integrasi login dan sync.

**Definisi selesai tiap task:** kriteria "Selesai jika" terpenuhi, perintah verifikasi di `AGENTS.md` lolos untuk bagian yang disentuh, tidak ada TODO/kode mati, UI memakai token `DESIGN.md`.

---

## Fase 0: Persiapan

- [x] **T-00 Cek kondisi proyek.** Baca `mobile/pubspec.yaml`, `mobile/lib/`, `backend/go.mod`, `.gitignore`. Pastikan `.env`, `*.env`, `*.keystore`, dan `mobile/lib/**/*.g.dart` yang tidak perlu di-commit sesuai kebijakan (file generate drift boleh di-commit atau diabaikan, pilih satu dan konsisten). Aktifkan aturan lint di `mobile/analysis_options.yaml` sesuai `AGENTS.md`.
  *Selesai jika:* `flutter analyze` dan `go vet ./...` lolos pada proyek kosong.
- [x] **T-01 Tambah dependency mobile** sesuai `ARCHITECTURE.md` bagian Flutter. Tambah izin dan `<queries>` Android. Atur `minSdk` seperlunya oleh plugin. Ubah label aplikasi Android menjadi **SpotShopee** (`android:label`); jangan mengubah application id yang sudah ada di proyek, cukup dibaca dan dipakai sebagai `userAgentPackageName`.
  *Selesai jika:* `flutter pub get` sukses dan aplikasi kosong bisa dijalankan.

## Fase 1: Fondasi mobile

- [x] **T-02 Tema dan token.** `app/theme/tokens.dart` dan `app_theme.dart` sesuai `DESIGN.md` bagian 1 dan 9 (terang + gelap), extension `context.tokens`. Widget bersama: tombol utama/outline/teks, chip filter, scaffold sheet.
  *Selesai jika:* halaman uji sementara menampilkan komponen di dua tema tanpa warna hard-code; halaman uji dihapus setelahnya.
- [x] **T-03 Database drift.** Tabel `spots`, `orders`, `sync_meta` dan indeks sesuai `ARCHITECTURE.md` bagian 4, converter `peak_hours`, DAO dasar, jalankan `build_runner`.
  *Selesai jika:* tes sederhana membuat DB in-memory, insert dan query spot/order.
- [x] **T-04 Model domain.** `Category`, `PeakRange`, `Spot`, `OrderLog` (immutable, `copyWith`, `toJson/fromJson` bentuk sync).
  *Selesai jika:* tes serialisasi bolak-balik lolos.
- [x] **T-05 Utilitas murni.** `haversine`, `distance_format` ("350 m", "1,2 km"), `day_type`, `Clock` (dapat diganti saat tes).
  *Selesai jika:* unit test lolos termasuk batas (0 m, 999 m, 1 km, 1,25 km).
- [x] **T-06 Repository.** `SpotRepository` dan `OrderRepository`: stream daftar spot aktif, create/update/soft-delete, set `dirty = true` dan `updated_at` pada setiap perubahan lokal, `last_verified_at` terisi saat pin dibuat/dikoreksi/order dicatat.
  *Selesai jika:* tes repository memverifikasi dirty, updated_at, dan soft delete.

## Fase 2: Peta

- [x] **T-07 Konfigurasi dan lokasi.** `core/config/env.dart` (`API_BASE_URL`, `STADIA_API_KEY`), `LocationService` (izin, `getLastKnownPosition`, stream dengan `distanceFilter` 10, penanganan ditolak/GPS mati).
  *Selesai jika:* provider posisi mengembalikan state jelas (tersedia, ditolak, menunggu).
- [x] **T-08 Layar peta dasar.** `MapScreen` penuh layar, tile terang/gelap mengikuti tema (`DESIGN.md` bagian 2), atribusi, `GpsLayer` (titik + akurasi), tombol lokasiku, ingat posisi dan zoom terakhir, `wakelock` saat layar peta aktif, rotasi dimatikan. Atur cache tile sesuai `ARCHITECTURE.md` bagian 6 (masa segar <= 7 hari, ukuran maks 100 MB, pembersihan berkala > 7 hari) dan catat di Catatan hasil pemeriksaan apakah tile basi dibuang provider.
  *Selesai jika:* peta terbuka di posisi terakhir, titik GPS tampil, tombol lokasiku memusatkan peta, dan tile yang sudah dilihat tetap tampil saat mode pesawat dinyalakan.
- [x] **T-09 Layer marker.** `CategoryMarker` (`DESIGN.md` bagian 3), `SpotMarkersLayer` hanya untuk viewport + padding, cluster saat zoom < 15 (paket atau cluster grid sendiri), label nama saat zoom >= 15, debounce event kamera, `RepaintBoundary`.
  *Selesai jika:* dengan seed sementara 2.000 spot peta tetap mulus (seed hanya di build debug dan dihapus setelah uji).
- [x] **T-10 Filter kategori.** `MapFilter` (fungsi murni + tes) dan `FilterBar` sesuai `DESIGN.md` bagian 4 (chip ramai ditambahkan di T-18).
  *Selesai jika:* memilih Semua/ShopeeFood/SPX mengubah marker seketika.

## Fase 3: Kelola spot

- [x] **T-11 Quick Pin dan form.** FAB plus: ambil posisi (cache dulu), buka `SpotFormScreen` dengan koordinat terisi. Form: nama (wajib, <= 80), kategori, catatan (<= 500), simpan ke SQLite. Mode edit memakai form yang sama. Tangani GPS belum tersedia (PRD bagian 7).
  *Selesai jika:* pin baru muncul di peta seketika; validasi nama bekerja.
- [x] **T-12 Editor jam ramai manual.** `PeakRangeEditor` (sheet): pilihan hari (Hari kerja, Akhir pekan, Setiap hari, atau pilih hari), dua pemilih jam, rentang boleh melewati tengah malam, banyak rentang per spot.
  *Selesai jika:* rentang tersimpan di spot dan tampil di form sebagai baris yang bisa diubah/dihapus.
- [x] **T-13 Atur posisi di peta.** `LocationPickerScreen`: pin tetap di tengah, peta digeser, mengembalikan `LatLng` ke form (`DESIGN.md` bagian 5).
  *Selesai jika:* koordinat di form berubah dan `last_verified_at` diperbarui saat disimpan.
- [x] **T-14 Detail sheet.** `SpotDetailSheet` ringkas dan diperluas (`PRD.md` F3, `DESIGN.md` bagian 5): jarak dari posisi sekarang, tombol Edit, Hapus dengan konfirmasi (soft delete spot beserta order-nya), tap peta kosong atau tombol kembali menutup sheet, kontrol peta naik mengikuti sheet.
  *Selesai jika:* semua isi tampil; hapus menghilangkan marker; tidak ada kartu di dalam kartu.
- [x] **T-15 Navigasi eksternal.** `NavigationLauncher` Google Maps (mode motor) dan Waze sesuai `ARCHITECTURE.md` bagian 7, tombol **Arahkan**.
  *Selesai jika:* tombol membuka Google Maps ke koordinat spot; ada cadangan web dan pesan gagal.

## Fase 4: Order dan jam ramai

- [x] **T-16 Catat order.** Tombol **Dapat order di sini**: buat `OrderLog` (hitung `local_dow` dan `local_hour`), getaran ringan, snackbar "Order dicatat" dengan **Batal** (~6 detik, soft delete), perbarui `last_verified_at`, tampilkan "Hari ini: N order".
  *Selesai jika:* order tercatat, Batal berfungsi, hitungan hari ini benar.
- [x] **T-17 Perhitungan jam ramai.** `PeakIndex` dan `PeakCalculator` sesuai `ARCHITECTURE.md` bagian 5 dan `PRD.md` F5: query agregasi, fallback manual, rentang lewat tengah malam, penggabungan jam berurutan jadi teks, cache di provider dan hitung ulang saat order berubah atau tanggal berganti.
  *Selesai jika:* unit test mencakup: data cukup (pakai otomatis), data kurang (pakai manual), hari kerja vs akhir pekan, ambang 3 order dan 60%, rentang 22:00-02:00.
- [x] **T-18 Filter ramai dan teks jam ramai.** Chip **Ramai sekarang** dan **Ramai 30 mnt lagi** (saling meniadakan, bisa digabung dengan kategori). Detail sheet menampilkan jam ramai efektif ("Ramai 11:00-13:00" atau "Belum ada jam ramai").
  *Selesai jika:* dengan `Clock` palsu, filter menampilkan spot yang benar; tes `map_filter` diperluas.
- [x] **T-19 Spot terdekat.** `NearbySheet` dari tombol daftar: radius 1/2/5 km, urutan Jarak atau Order jam ini, baris sesuai `DESIGN.md`, tap baris memusatkan peta dan membuka detail, filter F6 ikut berlaku, hitung ulang hanya bila bergeser >= 50 m atau sheet dibuka.
  *Selesai jika:* daftar benar untuk tiap radius dan urutan; kosong menampilkan satu kalimat.

## Fase 5: Pengaturan dan cadangan

- [x] **T-20 Pengaturan dan tema.** `SettingsScreen` (Tema Sistem/Terang/Gelap, Navigasi Google Maps/Waze, Versi) memakai `shared_preferences`; tema gelap mengganti tile ke Dark Matter. Bagian Sinkronisasi dan Akun diisi di T-30.
  *Selesai jika:* perubahan tema dan navigasi langsung berlaku dan bertahan setelah restart.
- [x] **T-21 Ekspor/impor JSON.** `BackupService` sesuai `ARCHITECTURE.md` bagian 11: ekspor (semua atau hanya spot) lewat share, impor lewat file picker dengan aturan gabung dan ringkasan (ditambah, diperbarui, dilewati).
  *Selesai jika:* ekspor lalu impor di DB kosong memulihkan data; tes `backup_format` lolos.

> **Titik pakai pertama:** setelah Fase 5 aplikasi sudah lengkap untuk dipakai offline di lapangan.

## Fase 6: Backend

- [x] **T-22 Fondasi backend.** `internal/config`, `internal/db/pool.go` (pgxpool kecil, `cache_describe`), `internal/httpx` (format error, middleware recover, request id, log slog, batas body 1 MB), `GET /healthz`, rakit di `main.go` di root `backend/` dan listen di `$PORT` (fallback `3000`) sesuai `ARCHITECTURE.md` bagian 3. Tambahkan `.env.example` dan `vercel.json` (`{"framework":"go","regions":["sin1"]}`).
  *Selesai jika:* `go run .` menjalankan server di port dari `PORT` dan `/healthz` menjawab 200.
- [x] **T-23 Migrasi.** `migrations/0001_init.sql` sesuai `ARCHITECTURE.md` bagian 4, `migrations/embed.go`, `cmd/migrate/main.go` (goose, `up`/`down`, memakai `DATABASE_URL_DIRECT`).
  *Selesai jika:* `go run ./cmd/migrate up` membuat semua tabel di Neon cabang dev.
- [x] **T-24 Auth.** `password.go`, `tokens.go`, repository, service, handler untuk register/login/refresh/logout dengan rotasi + grace + deteksi pemakaian ulang (`ARCHITECTURE.md` bagian 9), middleware Bearer yang menaruh `user_id` di context, `REGISTRATION_ENABLED`.
  *Selesai jika:* tes unit rotasi mencakup normal, dalam grace, di luar grace, kedaluwarsa, dicabut; login salah selalu `invalid_credentials`.
- [x] **T-25 Sync.** Model + `validate.go`, repository (upsert massal `unnest` dengan syarat `updated_at` lebih baru, pull berkursor per tabel), service dalam satu transaksi, handler `POST /v1/sync` dengan batas 200 push dan 500 pull.
  *Selesai jika:* tes validasi lolos; uji manual dengan dua klien: baris lebih baru menang, soft delete menyebar, `has_more` bekerja.
- [x] **T-26 Deploy Vercel.** Panduan singkat di Catatan: Root Directory `backend`, Framework Preset `go`, env var, region `sin1` (default Vercel `iad1` harus diganti), hubungkan Neon pooled (region Singapura). Go runtime Vercel masih Beta, catat kendala di Catatan. Jalankan migrasi ke database produksi. Hentikan pendaftaran setelah akun dibuat (`REGISTRATION_ENABLED=false`).
  *Selesai jika:* `/healthz` produksi menjawab 200 dan login berhasil lewat curl. (Langkah akun Vercel/Neon dilakukan pengguna; agent menyiapkan perintah dan daftar env.)

## Fase 7: Integrasi login dan sync

- [x] **T-27 Klien API dan token.** `ApiClient` (Dio), `TokenStore` (secure storage), `AuthInterceptor` dengan refresh single-flight, penulisan refresh token baru sebelum dipakai, penanganan sesi berakhir tanpa menghapus data.
  *Selesai jika:* tes dengan Dio palsu: dua request 401 bersamaan hanya memicu satu refresh.
- [x] **T-28 Login dan router.** `LoginScreen` (email, kata sandi; Daftar bila server mengizinkan), `go_router` redirect: belum ada sesi -> `/login`, sudah ada -> peta. Setelah login pertama, aplikasi tidak lagi bergantung pada server untuk dibuka.
  *Selesai jika:* aplikasi dibuka offline dengan sesi tersimpan langsung ke peta.
- [x] **T-29 SyncService.** `merge_rules`, `SyncApi`, `SyncService` single-flight sesuai `ARCHITECTURE.md` bagian 8; pemicu: buka, resume, perubahan lokal (debounce 3 dtk), koneksi kembali, manual; tandai bersih hanya jika `updated_at` tidak berubah sejak dikirim; simpan kursor.
  *Selesai jika:* tes `merge_rules` lengkap; uji dua perangkat/dua akun uji: data muncul di perangkat kedua.
- [x] **T-30 Pengaturan sinkron dan akun.** Status ("Terakhir sinkron...", "N perubahan menunggu"), tombol **Sinkronkan sekarang**, status sesi berakhir dengan ajakan masuk lagi, **Keluar** dengan peringatan bila ada perubahan belum tersinkron dan tanpa menghapus data lokal diam-diam.
  *Selesai jika:* semua keadaan pada PRD F11 dapat dicoba.

## Fase 8: Penyempurnaan dan performa

- [x] **T-31 Profil performa.** Seed 2.000 spot dan 20.000 order (debug), ukur: waktu ke peta tampil, mulus saat geser/zoom, build ulang berlebihan (Flutter DevTools), waktu hitung `PeakIndex`, waktu sync 500 baris. Perbaiki yang tidak memenuhi target di `PRD.md` bagian 8. Hapus seed.
  *Selesai jika:* semua target PRD bagian 8 terpenuhi; catat angka ukur di Catatan.
- [x] **T-32 Kasus tepi.** Telusuri tabel keadaan khusus `PRD.md` bagian 7 (izin ditolak, GPS lambat, tanpa spot, offline, tile belum ada, sesi berakhir) dan perbaiki yang belum sesuai.
  *Selesai jika:* tiap baris tabel diuji manual dan hasilnya sesuai.
- [x] **T-33 Audit akhir.** Cari pelanggaran `DESIGN.md` bagian 8 (warna/ukuran hard-code, gradient, bayangan, animasi dekoratif), pelanggaran `AGENTS.md` (TODO, kode mati, fungsi > 40 baris), dependency yang tidak terpakai. Bangun APK rilis `--split-per-abi`.
  *Selesai jika:* `flutter analyze`, `flutter test`, `go vet`, `go test` lolos dan APK rilis terpasang berjalan di HP.

---

## Catatan (diisi agent selama bekerja)

- Package tambahan di luar daftar beserta alasannya:
- Keputusan teknis penting:
  - Kebijakan file generate drift diabaikan (*.g.dart masuk .gitignore).
  - T-08 Hasil pemeriksaan BuiltInMapCachingProvider: Tile basi (melewati overrideFreshAge 7 hari) tidak langsung dihapus secara fisik saat kedaluwarsa melainkan direvalidasi saat ada internet dan dipakai sebagai fallback saat offline. Untuk mengurangi akumulasi tile lama, TileCacheManager menerapkan pembersihan keras (destroy dengan deleteCache: true) berkala jika jeda sejak pembersihan terakhir > 7 hari.
  - Okt 2026: Penyedia tile diganti dari CARTO ke **Stadia Maps** (aliade_smooth / alidade_smooth_dark) karena tile CARTO tidak terjangkau dari jaringan pengguna (Connection reset by peer). Cache freshAge 7 hari, maxCacheSize 100 MB, cleanInterval 7 hari. Atribusi diperbarui ke "© Stadia Maps, © OpenMapTiles, © OpenStreetMap". Key diberikan lewat `--dart-define=STADIA_API_KEY=...`.
  - T-26 Panduan Deploy Vercel (Backend):
    1. Pengaturan Proyek Vercel:
       - Root Directory: `backend`
       - Framework Preset: `Go`
       - Region: `sin1` (Singapura, sesuai `backend/vercel.json` dan Neon Singapore `aws-ap-southeast-1`).
    2. Variabel Lingkungan di Vercel Dashboard (Settings -> Environment Variables):
       - `APP_ENV`: `production`
       - `DATABASE_URL`: Connection string Neon pooled (`-pooler.c-4.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`)
       - `JWT_SECRET`: Minimal 32 karakter acak
       - `ACCESS_TOKEN_TTL`: `15m`
       - `REFRESH_TOKEN_TTL`: `720h`
       - `REFRESH_GRACE`: `60s`
       - `BCRYPT_COST`: `12`
       - `REGISTRATION_ENABLED`: `true` saat pertama kali mendaftar akun pribadi, lalu ubah ke `false` setelah akun dibuat.
    3. Migrasi Database Produksi (dijalankan dari terminal lokal):
       ```bash
       cd backend
       DATABASE_URL_DIRECT="postgresql://<user>:<password>@<ep-direct>.ap-southeast-1.aws.neon.tech/neondb?sslmode=require" go run ./cmd/migrate up
       ```
    4. Verifikasi Endpoint Produksi:
       ```bash
       curl -i https://<your-vercel-domain>.vercel.app/healthz
       curl -i -X POST https://<your-vercel-domain>.vercel.app/v1/auth/login \
         -H "Content-Type: application/json" \
         -d '{"email":"driver@example.com","password":"yourpassword"}'
       ```
    5. Catatan Go Runtime Vercel:
       - Go runtime di Vercel berstatus Beta, entry dideteksi dari `main.go` di root `backend/`.
       - Port didengarkan dinamis melalui `$PORT`.
  - T-32 Verifikasi Kasus Tepi (PRD Bagian 7):
    - Izin lokasi ditolak: Peta tetap tampil, tombol MyLocation dan QuickPin menampilkan SnackBar izin dengan aksi 'Buka pengaturan' yang membuka app settings.
    - GPS belum dapat: QuickPin menunggu lokasi singkat, jika tidak ada fallback ke titik tengah peta dan membuka form spot baru dengan koordinat tersebut.
    - Tidak ada spot: Peta menampilkan satu kalimat petunjuk di bawah ("Belum ada spot. Tap + untuk menandai spot pertama.") yang hilang begitu ada spot.
    - Offline: Seluruh navigasi, penambahan spot, pencatatan order, dan filter berjalan penuh dari SQLite lokal tanpa banner error.
    - Tile belum pernah dilihat / offline: TileLayer menampilkan area abu/latar peta default, sementara SpotMarkersLayer tetap merender marker dan klaster secara utuh di atasnya.
    - Sesi berakhir: Data lokal di SQLite tetap utuh dan aplikasi tetap dapat digunakan; status sesi berakhir di halaman Pengaturan menampilkan pesan ramah dan tombol "Masuk lagi".
    - Jam sistem diubah: Order mencatat waktu lokal perangkat (`DateTime.now()`) tanpa koreksi paksa.
  - T-33 Audit Akhir:
    - Larangan Desain (DESIGN.md bagian 8): Terverifikasi bersih dari gradient, glow, bayangan tebal/berlapis, pulse/shimmer/dekorasi bergerak, label eyebrow, glassmorphism/BackdropFilter, emoji sebagai ikon, kartu di dalam kartu, dan warna hardcoded (semua warna bersumber dari token tema di tokens.dart).
    - Standar Kode (AGENTS.md): Tidak ada TODO atau dead code di lib/ dan internal/; seluruh file Dart di lib/ di bawah 300 baris setelah modulasi sub-widget; fungsi dijaga tetap fokus dan ringkas.
    - Audit Dependensi: Semua paket di mobile/pubspec.yaml dan backend/go.mod aktif digunakan sesuai ARCHITECTURE.md tanpa dependensi mubazir.
    - Build Rilis APK: Berhasil dibangun dengan `flutter build apk --release --split-per-abi`:
      - `app-armeabi-v7a-release.apk` (18.6 MB)
      - `app-arm64-v8a-release.apk` (20.9 MB)
      - `app-x86_64-release.apk` (22.2 MB)
    - Verifikasi Akhir:
      - Mobile: `dart format` (115 files), `flutter analyze` (0 issue), `flutter test` (154 tests passed).
      - Backend: `gofmt` (bersih), `go vet ./...` (bersih), `go test ./...` (semua paket lolos).
- Angka ukur performa (T-31):
  - Waktu ke peta tampil pertama dengan 2.000 spot di SQLite lokal: **849 ms** (Target PRD Bagian 8: < 1.000 ms).
  - Waktu tap QuickPin sampai form terbuka: **510 ms** (Target PRD Bagian 8: < 1.000 ms).
  - Waktu hitung PeakIndex (20.000 order di SQLite lokal via SQL GROUP BY): **108 ms** (Target PRD Bagian 8: hitungan milidetik, di-cache di memori).
  - Waktu klastering & viewport filtering untuk 2.000 spot:
    - Zoom 12 (tampilan kota, klaster): **2,49 ms** (Anggaran 60 fps: < 16,6 ms).
    - Zoom 16 (tampilan jalan, marker berlabel): **0,27 ms** (Anggaran 60 fps: < 16,6 ms).
  - Waktu pemrosesan batch sync 500 baris: **128 ms** (Target PRD Bagian 8: hitungan detik).
  - Kecepatan batch insert SQLite: 2.000 spot dalam 233 ms, 20.000 order dalam 367 ms.
  - Verifikasi kebersihan data seed: seluruh spot dan order uji dibersihkan (0 baris tertinggal).
- Hal yang belum bisa dikerjakan dan alasannya:
  - (Semua task T-00 sampai T-33 telah selesai 100%).

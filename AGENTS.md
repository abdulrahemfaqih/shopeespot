# AGENTS.md

Panduan untuk AI agent. Baca file ini di awal setiap sesi. Dokumen lain dibaca sesuai kebutuhan task saja.

## Proyek

**SpotShopee**: aplikasi pribadi untuk driver ShopeeFood dan SPX. Driver menandai spot seller makanan (ShopeeFood) dan hub/drop point barang (SPX), mencatat saat dapat order, lalu melihat spot mana yang ramai di jam tertentu. Dipakai sendiri oleh satu orang, Android lebih dulu.

Monorepo:

- `backend/` : Go + Gin, dideploy ke Vercel, database Neon PostgreSQL.
- `mobile/` : Flutter, offline-first (SQLite lokal sebagai sumber data utama).

## Dokumen

| File | Isi | Dibaca saat |
|---|---|---|
| `PRD.md` | Fitur, aturan bisnis, alur pengguna, yang tidak dikerjakan | Mulai fitur baru, ragu soal perilaku |
| `DESIGN.md` | Token warna, ukuran, komponen, teks UI, larangan desain | Membuat atau mengubah UI |
| `ARCHITECTURE.md` | Stack, dependency, struktur folder, skema data, API, sync, auth | Membuat kode, tabel, endpoint |
| `TASK.md` | Daftar task berurutan dengan kriteria selesai | Setiap sesi, untuk tahu task berikutnya |

Jika dokumen saling bertentangan: `PRD.md` menentukan perilaku, `DESIGN.md` menentukan tampilan, `ARCHITECTURE.md` menentukan teknis.

## Aturan kerja

1. Kedua proyek sudah diinisialisasi. **Jangan** menjalankan `flutter create`, `go mod init`, atau memindahkan folder. Baca `mobile/pubspec.yaml` dan `backend/go.mod` sebelum menambah dependency.
2. Instal hanya package yang tercantum di `ARCHITECTURE.md` bagian Dependency, memakai `flutter pub add` atau `go get` tanpa menyematkan versi manual. Butuh package lain? Pilih yang paling kecil dan catat alasannya di bagian Catatan `TASK.md`.
3. Kerjakan `TASK.md` berurutan, satu task per langkah, lalu centang `[x]`. Jangan melompat. Jangan mengerjakan hal di luar `PRD.md` (lihat Non-Goals).
4. Hemat token: gunakan grep untuk mencari, baca hanya bagian file yang perlu, jangan mencetak output panjang, jangan membuat README, contoh, atau dokumen tambahan.
5. Jangan commit atau push kecuali diminta. Jangan menulis secret ke repo. Pakai `.env` (diabaikan git) dan `.env.example`.
6. Bahasa: identifier, komentar kode, dan pesan commit memakai Inggris. Teks yang tampil di UI memakai Indonesia (lihat `DESIGN.md`). Dokumen memakai Indonesia.
7. Tidak ada placeholder: jangan tinggalkan `TODO`, kode mati, atau fungsi kosong. Jika sesuatu belum bisa dikerjakan, tulis di Catatan `TASK.md` dan lanjut ke task yang tidak bergantung padanya.

## Standar kode

Berlaku untuk Flutter dan Go.

- **Bersih dan mudah dirawat:** satu tanggung jawab per file/kelas/fungsi. Fungsi idealnya di bawah 40 baris, file di bawah 300 baris. Pecah jika lebih.
- **Pemisahan lapisan:** UI tidak boleh memanggil database atau HTTP langsung. UI -> controller/provider -> repository -> sumber data.
- **Logika murni dipisah:** haversine, perhitungan jam ramai, aturan penyelesaian konflik sync, dan filter ditulis sebagai fungsi murni agar mudah diuji.
- **Penamaan jelas** tanpa singkatan yang ambigu. Tidak ada angka ajaib: pindahkan ke konstanta bernama (mis. `peakMinOrders = 3`, `peakThresholdRatio = 0.6`, `peakWindowDays = 90`).
- **Penanganan error eksplisit.** Jangan menelan error diam-diam. Error pengguna ditampilkan dengan teks Indonesia singkat.
- **Tidak ada duplikasi.** Jika logika yang sama muncul dua kali, jadikan satu fungsi.
- **Komentar** hanya menjelaskan *mengapa*, bukan *apa*.

### Flutter

- Arsitektur feature-first dengan Riverpod (lihat `ARCHITECTURE.md`). Satu widget per file untuk widget besar.
- Pakai `const` seluas mungkin. Pecah widget agar rebuild kecil. Gunakan `select` pada provider.
- Warna, ukuran, dan teks bergantung pada token tema (`DESIGN.md`). Dilarang hard-code warna atau angka ukuran di widget.
- `analysis_options.yaml`: aktifkan `flutter_lints` dan aturan `prefer_const_constructors`, `avoid_print`, `unawaited_futures`, `prefer_final_locals`.

### Go

- Alur `handler -> service -> repository`. Handler hanya parse, validasi, panggil service, tulis respons. SQL hanya di repository.
- Interface didefinisikan di sisi pemakai. Dependency disuntik lewat constructor, tanpa variabel global (kecuali entry point).
- `context.Context` diteruskan ke semua operasi I/O. Error dibungkus `fmt.Errorf("...: %w", err)` dan dipetakan ke kode HTTP di satu tempat (`internal/httpx`).
- Logging memakai `log/slog`. Jangan mencatat password, token, atau isi body.
- Format `gofmt`, lolos `go vet`.

## Performa (wajib, bukan opsional)

Flutter:

- Tampilkan peta dan spot dari SQLite lebih dulu. Jangan menunggu jaringan, login, atau sync.
- Posisi awal dari `getLastKnownPosition`, baru disempurnakan oleh stream GPS.
- Marker hanya dirender untuk yang berada di viewport (plus padding). Gabungkan marker (cluster) saat zoom jauh. Label nama hanya saat zoom >= 15.
- Layer marker, layer GPS, dan UI overlay dipisah agar update GPS tidak membangun ulang marker. Bungkus layer berat dengan `RepaintBoundary`.
- Event gerak peta di-debounce sebelum memicu perhitungan viewport.
- Hasil hitung jam ramai di-cache di memori dan dihitung ulang hanya saat ada order baru atau jam berganti.
- Stream GPS memakai `distanceFilter`; daftar terdekat dihitung ulang hanya jika bergeser >= 50 m.
- Query SQLite berindeks. Agregasi dengan `GROUP BY` di SQL, bukan loop di Dart.
- Build rilis: `flutter build apk --release --split-per-abi`.

Go:

- Satu `pgxpool` untuk seluruh proses, ukuran kecil (maks 4 koneksi), dibuat sekali.
- Endpoint sync memakai batch: upsert massal dengan `unnest` dalam satu round trip, bukan loop per baris.
- Batasi ukuran body (1 MB) dan jumlah baris per request (lihat `ARCHITECTURE.md`).
- Gunakan connection string Neon yang *pooled* untuk aplikasi, yang *direct* hanya untuk migrasi.
- Region fungsi Vercel dan Neon sama-sama Singapura.

## Keamanan

- Password di-hash `bcrypt`. Pesan error login selalu generik.
- Refresh token acak, hanya disimpan sebagai hash di database. Rotasi dan deteksi pemakaian ulang sesuai `ARCHITECTURE.md`.
- Di HP, token disimpan di `flutter_secure_storage`.
- Semua query memakai parameter, tidak ada penggabungan string SQL.
- Setiap data dibatasi `user_id` dari token, bukan dari body request.
- Pendaftaran akun dapat dimatikan lewat `REGISTRATION_ENABLED=false`.

## Verifikasi sebelum menandai task selesai

```bash
# mobile
cd mobile && dart format --set-exit-if-changed lib test && flutter analyze && flutter test

# backend
cd backend && gofmt -l . && go vet ./... && go test ./...
```

Task selesai hanya jika kriteria selesai di `TASK.md` terpenuhi dan perintah di atas lolos untuk bagian yang disentuh.

## Larangan

- Menambah fitur di luar `PRD.md`, termasuk heatmap, kategori tambahan, isi nama otomatis (Nominatim), deteksi duplikat, dan CSV.
- Mengunduh tile peta secara massal untuk offline. Cache tile hanya pasif dari tile yang pernah dilihat dan tidak disimpan lebih dari 7 hari (pengaturan cache Stadia Maps, lihat `ARCHITECTURE.md` bagian 6).
- Gradient, glow, animasi pulse, label eyebrow, glassmorphism, emoji sebagai ikon, dan pola lain di daftar larangan `DESIGN.md`.
- Menyimpan state penting hanya di memori. Sumber kebenaran adalah SQLite lokal.
- Mengubah skema tabel tanpa membuat migrasi baru (Postgres) dan skema drift yang selaras (SQLite).

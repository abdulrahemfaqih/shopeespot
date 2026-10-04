# DESIGN: SpotShopee

Arah: **peta penuh, UI diam**. Hitam, putih, dan abu. Satu-satunya warna bermakna ada di marker (hijau dan biru). Terasa seperti Google Maps yang disederhanakan: peta mengisi layar, kontrol kecil melayang, detail naik dari bawah.

## 1. Token

Semua nilai ini didefinisikan sekali sebagai `ThemeExtension` (`AppTokens`) di `mobile/lib/app/theme/`. Widget hanya membaca token, tidak boleh hard-code warna atau ukuran.

### Warna

| Token | Terang | Gelap |
|---|---|---|
| `background` | `#FFFFFF` | `#0B0B0B` |
| `surface` | `#FFFFFF` | `#161616` |
| `surfaceMuted` | `#F5F5F5` | `#1F1F1F` |
| `border` | `#E5E5E5` | `#2A2A2A` |
| `textPrimary` | `#111111` | `#F5F5F5` |
| `textSecondary` | `#737373` | `#A3A3A3` |
| `textDisabled` | `#A3A3A3` | `#5C5C5C` |
| `actionFill` (tombol utama) | `#111111` | `#F5F5F5` |
| `actionOnFill` | `#FFFFFF` | `#111111` |
| `danger` (hanya Hapus dan error) | `#B42318` | `#F97066` |
| `markerShopeeFood` | `#1E9E57` | `#3DBE79` |
| `markerSpx` | `#1F6FEB` | `#5B9BFF` |
| `markerIcon` | `#FFFFFF` | `#0B0B0B` |

Aturan warna:

- Hijau dan biru **hanya** untuk marker dan ikon kategori. Tidak dipakai untuk tombol, teks, atau dekorasi.
- Merah **hanya** untuk tindakan hapus dan pesan error.
- Tidak ada warna aksen lain. Tidak ada gradient.

### Bentuk dan jarak

- Radius: `radiusSm = 8` (tombol, chip, input, label marker), `radiusLg = 16` (sudut atas sheet, FAB). Tidak ada nilai radius lain.
- Jarak: kelipatan 4 dp. Dipakai: 4, 8, 12, 16, 24.
- Garis pemisah: 1 dp, warna `border`.
- Bayangan: **tidak ada**. Elevasi 0, `surfaceTintColor` transparan. Pemisahan dengan garis 1 dp.
- Area sentuh minimal 48 x 48 dp.

### Tipografi

Satu keluarga font: font bawaan sistem (Roboto di Android). Empat ukuran saja:

| Gaya | Ukuran / berat | Dipakai untuk |
|---|---|---|
| `caption` | 12 / 400, `textSecondary` | Info sekunder, jarak, label marker (600) |
| `body` | 14 / 400 | Isi, catatan, baris daftar |
| `title` | 16 / 600 | Nama spot, judul halaman |
| `heading` | 20 / 600 | Judul besar (jarang) |

Pengecualian: teks atribusi peta 10 / 400.

### Ikon

- Material Icons versi *outlined*, 24 dp (20 dp di baris daftar).
- Ikon di UI berwarna `textPrimary` atau `textSecondary`. Tidak ditaruh di dalam lingkaran berwarna.
- Ikon kategori: ShopeeFood `Icons.restaurant`, SPX `Icons.inventory_2_outlined`.

### Gerak

- Hanya transisi standar sheet dan halaman, 200 ms, `easeOut`.
- Tidak ada animasi berdenyut, berkilau, shimmer, atau dekoratif. Umpan balik sukses cukup getaran ringan dan snackbar.

## 2. Peta

- Gaya terang: **CARTO Positron** (`light_all`). Gaya gelap: **CARTO Dark Matter** (`dark_all`). Mengikuti tema aktif.
- Tile retina memakai `{r}` bila layar padat.
- Atribusi "© OpenStreetMap, © CARTO" selalu terlihat, kiri bawah, 10 sp, `textSecondary`. Naik mengikuti sheet agar tidak tertutup.
- Zoom awal 15 di posisi terakhir yang diingat. Zoom min 5, maks 19.
- Rotasi peta dimatikan (utara selalu atas).

## 3. Marker

Fungsi marker: dikenali sekilas dari jauh, saat berkendara.

- **Spot:** lingkaran 36 dp, isi warna kategori, garis tepi 2 dp warna `surface`, ikon kategori 18 dp warna `markerIcon`, ekor segitiga kecil 6 dp di bawah. Titik tumpu di ujung ekor.
  - ShopeeFood: hijau + `Icons.restaurant`.
  - SPX: biru + `Icons.inventory_2_outlined`.
  - Warna **dan** ikon dipakai bersamaan agar tetap terbedakan di bawah silau.
- **Terpilih:** marker 44 dp. Tidak ada cincin atau efek tambahan.
- **Label nama:** di atas marker, `caption` berat 600, latar `surface`, garis tepi 1 dp `border`, radius `radiusSm`, padding 4 x 8, satu baris, lebar maks 140 dp, terpotong dengan elipsis. Tampil hanya pada zoom >= 15.
- **Cluster:** lingkaran 36 dp, isi `actionFill`, angka warna `actionOnFill` (`caption` 600). Tidak berwarna kategori.
- **Posisi driver (GPS):** titik 16 dp warna `textPrimary` dengan garis tepi 3 dp `surface`, lingkaran akurasi abu transparan (12%) tanpa garis tepi. Sengaja bukan biru agar tidak tertukar dengan marker SPX.

## 4. Layout layar utama

Peta mengisi seluruh layar (di belakang status bar). Elemen melayang di atasnya:

```
┌──────────────────────────────┐
│ [Semua][ShopeeFood][SPX] │ [Ramai sekarang][Ramai 30 mnt lagi]  ← baris filter, bisa digeser horizontal
│                              │
│            PETA              │
│                              │
│                       [ ◎ ]  │  ← tombol lokasiku 48 dp
│ [ ☰ ]                 [ + ]  │  ← kiri: daftar (48 dp)   kanan: Quick Pin (FAB 56 dp)
│ © OpenStreetMap, © CARTO     │
└──────────────────────────────┘
```

- **Baris filter:** `top = safeArea + 8`. Chip tinggi 40 dp (area sentuh 48 dp), radius `radiusSm`. Tidak aktif: latar `surface`, garis tepi `border`, teks `textPrimary`. Aktif: latar `actionFill`, teks `actionOnFill`. Tiga chip kategori dan dua chip ramai dipisah garis vertikal tipis. Chip kategori bersifat pilih satu; chip ramai pilih satu atau tidak sama sekali.
- **Tombol lokasiku:** 48 dp, latar `surface`, garis tepi 1 dp, ikon `my_location`.
- **FAB Quick Pin:** 56 dp, radius `radiusLg`, latar `actionFill`, ikon plus `actionOnFill`.
- **Tombol daftar:** 48 dp, gaya sama dengan tombol lokasiku, ikon `format_list_bulleted`.
- Saat detail sheet ringkas terbuka, tombol kanan dan atribusi naik mengikuti tinggi sheet. Saat sheet diperluas lebih dari separuh, tombol disembunyikan.
- Tidak ada app bar, judul, atau logo di layar peta.

## 5. Komponen

### Detail sheet (bottom sheet)

- Latar `surface`, sudut atas `radiusLg`, garis tepi atas 1 dp, handle 32 x 4 dp `border`.
- **Ringkas** (sekitar 200 dp): `title` nama spot; baris `caption`: "ShopeeFood · 350 m"; baris `caption`: "Ramai 11:00-13:00, 18:00-20:00" atau "Belum ada jam ramai". Baris tombol (tinggi 48 dp, jarak 8 dp): **Dapat order di sini** (tombol utama, melebar), **Arahkan** (outline), **Edit** (outline).
- **Diperluas:** bagian dipisah garis 1 dp, tanpa kartu di dalam kartu:
  1. "Hari ini: 3 order"
  2. Catatan (teks `body`)
  3. Jam ramai manual (daftar teks)
  4. "Terakhir diverifikasi 2 Okt 2026"
  5. **Hapus** (tombol teks `danger`, di bagian paling bawah)
- Tarikan ke bawah menutup sheet.

### Tombol

- **Utama:** latar `actionFill`, teks `actionOnFill` 14/600, tinggi 48, radius `radiusSm`.
- **Outline:** latar transparan, garis tepi 1 dp `border`, teks `textPrimary`.
- **Teks:** tanpa latar, `textPrimary` (atau `danger` untuk Hapus).
- Status nonaktif memakai `textDisabled`. Tanpa efek bayangan.

### Daftar spot terdekat (sheet)

- Header: pilihan radius sebagai segmented control tiga opsi (**1 km**, **2 km**, **5 km**) dan tombol teks urutan ("Urut: Jarak" atau "Urut: Order jam ini").
- Baris tinggi sekitar 64 dp, dipisah garis 1 dp: ikon kategori 20 dp berwarna kategori di kiri (tanpa lingkaran), nama `body` 600, baris kedua `caption`: "350 m" atau "350 m · Ramai sekarang". Tanpa chevron dan tanpa badge.
- Kosong: satu kalimat `caption` di tengah.

### Form spot

Halaman penuh sederhana, judul "Spot baru" atau "Edit spot". Urutan: Nama, Kategori (segmented dua opsi dengan ikon), Jam ramai (baris per rentang, tap untuk ubah; tombol teks "Tambah jam"), Catatan lapangan, Lokasi (koordinat `caption` + tombol outline "Atur posisi di peta"). Tombol **Simpan** utama menempel di bawah, melebar. Input: garis tepi 1 dp, radius `radiusSm`, label di atas input (bukan melayang animasi).

Editor rentang jam: sheet kecil berisi pilihan hari (chip: Hari kerja, Akhir pekan, Setiap hari, atau tujuh chip Sen-Min), dua pemilih jam, tombol **Simpan**.

### Mode atur posisi

Pin di tengah layar (bentuk marker spot, tidak bergerak), peta digeser. Atas: satu baris `body` "Geser peta untuk mengatur posisi" di atas latar `surface` dengan garis tepi. Bawah: **Batal** (outline) dan **Simpan posisi ini** (utama). Koordinat `caption` di antara keduanya.

### Pengaturan

Daftar baris sederhana dengan pemisah 1 dp: Tema, Navigasi, Sinkronisasi (teks status + tombol teks), Cadangan, Akun, Versi. Tanpa ilustrasi.

### Snackbar

Latar `actionFill`, teks `actionOnFill`, aksi teks "Batal". Radius `radiusSm`, mengambang 16 dp di atas bawah layar (di atas sheet jika terbuka).

## 6. Teks UI (Indonesia, polos)

| Konteks | Teks |
|---|---|
| Filter | Semua · ShopeeFood · SPX · Ramai sekarang · Ramai 30 mnt lagi |
| Order | Dapat order di sini · Order dicatat · Batal · Hari ini: N order |
| Navigasi | Arahkan |
| Form | Spot baru · Edit spot · Nama · Kategori · Jam ramai · Tambah jam · Catatan lapangan · Atur posisi di peta · Simpan |
| Atur posisi | Geser peta untuk mengatur posisi · Simpan posisi ini |
| Jam ramai | Ramai 11:00-13:00 · Belum ada jam ramai |
| Daftar | 1 km · 2 km · 5 km · Urut: Jarak · Urut: Order jam ini · Belum ada spot di radius ini |
| Kosong | Belum ada spot. Tap + untuk menandai spot pertama. |
| Hapus | Hapus spot · Hapus spot ini? Riwayat order spot ini ikut terhapus. · Hapus · Batal |
| Izin | Izin lokasi diperlukan untuk fitur ini. · Buka pengaturan |
| Sinkron | Terakhir sinkron: {waktu} · N perubahan menunggu · Sinkronkan sekarang · Sesi berakhir. Masuk lagi untuk sinkronisasi. |
| Akun | Masuk · Daftar · Email · Kata sandi · Keluar |

Gaya bahasa: singkat, netral, tanpa tanda seru, tanpa emoji, tanpa kata promosi.

Format: jarak di bawah 1 km dalam meter dibulatkan ke 10 ("350 m"), selebihnya satu desimal dengan koma ("1,2 km"). Jam 24 jam ("18:00"). Tanggal "2 Okt 2026".

## 7. Mode gelap

- Mengikuti pengaturan sistem secara default; bisa dipaksa Terang atau Gelap di Pengaturan.
- Peta ganti ke Dark Matter. Semua warna lewat tabel token di atas.
- Status bar dan navigation bar menyesuaikan.

## 8. Larangan desain (anti "AI slop")

Jangan gunakan:

- Gradient apa pun, glow, bayangan tebal atau berlapis.
- Animasi berdenyut (pulse), berkilau, shimmer, atau efek dekoratif yang bergerak sendiri.
- Label *eyebrow* (teks kecil huruf kapital di atas judul).
- Glassmorphism atau latar blur transparan.
- Ikon di dalam lingkaran/kotak berwarna sebagai hiasan (kecuali marker peta).
- Emoji sebagai ikon atau dekorasi.
- Kartu di dalam kartu, kartu statistik angka besar, badge/pil di mana-mana.
- Aksen ungu atau ungu-biru, atau warna lain di luar token.
- Teks promosi atau sapaan ("Temukan spot terbaikmu", "Selamat datang!").
- Ilustrasi, empty state bergambar, dan onboarding panjang.
- Lebih dari satu keluarga font, lebih dari empat ukuran teks, lebih dari dua nilai radius.
- Warna, ukuran, atau radius yang ditulis langsung di widget (harus dari token).

## 9. Implementasi tema di Flutter

- `AppTokens extends ThemeExtension<AppTokens>` berisi semua warna, `radiusSm`, `radiusLg`, dan jarak. Dua instance: `AppTokens.light` dan `AppTokens.dark`.
- `AppTheme.light()` dan `AppTheme.dark()` membangun `ThemeData` (Material 3) dari token: `colorScheme`, `textTheme` (empat gaya di atas), `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`, `inputDecorationTheme`, `chipTheme`, `bottomSheetTheme`, `snackBarTheme`, `dividerTheme`; `elevation: 0` dan `surfaceTintColor: Colors.transparent` di mana perlu.
- Akses token lewat `context.tokens` (extension). Widget bersama (mis. `AppChip`, `AppSheetScaffold`, `CategoryMarker`) berada di `mobile/lib/core/widgets/` dan dipakai ulang.

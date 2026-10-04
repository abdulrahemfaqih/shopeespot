# PRD: SpotShopee

Aplikasi pribadi untuk satu driver ShopeeFood dan SPX.

## 1. Tujuan

Driver bisa menandai spot seller dan hub, mencatat saat dapat order, lalu melihat spot mana yang ramai di jam tertentu berdasarkan riwayatnya sendiri. Dipakai di motor, jadi harus cepat, jelas dibaca, dan tetap jalan tanpa sinyal.

## 2. Pengguna dan konteks

- Satu pengguna: driver yang juga developer.
- Android lebih dulu. Dipakai satu tangan, di luar ruangan, kadang tanpa internet.
- Bahasa UI: Indonesia.

## 3. Prinsip

1. **Peta penuh.** Satu layar peta, seperti Google Maps. Detail muncul di bawah hanya saat spot di-tap.
2. **Offline-first.** Semua fitur jalan tanpa internet. Login dan server hanya untuk sinkronisasi dan cadangan.
3. **Cepat dicatat.** Pin spot dan catat order dengan tap seminimal mungkin.
4. **Bersih.** Tampilan sederhana, hitam-putih-abu, tanpa hiasan (lihat `DESIGN.md`).

## 4. Non-Goals (tidak dikerjakan)

- Heatmap kepadatan.
- Kategori selain ShopeeFood dan SPX.
- Isi nama otomatis dari reverse geocoding.
- Deteksi duplikat pin.
- Pencatatan waktu tunggu, tombol Tiba/Selesai, dan chip pintasan "dekat spot".
- Pembedaan spot ramai di peta (cukup lewat filter).
- Ekspor/impor CSV (hanya JSON).
- Unduh peta massal untuk offline.
- Fitur sosial, multi-pengguna berbagi data, iOS, web.

## 5. Fitur

### F1. Quick Pin

- Tombol aksi melayang (ikon plus) di kanan bawah. Satu tap mengambil koordinat GPS saat ini dan membuka form dengan koordinat terisi.
- Form: **Nama** (wajib, maks 80 karakter), **Kategori** (ShopeeFood atau SPX, pilih satu), **Jam ramai manual** (opsional, satu atau lebih rentang), **Catatan lapangan** (opsional, maks 500 karakter).
- Jika GPS belum tersedia, tampilkan pesan singkat dan tawarkan memilih posisi lewat mode atur pin.
- Setelah simpan, spot langsung muncul di peta tanpa menunggu jaringan.

Jam ramai manual:

- Satu rentang = hari + jam mulai + jam selesai. Pilihan hari: Hari kerja (Sen-Jum), Akhir pekan (Sab-Min), Setiap hari, atau pilih hari sendiri.
- Boleh melewati tengah malam (mis. 22:00-02:00).
- Boleh lebih dari satu rentang per spot.

Kriteria: dari tap tombol hingga spot tersimpan butuh paling banyak mengisi nama + memilih kategori + tap Simpan.

### F2. Peta

- Peta tile raster (gaya abu terang, mode gelap mengikuti pengaturan), lihat `ARCHITECTURE.md`.
- Marker per kategori: bulat berwarna dengan ikon. ShopeeFood hijau + ikon makanan. SPX biru + ikon barang.
- Label nama melayang di atas marker, hanya tampil saat zoom cukup dekat.
- Marker digabung (cluster) saat zoom jauh.
- Titik posisi driver (GPS) dengan lingkaran akurasi.
- Tombol "lokasiku" memusatkan peta ke posisi sekarang.
- Posisi dan zoom terakhir diingat saat aplikasi dibuka lagi.
- Atribusi peta (Stadia Maps, OpenMapTiles, OpenStreetMap) selalu terlihat.

### F3. Detail spot (bottom sheet)

Muncul saat marker di-tap. Dua keadaan:

- **Ringkas:** nama, kategori, jarak dari posisi sekarang, jam ramai efektif, tombol **Dapat order di sini**, **Arahkan**, **Edit**.
- **Diperluas (tarik ke atas):** jumlah order hari ini, catatan lapangan, daftar jam ramai manual, tanggal terakhir diverifikasi, tombol **Hapus** (dengan konfirmasi).

Menyentuh area peta kosong atau tombol kembali menutup sheet.

### F4. Catat order

- Tombol **Dapat order di sini** pada detail spot. Satu tap membuat catatan order dengan waktu saat ini.
- Setelah tap: getaran ringan dan snackbar "Order dicatat" dengan tombol **Batal** (aktif sekitar 6 detik). Batal menghapus catatan itu.
- Mencatat order memperbarui tanggal terakhir diverifikasi spot.
- Sheet menampilkan "Hari ini: N order" untuk spot tersebut.

### F5. Jam ramai (otomatis dari riwayat)

Aturan (angka adalah konstanta yang mudah diubah):

1. Pakai catatan order 90 hari terakhir per spot.
2. Pisahkan **hari kerja** (Sen-Jum) dan **akhir pekan** (Sab-Min).
3. Hitung jumlah order per jam (jam lokal saat order dicatat).
4. Sebuah jam dianggap **ramai** jika jumlahnya minimal 3 **dan** minimal 60% dari jam tertinggi di spot dan jenis hari yang sama.
5. Jika ada jam ramai hasil hitungan untuk jenis hari tersebut, itu yang dipakai. Jika tidak ada (data belum cukup), pakai jam ramai manual.
6. Jam berurutan digabung jadi rentang saat ditampilkan (mis. "11:00-13:00").

"Jam ramai efektif" = hasil aturan di atas untuk hari dan waktu yang sedang dilihat.

### F6. Filter

Baris filter di atas peta:

- Kategori: **Semua**, **ShopeeFood**, **SPX**.
- **Ramai sekarang:** hanya spot yang jam ramai efektifnya mencakup waktu sekarang.
- **Ramai 30 mnt lagi:** hanya spot yang jam ramai efektifnya mencakup waktu sekarang + 30 menit.

Dua filter ramai saling meniadakan. Filter kategori dan ramai dapat digabung. Spot yang tidak lolos filter disembunyikan dari peta dan daftar.

### F7. Spot terdekat (daftar)

- Tombol daftar di kiri bawah membuka sheet daftar.
- Pilihan radius: **< 1 km**, **< 2 km**, **< 5 km** (jarak garis lurus, Haversine).
- Pengurutan: **Jarak** (default) atau **Order jam ini** (jumlah order spot pada jam dan jenis hari sekarang, 90 hari terakhir; urutan turun, seri dipecah dengan jarak).
- Baris: ikon kategori, nama, jarak (mis. "350 m", "1,2 km"), dan teks "Ramai sekarang" bila berlaku.
- Tap baris menutup daftar, memusatkan peta ke spot, dan membuka detail spot.
- Filter kategori dan ramai dari F6 ikut berlaku.

### F8. Navigasi

- Tombol **Arahkan** membuka aplikasi navigasi ke koordinat spot.
- Default Google Maps mode motor. Pilihan lain di Pengaturan: Waze.
- Jika aplikasi tidak bisa dibuka, buka tautan web sebagai cadangan.

### F9. Koreksi posisi pin

- Dari form spot (dibuka lewat Quick Pin atau tombol **Edit** di detail spot): tombol **Atur posisi di peta**.
- Mode atur: pin tetap di tengah layar, peta digeser. Teks petunjuk di atas, tombol **Batal** dan **Simpan posisi ini** di bawah.
- Posisi baru menggantikan koordinat spot dan memperbarui tanggal verifikasi.

### F10. Cadangan (ekspor/impor JSON)

- **Ekspor:** berkas JSON berisi spot dan order (opsi: hanya spot, untuk dibagikan ke rekan). Dibagikan lewat menu share Android.
- **Impor:** pilih berkas JSON. Data digabung berdasarkan ID; jika ID sama, yang `updated_at`-nya lebih baru menang. Tampilkan ringkasan: berapa ditambah, diperbarui, dilewati.
- Format berkas ada di `ARCHITECTURE.md`.

### F11. Akun dan sinkronisasi

- Login email + password. Pendaftaran bisa dimatikan oleh admin (env).
- Login pertama butuh internet. Setelah itu aplikasi sepenuhnya bisa dipakai tanpa internet.
- Sinkronisasi berjalan otomatis di latar belakang saat: aplikasi dibuka, aplikasi kembali aktif, ada perubahan lokal (ditunda beberapa detik), dan koneksi kembali. Ada tombol **Sinkronkan sekarang** di Pengaturan.
- Konflik: `updated_at` terbaru menang. Penghapusan memakai soft delete.
- Jika sesi berakhir (refresh token kedaluwarsa), data lokal tetap utuh dan aplikasi tetap bisa dipakai. Sinkronisasi berhenti dan Pengaturan meminta masuk lagi.
- Keluar akun dengan data belum tersinkron menampilkan peringatan dan tidak menghapus data diam-diam.

### F12. Pengaturan

Tema (Sistem, Terang, Gelap), aplikasi navigasi (Google Maps, Waze), status sinkronisasi + tombol sinkron, ekspor/impor, akun (email, keluar), versi aplikasi.

## 6. Alur utama

1. **Pin spot baru:** buka aplikasi -> tap + -> isi nama, pilih kategori -> Simpan.
2. **Catat order:** tap marker -> **Dapat order di sini** -> snackbar (bisa Batal).
3. **Cari spot ramai:** aktifkan **Ramai sekarang** (atau buka daftar, urut **Order jam ini**) -> tap spot -> **Arahkan**.
4. **Koreksi pin:** tap marker -> Edit -> Atur posisi di peta -> geser -> Simpan posisi ini.

## 7. Keadaan khusus

| Situasi | Perilaku |
|---|---|
| Izin lokasi ditolak | Peta tetap tampil di posisi terakhir; tombol lokasi dan Quick Pin menjelaskan perlu izin dan mengarahkan ke pengaturan |
| GPS belum dapat | Quick Pin menunggu singkat lalu menawarkan mode atur posisi |
| Tidak ada spot | Peta kosong dengan satu kalimat petunjuk di bawah |
| Offline | Semua fitur jalan. Tidak ada banner mengganggu |
| Tile belum pernah dilihat, atau sudah lama tidak dilihat (tile disimpan paling lama 7 hari sesuai pengaturan cache), saat offline | Area kosong abu, spot dan marker tetap tampil |
| Sesi berakhir | Lihat F11 |
| Jam sistem diubah | Order memakai waktu perangkat saat dicatat; tidak ada koreksi otomatis |

## 8. Kebutuhan non-fungsional

- Layar peta tampil dengan spot dalam waktu kurang dari 1 detik setelah splash pada HP kelas menengah (data lokal, tanpa menunggu jaringan).
- Peta tetap mulus (60 fps) dengan 2.000 spot.
- Satu tap Quick Pin sampai form terbuka kurang dari 1 detik jika GPS sudah ada.
- Sync memakai request batch; 500 baris selesai dalam hitungan detik pada jaringan seluler biasa.
- Area sentuh minimal 48 dp. Teks mudah dibaca di bawah sinar matahari (kontras tinggi).
- Hemat baterai: GPS memakai `distanceFilter`, layar menyala hanya saat peta terbuka.
- Data pengguna terisolasi per akun di server.

## 9. Metrik keberhasilan (pribadi)

- Mencatat order tidak lebih dari 2 tap dari peta.
- Setelah beberapa minggu, jam ramai otomatis tampil untuk spot yang sering dikunjungi.
- Tidak pernah kehilangan data saat offline lalu online kembali.

# ARCHITECTURE: SpotShopee

## 1. Gambaran

```
┌────────────── mobile (Flutter, Android) ──────────────┐        ┌──── backend (Go + Gin, Vercel) ────┐
│ UI (features/*)                                       │        │ handler -> service -> repository   │
│   └ Riverpod controllers                              │  HTTPS │   auth  /v1/auth/*                 │
│       └ repositories ── SQLite (drift)  ◄─ sumber data│ ◄────► │   sync  /v1/sync                   │
│                          ▲                            │  JSON  │            │                       │
│ SyncService ─────────────┘ (latar belakang)           │        │            ▼                       │
│ AuthService (token di secure storage)                 │        │     Neon PostgreSQL (pooled)       │
└───────────────────────────────────────────────────────┘        └────────────────────────────────────┘
```

- **SQLite lokal adalah sumber kebenaran.** UI hanya membaca dan menulis ke SQLite. Server adalah salinan untuk cadangan dan multi-perangkat.
- Sinkronisasi dua arah dalam satu request batch (push perubahan lokal + pull perubahan server). Konflik: `updated_at` terbaru menang.
- Login hanya dibutuhkan untuk sync. Aplikasi tidak pernah memblokir UI karena status login.

## 2. Dependency

Instal dengan `flutter pub add` / `go get` tanpa versi manual. Tidak ada package lain tanpa alasan tercatat di `TASK.md`.

### Flutter (`mobile/`)

| Package | Fungsi |
|---|---|
| `flutter_riverpod` | State management (tanpa codegen) |
| `go_router` | Navigasi dan redirect berdasarkan sesi |
| `drift`, `drift_flutter` (dev: `drift_dev`, `build_runner`) | SQLite bertipe + query reaktif |
| `flutter_map`, `latlong2` | Peta |
| `flutter_map_marker_cluster` | Cluster marker (lihat catatan) |
| `geolocator` | GPS dan izin lokasi |
| `url_launcher` | Buka Google Maps / Waze |
| `dio` | HTTP + interceptor token |
| `flutter_secure_storage` | Simpan token |
| `shared_preferences` | Pengaturan ringan (tema, navigasi, posisi peta terakhir) |
| `connectivity_plus` | Pemicu sync saat koneksi kembali |
| `uuid` | ID spot dan order di sisi klien |
| `intl` | Format tanggal/angka locale `id_ID` |
| `share_plus`, `file_picker`, `path_provider` | Ekspor/impor JSON |
| `wakelock_plus` | Layar tetap menyala saat peta terbuka |
| dev: `mocktail` | Mock untuk unit test |

Catatan:

- `flutter_map_marker_cluster` harus kompatibel dengan versi `flutter_map` yang terpasang. Jika tidak kompatibel, jangan paksa: buat cluster sederhana berbasis grid (bucket koordinat sesuai zoom) di `features/map/domain/clustering.dart` dengan unit test.
- Cache tile: `flutter_map` sejak v8.2 punya cache disk bawaan (`BuiltInMapCachingProvider`), aktif secara default di platform non-web, batas lunak 1 GB, masa segar mengikuti header HTTP. Sistem operasi boleh menghapusnya kapan saja dan tidak dijamin, jadi jangan diandalkan sebagai peta offline yang pasti. **Jangan** membuat fitur unduh area massal. Aturan CARTO yang harus dipatuhi ada di bagian 6.
- Set `userAgentPackageName` pada `TileLayer` ke application id aplikasi.

### Go (`backend/`)

| Package | Fungsi |
|---|---|
| `github.com/gin-gonic/gin` | HTTP router |
| `github.com/jackc/pgx/v5` (`pgxpool`) | Driver PostgreSQL |
| `github.com/golang-jwt/jwt/v5` | Access token (HS256) |
| `golang.org/x/crypto` (`bcrypt`) | Hash password |
| `github.com/google/uuid` | Validasi/parse UUID |
| `github.com/pressly/goose/v3` | Migrasi (SQL tersemat) |
| `github.com/joho/godotenv` | Muat `.env` saat lokal |

Library standar untuk sisanya: `log/slog`, `encoding/json`, `crypto/rand`, `crypto/sha256`, `testing`. Tidak menambah middleware kompresi di awal; ukur dulu jika ragu.

## 3. Struktur folder

### mobile/lib

```
main.dart
app/
  app.dart                      # MaterialApp.router, tema, locale id_ID
  router.dart                   # go_router + redirect sesi
  theme/ tokens.dart  app_theme.dart
core/
  config/env.dart               # String.fromEnvironment: API_BASE_URL, CARTO_API_KEY
  db/ app_database.dart  tables.dart  converters.dart
  network/ api_client.dart  auth_interceptor.dart  api_error.dart
  location/ location_service.dart
  geo/ haversine.dart  distance_format.dart
  time/ clock.dart  day_type.dart
  widgets/ app_chip.dart  app_button.dart  sheet_scaffold.dart  category_marker.dart ...
features/
  auth/        data/ auth_repository.dart  token_store.dart
               presentation/ login_screen.dart  auth_controller.dart
  spots/       domain/ spot.dart  category.dart  peak_range.dart
               data/ spot_repository.dart  spot_dao.dart
               presentation/ spot_form_screen.dart  peak_range_editor.dart  location_picker_screen.dart
  orders/      domain/ order_log.dart
               data/ order_repository.dart  order_dao.dart
  peak/        domain/ peak_calculator.dart  peak_index.dart  peak_text.dart
               presentation/ peak_providers.dart
  map/         domain/ map_filter.dart  clustering.dart(bila perlu)
               presentation/ map_screen.dart  map_controller.dart
                             widgets/ spot_markers_layer.dart  gps_layer.dart  filter_bar.dart
                                      map_controls.dart  spot_detail_sheet.dart
  nearby/      presentation/ nearby_sheet.dart  nearby_controller.dart
  navigation/  navigation_launcher.dart
  sync/        data/ sync_api.dart  sync_service.dart  sync_state_store.dart
               domain/ merge_rules.dart
  backup/      backup_service.dart  backup_format.dart
  settings/    presentation/ settings_screen.dart  settings_controller.dart
test/          # cermin struktur lib/, fokus pada domain murni
```

Aturan: `presentation` boleh bergantung ke `domain` dan `data` fitur sendiri lewat provider; `domain` tidak bergantung ke Flutter atau drift; `core/` tidak bergantung ke `features/`.

### backend

```
go.mod                          # wajib di root backend/ (Vercel membaca versi Go dari sini)
main.go                         # rakit dependency, router, listen di $PORT (entry Vercel)
vercel.json                     # {"framework":"go","regions":["sin1"]}
.env.example
cmd/migrate/main.go             # jalankan migrasi (pakai DATABASE_URL_DIRECT)
migrations/ embed.go  0001_init.sql
internal/
  config/ config.go
  db/ pool.go
  httpx/ errors.go  response.go  middleware.go  bind.go
  auth/ handler.go  service.go  repository.go  password.go  tokens.go  model.go
  sync/ handler.go  service.go  repository.go  model.go  validate.go
```

Vercel (sesuai dokumentasi Go runtime Vercel, diperiksa Okt 2026):

- Go runtime di Vercel berstatus **Beta**, tersedia di semua paket. Framework Preset `go` mendeteksi `go.mod` di root project dan entry `main.go` (atau `cmd/api/main.go`, `cmd/server/main.go`). Dipakai `main.go` di root `backend/`.
- Project Settings -> Root Directory = `backend`, sehingga `go.mod` berada di root project. Set juga `"framework": "go"` di `vercel.json` (atau Framework Preset = Go di dashboard).
- Server **wajib listen di environment variable `PORT`** (fallback `3000` untuk lokal), mis. `r.Run(":" + port)`. Jangan hard-code port.
- Versi Go dibaca dari direktif `go` di `go.mod` (direktif `toolchain`, bila ada, diprioritaskan). Commit `go.sum`.
- `cmd/migrate/` bukan entry yang dideteksi Vercel, jadi aman berdampingan dengan `main.go`.
- Region default fungsi untuk project baru adalah `iad1` (Washington, D.C.), **harus diubah** ke `sin1` (Singapura) lewat `vercel.json` atau Settings -> Functions -> Function Regions. Paket Hobby hanya satu region, cukup untuk kebutuhan ini. Neon dibuat di Singapura (`aws-ap-southeast-1`).
- Fitur Go runtime ini masih Beta; jika deploy gagal, baca dokumentasi Go runtime Vercel dan jangan mengubah struktur proyek sebelum itu.

## 4. Skema data

Waktu selalu disimpan UTC. Semua ID UUID dibuat di klien (`id` spot dan order); `users.id` dibuat server.

### PostgreSQL (`migrations/0001_init.sql`)

```sql
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id  uuid NOT NULL,
  token_hash text NOT NULL UNIQUE,            -- sha256 hex dari token mentah
  expires_at timestamptz NOT NULL,
  rotated_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_user_idx   ON refresh_tokens (user_id);

CREATE SEQUENCE sync_seq;

CREATE TABLE spots (
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id               uuid NOT NULL,
  name             text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80),
  category         text NOT NULL CHECK (category IN ('shopeefood','spx')),
  latitude         double precision NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
  longitude        double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  notes            text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 500),
  peak_hours       jsonb NOT NULL DEFAULT '[]',
  last_verified_at timestamptz,
  created_at       timestamptz NOT NULL,
  updated_at       timestamptz NOT NULL,
  deleted_at       timestamptz,
  seq              bigint NOT NULL DEFAULT nextval('sync_seq'),
  PRIMARY KEY (user_id, id)
);
CREATE INDEX spots_user_seq_idx ON spots (user_id, seq);

CREATE TABLE orders (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id         uuid NOT NULL,
  spot_id    uuid NOT NULL,                   -- tanpa FK: urutan tiba di batch tidak dijamin
  ordered_at timestamptz NOT NULL,
  local_dow  smallint NOT NULL CHECK (local_dow  BETWEEN 1 AND 7),   -- 1=Senin ... 7=Minggu
  local_hour smallint NOT NULL CHECK (local_hour BETWEEN 0 AND 23),  -- jam lokal saat dicatat
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  deleted_at timestamptz,
  seq        bigint NOT NULL DEFAULT nextval('sync_seq'),
  PRIMARY KEY (user_id, id)
);
CREATE INDEX orders_user_seq_idx ON orders (user_id, seq);
```

`peak_hours` (JSON), menit sejak tengah malam, hari ISO (1=Senin..7=Minggu), `end <= start` berarti melewati tengah malam:

```json
[{"days":[1,2,3,4,5],"start":660,"end":840},{"days":[1,2,3,4,5,6,7],"start":1320,"end":120}]
```

`local_dow` dan `local_hour` dihitung klien saat mencatat (zona waktu perangkat) agar agregasi cukup `GROUP BY`.

### SQLite lokal (drift)

Tabel `spots` dan `orders` memakai kolom yang sama dengan Postgres (tanpa `user_id` dan `seq`), ditambah:

- `dirty` (bool): ada perubahan lokal yang belum terkirim.
- `peak_hours` disimpan sebagai teks JSON lewat `TypeConverter` ke `List<PeakRange>`.

Tabel `sync_meta` (key/value): `cursor_spots`, `cursor_orders`, `last_sync_at`.

Indeks: `spots(deleted_at)`, `spots(dirty)`, `orders(spot_id, ordered_at)`, `orders(dirty)`, `orders(local_dow, local_hour)`.

Query ke UI selalu menyaring `deleted_at IS NULL`.

## 5. Logika inti (fungsi murni, wajib diuji)

### Haversine (`core/geo/haversine.dart`)

Jarak garis lurus dalam km, radius bumi 6371. Format tampilan di `distance_format.dart`.

### Jenis hari (`core/time/day_type.dart`)

`weekday` untuk `local_dow` 1-5, `weekend` untuk 6-7.

### Jam ramai (`features/peak/`)

Konstanta: `peakWindowDays = 90`, `peakMinOrders = 3`, `peakThresholdRatio = 0.6`.

1. **Index** (`PeakIndex`): satu query SQL mengambil jumlah order per `(spot_id, local_hour)` untuk tiap jenis hari dalam 90 hari terakhir:
   ```sql
   SELECT spot_id, local_hour, COUNT(*) AS cnt
   FROM orders
   WHERE deleted_at IS NULL AND ordered_at >= :since AND local_dow BETWEEN :dowMin AND :dowMax
   GROUP BY spot_id, local_hour;
   ```
   Dijalankan dua kali (hari kerja dan akhir pekan). Hasil: `Map<DayType, Map<spotId, Set<int hour>>>` berisi jam yang lolos (`cnt >= peakMinOrders` dan `cnt >= peakThresholdRatio * max`), plus `Map<spotId, Map<hour, int>>` untuk pengurutan "Order jam ini".
2. **`isPeakAt(spot, DateTime t)`**: jenis hari dari `t`. Jika index punya jam lolos untuk spot itu pada jenis hari tersebut, ramai bila `t.hour` ada di himpunan. Jika tidak, cek rentang manual `spot.peakHours`.
3. **`effectiveRanges(spot, DayType)`**: jam lolos digabung jadi rentang berurutan (untuk teks "11:00-13:00"); jika kosong, rentang manual yang mencakup jenis hari itu.
4. Index di-cache di provider dan dibangun ulang hanya saat: order ditambah/dihapus/di-pull dari sync, atau tanggal berganti. Ramai sekarang dan "30 mnt lagi" memakai `Clock` yang bisa diganti saat tes.

### Filter (`features/map/domain/map_filter.dart`)

`MapFilter { Set<Category> categories; PeakMode peakMode (off|now|in30) }`. Fungsi murni `List<Spot> apply(List<Spot>, MapFilter, PeakIndex, DateTime now)`.

### Spot terdekat

Haversine ke semua spot terfilter, saring `<= radius`, urutkan. Untuk ribuan spot cukup hitung langsung; saring kotak kasar dulu bila perlu. Diperbarui saat posisi bergeser >= 50 m atau saat sheet dibuka.

## 6. Peta

- URL tile terang: `https://basemaps.cartocdn.com/rastertiles/light_all/{z}/{x}/{y}{r}.png?key=$CARTO_API_KEY`
- Tile gelap: sama dengan `dark_all`.
- Kunci CARTO diberikan lewat `--dart-define=CARTO_API_KEY=...` (gratis, daftar di carto.com/basemaps/apikey). Jangan di-commit.
- Pengembangan tanpa kunci boleh memakai tile standar OSM secara ringan, tidak untuk rilis.
- Atribusi wajib terlihat dan mencolok (lihat `DESIGN.md`); CARTO dapat menangguhkan key jika atribusi tidak ada.
- **Aturan CARTO soal penyimpanan tile** (syarat penggunaan basemap, diperiksa Okt 2026): tile tidak boleh disimpan di perangkat lebih dari 30 hari, dilarang mengunduh massal (bulk), dan dilarang proxy/cache di sisi server. Karena itu:
  - Hanya cache pasif bawaan `flutter_map`; tanpa unduh area.
  - Batasi masa segar tile maksimal 14 hari lewat `overrideFreshAge` dan kecilkan `maxCacheSize` (mis. 200 MB; cek satuannya di dokumentasi).
  - Jangan mengandalkan kedaluwarsa saja: catat tanggal pembersihan terakhir di `shared_preferences`, dan jika sudah lebih dari 21 hari, hapus seluruh cache tile (`deleteCache: true`) saat aplikasi dibuka. Periksa pada T-08 apakah tile basi memang dibuang oleh provider; bila ya, pembersihan berkala tetap dipertahankan sebagai pengaman.
  - Akibat yang disengaja: area yang tidak dilihat dalam beberapa minggu terakhir tampil kosong saat offline. Spot dan marker tetap tampil karena berasal dari SQLite.
- Layer terpisah: `TileLayer`, `SpotMarkersLayer` (hanya marker di viewport + padding, cluster saat zoom < 15, label saat zoom >= 15), `GpsLayer`. Event kamera di-debounce sebelum menghitung viewport.
- Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`; `<queries>` untuk skema `https` dan `google.navigation` agar `url_launcher` dapat membuka aplikasi.
- GPS: `LocationSettings(accuracy: high, distanceFilter: 10)`. Posisi awal dari `getLastKnownPosition`.

## 7. Navigasi eksternal

- Google Maps (default): `google.navigation:q={lat},{lng}&mode=l` (mode motor). Cadangan: `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}&travelmode=two-wheeler`.
- Waze: `https://waze.com/ul?ll={lat},{lng}&navigate=yes`.
- Buka dengan `LaunchMode.externalApplication`; jika gagal, coba cadangan; jika masih gagal, snackbar singkat.

## 8. Sinkronisasi

### Pemicu

Aplikasi dibuka, kembali aktif (resume), perubahan lokal (debounce 3 detik), koneksi kembali, tombol manual. `SyncService` berjalan satu per satu (single-flight); pemicu saat sedang jalan diabaikan atau dijadwalkan sekali setelah selesai.

### Alur klien

```
loop:
  dirtySpots  = ambil sampai 200 baris spots dirty
  dirtyOrders = ambil sampai 200 baris orders dirty
  resp = POST /v1/sync {cursors, spots, orders}
  terapkan resp.spots / resp.orders ke SQLite (aturan merge)
  tandai baris yang dikirim sebagai bersih jika updated_at-nya belum berubah sejak dikirim
  simpan resp.cursors
  berhenti jika tidak ada dirty tersisa dan resp.has_more == false
```

### Aturan merge (`merge_rules.dart`, fungsi murni)

Untuk baris dari server `s` dan baris lokal `l` dengan ID sama:

- `l` tidak ada: sisipkan `s` (bersih).
- `s.updated_at > l.updated_at`: timpa dengan `s` (bersih).
- `s.updated_at <= l.updated_at` dan `l.dirty`: pertahankan `l` (akan dikirim).
- selain itu: pertahankan `l`.

Penghapusan = `deleted_at` terisi (soft delete) dan diperlakukan sebagai pembaruan biasa.

### Aturan server

Upsert massal per tabel dalam satu transaksi (`unnest`):

```sql
INSERT INTO spots (user_id, id, name, ..., updated_at, deleted_at)
SELECT $1, * FROM unnest($2::uuid[], $3::text[], ...)
ON CONFLICT (user_id, id) DO UPDATE
SET name = EXCLUDED.name, ..., updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at,
    seq = nextval('sync_seq')
WHERE spots.updated_at < EXCLUDED.updated_at;
```

Pull: `WHERE user_id = $1 AND seq > $cursor ORDER BY seq LIMIT 500`, per tabel, dengan kursor sendiri. `has_more` bernilai true jika salah satu tabel penuh.

## 9. Autentikasi

- **Access token:** JWT HS256, klaim `sub` (user id), `iat`, `exp`. Umur 15 menit.
- **Refresh token:** 32 byte acak (`crypto/rand`), base64url. Di database hanya `sha256` hex. Umur 30 hari.
- **Rotasi saat `POST /v1/auth/refresh`** (dalam satu transaksi, baris dikunci `FOR UPDATE`):
  1. Hash token masuk, cari barisnya. Tidak ada -> `invalid_refresh`.
  2. `revoked_at` terisi atau `expires_at` lewat -> `invalid_refresh`.
  3. `rotated_at` kosong -> normal: set `rotated_at = now()`, buat token baru satu `family_id`, kembalikan pasangan baru.
  4. `rotated_at` terisi: jika `now() - rotated_at <= REFRESH_GRACE` (default 60 detik, untuk kasus respons hilang karena sinyal putus) -> buat token baru lagi di family yang sama, tanpa mencabut. Jika lewat grace -> cabut seluruh family (`revoked_at = now()` untuk semua baris `family_id`) dan kembalikan `reuse_detected`.
- **Logout:** cabut seluruh family dari token yang dikirim.
- **Login:** `bcrypt` (cost dari env, default 12), pesan error selalu `invalid_credentials`. Email dinormalisasi lowercase.
- **Registrasi:** hanya bila `REGISTRATION_ENABLED=true`.

Klien (Dio):

- Interceptor menambahkan `Authorization: Bearer`. Jika 401 `token_expired`, jalankan refresh **single-flight** (satu `Completer` bersama), lalu ulangi request sekali.
- Tulis refresh token baru ke secure storage **sebelum** memakai access token baru.
- Jika refresh gagal dengan `invalid_refresh`/`reuse_detected`: tandai sesi berakhir, hentikan sync, **jangan hapus data lokal**, tampilkan status di Pengaturan.
- Logout: jika masih ada baris dirty, tampilkan peringatan terlebih dahulu.

## 10. API

Base: `/v1`. JSON, snake_case, waktu RFC 3339 UTC. Body maksimal 1 MB.

| Method | Path | Auth | Fungsi |
|---|---|---|---|
| GET | `/healthz` | tidak | Cek hidup |
| POST | `/v1/auth/register` | tidak | `{email, password}` (min 8 karakter) -> pasangan token |
| POST | `/v1/auth/login` | tidak | `{email, password}` -> pasangan token |
| POST | `/v1/auth/refresh` | tidak | `{refresh_token}` -> pasangan token baru |
| POST | `/v1/auth/logout` | tidak | `{refresh_token}` -> 204 |
| POST | `/v1/sync` | Bearer | Push + pull |

Respons token:

```json
{"access_token":"...","refresh_token":"...","expires_in":900,"user":{"id":"...","email":"..."}}
```

Request sync:

```json
{
  "cursors": {"spots": 0, "orders": 0},
  "spots":  [{"id":"uuid","name":"...","category":"shopeefood","latitude":-7.0,"longitude":113.4,
              "notes":"","peak_hours":[],"last_verified_at":null,
              "created_at":"...","updated_at":"...","deleted_at":null}],
  "orders": [{"id":"uuid","spot_id":"uuid","ordered_at":"...","local_dow":3,"local_hour":12,
              "created_at":"...","updated_at":"...","deleted_at":null}]
}
```

Respons sync: `{"cursors":{"spots":N,"orders":N},"spots":[... + "seq"],"orders":[... + "seq"],"has_more":false,"server_time":"..."}`.

Batas: push maks 200 baris per tabel per request, pull maks 500 per tabel.

Validasi server: UUID valid; `name` 1-80; `category` salah satu dari dua nilai; koordinat dalam rentang; `notes` <= 500; `peak_hours` maks 20 rentang dengan `days` 1-7 dan `start`/`end` 0-1439; `local_dow` 1-7; `local_hour` 0-23; `updated_at` tidak lebih dari 1 hari di masa depan.

Format error:

```json
{"error":{"code":"invalid_credentials","message":"Email atau kata sandi salah."}}
```

| Kode | HTTP |
|---|---|
| `validation_failed` | 400 |
| `invalid_credentials`, `invalid_token`, `token_expired`, `invalid_refresh`, `reuse_detected` | 401 |
| `registration_disabled` | 403 |
| `email_taken` | 409 |
| `payload_too_large` | 413 |
| `internal` | 500 |

## 11. Format berkas ekspor/impor

```json
{
  "app": "spotshopee",
  "version": 1,
  "exported_at": "2026-10-03T12:00:00Z",
  "spots":  [ /* bentuk sama dengan sync, tanpa seq, tanpa baris terhapus */ ],
  "orders": [ /* kosong bila ekspor "hanya spot" */ ]
}
```

Impor: validasi `app` dan `version`; gabungkan per ID dengan aturan `merge_rules` (baris impor diperlakukan seperti baris dari server, hasilnya ditandai `dirty = true` agar ikut tersinkron); order yang `spot_id`-nya tidak ada diabaikan dan dihitung di ringkasan.

## 12. Konfigurasi

### Backend (`.env.example`)

```
APP_ENV=development
PORT=3000
DATABASE_URL=            # Neon pooled
DATABASE_URL_DIRECT=     # Neon direct, hanya untuk cmd/migrate
JWT_SECRET=              # minimal 32 byte acak
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=720h
REFRESH_GRACE=60s
BCRYPT_COST=12
REGISTRATION_ENABLED=true
```

Koneksi pooled Neon (PgBouncer): set `default_query_exec_mode=cache_describe` pada konfigurasi pgx agar kompatibel; verifikasi saat integrasi pertama. `pgxpool`: `MaxConns` 4, `MinConns` 0, dibuat sekali di `main`.

Set `REGISTRATION_ENABLED=false` setelah akun pribadi dibuat.

### Mobile

`--dart-define=API_BASE_URL=https://<project>.vercel.app --dart-define=CARTO_API_KEY=...`, dibaca lewat `core/config/env.dart`.

## 13. Pengujian

Fokus pada logika murni. Tidak perlu uji UI luas.

Flutter (`mobile/test/`): `haversine`, `distance_format`, `day_type`, `peak_calculator`/`peak_index` (termasuk fallback manual dan rentang lewat tengah malam), `map_filter`, `merge_rules`, `clustering` (jika dibuat), `backup_format` (impor/ekspor dan gabung).

Go: `password`, `tokens` (JWT), logika rotasi refresh token memakai repository palsu (kasus: normal, dalam grace, di luar grace, kedaluwarsa, dicabut), `validate.go` untuk sync.

## 14. Rilis

- Mobile: `flutter build apk --release --split-per-abi --dart-define=...`.
- Backend: Vercel (Root Directory `backend`), env di dashboard, region `sin1`. Migrasi dijalankan lokal: `go run ./cmd/migrate up` dengan `DATABASE_URL_DIRECT`.

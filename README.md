# RMR CMS - Flutter + Supabase + Strava OAuth

Aplikasi Flutter mobile yang terintegrasi dengan Supabase dan Strava OAuth untuk manajemen aktivitas olahraga dan event.

## Fitur

- ✅ Login menggunakan Strava OAuth
- ✅ Simpan user ke Supabase (profile + tokens)
- ✅ Sinkronisasi aktivitas Strava ke tabel activities
- ✅ Event/pendaftaran sederhana: events + registrations (kuota)
- ✅ RLS (Row Level Security) dengan development-friendly policies
- ✅ UI lengkap: LoginPage, Dashboard (activities), EventsList, EventDetail + Daftar tombol

## Struktur Project

```
lib/
├── config/
│   └── app_config.dart          # Konfigurasi app (Supabase & Strava credentials)
├── models/
│   ├── user.dart                # Model User
│   ├── activity.dart            # Model Activity
│   └── event.dart               # Model Event & Registration
├── services/
│   ├── supabase_service.dart    # Service untuk operasi Supabase
│   └── strava_auth_service.dart # Service untuk OAuth Strava & sync activities
├── screens/
│   ├── login_page.dart          # Halaman login dengan Strava
│   ├── dashboard_page.dart      # Dashboard menampilkan activities
│   ├── events_page.dart         # Daftar events
│   └── event_detail.dart        # Detail event + tombol daftar
├── widgets/
│   ├── activity_card.dart       # Card untuk menampilkan activity
│   └── event_card.dart          # Card untuk menampilkan event
└── main.dart                    # Entry point aplikasi
```

## Setup Step-by-Step

### 1. Setup Supabase

1. Buat project baru di [Supabase](https://supabase.com)
2. Buka SQL Editor di dashboard Supabase
3. Copy seluruh isi file `supabase_migration.sql` dan paste ke SQL Editor
4. Jalankan script tersebut (klik Run)
5. Setelah selesai, ambil:
   - **Project URL** (dari Settings > API)
   - **anon/public key** (dari Settings > API)

### 2. Setup Strava App

1. Login ke [Strava](https://www.strava.com)
2. Buka [My API Application](https://www.strava.com/settings/api)
3. Klik "Create App" atau gunakan aplikasi yang sudah ada
4. Isi form:
   - **Application Name**: RMR CMS (atau nama lain)
   - **Category**: Website
   - **Website**: `https://yourwebsite.com` (bisa dummy)
   - **Authorization Callback Domain**: `com.example.rmr_cms` (untuk mobile)
   - **Application Description**: (opsional)
5. Setelah dibuat, catat:
   - **Client ID**
   - **Client Secret**

### 3. Konfigurasi Flutter App

#### 3.1. Install Dependencies

```bash
flutter pub get
```

#### 3.2. Update Konfigurasi

Edit file `lib/main.dart` dan ganti:

```dart
// Ganti dengan Supabase URL dan anon key Anda
await SupabaseService().initialize(
  url: 'YOUR_SUPABASE_URL',        // Contoh: https://xxxxx.supabase.co
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);

// Ganti dengan Strava credentials Anda
StravaAuthService().configure(
  clientId: 'YOUR_STRAVA_CLIENT_ID',
  clientSecret: 'YOUR_STRAVA_CLIENT_SECRET',
  redirectUri: 'com.example.rmr_cms://callback',
);
```

#### 3.3. Konfigurasi Android (untuk OAuth redirect)

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  ...
  <application>
    ...
    <!-- Tambahkan activity untuk OAuth redirect -->
    <activity
      android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
      android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.example.rmr_cms" />
      </intent-filter>
    </activity>
  </application>
</manifest>
```

#### 3.4. Konfigurasi iOS (untuk OAuth redirect)

Edit `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.rmr_cms</string>
    </array>
  </dict>
</array>
```

### 4. Jalankan Aplikasi

```bash
flutter run
```

## Cara Menggunakan

### Login dengan Strava

1. Buka aplikasi
2. Klik tombol "Login with Strava"
3. Browser akan terbuka untuk autentikasi Strava
4. Setelah login, aplikasi akan:
   - Menyimpan user ke Supabase
   - Sinkronisasi aktivitas Strava ke database
   - Redirect ke Dashboard

### Dashboard

- Menampilkan daftar aktivitas dari Strava
- Pull-to-refresh untuk update data
- Tombol Events untuk melihat daftar event

### Events

- Lihat daftar event yang tersedia
- Filter untuk menampilkan hanya event aktif
- Klik event untuk melihat detail dan mendaftar

### Event Detail

- Lihat informasi lengkap event
- Cek kuota dan sisa slot
- Klik "Daftar" untuk mendaftar event
- Klik "Unregister" untuk membatalkan pendaftaran

## Database Schema

### Tabel: users
- `id` (UUID, Primary Key)
- `strava_id` (BIGINT, Unique)
- `username`, `firstname`, `lastname`
- `profile_picture`
- `access_token`, `refresh_token`, `token_expires`
- `role`, `created_at`, `updated_at`

### Tabel: activities
- `id` (UUID, Primary Key)
- `user_id` (UUID, Foreign Key → users)
- `strava_activity_id` (BIGINT, Unique)
- `name`, `distance`, `moving_time`, `elapsed_time`, `type`
- `start_date`, `map_polyline`
- `created_at`

### Tabel: events
- `id` (UUID, Primary Key)
- `title`, `description`
- `quota` (INTEGER)
- `created_by` (UUID, Foreign Key → users)
- `is_active` (BOOLEAN)
- `created_at`, `updated_at`

### Tabel: registrations
- `id` (UUID, Primary Key)
- `event_id` (UUID, Foreign Key → events)
- `user_id` (UUID, Foreign Key → users)
- `registered_at`
- Unique constraint: (event_id, user_id)

### View: event_stats
View yang menampilkan statistik event termasuk total_registered dan remaining_quota.

## RLS Policies

**PENTING**: Script SQL menggunakan development-friendly policies (`USING true` / `WITH CHECK true`) yang membolehkan semua operasi. 

**Untuk production**, ubah policies di Supabase SQL Editor sesuai kebutuhan keamanan Anda, contoh:

```sql
-- Contoh policy untuk production
CREATE POLICY "Users can only see their own data" 
ON users FOR SELECT 
USING (auth.uid() = id);
```

## Troubleshooting

### OAuth redirect tidak bekerja
- Pastikan `redirectUri` di Flutter sama dengan yang diatur di Strava
- Pastikan AndroidManifest.xml dan Info.plist sudah dikonfigurasi dengan benar
- Untuk Android, pastikan `android:scheme` sesuai dengan redirectUri

### Error "Strava OAuth not configured"
- Pastikan `StravaAuthService().configure()` dipanggil di `main.dart` sebelum digunakan

### Error koneksi ke Supabase
- Pastikan Supabase URL dan anon key sudah benar
- Pastikan project Supabase sudah aktif
- Cek apakah RLS policies sudah dibuat dengan benar

### Activities tidak tersinkronisasi
- Pastikan access_token masih valid
- Cek apakah user sudah login dengan Strava
- Pastikan scope OAuth termasuk `activity:read`

## Dependencies

- `supabase_flutter`: ^2.0.0 - Client Supabase untuk Flutter
- `flutter_web_auth_2`: ^2.0.0 - OAuth flow untuk mobile
- `http`: ^1.1.0 - HTTP requests ke Strava API
- `provider`: ^6.1.1 - State management
- `intl`: ^0.19.0 - Formatting tanggal

## Catatan Penting

1. **Security**: Jangan commit credentials ke repository. Gunakan environment variables atau secure storage untuk production.

2. **Token Refresh**: Implementasi refresh token sudah ada di `StravaAuthService`, tapi perlu ditambahkan logic untuk auto-refresh sebelum token expired.

3. **Rate Limiting**: Strava API memiliki rate limit. Pastikan tidak melakukan terlalu banyak request dalam waktu singkat.

4. **Production RLS**: Pastikan untuk mengubah RLS policies sebelum deploy ke production.

## Support

Jika ada pertanyaan atau masalah, silakan buat issue di repository ini.

---

**SELESAI – Semua komponen untuk Flutter + Supabase + Strava OAuth sudah dibuat.**


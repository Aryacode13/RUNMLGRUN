# Cara Request Quota Increase di Strava

## Masalah Saat Ini
- **Number of athletes allowed to connect: 1** ← Ini masalahnya!
- **Number of athletes currently connected: 1** ← Sudah tercapai
- Tidak bisa login dengan akun kedua karena quota hanya 1

## Solusi: Request Quota Increase

### Cara 1: Via Email (Recommended)

**Email:** developers@strava.com

**Subject:** Request Quota Increase for API Application

**Isi Email:**
```
Subject: Request Quota Increase for API Application

Dear Strava Developer Support,

I am requesting a quota increase for my Strava API application.

Application Details:
- Application Name: Run Malang Run (RMR CMS)
- Client ID: [YOUR_CLIENT_ID]
- Current Quota: 1 athlete
- Requested Quota: [sebutkan jumlah, misalnya 100 atau 200]

Use Case:
Run Malang Run is a mobile application designed to facilitate runners in registering for running events in Malang city. The application uses Strava OAuth for user authentication and profile synchronization. We need to support multiple users (athletes) to register for events.

Expected Usage:
- Estimated number of users: [sebutkan jumlah]
- Application is for production use
- Users will use Strava OAuth to login and sync their activity data

Thank you for your consideration.

Best regards,
[Your Name]
[Your Email]
```

### Cara 2: Via Strava Website

1. **Login ke:** https://www.strava.com/settings/api
2. **Edit aplikasi** "Run Malang Run"
3. **Cari opsi** "Request Quota Increase" atau "Contact Support"
4. **Isi form** dengan informasi yang sama seperti di email
5. **Submit request**

### Cara 3: Via Strava Developer Portal

1. **Buka:** https://www.strava.com/settings/api
2. **Scroll ke bawah** atau cari bagian "Support" atau "Help"
3. **Klik** "Contact Developer Support" atau link serupa
4. **Isi form** request quota increase

## Informasi yang Perlu Disertakan

1. **Client ID aplikasi** (bisa dilihat di halaman API settings)
2. **Nama aplikasi:** Run Malang Run
3. **Use case:** Jelaskan tujuan aplikasi
4. **Estimasi jumlah user:** Berapa banyak athlete yang akan menggunakan aplikasi
5. **Alasan:** Mengapa perlu quota lebih besar

## Tips untuk Request yang Berhasil

1. **Jelaskan use case dengan jelas**
   - Aplikasi untuk event registration
   - Menggunakan Strava OAuth untuk authentication
   - Perlu support multiple users

2. **Sebutkan estimasi jumlah user**
   - Misalnya: "We expect 50-100 users in the first month"
   - Atau: "We need to support at least 50 concurrent users"

3. **Jelaskan manfaat untuk komunitas Strava**
   - Aplikasi membantu komunitas running di Malang
   - Integrasi dengan Strava meningkatkan engagement
   - Event registration yang lebih mudah

4. **Siapkan dokumentasi**
   - Screenshot aplikasi (jika ada)
   - Penjelasan fitur utama
   - Roadmap pengembangan

## Alternatif Sementara

Sementara menunggu approval dari Strava:

1. **Hapus koneksi yang tidak aktif**
   - Jika ada koneksi test, hapus dulu
   - Gunakan hanya untuk user production

2. **Gunakan aplikasi terpisah untuk testing**
   - Buat aplikasi Strava baru untuk development/testing
   - Gunakan aplikasi production hanya untuk user real

3. **Monitor quota usage**
   - Cek secara berkala di API settings
   - Pastikan tidak melebihi quota

## Catatan Penting

- **Quota increase tidak otomatis** - perlu approval dari Strava
- **Response time:** Biasanya 1-3 hari kerja
- **Beberapa request mungkin ditolak** - pastikan use case jelas
- **Quota bisa ditingkatkan bertahap** - mulai dari request kecil dulu

## Setelah Request Diterima

1. **Cek email** untuk konfirmasi dari Strava
2. **Login ke API settings** untuk melihat quota baru
3. **Test login** dengan akun kedua untuk verifikasi
4. **Monitor usage** untuk memastikan tidak melebihi quota baru


















# 🔧 Troubleshooting: Failed to Send Notification

## ❌ Error yang Terjadi:
"Failed to send notification. Please try again."

## 🔍 Kemungkinan Penyebab:

### 1. Tabel `notifications` Belum Ada
**Gejala:** Error saat insert ke database

**Solusi:**
- Buka Supabase Dashboard → SQL Editor
- Jalankan SQL migration untuk tabel `notifications`
- File: `create_notifications_table_migration.sql`

### 2. Tabel `user_fcm_tokens` Belum Ada
**Gejala:** Edge Function error "Could not find table user_fcm_tokens"

**Solusi:**
- Buka Supabase Dashboard → SQL Editor
- Jalankan SQL migration untuk tabel `user_fcm_tokens`
- File: `create_user_fcm_tokens_table.sql`

### 3. Edge Function Error
**Gejala:** Error saat memanggil Edge Function

**Cek:**
- Buka Supabase Dashboard → Edge Functions → `send-fcm-notification` → Logs
- Lihat error message di logs

**Solusi:**
- Pastikan FCM Server Key sudah di-set: `supabase secrets set FCM_SERVER_KEY=...`
- Pastikan Edge Function sudah ter-deploy: `supabase functions deploy send-fcm-notification`

### 4. RLS Policy Error
**Gejala:** Error "new row violates row-level security policy"

**Solusi:**
- Cek RLS policies di Supabase Dashboard → Authentication → Policies
- Pastikan admin bisa insert ke tabel `notifications`

### 5. FCM Server Key Tidak Valid
**Gejala:** Edge Function error "FCM_SERVER_KEY not configured" atau "401 Unauthorized"

**Solusi:**
- Pastikan API key sudah di-set sebagai secret
- Cek apakah API key sudah di-restrict ke "Cloud Messaging API" di Google Cloud Console

## 🔍 Cara Debug:

### 1. Cek Console Logs
Sekarang error message akan menampilkan detail error. Cek:
- Flutter console untuk error details
- Supabase Edge Function logs

### 2. Cek Database
- Buka Supabase Dashboard → Table Editor
- Cek apakah tabel `notifications` dan `user_fcm_tokens` sudah ada
- Cek apakah ada data di tabel tersebut

### 3. Test Edge Function Manual
```bash
# Test Edge Function
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-fcm-notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "USER_ID_HERE",
    "title": "Test",
    "message": "Test message"
  }'
```

## ✅ Checklist:

- [ ] Tabel `notifications` sudah dibuat
- [ ] Tabel `user_fcm_tokens` sudah dibuat
- [ ] Edge Function sudah ter-deploy
- [ ] FCM Server Key sudah di-set sebagai secret
- [ ] RLS policies sudah benar
- [ ] User sudah login dan FCM token tersimpan

## 📝 Next Steps:

1. **Cek error message detail** di console/logs
2. **Jalankan SQL migrations** jika belum
3. **Cek Edge Function logs** di Supabase Dashboard
4. **Test lagi** setelah fix

---

**Setelah memperbaiki error handling, error message sekarang akan menampilkan detail error yang lebih informatif!**












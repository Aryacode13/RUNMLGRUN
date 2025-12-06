# Set FCM Server Key - Langkah Cepat

## API Key Anda
```
AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso
```

---

## Langkah 1: Set di Supabase Secrets

### Via Supabase Dashboard (RECOMMENDED)

1. **Buka Supabase Dashboard**
   - https://supabase.com/dashboard/project/icphxtjmdmwesduxkxvx

2. **Edge Functions** → **Secrets**

3. **Klik "New secret"** (atau edit yang sudah ada jika `FCM_SERVER_KEY` sudah ada)

4. **Isi form:**
   - **Name:** `FCM_SERVER_KEY`
   - **Value:** `AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso`
   - **Description (optional):** `FCM Server Key for push notifications`

5. **Klik "Save"** atau **"Add secret"**

### Via Supabase CLI (Alternatif)

Jika Anda punya Supabase CLI:
```bash
supabase secrets set FCM_SERVER_KEY=AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso
```

---

## Langkah 2: Redeploy Edge Function

**PENTING:** Setelah set secret, HARUS redeploy Edge Function!

### Via Supabase Dashboard

1. **Edge Functions** → `send-fcm-notification`
2. Klik **"Redeploy"** atau **"Deploy"**
3. Tunggu sampai deploy selesai

### Via Supabase CLI

```bash
supabase functions deploy send-fcm-notification
```

---

## Langkah 3: Verifikasi di Google Cloud Console

**Pastikan API Key sudah di-restrict ke Cloud Messaging API:**

1. **Buka Google Cloud Console**
   - https://console.cloud.google.com/

2. **Pilih project:** `run-malang-run`

3. **APIs & Services** → **Credentials**

4. **Cari API Key:** `AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso`

5. **Klik API Key** → **Edit**

6. **Cek "API restrictions":**
   - Harus **"Restrict key"**
   - Harus ada **"Cloud Messaging API"** di list

7. **Jika belum:**
   - Pilih **"Restrict key"**
   - Di **"Select APIs"**, cari dan pilih **"Cloud Messaging API"**
   - **Save**

---

## Langkah 4: Test

1. **Buka app** → Login
2. **Tutup app sepenuhnya** (swipe away)
3. **Kirim notifikasi dari admin dashboard**
4. **Cek Edge Function logs:**
   - Supabase Dashboard → Edge Functions → `send-fcm-notification` → Logs
   - Harus ada log:
     ```
     FCM Response status: 200
     FCM success for user ...
     ```
   - **TIDAK boleh ada error 404 lagi!**

5. **Cek device:**
   - Notification harus muncul di status bar
   - Notification bisa di-tap dan buka app

---

## Checklist

### ✅ Checklist 1: Supabase Secrets
- [ ] Buka Supabase Dashboard → Edge Functions → Secrets
- [ ] `FCM_SERVER_KEY` sudah ada
- [ ] Value = `AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso`
- [ ] Tidak kosong

### ✅ Checklist 2: Edge Function
- [ ] Edge Function sudah di-redeploy
- [ ] Status = Active
- [ ] Tidak ada error di logs

### ✅ Checklist 3: Google Cloud Console
- [ ] API Key `AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso` ada
- [ ] API restrictions = Cloud Messaging API
- [ ] Status = Enabled

### ✅ Checklist 4: Test
- [ ] Kirim notifikasi dari admin
- [ ] Edge Function logs → status 200 (bukan 404)
- [ ] Notification muncul di device

---

## Troubleshooting

### Masalah 1: Masih Error 404

**Cek:**
1. Apakah secret sudah di-set? → Supabase Dashboard → Secrets
2. Apakah Edge Function sudah di-redeploy? → Redeploy lagi
3. Apakah API Key valid? → Cek di Google Cloud Console

### Masalah 2: Error 401 Unauthorized

**Artinya:** API Key tidak valid atau tidak di-restrict ke Cloud Messaging API

**Solusi:**
- Cek di Google Cloud Console
- Pastikan API restrictions = Cloud Messaging API
- Pastikan API Key tidak expired

### Masalah 3: Secret Tidak Ter-load

**Gejala:** Error "FCM_SERVER_KEY not configured"

**Solusi:**
- Pastikan secret name = `FCM_SERVER_KEY` (case-sensitive)
- Redeploy Edge Function setelah set secret
- Cek di Supabase Dashboard → Secrets

---

## Catatan Penting

1. **Set Secret HARUS diikuti Redeploy**
   - Set secret saja tidak cukup
   - Edge Function perlu di-redeploy untuk load secret baru

2. **API Key Harus Di-Restrict**
   - Untuk security, restrict API Key ke "Cloud Messaging API" saja
   - Jangan biarkan "Don't restrict key"

3. **Test Setelah Set Secret**
   - Set secret → Redeploy → Test
   - Cek logs untuk memastikan tidak ada error 404 lagi

---

## Next Steps

1. ✅ **Set secret di Supabase** (Langkah 1)
2. ✅ **Redeploy Edge Function** (Langkah 2)
3. ✅ **Verifikasi API Key** (Langkah 3)
4. ✅ **Test kirim notifikasi** (Langkah 4)

Setelah semua langkah selesai, error 404 harus hilang dan notification harus muncul!









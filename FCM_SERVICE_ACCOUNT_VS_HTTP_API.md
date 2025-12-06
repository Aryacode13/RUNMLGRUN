# FCM: Service Account vs HTTP API - Penjelasan

## 📋 Yang Anda Lihat di Firebase Console

**Service Account:** `firebase-adminsdk-fbsvc@run-malang-run.iam.gserviceaccount.com`
- **Untuk:** Firebase Admin SDK (Node.js)
- **Format:** Service Account JSON file
- **Digunakan untuk:** Server-side Firebase operations di Node.js

---

## ⚠️ Penting: Supabase Edge Function ≠ Node.js

### Supabase Edge Function
- **Runtime:** Deno (TypeScript)
- **TIDAK support:** Firebase Admin SDK (hanya untuk Node.js)
- **Yang kita pakai:** FCM HTTP API dengan Server Key

### Node.js Server
- **Runtime:** Node.js
- **Support:** Firebase Admin SDK
- **Bisa pakai:** Service Account JSON

---

## ✅ Setup Kita Sekarang (SUDAH BENAR)

### Yang Kita Pakai: FCM HTTP API

**File:** `supabase/functions/send-fcm-notification/index.ts`

```typescript
// Pakai HTTP API, BUKAN Admin SDK
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY') || 'AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso'
const FCM_API_URL = 'https://fcm.googleapis.com/fcm/send'

// Send via HTTP POST
const response = await fetch(FCM_API_URL, {
  method: 'POST',
  headers: {
    'Authorization': `key=${FCM_SERVER_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(fcmPayload),
})
```

**Tidak perlu:**
- ❌ Service Account JSON
- ❌ Firebase Admin SDK
- ❌ Node.js setup

**Hanya perlu:**
- ✅ FCM Server Key (API Key)
- ✅ HTTP request ke FCM API

---

## 🔄 Jika Ingin Pakai Service Account

### Opsi 1: Tetap Pakai HTTP API (RECOMMENDED)
- ✅ Sudah setup
- ✅ Lebih sederhana
- ✅ Tidak perlu Service Account
- ✅ Cukup Server Key

### Opsi 2: Pakai FCM V1 API dengan Service Account
- ⚠️ Lebih kompleks
- ⚠️ Perlu generate Access Token dari Service Account
- ⚠️ Perlu library untuk JWT signing di Deno
- ⚠️ Tidak recommended untuk Deno

**Untuk Deno, lebih baik tetap pakai HTTP API (Legacy API) dengan Server Key.**

---

## 📝 Kesimpulan

### Service Account yang Anda Lihat:
- **Untuk:** Node.js applications dengan Firebase Admin SDK
- **Kita pakai?** ❌ TIDAK (karena kita pakai Deno)

### Setup Kita:
- **Platform:** Supabase Edge Function (Deno)
- **Method:** FCM HTTP API dengan Server Key
- **Status:** ✅ SUDAH BENAR

---

## ✅ Yang Perlu Dilakukan

1. **Tetap pakai setup sekarang** (HTTP API dengan Server Key)
2. **Set FCM_SERVER_KEY di Supabase Secrets** (jika belum)
3. **Deploy Edge Function**
4. **Test push notifications**

**TIDAK perlu:**
- ❌ Download Service Account JSON
- ❌ Setup Firebase Admin SDK
- ❌ Ubah ke Node.js

---

**Setup sekarang sudah benar! Service Account tidak diperlukan untuk Supabase Edge Function.**






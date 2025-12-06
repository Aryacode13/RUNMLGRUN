# Send FCM Notification Edge Function

Edge Function untuk mengirim FCM push notifications ke users.

## Setup

### 1. Install Supabase CLI

```bash
npm install -g supabase
```

### 2. Login ke Supabase

```bash
supabase login
```

### 3. Link ke Project

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

### 4. Set FCM Server Key

Dapatkan FCM Server Key dari Firebase Console:
1. Buka Firebase Console → Project Settings
2. Tab "Cloud Messaging"
3. Copy "Server key"

Set sebagai secret:
```bash
supabase secrets set FCM_SERVER_KEY=YOUR_FCM_SERVER_KEY
```

### 5. Deploy Function

```bash
supabase functions deploy send-fcm-notification
```

## Usage

### Dari Flutter App

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendFcmNotification({
  required String userId,
  required String title,
  required String message,
  String? notificationId,
}) async {
  final supabaseUrl = 'YOUR_SUPABASE_URL';
  final supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  final response = await http.post(
    Uri.parse('$supabaseUrl/functions/v1/send-fcm-notification'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $supabaseAnonKey',
    },
    body: jsonEncode({
      'userId': userId,
      'title': title,
      'message': message,
      'notificationId': notificationId,
    }),
  );
  
  if (response.statusCode == 200) {
    print('FCM notification sent successfully');
  } else {
    print('Error: ${response.body}');
  }
}
```

### Send to Multiple Users

```dart
await http.post(
  Uri.parse('$supabaseUrl/functions/v1/send-fcm-notification'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $supabaseAnonKey',
  },
  body: jsonEncode({
    'userIds': ['user-id-1', 'user-id-2', 'user-id-3'],
    'title': 'Notification Title',
    'message': 'Notification Message',
  }),
);
```

## Environment Variables

- `FCM_SERVER_KEY`: Firebase Cloud Messaging Server Key (required)
- `SUPABASE_URL`: Supabase project URL (auto-set)
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service role key (auto-set)

## Response Format

```json
{
  "success": true,
  "sent": 5,
  "failed": 0,
  "total": 5
}
```













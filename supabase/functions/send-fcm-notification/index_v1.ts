// Supabase Edge Function untuk mengirim FCM push notifications (V1 API)
// Deploy dengan: supabase functions deploy send-fcm-notification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Untuk V1 API, kita perlu Service Account JSON
// Tapi untuk sekarang, kita bisa pakai Legacy API endpoint dengan Server Key
// Atau kita bisa pakai V1 API dengan Service Account

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY') || ''
const FCM_LEGACY_API_URL = 'https://fcm.googleapis.com/fcm/send'
const FCM_V1_API_URL = 'https://fcm.googleapis.com/v1/projects/{project_id}/messages:send'

interface FcmRequest {
  userId?: string
  userIds?: string[]
  title: string
  message: string
  notificationId?: string
}

serve(async (req) => {
  try {
    // CORS headers
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    // Check FCM server key
    if (!FCM_SERVER_KEY) {
      return new Response(
        JSON.stringify({ error: 'FCM_SERVER_KEY not configured. Please set it as a secret.' }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    )

    // Parse request body
    const body: FcmRequest = await req.json()
    const { userId, userIds, title, message, notificationId } = body

    // Validate input
    if (!title || !message) {
      return new Response(
        JSON.stringify({ error: 'Title and message are required' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Get target user IDs
    let targetUserIds: string[] = []
    if (userIds && userIds.length > 0) {
      targetUserIds = userIds
    } else if (userId) {
      targetUserIds = [userId]
    } else {
      return new Response(
        JSON.stringify({ error: 'userId or userIds is required' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Get FCM tokens from database
    const { data: tokens, error: tokenError } = await supabaseClient
      .from('user_fcm_tokens')
      .select('fcm_token, user_id')
      .in('user_id', targetUserIds)

    if (tokenError) {
      console.error('Error fetching FCM tokens:', tokenError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch FCM tokens', details: tokenError.message }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0, 
          message: 'No FCM tokens found for target users' 
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Prepare FCM message (Legacy API format)
    // Note: Legacy API masih bisa dipakai meskipun "Disabled" di console
    // Asalkan kita punya Server Key yang valid
    const fcmMessage = {
      notification: {
        title: title,
        body: message,
      },
      data: {
        notification_id: notificationId || '',
        title: title,
        message: message,
      },
      priority: 'high',
    }

    // Send FCM notifications using Legacy API
    // Legacy API endpoint masih berfungsi meskipun status "Disabled"
    const results = await Promise.allSettled(
      tokens.map(async (tokenData) => {
        const fcmPayload = {
          ...fcmMessage,
          to: tokenData.fcm_token,
        }

        const response = await fetch(FCM_LEGACY_API_URL, {
          method: 'POST',
          headers: {
            'Authorization': `key=${FCM_SERVER_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        })

        if (!response.ok) {
          const errorText = await response.text()
          throw new Error(`FCM error: ${response.status} - ${errorText}`)
        }

        return { userId: tokenData.user_id, success: true }
      })
    )

    // Count results
    const sent = results.filter((r) => r.status === 'fulfilled').length
    const failed = results.filter((r) => r.status === 'rejected').length

    // Log errors
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        console.error(`Failed to send to token ${index}:`, result.reason)
      }
    })

    return new Response(
      JSON.stringify({
        success: true,
        sent,
        failed,
        total: tokens.length,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Error in send-fcm-notification:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        details: error instanceof Error ? error.message : String(error) 
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})













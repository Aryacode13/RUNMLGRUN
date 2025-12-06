// Supabase Edge Function untuk mengirim FCM push notifications
// Deploy dengan: supabase functions deploy send-fcm-notification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// FCM Server Key - Get from Supabase Secrets (recommended) or use direct value
// Recommended: Set as secret in Supabase Dashboard → Edge Functions → Secrets
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY') || 'AIzaSyDsKeAVHzCb5vPzDRZ7q9wTILJucwYsvso'
const FCM_API_URL = 'https://fcm.googleapis.com/fcm/send'

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
        JSON.stringify({ error: 'FCM_SERVER_KEY not configured' }),
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
    console.log(`Fetching FCM tokens for ${targetUserIds.length} users:`, targetUserIds)
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

    console.log(`Found ${tokens?.length || 0} FCM tokens for target users`)
    if (tokens && tokens.length > 0) {
      console.log('Token details:', tokens.map(t => ({ userId: t.user_id, token: t.fcm_token?.substring(0, 20) + '...' })))
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0, 
          failed: 0,
          total: 0,
          message: 'No FCM tokens found for target users. Users may not be logged in on any device.' 
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Prepare FCM message
    // For background notifications (app killed), we need both 'notification' and 'data' fields
    const fcmMessage = {
      notification: {
        title: title,
        body: message,
        sound: 'default',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      data: {
        notification_id: notificationId || '',
        title: title,
        message: message,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      priority: 'high',
      content_available: true, // Required for background notifications
    }

    // Send FCM notifications
    const results = await Promise.allSettled(
      tokens.map(async (tokenData) => {
        // For Android background notifications (app killed), we need BOTH 'notification' and 'data' fields
        // The 'notification' field makes Android automatically display the notification
        // The 'data' field is for app to handle when opened
        const fcmPayload: any = {
          to: tokenData.fcm_token,
          // 'notification' field - Android will auto-display this when app is killed
          notification: {
            title: title,
            body: message,
            sound: 'default',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          // 'data' field - for app to process when opened
          data: {
            notification_id: notificationId || '',
            title: title,
            message: message,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          // High priority for immediate delivery
          priority: 'high',
          // Required for background notifications
          content_available: true,
          // Android-specific settings
          android: {
            priority: 'high',
            notification: {
              channel_id: 'rmr_notifications', // Must match AndroidManifest.xml
              sound: 'default',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              // Ensure notification is shown even when app is killed
              default_sound: true,
              default_vibrate_timings: true,
              default_light_settings: true,
            },
          },
        }

        console.log(`Sending FCM to token: ${tokenData.fcm_token.substring(0, 20)}...`)
        console.log(`Payload:`, JSON.stringify(fcmPayload, null, 2))
        
        const response = await fetch(FCM_API_URL, {
          method: 'POST',
          headers: {
            'Authorization': `key=${FCM_SERVER_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        })

        const responseText = await response.text()
        console.log(`FCM Response status: ${response.status}`)
        console.log(`FCM Response body: ${responseText}`)

        if (!response.ok) {
          console.error(`FCM error for token ${tokenData.fcm_token.substring(0, 20)}...: ${response.status} - ${responseText}`)
          throw new Error(`FCM error: ${response.status} - ${responseText}`)
        }

        const responseData = JSON.parse(responseText)
        console.log(`FCM success for user ${tokenData.user_id}:`, responseData)

        return { userId: tokenData.user_id, success: true, messageId: responseData.message_id }
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




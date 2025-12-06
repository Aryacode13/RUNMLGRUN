/**
 * Backend Helper Script - Sync Strava Activities
 * 
 * Contoh script Node.js untuk sync activities dari Strava ke Supabase
 * Bisa dijalankan sebagai Cloud Function atau scheduled job
 * 
 * Usage:
 *   node sync_activities.js
 * 
 * Environment Variables Required:
 *   SUPABASE_URL=your_supabase_url
 *   SUPABASE_SERVICE_KEY=your_service_role_key (not anon key!)
 *   STRAVA_CLIENT_ID=your_strava_client_id
 *   STRAVA_CLIENT_SECRET=your_strava_client_secret
 */

const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');

// Load environment variables
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const STRAVA_CLIENT_ID = process.env.STRAVA_CLIENT_ID;
const STRAVA_CLIENT_SECRET = process.env.STRAVA_CLIENT_SECRET;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing Supabase configuration');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

/**
 * Refresh Strava access token
 */
async function refreshStravaToken(user) {
  try {
    const response = await axios.post('https://www.strava.com/oauth/token', {
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      refresh_token: user.refresh_token,
      grant_type: 'refresh_token',
    });

    const { access_token, refresh_token, expires_at } = response.data;

    // Update user tokens in Supabase
    await supabase
      .from('users')
      .update({
        access_token: access_token,
        refresh_token: refresh_token,
        token_expires: expires_at,
      })
      .eq('id', user.id);

    return access_token;
  } catch (error) {
    console.error(`Failed to refresh token for user ${user.id}:`, error.message);
    throw error;
  }
}

/**
 * Get activities from Strava API
 */
async function getStravaActivities(accessToken, perPage = 100, page = 1) {
  try {
    const response = await axios.get('https://www.strava.com/api/v3/athlete/activities', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
      params: {
        per_page: perPage,
        page: page,
      },
    });

    return response.data;
  } catch (error) {
    console.error('Failed to fetch activities from Strava:', error.message);
    throw error;
  }
}

/**
 * Sync activities for a single user
 */
async function syncUserActivities(user) {
  try {
    // Check if token needs refresh
    const now = Math.floor(Date.now() / 1000);
    let accessToken = user.access_token;

    if (user.token_expires && user.token_expires < now) {
      console.log(`Token expired for user ${user.id}, refreshing...`);
      accessToken = await refreshStravaToken(user);
    }

    // Fetch activities from Strava
    const stravaActivities = await getStravaActivities(accessToken, 100, 1);

    let synced = 0;
    let skipped = 0;

    for (const stravaActivity of stravaActivities) {
      // Check if activity already exists
      const { data: existing } = await supabase
        .from('activities')
        .select('id')
        .eq('strava_activity_id', stravaActivity.id)
        .single();

      if (existing) {
        skipped++;
        continue;
      }

      // Insert new activity
      const activityData = {
        user_id: user.id,
        strava_activity_id: stravaActivity.id,
        name: stravaActivity.name,
        distance: stravaActivity.distance,
        moving_time: stravaActivity.moving_time,
        elapsed_time: stravaActivity.elapsed_time,
        type: stravaActivity.type,
        start_date: stravaActivity.start_date_local,
        map_polyline: stravaActivity.map?.summary_polyline || null,
      };

      await supabase.from('activities').insert(activityData);
      synced++;
    }

    console.log(`User ${user.id}: Synced ${synced} activities, skipped ${skipped}`);
    return { synced, skipped };
  } catch (error) {
    console.error(`Failed to sync activities for user ${user.id}:`, error.message);
    throw error;
  }
}

/**
 * Main sync function - syncs activities for all users
 */
async function syncAllActivities() {
  try {
    console.log('Starting activity sync...');

    // Get all users with Strava tokens
    const { data: users, error } = await supabase
      .from('users')
      .select('id, access_token, refresh_token, token_expires')
      .not('access_token', 'is', null);

    if (error) {
      throw error;
    }

    if (!users || users.length === 0) {
      console.log('No users with Strava tokens found');
      return;
    }

    console.log(`Found ${users.length} users to sync`);

    let totalSynced = 0;
    let totalSkipped = 0;

    for (const user of users) {
      try {
        const result = await syncUserActivities(user);
        totalSynced += result.synced;
        totalSkipped += result.skipped;
      } catch (error) {
        console.error(`Error syncing user ${user.id}:`, error.message);
      }
    }

    console.log(`\nSync completed:`);
    console.log(`  Total synced: ${totalSynced}`);
    console.log(`  Total skipped: ${totalSkipped}`);
  } catch (error) {
    console.error('Sync failed:', error);
    process.exit(1);
  }
}

// Run sync if executed directly
if (require.main === module) {
  syncAllActivities()
    .then(() => {
      console.log('Done!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { syncAllActivities, syncUserActivities };


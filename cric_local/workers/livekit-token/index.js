import { AccessToken } from 'livekit-server-sdk';

const LIVEKIT_API_KEY = 'APIuYrhXdHMcLgd';
const LIVEKIT_API_SECRET = '2m5Tf3WAAGkX8o6oLCZIg9qbVtpSoX865TCh5p5kMUQ';

export default {
  async fetch(request) {
    const url = new URL(request.url);

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Content-Type': 'application/json',
    };

    // Handle preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only handle /token path
    if (url.pathname !== '/token') {
      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers: corsHeaders,
      });
    }

    const roomName = url.searchParams.get('room');
    const participantName = url.searchParams.get('name');
    const canPublish = url.searchParams.get('publish') === 'true';

    if (!roomName || !participantName) {
      return new Response(
        JSON.stringify({ error: 'Missing required params: room, name' }),
        { status: 400, headers: corsHeaders }
      );
    }

    try {
      const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
        identity: participantName,
        ttl: '6h',
      });

      token.addGrant({
        room: roomName,
        roomJoin: true,
        canPublish: canPublish,
        canSubscribe: true,
        canPublishData: canPublish,
      });

      const jwt = await token.toJwt();

      return new Response(JSON.stringify({ token: jwt }), {
        headers: corsHeaders,
      });
    } catch (err) {
      return new Response(
        JSON.stringify({ error: 'Token generation failed', details: err.message }),
        { status: 500, headers: corsHeaders }
      );
    }
  },
};

# Platform Gateway

This is the local integration boundary for the New API based deployment. Canvas
traffic enters through `/canvas`; the gateway redirects authentication to New API
and never creates a local account or wallet.

Required configuration for a real integration:

```powershell
$env:NEW_API_BASE_URL = 'https://<new-api-host>'
$env:CANVAS_CALLBACK_URL = 'https://<canvas-host>/sso/callback'
npm start
```

Without `NEW_API_BASE_URL`, `/canvas/login` deliberately returns `503` instead of
falling back to LocalMiniDrama login. This prevents a second identity/data plane.

The current checkout does not include the New API upstream source or a deployed
New API endpoint, so this service is a boundary and redirect implementation, not
proof of production New API integration.

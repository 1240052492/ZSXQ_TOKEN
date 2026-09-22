# WP-03 SSO Baseline

状态：`in_progress`

Implemented local canvas-side reference component:

- `services/super-canvas-adapter/src/one-time-sso-store.js`
- `services/super-canvas-adapter/test/one-time-sso-store.test.js`

Verified behavior:

- opaque random code;
- only a SHA-256 digest is retained by the store;
- `audience=canvas` is mandatory;
- state mismatch is rejected;
- expiry is rejected;
- successful exchange consumes the code and replay is rejected.

This is not the New API endpoint or a production session store. The next slice
must add an HTTP client for `/internal/v1/sso/exchange`, service authentication,
CSRF/state propagation and a canvas session backed by `super_canvas`.

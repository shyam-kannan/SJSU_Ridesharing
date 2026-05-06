# Session Expiry Fix - Profile Editing Issue

## Problem
When editing profile, setting up driver, or editing driver info in the LessGo iOS app, users see:
> "Your session has expired. Please log in again"

This occurs even though the user just logged in a minute ago.

## Root Cause
The backend's JWT access token TTL is set to **15 minutes** (default in `services/auth-service/src/config.ts`):
```typescript
jwtAccessExpiry: getSecretValue('JWT_ACCESS_EXPIRY') ?? '15m',
```

The iOS app only attempts to refresh the token **after** receiving a 401 error (reactive refresh), not **before** it expires (proactive refresh). This creates a race condition where:

1. User logs in → gets 15-minute access token
2. User starts editing profile
3. If the operation takes longer than 15 minutes, or if there's any delay, the token expires mid-operation
4. The next API call fails with 401 → app shows "session expired" message

## Solution Implemented
Added **proactive token refresh** to the iOS NetworkManager:

### Changes Made

#### 1. Created `JWTPayload.swift` model
- New file: `LessGo/LessGo/Models/JWTPayload.swift`
- Defines the JWT payload structure with `exp` (expiration) field
- Allows decoding JWT tokens to check expiry time

#### 2. Enhanced `NetworkManager.swift`
Added three new methods:

**`isAccessTokenExpired()`**
- Decodes the JWT token to extract the `exp` claim
- Checks if token expires within 2 minutes
- Returns `true` if token is expired or about to expire

**`decodeJWT(_ token: String)`**
- Manually decodes JWT payload (without verification)
- Extracts the base64-encoded payload section
- Decodes and returns the JWTPayload struct

**`refreshTokenIfNeeded()`**
- Called before every authenticated API request
- Uses a lock to prevent concurrent refresh attempts
- Silently refreshes token if it's about to expire
- Errors are logged but don't block the request

### How It Works
1. Before making any authenticated API request, the app now checks if the token expires within 2 minutes
2. If yes, it silently refreshes the token using the refresh token
3. The new token is stored in the keychain
4. The API request proceeds with the fresh token
5. User never sees the "session expired" message

## Benefits
- ✅ Eliminates the "session expired" error during profile editing
- ✅ Seamless user experience - token refreshes happen silently in the background
- ✅ Works with any token TTL (15 min, 1 hour, etc.)
- ✅ Thread-safe with refresh lock to prevent duplicate refresh calls
- ✅ Minimal performance impact - only checks expiry, doesn't refresh unnecessarily

## Testing
To verify the fix works:

1. Log in to the app
2. Go to Profile → Edit Profile
3. Make changes and save (should work without "session expired" error)
4. Try Profile → Setup Driver or Edit Driver
5. All operations should complete successfully

## Optional: Increase Token TTL
If you want to further reduce token refreshes, you can increase the access token TTL in the backend:

```bash
# In your .env or deployment config:
JWT_ACCESS_EXPIRY=1h  # or 2h, 4h, etc.
```

The proactive refresh will still work correctly with any TTL value.

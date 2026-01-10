# Phone Auto-Registration Feature

## Overview

The new `PhoneUsernamePasswordFormWithAutoRegistration` authenticator extends the existing phone login functionality to automatically register users who don't exist in Keycloak when they successfully verify their phone number with OTP.

## Key Features

- **Seamless User Experience**: Users can login/register using just their phone number and OTP
- **Automatic User Creation**: New users are created automatically upon successful OTP verification
- **Configurable Username**: Option to use phone number as username or generate a unique username
- **Security**: Maintains all existing security checks and rate limiting
- **Backward Compatible**: Existing phone login functionality remains unchanged

## How It Works

1. **User enters phone number**: User enters their phone number on the login screen
2. **OTP is sent**: System sends OTP to the phone number (regardless of whether user exists)
3. **User enters OTP**: User enters the received OTP code
4. **Verification & Registration**:
   - If user exists: Normal login process continues
   - If user doesn't exist AND auto-registration is enabled: New user is created automatically
   - If user doesn't exist AND auto-registration is disabled: Shows "user not found" error

## Configuration

### 1. Authentication Flow Setup

1. Go to **Authentication** > **Flows** in Keycloak Admin Console
2. Copy the `Browser` flow to create `Browser with Phone Auto Registration`
3. Replace `Username Password Form` with `Phone Username Password Form with Auto Registration`
4. Configure the authenticator settings:
   - **Enable Auto Registration**: `true` (to enable auto-registration)
   - **Auto Registration: Phone as Username**: `true` (to use phone number as username)
   - **Login with phone verify**: `true` (to enable phone+OTP login)
   - **Login with phone number**: `true` (to enable phone+password login)

### 2. Bind the Flow

1. Go to **Authentication** > **Bindings**
2. Set **Browser Flow** to `Browser with Phone Auto Registration`

### 3. Theme Configuration

Ensure your realm uses the `phone` theme:
1. Go to **Realm Settings** > **Themes**
2. Set **Login Theme** to `phone`

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| Enable Auto Registration | `false` | Automatically register users who don't exist when they successfully verify their phone number |
| Auto Registration: Phone as Username | `true` | Use phone number as username for auto-registered users |
| Login with phone verify | `true` | Allow login using phone number and OTP verification |
| Login with phone number | `true` | Allow login using phone number and password |

## User Creation Details

When a new user is auto-registered:

- **Username**: Phone number (if `Auto Registration: Phone as Username` is true) or generated username like `user_1234567890`
- **Enabled**: `true`
- **Phone Number**: Set as user attribute `phoneNumber`
- **Phone Verified**: Set as user attribute `phoneNumberVerified=true`
- **Events**: Registration event is logged for audit purposes

## Security Considerations

- **Rate Limiting**: All existing rate limiting applies to auto-registration attempts
- **Phone Validation**: Phone numbers are validated and canonicalized before registration
- **Duplicate Prevention**: Checks for existing usernames to prevent conflicts
- **Audit Trail**: All auto-registration events are logged

## Prerequisites

- **Duplicate Phone**: Must be set to `false` in realm phone provider settings
- **Phone Theme**: Login theme must be set to `phone`
- **Phone Provider**: MSG91 or other SMS provider must be configured

## Testing

1. **Existing User**: Enter phone number of existing user → Normal login flow
2. **New User (Auto-reg enabled)**: Enter new phone number → Auto-registration → Login
3. **New User (Auto-reg disabled)**: Enter new phone number → "User not found" error

## Migration from Existing Setup

1. **Backup**: Export your current authentication flows
2. **Create New Flow**: Set up the new auto-registration flow alongside existing flows
3. **Test**: Test with a few users before switching the main browser flow
4. **Switch**: Update the browser flow binding when ready
5. **Monitor**: Check logs for any issues during the transition

## Troubleshooting

### Common Issues

1. **"Username already exists" error**: 
   - Check if phone number conflicts with existing username
   - Consider using generated usernames instead of phone numbers

2. **Auto-registration not working**:
   - Verify `Enable Auto Registration` is set to `true`
   - Check that duplicate phone is disabled in realm settings
   - Ensure phone theme is active

3. **OTP not received**:
   - Check SMS provider configuration
   - Verify phone number format and region settings

### Logs

Check Keycloak logs for auto-registration events:
```
Auto-registered user: +1234567890 with phone: +1234567890
```

## Example Flow Configuration

```
Browser with Phone Auto Registration
├── Cookie
├── Kerberos
├── Identity Provider Redirector
└── Phone Username Password Form with Auto Registration (REQUIRED)
    ├── Enable Auto Registration: true
    ├── Auto Registration: Phone as Username: true
    ├── Login with phone verify: true
    └── Login with phone number: true
```

This feature provides a seamless onboarding experience while maintaining security and flexibility for different use cases.
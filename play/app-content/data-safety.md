# Data safety worksheet

These answers cover Android 1.0.0 (1).

## Data collection and security

- Does the app collect or share any required user data types? **No**
- Is all user data encrypted in transit? **Not applicable. The app makes no network requests.**
- Can users request data deletion? **Not applicable. The developer collects no user data and creates no account.**

## Why the answer is No

- The manifest declares no permissions.
- The WebView blocks network loads.
- The packaged HTML, JavaScript, fonts, and libraries run from Android assets.
- The app contains no advertising, analytics, crash reporting, or tracking SDK.
- Visualization preferences, onboarding state, and lesson progress stay in local WebView storage on the device.
- The app does not use a developer-operated server.

Do not add a data type merely because the interface shows bundled examples labeled climate, heart rate, finance, or similar topics. Those examples contain no user data and do not fetch live records in the Android build.

Recheck this worksheet if a future release adds telemetry, remote datasets, cloud sync, accounts, or any SDK that transmits data off the device.

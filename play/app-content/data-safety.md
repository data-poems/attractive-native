# Data safety worksheet

These answers cover Android 1.0.7 (8).

## Data collection and security

- Does the app collect or share any required user data types? **No**
- Is all user data encrypted in transit? **Not applicable. The app does not transmit user data; its WebView blocks network loads.**
- Can users request data deletion? **Not applicable. The developer collects no user data and creates no account.**

## Why the answer is No

- The manifest declares no permissions.
- The WebView blocks network loads.
- The packaged HTML, JavaScript, fonts, and libraries run from Android assets.
- The app contains no advertising, analytics, crash reporting, or tracking SDK.
- Visualization preferences, onboarding state, and lesson progress stay in local WebView storage on the device.
- Export as PNG writes one image to the place the person chooses in the system Save dialog. The app keeps no copy and gets no access to other files.
- The app does not use a developer-operated server.
- Privacy policy URL for the Console form: `https://dr.eamer.dev/attractive/privacy.html` (covers iOS and Android, effective November 12, 2026).

Do not add a data type merely because the interface has data themes named climate, heart rate, finance, or similar topics. A theme only renames the equation parameters and loads starting values; the app says so. No theme contains user data or fetches records.

Recheck this worksheet if a future release adds telemetry, remote datasets, cloud sync, accounts, or any SDK that transmits data off the device.

# Accessibility evidence

## Manual Android check

- Device: Android 15, 7-inch tablet profile, 1080 x 1920 at 280 dpi (`sw617dp`)
- Build: signed 1.0.0 (1) release APK
- Hardware-keyboard check: `KEYCODE_TAB` moves focus to the skip link.
- Visible focus: `tablet-keyboard-focus.png` shows the focused "Skip to visualization" target with a high-contrast outline.

## Source semantics

The bundled interface includes:

- A skip link to the visualization
- A polite live-announcement region
- Labels and expanded states on the controls menu
- Named groups for presets, style, content, and playback
- An interactive canvas with `role="img"`, an accessible description, and keyboard focus
- Named controls with pressed, disabled, expanded, and dialog states where applicable
- A named visualization toolbar and named equations and lessons panels

These semantics are in `android/web/index.html`. The same content is packaged into the signed release.

## Automation boundary

`uiautomator-window.xml` records the Android-native hierarchy. Android UI Automator sees the full-screen `android.webkit.WebView` as focusable, but it does not enumerate the WebView's internal HTML accessibility tree. The XML is useful as native-container evidence, not as proof of every web control.

Before production rollout, repeat the key journeys with TalkBack on physical Android hardware: open and close controls, change an attractor, pause and resume, open equations, and complete a lesson.

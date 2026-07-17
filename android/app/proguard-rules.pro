# File Purpose: Documents shrinker behavior for Attractive's deliberately small Android shell.
# Primary Components: WebView callback retention policy.
# Inputs/Outputs: Read by R8 when producing optimized release APK and AAB artifacts.

-keepclassmembers class * extends android.webkit.WebViewClient {
    public *;
}

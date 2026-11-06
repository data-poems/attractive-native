package attractive.lukesteuber.android;
import android.app.Instrumentation;
import android.app.Activity;
import android.os.Bundle;
/** Platform-only runner; no production bridge or additional dependency. */
public final class NativeUiRestorationRunner extends Instrumentation {
    private Bundle arguments;
    @Override public void onCreate(Bundle args) { super.onCreate(args); arguments=args; start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            result.putString("nativeUiReceipt", NativeUiRestorationChecks.run(this, arguments).toString());
            result.putString("stream", "Native restoration checks passed\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}

package com.parasjain.rewiremind

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodChannel

/**
 * The app's only activity, plus the one thing Flutter cannot ask Android for.
 *
 * Pinning a widget is a request, not a command: the launcher puts up its own
 * dialog and the person decides. `home_widget` makes that request and stops
 * there, which leaves the app with no idea whether anything was placed — so
 * after tapping Add you are handed back to a settings page with the widget
 * sitting on a home screen you cannot see.
 *
 * Android will say so if asked. `requestPinAppWidget` takes a success callback
 * it fires once the widget is actually on the home screen, and that is the
 * moment worth acting on: it is the difference between "added" and "asked".
 */
class MainActivity : FlutterActivity() {

    /** Kept, so the app can be told when a widget has landed. */
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pin" -> result.success(pin(call.argument<String>("provider")))
                    "country" -> result.success(country())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Which country's prices to show, as an ISO code, or null.
     *
     * The phone's language is a poor guide to it — plenty of phones in India
     * are set to en-GB — so the SIM is asked first, then the network it is
     * on, and the locale is only the last word. Needs no permission: both
     * country codes are readable by anybody.
     *
     * A store purchase is priced by the account's billing country rather than
     * by any of this; until there is one, this is the best guess available.
     */
    private fun country(): String? {
        val phone = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val sim = phone?.simCountryIso
        if (!sim.isNullOrBlank()) return sim
        val network = phone?.networkCountryIso
        if (!network.isNullOrBlank()) return network
        return resources.configuration.locales[0].country.ifBlank { null }
    }

    /**
     * Asks the launcher to place a widget.
     *
     * Returns false when the launcher has no such gesture — plenty of older
     * ones do not — so that Dart can fall back to telling somebody how to do
     * it by hand rather than appearing to do nothing.
     */
    private fun pin(provider: String?): Boolean {
        if (provider.isNullOrEmpty()) return false

        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) return false

        // Comes back to this activity rather than to a receiver. A broadcast
        // receiver cannot bring anything to the front on a modern Android, and
        // what has to happen here is a change of what is on screen.
        val landed = PendingIntent.getActivity(
            this,
            provider.hashCode(),
            Intent(this, MainActivity::class.java)
                .setAction(ACTION_PINNED)
                .putExtra(EXTRA_PROVIDER, provider)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return try {
            manager.requestPinAppWidget(
                ComponentName(this, "$packageName.$provider"),
                null,
                landed,
            )
        } catch (_: Exception) {
            false
        }
    }

    /**
     * The callback above, arriving because a widget was just placed.
     *
     * The app stays open and says so: it tells Dart which widget landed, and
     * Dart takes you to Home with a word about it. It used to step out of the
     * way to the home screen instead, which read as the app closing on you.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == ACTION_PINNED) {
            channel?.invokeMethod("pinned", intent.getStringExtra(EXTRA_PROVIDER))
        }
    }

    companion object {
        private const val CHANNEL = "com.parasjain.rewiremind/widgets"

        /** Marks the intent Android sends us once a widget is on the screen. */
        private const val ACTION_PINNED = "com.parasjain.rewiremind.WIDGET_PINNED"

        /** Which provider was placed, carried on [ACTION_PINNED]. */
        private const val EXTRA_PROVIDER = "provider"
    }
}

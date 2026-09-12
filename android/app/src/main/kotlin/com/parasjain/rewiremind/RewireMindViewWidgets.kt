package com.parasjain.rewiremind

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * The widgets that show your habits rather than the character: today's
 * checklist, this week, and this month.
 *
 * Like the mascot widget, they decide nothing about the habits themselves.
 * Dart writes each day's habits and each day's status; this reads them back
 * against the real clock. That last part is the reason there is any logic
 * here at all — a widget is looked at on days the app is never opened, and a
 * calendar that still has yesterday ringed as today is worse than none.
 */
abstract class RewireMindPanelWidget : HomeWidgetProvider() {

    protected abstract val layout: Int

    /** The layout for a widget of this size. Most views have just the one. */
    protected open fun layoutFor(options: Bundle): Int = layout

    /** Where a tap lands in the app: `rewiremind://<target>`. */
    protected open val target: String = "home"

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(
                id,
                render(context, widgetData, options(appWidgetManager, id)),
            )
        }
    }

    /**
     * Redraws on resize: the checklist shows as many rows as there is room
     * for, and the month swaps to its roomy layout once stretched.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val data = context.getSharedPreferences(RewireMindWidget.PREFS, Context.MODE_PRIVATE)
        appWidgetManager.updateAppWidget(appWidgetId, render(context, data, newOptions))
    }

    private fun options(manager: AppWidgetManager, id: Int): Bundle =
        try {
            manager.getAppWidgetOptions(id)
        } catch (_: Exception) {
            Bundle()
        }

    private fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
        val views = RemoteViews(context.packageName, layoutFor(options))
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val look = Look.of(context, RewireMindWidget.phaseOf(data, hour))
        views.setInt(R.id.wm_root, "setBackgroundResource", look.panel)

        bind(context, views, data, look, options)

        views.setOnClickPendingIntent(
            R.id.wm_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("rewiremind://$target"),
            ),
        )
        return views
    }

    protected abstract fun bind(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        look: Look,
        options: Bundle,
    )

    /** The widget's height in dp as placed, or 0 when the launcher has not said. */
    protected fun heightDp(options: Bundle): Int {
        // Portrait reports its real height as the maximum, landscape as the
        // minimum. Phones are held upright far more often than not.
        val max = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return if (max > 0) max else options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
    }

    /** The widget's width in dp as placed, or 0 when the launcher has not said. */
    protected fun widthDp(options: Bundle): Int {
        // And portrait reports its real width as the minimum.
        val min = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        return if (min > 0) min else options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
    }

    /**
     * Marks one day's circle: filled, tinted, ringed, or plain.
     *
     * The same four states the Calendar tab draws, plus a ring for today.
     * Today is never "missed" — it is not over — so a today with nothing done
     * yet gets the plain ring rather than the faint one.
     */
    protected fun markDay(
        views: RemoteViews,
        id: Int,
        day: Int,
        status: Char,
        isToday: Boolean,
        isFuture: Boolean,
        look: Look,
    ) {
        views.setTextViewText(id, day.toString())
        val (background, colour) = when {
            isFuture -> 0 to look.faint
            isToday -> when (status) {
                Cal.ALL -> look.todayAll to Color.WHITE
                Cal.SOME -> look.todaySome to look.ink
                else -> look.today to look.ink
            }
            else -> when (status) {
                Cal.ALL -> look.dayAll to Color.WHITE
                Cal.SOME -> look.daySome to look.ink
                Cal.NONE -> look.dayNone to look.soft
                else -> 0 to look.soft
            }
        }
        views.setInt(id, "setBackgroundResource", background)
        views.setTextColor(id, colour)
    }
}

/** The colours and markers for one time of day. */
class Look(
    val panel: Int,
    val ink: Int,
    val soft: Int,
    val faint: Int,
    val accent: Int,
    val chip: Int,
    val tickOn: Int,
    val tickOff: Int,
    val dayAll: Int,
    val daySome: Int,
    val dayNone: Int,
    val today: Int,
    val todaySome: Int,
    val todayAll: Int,
) {
    companion object {
        fun of(context: Context, phase: String): Look {
            val night = phase == "night"
            val panel = when (phase) {
                "night" -> R.drawable.wm_panel_night
                "earlyMorning" -> R.drawable.wm_panel_dawn
                else -> R.drawable.wm_panel_day
            }
            return if (night) {
                Look(
                    panel = panel,
                    ink = context.getColor(R.color.wm_on_dark),
                    soft = context.getColor(R.color.wm_on_dark_soft),
                    faint = context.getColor(R.color.wm_on_dark_faint),
                    accent = context.getColor(R.color.wm_on_dark_accent),
                    chip = R.drawable.wm_chip_d,
                    tickOn = R.drawable.wm_tick_on_d,
                    tickOff = R.drawable.wm_tick_off_d,
                    dayAll = R.drawable.wm_day_all_d,
                    daySome = R.drawable.wm_day_some_d,
                    dayNone = R.drawable.wm_day_none_d,
                    today = R.drawable.wm_day_today_d,
                    todaySome = R.drawable.wm_day_today_some_d,
                    todayAll = R.drawable.wm_day_today_all_d,
                )
            } else {
                Look(
                    panel = panel,
                    ink = context.getColor(R.color.wm_on_light),
                    soft = context.getColor(R.color.wm_on_light_soft),
                    faint = context.getColor(R.color.wm_on_light_faint),
                    accent = context.getColor(R.color.wm_on_light_accent),
                    chip = R.drawable.wm_chip_l,
                    tickOn = R.drawable.wm_tick_on_l,
                    tickOff = R.drawable.wm_tick_off_l,
                    dayAll = R.drawable.wm_day_all_l,
                    daySome = R.drawable.wm_day_some_l,
                    dayNone = R.drawable.wm_day_none_l,
                    today = R.drawable.wm_day_today_l,
                    todaySome = R.drawable.wm_day_today_some_l,
                    todayAll = R.drawable.wm_day_today_all_l,
                )
            }
        }
    }
}

/**
 * Day arithmetic, and the statuses Dart wrote.
 *
 * Days are counted as whole days since 1970 in UTC, which makes "the day
 * after" a plain `+ 1` with no daylight saving in it. `java.time` would say
 * this more nicely and is not there on every Android this runs on.
 */
object Cal {
    const val ALL = 'a'
    const val SOME = 's'
    const val NONE = 'n'
    const val EMPTY = 'e'

    /** Today's date on this phone, as a day number. */
    fun today(): Long {
        val now = Calendar.getInstance()
        return number(now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH))
    }

    fun number(year: Int, month: Int, day: Int): Long {
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        utc.clear()
        utc.set(year, month - 1, day)
        return utc.timeInMillis / 86_400_000L
    }

    /** "2026-09-11" as a day number, or null if it is not one. */
    fun parse(key: String?): Long? {
        val parts = key?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
        return if (parts.size == 3) number(parts[0], parts[1], parts[2]) else null
    }

    /** A day number back to its fields: year, month (1-12), day of month, weekday (0 = Monday). */
    fun fields(day: Long): IntArray {
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        utc.timeInMillis = day * 86_400_000L
        val weekday = (utc.get(Calendar.DAY_OF_WEEK) + 5) % 7
        return intArrayOf(
            utc.get(Calendar.YEAR),
            utc.get(Calendar.MONTH) + 1,
            utc.get(Calendar.DAY_OF_MONTH),
            weekday,
        )
    }

    fun key(day: Long): String {
        val f = fields(day)
        return String.format(Locale.US, "%04d-%02d-%02d", f[0], f[1], f[2])
    }

    /**
     * What Dart wrote: one letter per day from `from` up to `stamp`, the day it
     * was written. Days after the stamp are unknown rather than missed — the
     * app has not been opened since — and are drawn plain.
     */
    class Statuses(private val from: Long, private val stamp: Long, private val codes: String) {
        fun at(day: Long): Char {
            if (day < from || day > stamp) return EMPTY
            val i = (day - from).toInt()
            return if (i < codes.length) codes[i] else EMPTY
        }

        /** The day Dart last wrote, for anything that goes stale with it. */
        val writtenOn: Long get() = stamp
    }

    fun statuses(data: SharedPreferences): Statuses? = try {
        val json = JSONObject(data.getString(RewireMindWidget.KEY_CALENDAR, null) ?: "")
        val from = parse(json.optString("from"))
        val stamp = parse(json.optString("stamp"))
        if (from == null || stamp == null) null else Statuses(from, stamp, json.optString("s"))
    } catch (_: Exception) {
        null
    }
}

/** Today's habits, finished ones struck through. */
class RewireMindListWidgetProvider : RewireMindPanelWidget() {
    override val layout = R.layout.rewiremind_widget_list

    override fun bind(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        look: Look,
        options: Bundle,
    ) {
        val today = Cal.today()
        views.setTextColor(R.id.wm_title, look.ink)
        views.setTextColor(R.id.wm_date, look.soft)
        views.setTextColor(R.id.wm_empty, look.soft)
        views.setTextColor(R.id.wm_count, look.accent)
        views.setInt(R.id.wm_count, "setBackgroundResource", look.chip)
        views.setTextViewText(
            R.id.wm_date,
            SimpleDateFormat("EEE d MMM", Locale.getDefault()).format(Calendar.getInstance().time),
        )

        // Dart writes a week of days ahead, so the list is right tomorrow
        // morning even if the app is not opened until the afternoon. Only
        // today's ticks are real; the days ahead are all still to do.
        val json = try {
            JSONObject(data.getString(RewireMindWidget.KEY_LIST, null) ?: "")
        } catch (_: Exception) {
            null
        }
        val day = json?.optJSONObject("days")?.optJSONArray(Cal.key(today))
        val hasHabits = json?.optInt("habits", 1) != 0

        val tasks = mutableListOf<Pair<String, Boolean>>()
        if (day != null) {
            for (i in 0 until day.length()) {
                val entry = day.optJSONArray(i) ?: continue
                tasks += entry.optString(0) to (entry.optInt(1) == 1)
            }
        }

        val done = tasks.count { it.second }
        views.setTextViewText(R.id.wm_count, "$done of ${tasks.size} done")
        views.setViewVisibility(R.id.wm_count, if (tasks.isEmpty()) View.GONE else View.VISIBLE)

        if (tasks.isEmpty()) {
            views.setTextViewText(
                R.id.wm_empty,
                when {
                    json == null -> "Open RewireMind to begin"
                    !hasHabits -> "Add a habit to begin"
                    day == null -> "Open RewireMind to catch up"
                    else -> "Nothing due today"
                },
            )
            views.setViewVisibility(R.id.wm_empty, View.VISIBLE)
            views.setViewVisibility(R.id.wm_rows, View.GONE)
            return
        }
        views.setViewVisibility(R.id.wm_empty, View.GONE)
        views.setViewVisibility(R.id.wm_rows, View.VISIBLE)

        // What is left comes first, so a list too long for the widget still
        // shows the habits that need doing rather than the ones already done.
        val ordered = tasks.filter { !it.second } + tasks.filter { it.second }

        val height = heightDp(options)
        val room = if (height <= 0) 5 else ((height - 58) / ROW_DP).coerceIn(1, ROWS.size)
        val shown = if (ordered.size > room) room - 1 else ordered.size

        ROWS.forEachIndexed { i, (row, tick, text) ->
            when {
                i < shown -> {
                    val (name, finished) = ordered[i]
                    views.setViewVisibility(row, View.VISIBLE)
                    views.setViewVisibility(tick, View.VISIBLE)
                    views.setImageViewResource(tick, if (finished) look.tickOn else look.tickOff)
                    if (finished) {
                        val struck = SpannableString(name)
                        struck.setSpan(StrikethroughSpan(), 0, name.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        views.setTextViewText(text, struck)
                        views.setTextColor(text, look.faint)
                    } else {
                        views.setTextViewText(text, name)
                        views.setTextColor(text, look.ink)
                    }
                }
                i == shown && ordered.size > shown -> {
                    views.setViewVisibility(row, View.VISIBLE)
                    views.setViewVisibility(tick, View.INVISIBLE)
                    views.setTextViewText(text, "+${ordered.size - shown} more")
                    views.setTextColor(text, look.soft)
                }
                else -> views.setViewVisibility(row, View.GONE)
            }
        }
    }

    companion object {
        const val ROW_DP = 26

        private val ROWS = listOf(
            Triple(R.id.wm_r0, R.id.wm_r0_tick, R.id.wm_r0_text),
            Triple(R.id.wm_r1, R.id.wm_r1_tick, R.id.wm_r1_text),
            Triple(R.id.wm_r2, R.id.wm_r2_tick, R.id.wm_r2_text),
            Triple(R.id.wm_r3, R.id.wm_r3_tick, R.id.wm_r3_text),
            Triple(R.id.wm_r4, R.id.wm_r4_tick, R.id.wm_r4_text),
            Triple(R.id.wm_r5, R.id.wm_r5_tick, R.id.wm_r5_text),
            Triple(R.id.wm_r6, R.id.wm_r6_tick, R.id.wm_r6_text),
            Triple(R.id.wm_r7, R.id.wm_r7_tick, R.id.wm_r7_text),
        )
    }
}

/** Monday to Sunday of this week. */
class RewireMindWeekWidgetProvider : RewireMindPanelWidget() {
    override val layout = R.layout.rewiremind_widget_week
    override val target = "calendar"

    override fun bind(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        look: Look,
        options: Bundle,
    ) {
        val today = Cal.today()
        val monday = today - Cal.fields(today)[3]
        val statuses = Cal.statuses(data)

        for (i in 0 until 7) {
            val day = monday + i
            views.setTextColor(LABELS[i], if (day == today) look.accent else look.soft)
            markDay(
                views,
                CELLS[i],
                Cal.fields(day)[2],
                statuses?.at(day) ?: Cal.EMPTY,
                isToday = day == today,
                isFuture = day > today,
                look = look,
            )
        }
    }

    companion object {
        private val CELLS = intArrayOf(
            R.id.wm_w0, R.id.wm_w1, R.id.wm_w2, R.id.wm_w3, R.id.wm_w4, R.id.wm_w5, R.id.wm_w6,
        )
        private val LABELS = intArrayOf(
            R.id.wm_w0_label, R.id.wm_w1_label, R.id.wm_w2_label, R.id.wm_w3_label,
            R.id.wm_w4_label, R.id.wm_w5_label, R.id.wm_w6_label,
        )
    }
}

/** This month, as the Calendar tab draws it. */
class RewireMindMonthWidgetProvider : RewireMindPanelWidget() {
    /** Where it starts: the whole month in three cells by two. */
    override val layout = R.layout.rewiremind_widget_month_small
    override val target = "calendar"

    /** Stretched past this in both directions, it has room for the big one. */
    private fun roomy(options: Bundle) =
        heightDp(options) >= ROOMY_HEIGHT && widthDp(options) >= ROOMY_WIDTH

    override fun layoutFor(options: Bundle): Int =
        if (roomy(options)) R.layout.rewiremind_widget_month else layout

    override fun bind(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        look: Look,
        options: Bundle,
    ) {
        val today = Cal.today()
        val t = Cal.fields(today)
        val first = Cal.number(t[0], t[1], 1)
        val offset = Cal.fields(first)[3]
        val length = Calendar.getInstance().getActualMaximum(Calendar.DAY_OF_MONTH)
        val statuses = Cal.statuses(data)

        val now = Calendar.getInstance()
        views.setTextViewText(R.id.wm_m_title, SimpleDateFormat("MMMM", Locale.getDefault()).format(now.time))
        views.setTextViewText(R.id.wm_m_year, t[0].toString())
        views.setTextColor(R.id.wm_m_title, look.ink)
        views.setTextColor(R.id.wm_m_year, look.soft)
        HEADS.forEach { views.setTextColor(it, look.soft) }

        // The streak as of the day Dart wrote it. Older than yesterday and it
        // has certainly been broken since, so it goes rather than lies.
        val streak = data.getInt(RewireMindWidget.KEY_STREAK_DAYS, 0)
        val fresh = statuses != null && today - statuses.writtenOn <= 1
        views.setViewVisibility(R.id.wm_m_streak, if (fresh && streak >= 2) View.VISIBLE else View.GONE)
        // Short in the compact layout, where it shares a row with the month.
        views.setTextViewText(
            R.id.wm_m_streak,
            if (roomy(options)) "🔥 $streak-day streak" else "🔥 $streak",
        )
        views.setTextColor(R.id.wm_m_streak, look.accent)
        views.setInt(R.id.wm_m_streak, "setBackgroundResource", look.chip)

        CELLS.forEachIndexed { i, id ->
            val date = i - offset + 1
            if (date < 1 || date > length) {
                views.setTextViewText(id, "")
                views.setInt(id, "setBackgroundResource", 0)
            } else {
                val day = first + date - 1
                markDay(
                    views,
                    id,
                    date,
                    statuses?.at(day) ?: Cal.EMPTY,
                    isToday = day == today,
                    isFuture = day > today,
                    look = look,
                )
            }
        }

        val weeks = (offset + length + 6) / 7
        ROWS.forEachIndexed { r, id ->
            views.setViewVisibility(id, if (r < weeks) View.VISIBLE else View.GONE)
        }
    }

    companion object {
        const val ROOMY_HEIGHT = 230
        const val ROOMY_WIDTH = 250

        private val ROWS = intArrayOf(
            R.id.wm_mrow0, R.id.wm_mrow1, R.id.wm_mrow2,
            R.id.wm_mrow3, R.id.wm_mrow4, R.id.wm_mrow5,
        )
        private val HEADS = intArrayOf(
            R.id.wm_mh0, R.id.wm_mh1, R.id.wm_mh2, R.id.wm_mh3,
            R.id.wm_mh4, R.id.wm_mh5, R.id.wm_mh6,
        )
        private val CELLS = intArrayOf(
            R.id.wm_m0, R.id.wm_m1, R.id.wm_m2, R.id.wm_m3, R.id.wm_m4, R.id.wm_m5, R.id.wm_m6,
            R.id.wm_m7, R.id.wm_m8, R.id.wm_m9, R.id.wm_m10, R.id.wm_m11, R.id.wm_m12, R.id.wm_m13,
            R.id.wm_m14, R.id.wm_m15, R.id.wm_m16, R.id.wm_m17, R.id.wm_m18, R.id.wm_m19, R.id.wm_m20,
            R.id.wm_m21, R.id.wm_m22, R.id.wm_m23, R.id.wm_m24, R.id.wm_m25, R.id.wm_m26, R.id.wm_m27,
            R.id.wm_m28, R.id.wm_m29, R.id.wm_m30, R.id.wm_m31, R.id.wm_m32, R.id.wm_m33, R.id.wm_m34,
            R.id.wm_m35, R.id.wm_m36, R.id.wm_m37, R.id.wm_m38, R.id.wm_m39, R.id.wm_m40, R.id.wm_m41,
        )
    }
}

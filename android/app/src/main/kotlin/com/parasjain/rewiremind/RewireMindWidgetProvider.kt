package com.parasjain.rewiremind

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import java.util.Calendar
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home screen widget, in whichever size was placed.
 *
 * It works nothing out for itself: the line, the mood and the counts are all
 * decided in Dart, where the habit data lives, and written here through
 * `home_widget`. This class is the last mile — it maps those values onto views.
 *
 * All three layouts carry the same view ids, hidden where a size has no room
 * for them, so this one method drives every size. Three parallel binding
 * routines would be three things to keep in step.
 */
abstract class RewireMindWidget : HomeWidgetProvider() {

    protected abstract val layout: Int

    /** Whether this size shows the "try me bigger" line while it is small. */
    protected open val invitesResize: Boolean = false

    /**
     * Whether this size takes the two-word form of the line and the count.
     *
     * The strip and the square have a row to share with a mascot and a chip.
     * Rather than let Android cut a good line off with an ellipsis, Dart writes
     * every thought at both lengths and these sizes read the short one.
     */
    protected open val terse: Boolean = false

    /**
     * Whether this size abbreviates the day counter as well as the line.
     *
     * Defaults to following [terse], because the square abbreviates both. The
     * strip overrides it: it is a whole row wide, and "9/21" sitting on that
     * much space read like something had been truncated.
     */
    protected open val chipTerse: Boolean = terse

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(
                id,
                build(context, widgetData, options(appWidgetManager, id)),
            )
        }
    }

    /**
     * Redraws when the widget is resized, which is what lets the invitation to
     * make it bigger disappear the moment somebody has.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val data = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        appWidgetManager.updateAppWidget(appWidgetId, build(context, data, newOptions))
    }

    /**
     * The hour to draw, honouring a time of day the reader has pinned.
     *
     * Appearance lets somebody keep the app on one look. The widget paints the
     * same sky, so if it went on choosing its character from the real clock
     * you would get a brain in bed under a midday sun. This walks the clock
     * hour into the pinned band instead, which keeps the picture and the sky
     * agreeing and still turns the character over every hour.
     */
    private fun hourInPhase(hour: Int, phase: String?): Int {
        val band = when (phase) {
            "earlyMorning" -> 5..9
            "night" -> null // 19..4, which is not a range that counts upwards
            "day" -> 10..18
            else -> return hour
        }
        if (band == null) {
            val night = intArrayOf(19, 20, 21, 22, 23, 0, 1, 2, 3, 4)
            return if (hour in 19..23 || hour in 0..4) hour else night[hour % night.size]
        }
        return if (hour in band) hour else band.first + hour % band.count()
    }

    /**
     * One line out of the pool Dart wrote, chosen by the hour.
     *
     * The pool arrives newline-separated because it is one preference and
     * `home_widget` writes strings. An empty or missing pool falls back to the
     * default, which is what a widget placed before the app has ever run gets.
     */
    private fun pick(pool: String?, hour: Int, fallback: String): String {
        val lines = pool?.split("\n")?.filter { it.isNotEmpty() } ?: emptyList()
        return if (lines.isEmpty()) fallback else lines[hour % lines.size]
    }

    private fun options(manager: AppWidgetManager, id: Int): Bundle =
        try {
            manager.getAppWidgetOptions(id)
        } catch (_: Exception) {
            Bundle()
        }

    private fun build(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
        val views = RemoteViews(context.packageName, layout)

        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // Dart writes the whole pool, not one line, and the hour picks out of
        // it. The copy stays in Dart where it can be read and tested as
        // English; what the hour buys is a widget that has something new to
        // say on its own, hours after the app was last opened.
        views.setTextViewText(
            R.id.wm_line,
            pick(
                data.getString(if (terse) KEY_LINES_SHORT else KEY_LINES, null),
                hour,
                if (terse) "Ready?" else "Got a minute?",
            ),
        )
        views.setTextViewText(R.id.wm_sub, data.getString(KEY_SUB, "Open RewireMind"))
        views.setTextViewText(
            R.id.wm_streak,
            if (chipTerse) {
                data.getString(KEY_STREAK_SHORT, "0/21")
            } else {
                data.getString(KEY_STREAK, "Day 0 of 21")
            },
        )
        views.setProgressBar(R.id.wm_progress, 100, data.getInt(KEY_PROGRESS, 0), false)

        // The backdrop, and the text colours that go with it. Both follow the
        // app's time of day rather than the system theme: a phone in light
        // mode showing the night scene needs light text, and the other way
        // round, so the two cannot be decided separately.
        val phase = phaseOf(data, hour)
        val night = phase == "night"
        views.setImageViewResource(
            R.id.wm_scene,
            when (phase) {
                "earlyMorning" -> R.drawable.wm_scene_earlymorning
                "night" -> R.drawable.wm_scene_night
                else -> R.drawable.wm_scene_day
            },
        )

        val ink = context.getColor(
            if (night) R.color.wm_on_dark else R.color.wm_on_light,
        )
        val soft = context.getColor(
            if (night) R.color.wm_on_dark_soft else R.color.wm_on_light_soft,
        )
        val chip = context.getColor(
            if (night) R.color.wm_on_dark_accent else R.color.wm_on_light_accent,
        )
        views.setTextColor(R.id.wm_line, ink)
        views.setTextColor(R.id.wm_sub, soft)
        views.setTextColor(R.id.wm_hint, soft)
        views.setTextColor(R.id.wm_streak, chip)

        // Which of the six characters is in the window.
        //
        // The mood wins where there is one worth having — a finished day and a
        // fortnight of silence are both worth saying out loud whatever the
        // hour. Otherwise the clock decides, and the widget shows you the same
        // brain the app's own header would be showing: brushing its teeth
        // first thing, out for a run in the middle of the day, in bed at
        // night. It is the difference between a status readout and something
        // that appears to be having a day of its own.
        //
        // Dart writes the line to match, so the sentence and the picture are
        // chosen from the same two facts and never disagree.
        val frames = when (data.getString(KEY_MOOD, "nudge")) {
            "happy" -> HAPPY
            "sad" -> SAD
            else -> HOURS[hourInPhase(hour, phase)]
        }
        SLOTS.forEachIndexed { i, id -> views.setImageViewResource(id, frames[i]) }

        // Only asked for on the smallest size, and only while it is still
        // small. A widget nagging to be resized after it has been resized is
        // the sort of thing that gets a widget removed.
        val roomy = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) >= ROOMY_DP &&
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) >= ROOMY_DP
        views.setViewVisibility(
            R.id.wm_hint,
            if (invitesResize && !roomy) View.VISIBLE else View.GONE,
        )

        // The whole card opens the app, on Home. Built through home_widget's
        // launch intent rather than a plain launcher intent: that carries a
        // URI Dart can read, which is what lets the app come back to the Home
        // tab instead of resuming on whatever screen was last open. A bare
        // launcher intent reuses the task and leaves you wherever you were.
        val pending = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("rewiremind://home"),
        )
        views.setOnClickPendingIntent(R.id.wm_scene, pending)
        views.setOnClickPendingIntent(R.id.wm_mascot, pending)
        views.setOnClickPendingIntent(R.id.wm_line, pending)
        views.setOnClickPendingIntent(R.id.wm_streak, pending)

        return views
    }

    companion object {
        /** Where `home_widget` puts what Dart saved. */
        const val PREFS = "HomeWidgetPreferences"

        const val KEY_LINE = "wm_line"
        const val KEY_LINE_SHORT = "wm_line_short"

        /** Every line Dart thinks fits the moment, newline-separated. */
        const val KEY_LINES = "wm_lines"
        const val KEY_LINES_SHORT = "wm_lines_short"
        const val KEY_SUB = "wm_sub"
        const val KEY_STREAK = "wm_streak"
        const val KEY_STREAK_SHORT = "wm_streak_short"
        const val KEY_MOOD = "wm_mood"
        const val KEY_PROGRESS = "wm_progress"
        const val KEY_PHASE = "wm_phase"

        /** "1" while the app takes its time of day from the clock, "0" when pinned. */
        const val KEY_CLOCK = "wm_clock"

        /** Today and the six days after: each one's habits, and today's ticks. */
        const val KEY_LIST = "wm_list"

        /** One status letter per day, for the week and month widgets. */
        const val KEY_CALENDAR = "wm_cal"

        /** Days in a row with everything done, as of the last write. */
        const val KEY_STREAK_DAYS = "wm_streak_days"

        /**
         * The time of day to paint, worked out now rather than when Dart wrote.
         *
         * Dart writes the phase when something changes in the app, which on a
         * quiet day might be breakfast — and a widget still showing the
         * morning at ten at night is the app disagreeing with the sky. While
         * the app follows the clock, so does this; a pinned phase is kept.
         * The boundaries are DayPhase.of's.
         */
        fun phaseOf(data: SharedPreferences, hour: Int): String {
            if (data.getString(KEY_CLOCK, "1") != "1") {
                return data.getString(KEY_PHASE, "day") ?: "day"
            }
            return when {
                hour < 5 -> "night"
                hour < 10 -> "earlyMorning"
                hour < 19 -> "day"
                else -> "night"
            }
        }

        /** Past this in both directions it is big enough to read at a glance. */
        const val ROOMY_DP = 130

        /**
         * The flipper's six children, in order.
         *
         * Ten rather than the four it was. A ViewFlipper is the only thing on
         * the RemoteViews list that moves by itself, so the animation is
         * stills on a timer — and the fewer of them there are, the further the
         * character has to jump between one and the next. Ten covers a whole
         * walk cycle in small steps, which is what lets the flipper run slowly
         * and still look like movement rather than a slideshow.
         */
        val SLOTS = intArrayOf(
            R.id.wm_f1, R.id.wm_f2, R.id.wm_f3, R.id.wm_f4, R.id.wm_f5,
            R.id.wm_f6, R.id.wm_f7, R.id.wm_f8, R.id.wm_f9, R.id.wm_f10,
        )

        /** The ten frames of one scene, by name. */
        private fun scene(
            a: Int, b: Int, c: Int, d: Int, e: Int,
            f: Int, g: Int, h: Int, i: Int, j: Int,
        ) = intArrayOf(a, b, c, d, e, f, g, h, i, j)

        /** Everything done: the same cheer the app throws on day 21. */
        val HAPPY = scene(
            R.drawable.wm_happy_1, R.drawable.wm_happy_2, R.drawable.wm_happy_3,
            R.drawable.wm_happy_4, R.drawable.wm_happy_5, R.drawable.wm_happy_6,
            R.drawable.wm_happy_7, R.drawable.wm_happy_8, R.drawable.wm_happy_9,
            R.drawable.wm_happy_10,
        )

        private val WAKE = scene(
            R.drawable.wm_wake_1, R.drawable.wm_wake_2, R.drawable.wm_wake_3,
            R.drawable.wm_wake_4, R.drawable.wm_wake_5, R.drawable.wm_wake_6,
            R.drawable.wm_wake_7, R.drawable.wm_wake_8, R.drawable.wm_wake_9,
            R.drawable.wm_wake_10,
        )

        private val BRUSH = scene(
            R.drawable.wm_brush_1, R.drawable.wm_brush_2, R.drawable.wm_brush_3,
            R.drawable.wm_brush_4, R.drawable.wm_brush_5, R.drawable.wm_brush_6,
            R.drawable.wm_brush_7, R.drawable.wm_brush_8, R.drawable.wm_brush_9,
            R.drawable.wm_brush_10,
        )

        private val TOWEL = scene(
            R.drawable.wm_towel_1, R.drawable.wm_towel_2, R.drawable.wm_towel_3,
            R.drawable.wm_towel_4, R.drawable.wm_towel_5, R.drawable.wm_towel_6,
            R.drawable.wm_towel_7, R.drawable.wm_towel_8, R.drawable.wm_towel_9,
            R.drawable.wm_towel_10,
        )

        private val COFFEE = scene(
            R.drawable.wm_coffee_1, R.drawable.wm_coffee_2,
            R.drawable.wm_coffee_3, R.drawable.wm_coffee_4,
            R.drawable.wm_coffee_5, R.drawable.wm_coffee_6,
            R.drawable.wm_coffee_7, R.drawable.wm_coffee_8,
            R.drawable.wm_coffee_9, R.drawable.wm_coffee_10,
        )

        private val HERO = scene(
            R.drawable.wm_hero_1, R.drawable.wm_hero_2, R.drawable.wm_hero_3,
            R.drawable.wm_hero_4, R.drawable.wm_hero_5, R.drawable.wm_hero_6,
            R.drawable.wm_hero_7, R.drawable.wm_hero_8, R.drawable.wm_hero_9,
            R.drawable.wm_hero_10,
        )

        private val JOG = scene(
            R.drawable.wm_jog_1, R.drawable.wm_jog_2, R.drawable.wm_jog_3,
            R.drawable.wm_jog_4, R.drawable.wm_jog_5, R.drawable.wm_jog_6,
            R.drawable.wm_jog_7, R.drawable.wm_jog_8, R.drawable.wm_jog_9,
            R.drawable.wm_jog_10,
        )

        private val FOCUS = scene(
            R.drawable.wm_focus_1, R.drawable.wm_focus_2, R.drawable.wm_focus_3,
            R.drawable.wm_focus_4, R.drawable.wm_focus_5, R.drawable.wm_focus_6,
            R.drawable.wm_focus_7, R.drawable.wm_focus_8, R.drawable.wm_focus_9,
            R.drawable.wm_focus_10,
        )

        private val LUNCH = scene(
            R.drawable.wm_lunch_1, R.drawable.wm_lunch_2, R.drawable.wm_lunch_3,
            R.drawable.wm_lunch_4, R.drawable.wm_lunch_5, R.drawable.wm_lunch_6,
            R.drawable.wm_lunch_7, R.drawable.wm_lunch_8, R.drawable.wm_lunch_9,
            R.drawable.wm_lunch_10,
        )

        private val DINNER = scene(
            R.drawable.wm_dinner_1, R.drawable.wm_dinner_2,
            R.drawable.wm_dinner_3, R.drawable.wm_dinner_4,
            R.drawable.wm_dinner_5, R.drawable.wm_dinner_6,
            R.drawable.wm_dinner_7, R.drawable.wm_dinner_8,
            R.drawable.wm_dinner_9, R.drawable.wm_dinner_10,
        )

        private val HEART = scene(
            R.drawable.wm_heart_1, R.drawable.wm_heart_2, R.drawable.wm_heart_3,
            R.drawable.wm_heart_4, R.drawable.wm_heart_5, R.drawable.wm_heart_6,
            R.drawable.wm_heart_7, R.drawable.wm_heart_8, R.drawable.wm_heart_9,
            R.drawable.wm_heart_10,
        )

        private val NIGHTCAP = scene(
            R.drawable.wm_night_1, R.drawable.wm_night_2, R.drawable.wm_night_3,
            R.drawable.wm_night_4, R.drawable.wm_night_5, R.drawable.wm_night_6,
            R.drawable.wm_night_7, R.drawable.wm_night_8, R.drawable.wm_night_9,
            R.drawable.wm_night_10,
        )

        /** Also what days of silence look like. */
        val SAD = scene(
            R.drawable.wm_sleep_1, R.drawable.wm_sleep_2, R.drawable.wm_sleep_3,
            R.drawable.wm_sleep_4, R.drawable.wm_sleep_5, R.drawable.wm_sleep_6,
            R.drawable.wm_sleep_7, R.drawable.wm_sleep_8, R.drawable.wm_sleep_9,
            R.drawable.wm_sleep_10,
        )

        /**
         * A day in the life, one entry per hour.
         *
         * The widget used to have three faces and change between them about as
         * often as the week did, which on a home screen you look at forty times
         * a day is wallpaper. This is the same brain doing what you are
         * probably doing: asleep until five, up and brushing, showered,
         * coffee, out for a run, lunch, head down, dinner, and off to bed.
         *
         * It costs nothing to run — the character is chosen when the widget is
         * drawn, and it is redrawn on the update period it already had.
         */
        val HOURS = arrayOf(
            SAD, SAD, SAD, SAD, SAD,          // 00-04  asleep
            WAKE,                             // 05     stretching
            BRUSH,                            // 06     teeth
            TOWEL,                            // 07     shower
            COFFEE,                           // 08     first coffee
            HERO,                             // 09     out the door
            JOG,                              // 10     run
            FOCUS,                            // 11     head down
            LUNCH,                            // 12     lunch
            COFFEE,                           // 13     the other coffee
            FOCUS,                            // 14     back to it
            JOG,                              // 15     afternoon walk
            HERO,                             // 16     on the move
            HEART,                            // 17     feeling good
            DINNER,                           // 18     dinner
            FOCUS,                            // 19     evening reading
            HEART,                            // 20     winding down
            NIGHTCAP,                         // 21     yawning
            SAD, SAD,                         // 22-23  bed
        )
    }
}

/** 4x2. Kept under the original class name so widgets already placed survive. */
class RewireMindWidgetProvider : RewireMindWidget() {
    override val layout = R.layout.rewiremind_widget
}

/** 2x2 — the one that asks to be made bigger. */
class RewireMindSmallWidgetProvider : RewireMindWidget() {
    override val layout = R.layout.rewiremind_widget_small
    override val terse = true
    override val invitesResize = true
}

/** 4x1: one row, everything in it. */
class RewireMindStripWidgetProvider : RewireMindWidget() {
    override val layout = R.layout.rewiremind_widget_strip
    override val terse = true
    override val chipTerse = false
}

package ru.merrcurys.my_mpt

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

/**
 * Виджет «Пары на сегодня». Показывает расписание на текущий день.
 * Обновляется в 00:00 через AlarmManager. Кнопка «Обновить» перечитывает данные из SharedPreferences.
 */
class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (_: Exception) {
                // Игнорируем ошибку по одному виджету
            }
        }
        try {
            scheduleMidnightUpdate(context)
        } catch (_: Exception) {
            // Будильник в 00:00 — не критично для отображения виджета
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val provider = ComponentName(context, ScheduleWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(provider)
            scheduleMidnightUpdate(context)
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }
    }

    override fun onEnabled(context: Context) {
        scheduleMidnightUpdate(context)
    }

    override fun onDisabled(context: Context) {
        cancelMidnightUpdate(context)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            updateWidgetInternal(context, appWidgetManager, appWidgetId)
        } catch (_: Exception) {
            val layoutId = getLayoutId(context, "schedule_widget_layout")
            if (layoutId == 0) return
            val views = RemoteViews(context.packageName, layoutId)
            views.setTextViewText(R.id.schedule_widget_subtitle, "Откройте приложение")
            views.setEmptyView(R.id.schedule_widget_list, R.id.schedule_widget_empty)
            views.setTextViewText(R.id.schedule_widget_empty, "Нет данных")
            setListAdapter(context, views, appWidgetId)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.schedule_widget_list)
        }
    }

    private fun updateWidgetInternal(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val dateStr = prefs.getString(KEY_DATE, null)
        val dataJson = prefs.getString(KEY_DATA, null)
        val groupName = prefs.getString(KEY_GROUP, null) ?: ""

        val layoutId = getLayoutId(context, "schedule_widget_layout")
        if (layoutId == 0) return
        val views = RemoteViews(context.packageName, layoutId)

        val todayStr = todayDateString()
        val isOutdated = dateStr != todayStr
        val dateForSubtitle = if (dateStr.isNullOrEmpty()) todayStr else dateStr
        val dateFormatted = formatDateForSubtitle(dateForSubtitle)

        val subtitle = when {
            isOutdated -> (if (groupName.isNotEmpty()) "$groupName — $dateFormatted" else dateFormatted) + " · Откройте приложение"
            groupName.isNotEmpty() -> "$groupName — $dateFormatted"
            else -> dateFormatted
        }
        views.setTextViewText(R.id.schedule_widget_subtitle, subtitle)

        views.setEmptyView(R.id.schedule_widget_list, R.id.schedule_widget_empty)
        views.setTextViewText(R.id.schedule_widget_empty, "Нет пар на сегодня")
        setListAdapter(context, views, appWidgetId)

        val refreshIntent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_WIDGET
        }
        val refreshPending = PendingIntent.getBroadcast(
            context, 0, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.schedule_widget_btn_reload, refreshPending)

        val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (openAppIntent != null) {
            val openPending = PendingIntent.getActivity(
                context, 0, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.schedule_widget_title, openPending)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.schedule_widget_list)
    }

    private fun setListAdapter(context: Context, views: RemoteViews, appWidgetId: Int) {
        val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setPackage(context.packageName)
        }
        views.setRemoteAdapter(R.id.schedule_widget_list, serviceIntent)
    }

    private fun getLayoutId(context: Context, name: String): Int {
        return context.resources.getIdentifier(name, "layout", context.packageName)
    }

    private fun todayDateString(): String {
        val c = Calendar.getInstance()
        return String.format("%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
    }

    /** Формат: "понедельник 02.03" */
    private fun formatDateForSubtitle(dateStr: String): String {
        val parts = dateStr.split("-")
        if (parts.size != 3) return dateStr
        val y = parts[0].toIntOrNull() ?: return dateStr
        val m = parts[1].toIntOrNull() ?: return dateStr
        val d = parts[2].toIntOrNull() ?: return dateStr
        val c = Calendar.getInstance(Locale("ru"))
        c.set(Calendar.YEAR, y)
        c.set(Calendar.MONTH, m - 1)
        c.set(Calendar.DAY_OF_MONTH, d)
        val weekday = when (c.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> "воскресенье"
            Calendar.MONDAY -> "понедельник"
            Calendar.TUESDAY -> "вторник"
            Calendar.WEDNESDAY -> "среда"
            Calendar.THURSDAY -> "четверг"
            Calendar.FRIDAY -> "пятница"
            Calendar.SATURDAY -> "суббота"
            else -> ""
        }
        return "$weekday %02d.%02d".format(Locale.ROOT, d, m)
    }

    private fun scheduleMidnightUpdate(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, ScheduleWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(provider)
        if (appWidgetIds.isEmpty()) return
        val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        val pending = PendingIntent.getBroadcast(
            context, MIDNIGHT_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val nextMidnight = nextMidnightCalendar()
        try {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC, nextMidnight.timeInMillis, pending)
        } catch (_: Exception) {
            alarm.set(AlarmManager.RTC, nextMidnight.timeInMillis, pending)
        }
    }

    private fun cancelMidnightUpdate(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pending = PendingIntent.getBroadcast(
            context, MIDNIGHT_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarm.cancel(pending)
    }

    private fun nextMidnightCalendar(): Calendar {
        val c = Calendar.getInstance()
        c.add(Calendar.DAY_OF_MONTH, 1)
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c
    }

    companion object {
        const val PREFS_NAME = "schedule_widget"
        const val KEY_DATE = "schedule_widget_date"
        const val KEY_DATA = "schedule_widget_data"
        const val KEY_GROUP = "schedule_widget_group"
        private const val ACTION_REFRESH_WIDGET = "ru.merrcurys.my_mpt.SCHEDULE_WIDGET_REFRESH"
        private const val MIDNIGHT_REQUEST_CODE = 1001
    }
}

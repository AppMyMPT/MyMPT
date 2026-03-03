package ru.merrcurys.my_mpt

import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

/**
 * Сервис для заполнения списка пар в виджете. Обеспечивает прокрутку списка.
 */
class ScheduleWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsService.RemoteViewsFactory {
        return ScheduleWidgetFactory(applicationContext, intent)
    }
}

class ScheduleWidgetFactory(
    private val context: android.content.Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private var lessons: List<LessonItem> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences(ScheduleWidgetProvider.PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = prefs.getString(ScheduleWidgetProvider.KEY_DATA, null)
        lessons = parseLessons(json)
    }

    override fun onDestroy() {}

    override fun getCount(): Int = lessons.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position !in lessons.indices) return null
        val lesson = lessons[position]
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_lesson_item)
        views.setTextViewText(R.id.widget_lesson_num, lesson.number)
        views.setTextViewText(R.id.widget_lesson_text, lesson.subject)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun parseLessons(json: String?): List<LessonItem> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(json)
            List(arr.length()) { i ->
                val obj = arr.getJSONObject(i)
                LessonItem(
                    number = obj.optString("number", ""),
                    subject = obj.optString("subject", "")
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private data class LessonItem(val number: String, val subject: String)
}

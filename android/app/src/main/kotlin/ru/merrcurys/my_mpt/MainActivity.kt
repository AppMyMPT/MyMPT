package ru.merrcurys.my_mpt

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.merrcurys.my_mpt/schedule_widget"
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                if (args != null) {
                    val date = args["date"] as? String ?: ""
                    val group = args["group"] as? String ?: ""
                    val lessons = args["lessons"] as? List<Map<String, Any?>>
                    updateScheduleWidget(date, group, lessons)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun updateScheduleWidget(
        date: String,
        group: String,
        lessons: List<Map<String, Any?>>?
    ) {
        val prefs = getSharedPreferences(ScheduleWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(ScheduleWidgetProvider.KEY_DATE, date)
            .putString(ScheduleWidgetProvider.KEY_GROUP, group)
            .putString(ScheduleWidgetProvider.KEY_DATA, lessonsToJson(lessons))
            .apply()
        notifyScheduleWidgetUpdate()
    }

    private fun lessonsToJson(lessons: List<Map<String, Any?>>?): String {
        if (lessons.isNullOrEmpty()) return "[]"
        val arr = JSONArray()
        for (lesson in lessons) {
            val obj = JSONObject()
            obj.put("number", lesson["number"] ?: "")
            obj.put("subject", lesson["subject"] ?: "")
            obj.put("teacher", lesson["teacher"] ?: "")
            obj.put("startTime", lesson["startTime"] ?: "")
            obj.put("endTime", lesson["endTime"] ?: "")
            obj.put("building", lesson["building"] ?: "")
            lesson["lessonType"]?.let { obj.put("lessonType", it) }
            arr.put(obj)
        }
        return arr.toString()
    }

    private fun notifyScheduleWidgetUpdate() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val provider = ComponentName(this, ScheduleWidgetProvider::class.java)
        val ids = appWidgetManager.getAppWidgetIds(provider)
        if (ids.isNotEmpty()) {
            val intent = Intent(this, ScheduleWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(intent)
        }
    }
}

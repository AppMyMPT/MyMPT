package ru.merrcurys.my_mpt

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var appUpdateManager: AppUpdateManager? = null
    private var installStateListener: InstallStateUpdatedListener? = null

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

        val updateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.merrcurys.my_mpt/google_play_update"
        )
        updateChannel.setMethodCallHandler { call, result ->
            if (call.method == "checkAndRunDeferredUpdate") {
                checkAndRunGooglePlayUpdate(result)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        appUpdateManager?.appUpdateInfo?.addOnSuccessListener { appUpdateInfo ->
            if (appUpdateInfo.installStatus() == InstallStatus.DOWNLOADED) {
                appUpdateManager?.completeUpdate()
            }
        }
    }

    override fun onDestroy() {
        installStateListener?.let { listener ->
            appUpdateManager?.unregisterListener(listener)
        }
        installStateListener = null
        super.onDestroy()
    }

    private fun checkAndRunGooglePlayUpdate(result: MethodChannel.Result) {
        try {
            val manager = appUpdateManager ?: AppUpdateManagerFactory.create(this).also {
                appUpdateManager = it
            }
            manager.appUpdateInfo
                .addOnSuccessListener { appUpdateInfo ->
                    when {
                        appUpdateInfo.installStatus() == InstallStatus.DOWNLOADED -> {
                            manager.completeUpdate()
                            result.success(true)
                        }
                        appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                            appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) -> {
                            startGooglePlayFlexibleUpdate(manager, appUpdateInfo, result)
                        }
                        else -> result.success(false)
                    }
                }
                .addOnFailureListener {
                    result.success(false)
                }
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun startGooglePlayFlexibleUpdate(
        manager: AppUpdateManager,
        appUpdateInfo: AppUpdateInfo,
        result: MethodChannel.Result
    ) {
        try {
            ensureGooglePlayUpdateListener(manager)
            @Suppress("DEPRECATION")
            manager.startUpdateFlowForResult(
                appUpdateInfo,
                AppUpdateType.FLEXIBLE,
                this,
                GOOGLE_PLAY_UPDATE_REQUEST_CODE
            )
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun ensureGooglePlayUpdateListener(manager: AppUpdateManager) {
        if (installStateListener != null) return
        val listener = InstallStateUpdatedListener { state ->
            if (state.installStatus() == InstallStatus.DOWNLOADED) {
                manager.completeUpdate()
            }
        }
        installStateListener = listener
        manager.registerListener(listener)
    }

    private companion object {
        const val GOOGLE_PLAY_UPDATE_REQUEST_CODE = 7001
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

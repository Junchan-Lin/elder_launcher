package com.code_sky.customlancher

import android.app.role.RoleManager
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import android.view.View
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {

    private lateinit var appWidgetManager: AppWidgetManager
    private lateinit var appWidgetHost: AppWidgetHost
    private var pendingResult: MethodChannel.Result? = null
    private var pendingAppWidgetId: Int = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必須在 super.onCreate() 之前初始化：super.onCreate() 會同步觸發
        // configureFlutterEngine()，該函式已經需要用到 appWidgetHost/appWidgetManager。
        appWidgetManager = AppWidgetManager.getInstance(this)
        appWidgetHost = AppWidgetHost(this, APPWIDGET_HOST_ID)
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        appWidgetHost.startListening()
    }

    override fun onStop() {
        super.onStop()
        appWidgetHost.stopListening()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CONTACTS).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasTelephoneFeature" -> result.success(hasTelephoneFeature())
                "launchContactsApp" -> openContactsApp()
                "launchDialerWithNumber" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        openDialerWithNumber(number)
                    } else {
                        result.error("ARGUMENT_ERROR", "Number is null", null)
                    }
                }
                "startPhoneCall" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        startPhoneCall(number)
                    } else {
                        result.error("ARGUMENT_ERROR", "Number is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CORE).setMethodCallHandler { call, result ->
            when (call.method) {
                "canSetDefaultLauncher" -> result.success(canSetDefaultLauncher())
                "getDeprecatedFavAppIds" -> result.success(getDeprecatedFavAppIds())
                "setDefaultLauncher" -> setDefaultLauncher()
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WIDGETS).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAndBindWidget" -> pickAndBindWidget(result)
                "deleteWidget" -> {
                    val appWidgetId = call.argument<Int>("appWidgetId")
                    if (appWidgetId != null) {
                        appWidgetHost.deleteAppWidgetId(appWidgetId)
                        result.success(null)
                    } else {
                        result.error("ARGUMENT_ERROR", "appWidgetId is null", null)
                    }
                }
                "filterValidWidgetIds" -> {
                    val appWidgetIds = call.argument<List<Int>>("appWidgetIds") ?: emptyList()
                    val validIds = appWidgetIds.filter { appWidgetManager.getAppWidgetInfo(it) != null }
                    result.success(validIds)
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "widget_host_view",
            WidgetHostViewFactory(appWidgetHost, appWidgetManager)
        )
    }

    private fun hasTelephoneFeature(): Boolean {
        return packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
    }

    private fun openContactsApp() {
        try {
            val intent = Intent(Intent.ACTION_VIEW, ContactsContract.Contacts.CONTENT_URI)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openDialerWithNumber(number: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL)
            intent.data = Uri.parse("tel:$number")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startPhoneCall(number: String) {
        try {
            val intent = Intent(Intent.ACTION_CALL)
            intent.data = Uri.parse("tel:$number")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun canSetDefaultLauncher(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager?
            roleManager?.isRoleAvailable(RoleManager.ROLE_HOME) == true && !roleManager.isRoleHeld(RoleManager.ROLE_HOME)
        } else {
            false
        }
    }

    private fun getDeprecatedFavAppIds(): List<String> {
        val sharedPrefs = applicationContext.getSharedPreferences("key_apps", Context.MODE_PRIVATE)
        val deprecatedFavAppIds = sharedPrefs.getStringSet("key_favorites", emptySet<String>())
        return deprecatedFavAppIds?.toList() ?: emptyList()
    }

    private fun setDefaultLauncher() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager?
            if (roleManager != null && !roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                val roleRequestIntent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                startActivityForResult(roleRequestIntent, DEFAULT_LAUNCHER_INTENT_REQUEST_CODE)
            }
        }
    }

    private fun pickAndBindWidget(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("ALREADY_IN_PROGRESS", "A widget pick/configure flow is already in progress", null)
            return
        }
        pendingResult = result
        val appWidgetId = appWidgetHost.allocateAppWidgetId()
        pendingAppWidgetId = appWidgetId
        val pickIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_PICK)
        pickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        try {
            startActivityForResult(pickIntent, REQUEST_PICK_APPWIDGET)
        } catch (e: Exception) {
            e.printStackTrace()
            cancelPendingWidget()
        }
    }

    private fun finishAddWidget(appWidgetId: Int) {
        val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
        if (info == null) {
            appWidgetHost.deleteAppWidgetId(appWidgetId)
            pendingResult?.success(null)
            pendingResult = null
            pendingAppWidgetId = -1
            return
        }
        val density = resources.displayMetrics.densityDpi
        val previewDrawable = info.loadPreviewImage(this, density) ?: info.loadIcon(this, density)
        val iconBytes = previewDrawable?.let { drawableToBytes(it) }
        pendingResult?.success(
            mapOf(
                "appWidgetId" to appWidgetId,
                "label" to info.loadLabel(packageManager),
                "icon" to iconBytes,
                "minHeight" to info.minHeight
            )
        )
        pendingResult = null
        pendingAppWidgetId = -1
    }

    private fun cancelPendingWidget() {
        if (pendingAppWidgetId != -1) {
            appWidgetHost.deleteAppWidgetId(pendingAppWidgetId)
        }
        pendingAppWidgetId = -1
        pendingResult?.success(null)
        pendingResult = null
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            DEFAULT_LAUNCHER_INTENT_REQUEST_CODE -> {
                if (resultCode != RESULT_OK) {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let {
                        MethodChannel(it, CHANNEL_CORE).invokeMethod("setDefaultLauncherFailure", null)
                    }
                }
            }
            REQUEST_PICK_APPWIDGET -> {
                if (resultCode == RESULT_OK && data != null) {
                    val appWidgetId = data.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, pendingAppWidgetId)
                    val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
                    if (info?.configure != null) {
                        pendingAppWidgetId = appWidgetId
                        val configIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE)
                        configIntent.component = info.configure
                        configIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        try {
                            startActivityForResult(configIntent, REQUEST_CONFIGURE_APPWIDGET)
                        } catch (e: Exception) {
                            e.printStackTrace()
                            cancelPendingWidget()
                        }
                    } else {
                        finishAddWidget(appWidgetId)
                    }
                } else {
                    cancelPendingWidget()
                }
            }
            REQUEST_CONFIGURE_APPWIDGET -> {
                if (resultCode == RESULT_OK) {
                    finishAddWidget(pendingAppWidgetId)
                } else {
                    cancelPendingWidget()
                }
            }
        }
    }
}

private class WidgetHostViewFactory(
    private val appWidgetHost: AppWidgetHost,
    private val appWidgetManager: AppWidgetManager
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<*, *>
        val appWidgetId = (creationParams?.get("appWidgetId") as? Int) ?: -1
        return WidgetHostPlatformView(context, appWidgetHost, appWidgetManager, appWidgetId)
    }
}

private class WidgetHostPlatformView(
    context: Context,
    appWidgetHost: AppWidgetHost,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) : PlatformView {
    private val hostView: AppWidgetHostView = appWidgetHost.createView(
        context,
        appWidgetId,
        appWidgetManager.getAppWidgetInfo(appWidgetId)
    )

    override fun getView(): View = hostView

    override fun dispose() {}
}

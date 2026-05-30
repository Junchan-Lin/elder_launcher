package com.code_sky.customlancher

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DEFAULT_LAUNCHER_INTENT_REQUEST_CODE) {
            if (resultCode != RESULT_OK) {
                flutterEngine?.dartExecutor?.binaryMessenger?.let {
                    MethodChannel(it, CHANNEL_CORE).invokeMethod("setDefaultLauncherFailure", null)
                }
            }
        }
    }
}

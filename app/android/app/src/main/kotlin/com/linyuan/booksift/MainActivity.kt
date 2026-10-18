package com.linyuan.booksift

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingFontPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openTiebaOrBrowser") {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("bad_args", "url missing", null)
                } else {
                    result.success(openTiebaOrBrowser(url))
                }
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_FONT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestReadPermission") {
                requestReadFontsPermission(result)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("bad_args", "path missing", null)
                } else {
                    installApk(path, result)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Android 读取 /system/fonts 通常不需要权限；这里只在目录扫描遇 EACCES 时兜底请求
     * READ_EXTERNAL_STORAGE（仅 Android 12 及以下需要；13+ 直接让 Dart 侧重试目录）。
     */
    private fun requestReadFontsPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 23 ||
            Build.VERSION.SDK_INT >= 33 ||
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingFontPermissionResult != null) {
            result.error("in_progress", "font permission request already pending", null)
            return
        }
        pendingFontPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
            FONT_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != FONT_PERMISSION_REQUEST_CODE) return
        val result = pendingFontPermissionResult ?: return
        pendingFontPermissionResult = null
        result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
    }

    /** 依次尝试贴吧 App（官方 / 贴吧 Lite），都未安装则回落系统浏览器。返回是否走了贴吧系 App。 */
    private fun openTiebaOrBrowser(url: String): Boolean {
        for (pkg in TIEBA_PACKAGES) {
            if (tryLaunch(url, pkg)) {
                return true
            }
        }
        return tryLaunch(url, null)
    }

    private fun tryLaunch(url: String, pkg: String?): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addCategory(Intent.CATEGORY_BROWSABLE)
            if (pkg != null) intent.setPackage(pkg)
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val file = validatedUpdateFile(path)
            if (!file.name.endsWith(".apk", ignoreCase = true)) {
                result.error("bad_args", "update file is not an APK", null)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
            ) {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName"),
                    ),
                )
                result.error(
                    "permission_required",
                    "allow unknown app installs, then open the update package again",
                    null,
                )
                return
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.update-files", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK_MIME_TYPE)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("invalid_path", e.message ?: "update file path is not allowed", null)
        } catch (e: ActivityNotFoundException) {
            result.error("no_installer", "no Android package installer is available", null)
        } catch (e: IllegalArgumentException) {
            result.error("invalid_path", e.message ?: "update file path is not allowed", null)
        } catch (e: Exception) {
            result.error("install_failed", e.message ?: "unable to start APK installer", null)
        }
    }

    private fun validatedUpdateFile(path: String): File {
        val file = File(path).canonicalFile
        val allowedRoots = listOf(
            File(filesDir, UPDATE_DIRECTORY).canonicalFile,
            File(cacheDir, UPDATE_DIRECTORY).canonicalFile,
        )
        val allowed = allowedRoots.any { root ->
            file.path == root.path || file.path.startsWith(root.path + File.separator)
        }
        if (!allowed || !file.isFile || !file.canRead()) {
            throw SecurityException("update file must be a readable file under the app update directory")
        }
        return file
    }

    private companion object {
        const val CHANNEL = "booksift/external_launch"
        const val SYSTEM_FONT_CHANNEL = "booksift/system_fonts"
        const val UPDATE_CHANNEL = "booksift/update"
        const val FONT_PERMISSION_REQUEST_CODE = 4107
        const val UPDATE_DIRECTORY = "update-cache"
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"

        /** 官方贴吧 + 贴吧 Lite（huanchengfly 版）包名，按优先级排列。 */
        val TIEBA_PACKAGES = listOf("com.baidu.tieba", "com.huanchengfly.tieba.post")
    }
}

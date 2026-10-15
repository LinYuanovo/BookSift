package com.linyuan.booksift

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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

    private companion object {
        const val CHANNEL = "booksift/external_launch"

        /** 官方贴吧 + 贴吧 Lite（huanchengfly 版）包名，按优先级排列。 */
        val TIEBA_PACKAGES = listOf("com.baidu.tieba", "com.huanchengfly.tieba.post")
    }
}

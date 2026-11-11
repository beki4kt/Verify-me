package com.chekmi.app

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chekmi.app/audit_export",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareCsv") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val requestedName = call.argument<String>("fileName") ?: "chekmi-audit.csv"
                val fileName = requestedName.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val content = call.argument<String>("content") ?: ""
                val exportDirectory = File(cacheDir, "audit_exports").apply { mkdirs() }
                val exportFile = File(exportDirectory, fileName).apply { writeText(content) }
                val uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    exportFile,
                )
                val share = Intent(Intent.ACTION_SEND).apply {
                    type = "text/csv"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_SUBJECT, "CHEKMI audit export")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(share, "Export audit CSV"))
                result.success(null)
            } catch (error: Exception) {
                result.error("AUDIT_EXPORT_FAILED", error.message, null)
            }
        }
    }
}

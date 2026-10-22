package com.gorkem.ekspersiz

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Installation preferences must survive logout and updates, but must
        // never be restored onto a fresh install by Android Auto Backup.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ekspersiz/installation")
            .setMethodCallHandler { call, result ->
                if (call.method != "directory") {
                    result.notImplemented()
                } else {
                    try {
                        val directory = java.io.File(noBackupFilesDir, "installation")
                        if (!directory.isDirectory && !directory.mkdirs()) {
                            result.error("STORAGE_UNAVAILABLE", "Yerel tercih kaydedilemedi.", null)
                        } else {
                            result.success(directory.absolutePath)
                        }
                    } catch (_: Exception) {
                        result.error("STORAGE_UNAVAILABLE", "Yerel tercih kaydedilemedi.", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ekspersiz/integrity")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceId" -> result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
                    "token" -> {
                        val project = call.argument<String>("cloudProjectNumber")?.toLongOrNull()
                        val hash = call.argument<String>("requestHash")
                        if (project == null || hash == null) {
                            result.error("INVALID_REQUEST", "Cihaz doğrulaması başlatılamadı.", null)
                        } else {
                            val manager = IntegrityManagerFactory.createStandard(applicationContext)
                            manager.prepareIntegrityToken(StandardIntegrityManager.PrepareIntegrityTokenRequest.builder()
                                .setCloudProjectNumber(project).build())
                                .addOnSuccessListener { provider ->
                                    provider.request(StandardIntegrityManager.StandardIntegrityTokenRequest.builder()
                                        .setRequestHash(hash).build())
                                        .addOnSuccessListener { response -> result.success(response.token()) }
                                        .addOnFailureListener { result.error("INTEGRITY_FAILED", "Cihaz doğrulanamadı.", null) }
                                }
                                .addOnFailureListener { result.error("INTEGRITY_UNAVAILABLE", "Cihaz doğrulaması kullanılamıyor.", null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

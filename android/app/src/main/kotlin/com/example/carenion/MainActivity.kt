package com.example.carenion

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.carenion/maps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "openMap") {
                val address: String? = call.argument("address")
                if (address != null) {
                    try {
                        val gmmIntentUri = Uri.parse("geo:0,0?q=" + Uri.encode(address))
                        val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
                        mapIntent.setPackage("com.google.android.apps.maps")
                        
                        if (mapIntent.resolveActivity(packageManager) != null) {
                            startActivity(mapIntent)
                            result.success(true)
                        } else {
                            // Fallback to generic map app
                            val genericIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
                            startActivity(genericIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not open map.", e.message)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Address not provided", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

package com.example.smart_noties

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.fluttercommunity.plus/sensors/method"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAccelerationSamplingPeriod",
                "setGyroscopeSamplingPeriod",
                "setUserAccelerometerSamplingPeriod",
                "setMagnetometerSamplingPeriod" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}

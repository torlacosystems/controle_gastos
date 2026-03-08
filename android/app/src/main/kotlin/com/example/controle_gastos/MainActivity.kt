package com.example.controle_gastos

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    private val channel = "com.example.controle_gastos/widget"
    private var flutterChannel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == NovoGastoWidget.ACTION_NOVO_GASTO) {
            pendingAction = "novo_gasto"
        }
    }

    override fun onResume() {
        super.onResume()
        pendingAction?.let { action ->
            flutterChannel?.invokeMethod(action, null)
            pendingAction = null
        }
    }
}

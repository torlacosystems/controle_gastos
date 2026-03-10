package com.example.controle_gastos

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    private val channel = "com.example.controle_gastos/widget"
    private var flutterChannel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        flutterChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "get_pending_action" -> {
                    val action = pendingAction
                    pendingAction = null
                    result.success(action)
                }
                "pin_widget" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val manager = AppWidgetManager.getInstance(this)
                        val provider = ComponentName(this, NovoGastoWidget::class.java)
                        if (manager.isRequestPinAppWidgetSupported) {
                            manager.requestPinAppWidget(provider, null, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
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
        when (intent?.action) {
            NovoGastoWidget.ACTION_NOVO_GASTO -> pendingAction = "novo_gasto"
            NovoGastoWidget.ACTION_NOVA_RECEITA -> pendingAction = "nova_receita"
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

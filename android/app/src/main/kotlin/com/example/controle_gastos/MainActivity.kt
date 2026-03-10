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

    // Ação de cold start — lida pelo Flutter via get_pending_action
    private var coldStartAction: String? = null

    // Ação de resume (app já aberto) — enviada via invokeMethod quando HomeScreen está pronto
    private var resumeAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        flutterChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "get_pending_action" -> {
                    val action = coldStartAction
                    coldStartAction = null
                    result.success(action)
                }
                "check_widget_installed" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, NovoGastoWidget::class.java)
                    val ids = manager.getAppWidgetIds(provider)
                    result.success(ids.isNotEmpty())
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
        // Cold start: ação guardada para get_pending_action
        coldStartAction = actionFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App já aberto: ação enviada via invokeMethod no onResume
        resumeAction = actionFromIntent(intent)
    }

    private fun actionFromIntent(intent: Intent?): String? = when (intent?.action) {
        NovoGastoWidget.ACTION_NOVO_GASTO -> "novo_gasto"
        NovoGastoWidget.ACTION_NOVA_RECEITA -> "nova_receita"
        else -> null
    }

    override fun onResume() {
        super.onResume()
        resumeAction?.let { action ->
            flutterChannel?.invokeMethod(action, null)
            resumeAction = null
        }
    }
}

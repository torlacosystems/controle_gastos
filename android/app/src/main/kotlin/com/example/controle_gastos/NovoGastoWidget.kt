package com.example.controle_gastos

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class NovoGastoWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val intentGasto = Intent(context, MainActivity::class.java).apply {
                action = ACTION_NOVO_GASTO
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingGasto = PendingIntent.getActivity(
                context, 1, intentGasto,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val intentReceita = Intent(context, MainActivity::class.java).apply {
                action = ACTION_NOVA_RECEITA
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingReceita = PendingIntent.getActivity(
                context, 2, intentReceita,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.widget_novo_gasto)
            views.setOnClickPendingIntent(R.id.btn_gasto, pendingGasto)
            views.setOnClickPendingIntent(R.id.btn_receita, pendingReceita)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    companion object {
        const val ACTION_NOVO_GASTO = "com.example.controle_gastos.NOVO_GASTO"
        const val ACTION_NOVA_RECEITA = "com.example.controle_gastos.NOVA_RECEITA"
    }
}

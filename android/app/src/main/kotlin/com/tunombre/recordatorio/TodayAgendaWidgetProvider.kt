package com.tunombre.recordatorio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.view.View
import android.widget.RemoteViews
import com.google.assistant.appactions.widgets.AppActionsWidgetExtension
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

private val widgetTimeFormatter =
    DateTimeFormatter.ofPattern("HH:mm", Locale("es", "ES"))
private const val todayAgendaDatabaseName = "recordatorio.db"

class TodayAgendaWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val agenda = loadTodayAgendaSnapshot(context)
            val views = RemoteViews(context.packageName, R.layout.today_agenda_widget)

            views.setTextViewText(
                R.id.today_agenda_title,
                context.getString(R.string.today_agenda_widget_title),
            )
            views.setTextViewText(R.id.today_agenda_summary, agenda.summary)
            views.setTextViewText(R.id.today_agenda_items, agenda.itemsText)
            views.setViewVisibility(
                R.id.today_agenda_items,
                if (agenda.itemsText.isBlank()) View.GONE else View.VISIBLE,
            )

            val widgetExtension = AppActionsWidgetExtension.newBuilder(appWidgetManager)
                .setResponseSpeech(agenda.ttsText)
                .setResponseText(agenda.summary)
                .build()

            widgetExtension.updateWidget(appWidgetId)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

internal fun loadTodayAgendaSnapshot(context: Context): AgendaSnapshot {
    val databasePath = context.getDatabasePath(todayAgendaDatabaseName)
    if (!databasePath.exists()) {
        return AgendaSnapshot.empty(context)
    }

    return try {
        SQLiteDatabase.openDatabase(
            databasePath.path,
            null,
            SQLiteDatabase.OPEN_READONLY,
        ).use { database ->
            val today = LocalDate.now()
            val tomorrow = today.plusDays(1)
            val cursor = database.query(
                "reminders",
                arrayOf("title", "scheduled_at"),
                "is_completed = 0 AND scheduled_at >= ? AND scheduled_at < ?",
                arrayOf(
                    today.atStartOfDay().toString(),
                    tomorrow.atStartOfDay().toString(),
                ),
                null,
                null,
                "scheduled_at ASC",
            )

            val items = mutableListOf<AgendaItem>()
            cursor.use {
                while (it.moveToNext()) {
                    val title = it.getString(0) ?: continue
                    val scheduledAt = it.getString(1) ?: continue
                    val parsed = runCatching {
                        LocalDateTime.parse(scheduledAt)
                    }.getOrNull() ?: continue
                    items += AgendaItem(
                        title = title,
                        scheduledAt = parsed,
                    )
                }
            }

            AgendaSnapshot.fromItems(context, items)
        }
    } catch (_: Exception) {
        AgendaSnapshot.empty(context)
    }
}

internal data class AgendaItem(
    val title: String,
    val scheduledAt: LocalDateTime,
)

internal data class AgendaSnapshot(
    val summary: String,
    val itemsText: String,
    val ttsText: String,
) {
    companion object {
        fun empty(context: Context): AgendaSnapshot {
            val text = context.getString(R.string.today_agenda_widget_empty)
            return AgendaSnapshot(
                summary = text,
                itemsText = "",
                ttsText = text,
            )
        }

        fun fromItems(
            context: Context,
            items: List<AgendaItem>,
        ): AgendaSnapshot {
            if (items.isEmpty()) {
                return empty(context)
            }

            val previewItems = items.take(4)
            val itemsText = previewItems.joinToString(separator = "\n") { item ->
                "${item.scheduledAt.format(widgetTimeFormatter)} ${item.title}"
            }
            val summary = when (items.size) {
                1 -> "Hoy tienes 1 recordatorio pendiente."
                else -> "Hoy tienes ${items.size} recordatorios pendientes."
            }
            val tts = buildString {
                append(summary)
                append(' ')
                append(
                    previewItems.joinToString(separator = ", ") { item ->
                        "${item.scheduledAt.format(widgetTimeFormatter)} ${item.title}"
                    },
                )
                if (items.size > previewItems.size) {
                    append(". ")
                    append(
                        context.getString(
                            R.string.today_agenda_widget_more,
                            items.size - previewItems.size,
                        ),
                    )
                }
            }

            return AgendaSnapshot(
                summary = summary,
                itemsText = itemsText,
                ttsText = tts,
            )
        }
    }
}

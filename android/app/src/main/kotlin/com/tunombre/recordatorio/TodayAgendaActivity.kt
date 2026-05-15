package com.tunombre.recordatorio

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

class TodayAgendaActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_today_agenda)

        val snapshot = loadTodayAgendaSnapshot(this)
        findViewById<TextView>(R.id.today_agenda_activity_summary).text = snapshot.summary

        val itemsView = findViewById<TextView>(R.id.today_agenda_activity_items)
        itemsView.text = snapshot.itemsText
        if (snapshot.itemsText.isBlank()) {
            itemsView.text = getString(R.string.today_agenda_widget_empty)
        }

        findViewById<Button>(R.id.today_agenda_activity_close).setOnClickListener {
            finish()
        }
    }
}

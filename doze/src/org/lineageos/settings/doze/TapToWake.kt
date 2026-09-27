/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.doze

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import java.io.File

/**
 * Tap to wake: the Focaltech touch driver reports KEY_WAKEUP for a tap on the screen while it
 * sleeps once its gesture mode is on. Stock turns the mode on itself and the stock power HAL does
 * not handle the DOUBLE_TAP_TO_WAKE mode, so follow Settings.Secure.DOUBLE_TAP_TO_WAKE here. The
 * driver takes the write only while the panel is awake, so apply on every screen on as well.
 */
object TapToWake {
    private const val TAG = "TapToWake"

    fun init(context: Context) {
        val node = File(context.getString(R.string.tap_to_wake_node))
        if (node.path.isEmpty() || !node.exists()) {
            Log.w(TAG, "No tap to wake node")
            return
        }
        val apply = { write(context, node) }
        context.contentResolver.registerContentObserver(
            Settings.Secure.getUriFor(Settings.Secure.DOUBLE_TAP_TO_WAKE),
            false,
            object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) = apply()
            },
        )
        context.registerReceiver(
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) = apply()
            },
            IntentFilter(Intent.ACTION_SCREEN_ON),
        )
        apply()
    }

    private fun write(context: Context, node: File) {
        // def_double_tap_to_wake is true: on unless the user turned it off
        val on = Settings.Secure.getInt(
            context.contentResolver, Settings.Secure.DOUBLE_TAP_TO_WAKE, 1) != 0
        try {
            node.writeText(if (on) "1" else "0")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write ${node.path}", e)
        }
    }
}

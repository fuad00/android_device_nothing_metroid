/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.doze

import android.app.Application

class DozeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // the app is persistent: this runs at boot and whenever the process is restarted
        TapToWake.init(this)
    }
}

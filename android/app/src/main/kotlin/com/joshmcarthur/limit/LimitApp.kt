package com.joshmcarthur.limit

import android.app.Application

class LimitApp : Application() {
    lateinit var driveModel: DriveModel
        private set

    override fun onCreate() {
        super.onCreate()
        driveModel = DriveModel(this)
    }
}

package com.joshmcarthur.limit

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.joshmcarthur.limit.ui.RootScreen
import com.joshmcarthur.limit.ui.theme.LimitTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val model = (application as LimitApp).driveModel
        setContent {
            LimitTheme {
                RootScreen(model)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        (application as LimitApp).driveModel.refreshAccess()
    }
}

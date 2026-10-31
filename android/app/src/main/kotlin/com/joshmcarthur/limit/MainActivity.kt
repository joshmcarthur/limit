package com.joshmcarthur.limit

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.joshmcarthur.limit.ui.RootScreen
import com.joshmcarthur.limit.ui.theme.LimitTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val model = (application as LimitApp).driveModel
        setContent {
            LimitTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    RootScreen(model)
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        (application as LimitApp).driveModel.onForeground()
    }
}

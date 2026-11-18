package com.example.cmp_hello

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import dev.maduikit.demo.generated.FigmaProfileScreen

/** All platform entries use the same composable; the host adds no page UI. */
@Composable
fun App() {
    MaterialTheme {
        Surface { FigmaProfileScreen() }
    }
}

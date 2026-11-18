package com.example.cmp_hello

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import com.mad.maduikit.MadTheme
import com.mad.maduikit.MadFilterTabs
import com.mad.maduikit.MadFilterTab
import dev.maduikit.demo.generated.FigmaProfileScreen

/** Synthetic data only; compile/link gate, not runtime verification. */
@Composable
fun App() {
    var selected by remember { mutableStateOf(0) }
    MadTheme {
        Column {
            MadFilterTabs {
                listOf("Books", "Favorites").forEachIndexed { index, label ->
                    MadFilterTab(selected = selected == index, onSelect = { selected = index }) {
                        Text(label)
                    }
                }
            }
            Text("Selected: $selected")
            FigmaProfileScreen()
        }
    }
}

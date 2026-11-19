package dev.mad.adoption

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.ComposeUIViewController
import com.mad.maduikit.MadTheme
import dev.maduikit.demo.generated.FigmaProfileScreen

fun makeDemoViewController() = ComposeUIViewController {
    MadTheme {
        var selected by remember { mutableStateOf(false) }
        var requests by remember { mutableIntStateOf(0) }
        Column(Modifier.padding(top = 80.dp)) {
            BasicText("Generated typed component + font role")
            BasicText("Selection requests: $requests")
            BasicText("Selected: $selected")
            FigmaProfileScreen(
                selected = selected,
                onSelect = { requests++; selected = true },
                fontRoleBody = FontFamily.Serif,
            )
        }
    }
}

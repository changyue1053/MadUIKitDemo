package dev.mad.adoption

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadTheme
import dev.maduikit.demo.generated.FigmaProfileScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MadTheme {
                var selected by remember { mutableStateOf(false) }
                var requests by remember { mutableIntStateOf(0) }
                Column(Modifier.safeDrawingPadding().padding(top = 16.dp)) {
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
    }
}

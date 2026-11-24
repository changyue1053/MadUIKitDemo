package dev.mad.synthetic.typography

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadActionButton
import com.mad.maduikit.MadButtonVariant
import com.mad.maduikit.MadText
import com.mad.maduikit.MadTheme

@Composable
fun ActionGallery() {
    var running by remember { mutableStateOf(false) }
    var starts by remember { mutableStateOf(0) }
    var completions by remember { mutableStateOf(0) }
    var denied by remember { mutableStateOf(0) }
    val actionWidth = Modifier.width(240.dp)
    MadTheme(darkTheme = false) {
        Column(
            Modifier.fillMaxWidth().background(Color.White).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            MadText("Action buttons · alpha10", modifier = Modifier.testTag("actions-title"))
            MadText("Start an operation, then complete it manually.")
            MadActionButton(
                label = "Start operation",
                variant = MadButtonVariant.Primary,
                enabled = true, // Loading must override an otherwise-enabled input.
                loadingStatus = if (running) "In progress" else null,
                onClick = { starts++; running = true },
                modifier = actionWidth.testTag("start-action"),
            )
            MadActionButton(
                label = "Complete operation",
                variant = MadButtonVariant.Secondary,
                enabled = running,
                onClick = { completions++; running = false },
                modifier = actionWidth.testTag("complete-action"),
            )
            MadActionButton(
                label = "Delete operation",
                variant = MadButtonVariant.Danger,
                enabled = false,
                onClick = { denied++ },
                modifier = actionWidth.testTag("disabled-action"),
            )
            val phase = if (running) "In progress" else "Ready"
            MadText("State: $phase", modifier = Modifier.testTag("actions-phase"))
            MadText("Starts: $starts / Completions: $completions / Disabled: $denied",
                modifier = Modifier.testTag("actions-counters"))
        }
    }
}

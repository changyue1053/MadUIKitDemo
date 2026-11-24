package dev.mad.synthetic.typography

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadCheckbox
import com.mad.maduikit.MadIconButton
import com.mad.maduikit.MadSwitch
import com.mad.maduikit.MadText

private object CatalogPainter : Painter() {
    override val intrinsicSize = Size(20f, 20f)
    override fun DrawScope.onDraw() {
        drawLine(Color.Black, Offset(size.width / 5f, size.height / 2f),
            Offset(size.width * 4f / 5f, size.height / 2f), strokeWidth = size.width / 8f)
        drawLine(Color.Black, Offset(size.width / 2f, size.height / 5f),
            Offset(size.width / 2f, size.height * 4f / 5f), strokeWidth = size.width / 8f)
    }
}

@Composable
fun ControlsCatalog() {
    var checkbox by remember { mutableStateOf(false) }
    var switch by remember { mutableStateOf(false) }
    var checkboxRequests by remember { mutableStateOf(0) }
    var switchRequests by remember { mutableStateOf(0) }
    var actions by remember { mutableStateOf(0) }
    var blocked by remember { mutableStateOf(0) }
    Column(Modifier.fillMaxWidth().padding(24.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
        MadText("Settings controls · alpha07", modifier = Modifier.testTag("catalog"))
        MadCheckbox(label = "Include reminders", checked = checkbox, onCheckedChange = { request ->
            checkboxRequests += 1
            if (checkboxRequests > 1) checkbox = request // First tap is declined; next taps are host-owned.
        }, modifier = Modifier.fillMaxWidth().testTag("checkbox"))
        MadText("Checkbox: ${if (checkbox) "on" else "off"} / $checkboxRequests", modifier = Modifier.testTag("checkbox-status"))
        MadSwitch(label = "Sync changes", checked = switch, onCheckedChange = { request ->
            switchRequests += 1
            switch = request
        }, modifier = Modifier.fillMaxWidth().testTag("switch"))
        MadText("Switch: ${if (switch) "on" else "off"} / $switchRequests", modifier = Modifier.testTag("switch-status"))
        MadIconButton(painter = CatalogPainter, label = "Add shortcut", onClick = { actions += 1 },
            modifier = Modifier.testTag("add"))
        MadText("Shortcuts: $actions", modifier = Modifier.testTag("actions-status"))
        MadText("Disabled controls")
        MadCheckbox(label = "Locked reminders", checked = false, onCheckedChange = { blocked += 1 },
            modifier = Modifier.fillMaxWidth().testTag("locked-checkbox"), enabled = false)
        MadSwitch(label = "Locked sync", checked = false, onCheckedChange = { blocked += 1 },
            modifier = Modifier.fillMaxWidth().testTag("locked-switch"), enabled = false)
        MadIconButton(painter = CatalogPainter, label = "Locked shortcut", onClick = { blocked += 1 },
            modifier = Modifier.testTag("locked-add"), enabled = false)
        MadText("Blocked callbacks: $blocked", modifier = Modifier.testTag("blocked-status"))
    }
}

package dev.mad.synthetic.typography

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.painter.Painter
import com.mad.maduikit.MadIcon
import com.mad.maduikit.MadIconButton
import com.mad.maduikit.MadSwitch

@Composable
fun ControlsProbe(
    painter: Painter,
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    onRefresh: () -> Unit,
) {
    MadSwitch(label = "Sync library", checked = checked, enabled = enabled, onCheckedChange = onCheckedChange)
    MadIcon(painter = painter, contentDescription = "Library status")
    MadIconButton(painter = painter, label = "Refresh library", enabled = enabled, onClick = onRefresh)
}

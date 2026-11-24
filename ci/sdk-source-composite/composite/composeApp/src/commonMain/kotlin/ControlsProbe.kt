package dev.mad.synthetic.typography

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.Painter
import com.mad.maduikit.MadCheckbox
import com.mad.maduikit.MadIcon
import com.mad.maduikit.MadIconButton
import com.mad.maduikit.MadRadio
import com.mad.maduikit.MadSwitch

enum class SelectionMode { ONLINE, OFFLINE }

data class SelectionSettings(
    val mode: SelectionMode = SelectionMode.ONLINE,
    val includeReminders: Boolean = false,
    val syncLibrary: Boolean = false,
)

@Composable
fun ControlsProbe(
    painter: Painter,
    settings: SelectionSettings,
    enabled: Boolean,
    onSettingsRequest: (SelectionSettings) -> Unit,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        Column(Modifier.selectableGroup()) {
            MadRadio(label = "Online", selected = settings.mode == SelectionMode.ONLINE,
                onSelect = { onSettingsRequest(settings.copy(mode = SelectionMode.ONLINE)) }, enabled = enabled)
            MadRadio(label = "Offline", selected = settings.mode == SelectionMode.OFFLINE,
                onSelect = { onSettingsRequest(settings.copy(mode = SelectionMode.OFFLINE)) }, enabled = enabled)
        }
        MadCheckbox(label = "Include reminders", checked = settings.includeReminders,
            onCheckedChange = { checked -> onSettingsRequest(settings.copy(includeReminders = checked)) },
            enabled = enabled)
        MadSwitch(label = "Sync library", checked = settings.syncLibrary,
            onCheckedChange = { checked -> onSettingsRequest(settings.copy(syncLibrary = checked)) },
            enabled = enabled)
        MadIcon(painter = painter, contentDescription = "Library status")
        MadIconButton(painter = painter, label = "Refresh library", enabled = enabled, onClick = onRefresh)
    }
}

package dev.mad.synthetic.typography

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.Painter
import com.mad.maduikit.MadConfirmDialog
import com.mad.maduikit.MadLinearProgress
import com.mad.maduikit.MadNavigationBar
import com.mad.maduikit.MadNavigationItem

@Composable
fun FlowProbe(
    libraryIcon: Painter,
    settingsIcon: Painter,
    selected: String,
    onNavigate: (String) -> Unit,
    progress: Float?,
    visible: Boolean,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        MadNavigationBar(
            items = listOf(
                MadNavigationItem(id = "library", label = "Library", painter = libraryIcon, enabled = true),
                MadNavigationItem(id = "settings", label = "Settings", painter = settingsIcon, enabled = true),
            ),
            selectedId = selected, onDestinationRequest = onNavigate,
        )
        MadLinearProgress(fraction = progress, label = "Sync progress")
        MadConfirmDialog(
            visible = visible, title = "Discard changes?", message = "Unsaved changes will be lost.",
            confirmLabel = "Discard", cancelLabel = "Keep editing",
            onConfirm = onConfirm, onCancel = onCancel, onDismissRequest = onDismiss,
            dismissOnBackPress = true, dismissOnClickOutside = false,
        )
    }
}

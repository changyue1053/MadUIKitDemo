package dev.mad.synthetic.typography

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.input.TextFieldValue
import com.mad.maduikit.*

@Composable
fun WorkspaceProbe(
    icon: Painter,
    value: TextFieldValue,
    onEdit: (TextFieldValue) -> Unit,
    onSearch: () -> Unit,
    onClear: () -> Unit,
    showingSheet: Boolean,
    onCloseSheet: () -> Unit,
    modifier: Modifier = Modifier,
) {
    MadScaffold(modifier = modifier, topBar = { MadTopAppBar(if (value.text.isEmpty()) "Workspace" else "Workspace draft") }) {
        Column {
            MadBanner(MadBannerTone.Warning, "Offline preview", "Changes remain local")
            MadStatePanel(MadPanelState.Empty, "No entries", message = "Try a new search")
            MadTextArea("Notes", value, onEdit, minVisibleLines = 2, maxVisibleLines = 4)
            MadDecoratedTextField("Display name", value, onEdit, placeholder = "Sample name", leading = icon)
            MadSearchFieldWithClear("Search workspace", value, onEdit, onSearch,
                clearLabel = "Clear query", clearIcon = icon, onClearRequest = onClear)
        }
    }
    MadBottomSheet(showingSheet, "Workspace settings", "Configure this view", "Close settings", onCloseSheet)
}

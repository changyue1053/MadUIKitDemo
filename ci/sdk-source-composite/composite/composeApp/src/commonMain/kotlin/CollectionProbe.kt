package dev.mad.synthetic.typography

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.input.TextFieldValue
import com.mad.maduikit.MadAvatar
import com.mad.maduikit.MadBorderRole
import com.mad.maduikit.MadCard
import com.mad.maduikit.MadListItem
import com.mad.maduikit.MadSearchField

@Composable
fun CollectionProbe(
    query: TextFieldValue,
    onQuery: (TextFieldValue) -> Unit,
    onSearch: () -> Unit,
    onOpen: () -> Unit,
    painter: Painter?,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        MadSearchField(label = "Search library", value = query, onValueChange = onQuery, onSearch = onSearch)
        MadCard(borderRole = MadBorderRole.Subtle) {
            MadAvatar(contentDescription = "Library avatar", painter = painter, initials = "LB")
            MadListItem(label = "Library", supportingText = "Open the collection", onClick = onOpen)
        }
    }
}

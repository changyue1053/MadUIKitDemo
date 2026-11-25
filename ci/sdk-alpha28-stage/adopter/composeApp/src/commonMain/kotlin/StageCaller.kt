package dev.mad.synthetic.stage

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.input.TextFieldValue
import com.mad.maduikit.MadFieldLength
import com.mad.maduikit.MadScaffold
import com.mad.maduikit.MadTextArea

@Composable
fun StageCaller(draft: TextFieldValue, onEdit: (TextFieldValue) -> Unit) {
    MadScaffold {
        Column {
            MadTextArea("Notes", draft, onEdit)
            val count = draft.text.length
            MadFieldLength(current = count, limit = 12, message = "Sample UTF-16 units: $count / 12")
        }
    }
}

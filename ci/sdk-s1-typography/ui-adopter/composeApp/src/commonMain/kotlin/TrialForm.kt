package dev.mad.synthetic.typography

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadBadge
import com.mad.maduikit.MadButton
import com.mad.maduikit.MadText
import com.mad.maduikit.MadTextField
import com.mad.maduikit.MadTheme

@Composable
fun TrialForm() {
    var name by remember { mutableStateOf(TextFieldValue("ab", TextRange(2))) }
    var note by remember { mutableStateOf(TextFieldValue()) }
    var locked by remember { mutableStateOf(TextFieldValue("ABC")) }
    var disabled by remember { mutableStateOf(TextFieldValue("XYZ")) }
    var forbiddenEdits by remember { mutableStateOf(0) }
    var focused by remember { mutableStateOf("None") }
    var submissions by remember { mutableStateOf(0) }
    var committed by remember { mutableStateOf("None") }
    val focusManager = LocalFocusManager.current
    val second = remember { FocusRequester() }
    val validName = name.text.length >= 4
    val canSubmit = validName && note.text.isNotBlank() && submissions == 0
    fun submit() {
        if (!validName || note.text.isBlank() || submissions != 0) return
        committed = "${name.text},${note.text}"
        submissions += 1
        focusManager.clearFocus()
    }
    fun track(tag: String, label: String) = Modifier.fillMaxWidth().testTag(tag).onFocusChanged {
        if (it.isFocused) focused = label else if (focused == label) focused = "None"
    }
    MadTheme(darkTheme = false) {
        Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp)) {
            MadText("Sample form · alpha12", modifier = Modifier.testTag("form-title"))
            MadTextField(
                label = "Display name", value = name, onValueChange = { name = it },
                modifier = track("form-name", "Name"), supportingText = "Use a public name",
                errorMessage = if (validName) null else "Use at least 4 characters",
                keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { second.requestFocus() }),
            )
            MadTextField(
                label = "Note", value = note, onValueChange = { note = it },
                modifier = track("form-note", "Note").focusRequester(second),
                keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { submit() }),
            )
            MadText("Focus: $focused", modifier = Modifier.testTag("form-focus"))
            MadText("Values: ${name.text},${note.text}", modifier = Modifier.testTag("form-values"))
            MadButton("Submit", onClick = { submit() }, enabled = canSubmit, modifier = Modifier.testTag("form-submit"))
            MadBadge(text = if (submissions == 0) "Draft" else "Saved", modifier = Modifier.testTag("form-badge"),
                spokenLabel = if (submissions == 0) "Form is a draft" else "Form is saved")
            MadText("Submissions: $submissions / $committed", modifier = Modifier.testTag("form-count"))
            MadTextField(
                label = "Read-only ID", value = locked,
                onValueChange = { if (it.text != locked.text) forbiddenEdits++ else locked = it },
                readOnly = true, modifier = track("form-readonly", "Read-only"),
            )
            MadTextField(
                label = "Disabled ID", value = disabled,
                onValueChange = { if (it.text != disabled.text) forbiddenEdits++ },
                enabled = false, modifier = track("form-disabled", "Disabled"),
            )
            MadText("Locked: ${locked.text},${disabled.text} / Edits: $forbiddenEdits", modifier = Modifier.testTag("form-locked"))
        }
    }
}

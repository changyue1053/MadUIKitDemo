package dev.mad.synthetic.typography

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import com.mad.maduikit.*

private object ClearMark : Painter() {
    override val intrinsicSize = Size(24f, 24f)
    override fun DrawScope.onDraw() {
        val d = size.minDimension
        drawLine(Color.Black, Offset(d*.28f,d*.28f), Offset(d*.72f,d*.72f), d*.09f)
        drawLine(Color.Black, Offset(d*.72f,d*.28f), Offset(d*.28f,d*.72f), d*.09f)
    }
}

@Composable
fun AtlasSearchCounter() {
    var value by remember { mutableStateOf(TextFieldValue()) }
    var clears by remember { mutableStateOf(0) }
    var searches by remember { mutableStateOf(0) }
    var focused by remember { mutableStateOf(false) }
    val count = value.text.length // Explicit synthetic ASCII / UTF-16 fixture unit.
    val limit = 4
    val visibleCount = if (count > limit) "$count / $limit · Over limit" else "$count / $limit · Within limit"
    MadTheme(darkTheme = false, colors = MadColors(Color(0xff136657), Color.White)) {
        Column(Modifier.fillMaxSize().background(Color(0xffedf2ee)).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            MadTopAppBar("Atlas workspace")
            MadText("Search and field length", role = MadTextRole.Title, modifier = Modifier.testTag("counter-title"))
            MadCard(Modifier.fillMaxWidth(), borderRole = MadBorderRole.Subtle) {
                Column(Modifier.fillMaxWidth().padding(10.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    MadSearchFieldWithClear(
                        "Search drafts", value, { value = it }, onSearch = { searches++ },
                        clearLabel = "Clear draft query", clearIcon = ClearMark,
                        onClearRequest = {
                            clears++
                            if (clears > 1) value = TextFieldValue()
                        },
                        modifier = Modifier.fillMaxWidth().testTag("counter-query-input")
                            .onFocusChanged { focused = it.hasFocus },
                        supportingText = "A short sample, kept in this view only.",
                    )
                    MadFieldLength(count, limit, visibleCount, modifier = Modifier.testTag("counter-length"),
                        spokenMessage = visibleCount)
                    MadText("Typed: ${value.text.lowercase().ifEmpty { "—" }}", modifier = Modifier.testTag("counter-value"))
                    MadText(if (focused) "Editor focused" else "Editor unfocused", modifier = Modifier.testTag("counter-focus"))
                    MadText("Clears: $clears / Searches: $searches", modifier = Modifier.testTag("counter-events"))
                }
            }
            MadText("SYNTHETIC SAMPLE · MADUIKIT ALPHA28", role = MadTextRole.Label)
        }
    }
}

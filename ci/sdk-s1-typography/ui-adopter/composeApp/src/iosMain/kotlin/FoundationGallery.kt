package dev.mad.synthetic.typography

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadBorderRole
import com.mad.maduikit.MadBorderWidths
import com.mad.maduikit.MadButton
import com.mad.maduikit.MadColors
import com.mad.maduikit.MadCornerRole
import com.mad.maduikit.MadDivider
import com.mad.maduikit.MadGeometryDefaults
import com.mad.maduikit.MadRadio
import com.mad.maduikit.MadText
import com.mad.maduikit.MadTheme

@Composable
fun FoundationGallery() {
    var mode by remember { mutableStateOf("Online") }
    var requests by remember { mutableStateOf(0) }
    var subtle by remember { mutableStateOf(IntSize.Zero) }
    var strong by remember { mutableStateOf(IntSize.Zero) }
    val scale = LocalDensity.current.density
    val panelShape = RoundedCornerShape(MadGeometryDefaults.CornerRadii[MadCornerRole.Medium].dp)
    MadTheme(darkTheme = false) {
        Column(
            Modifier.fillMaxWidth().background(Color.White).padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            MadText("Foundation gallery · alpha09", modifier = Modifier.testTag("gallery-title"))
            PaletteSample("Light", "gallery-light")
            MadTheme(darkTheme = true) {
                PaletteSample("Dark", "gallery-dark")
            }
            MadTheme(darkTheme = false, colors = MadColors(Color(0xFF006B56), Color.White)) {
                PaletteSample("Brand", "gallery-brand")
            }
            PaletteSample("Restored", "gallery-restored")
            Column(Modifier.fillMaxWidth().background(Color(0xFFF2F4F7), panelShape).padding(horizontal = 8.dp)) {
                MadText("Dividers")
                MadDivider(color = Color(0xFF294766), modifier = Modifier.onSizeChanged { subtle = it })
                MadDivider(
                    role = MadBorderRole.Strong, borderWidths = MadBorderWidths(2, 3),
                    color = Color(0xFF294766), modifier = Modifier.padding(top = 8.dp).onSizeChanged { strong = it },
                )
                val bounded = if (subtle.width > 0 && subtle.width == strong.width) "bounded" else "invalid"
                MadText("Dividers: ${subtle.height}/${strong.height} px @ ${scale}x / $bounded", modifier = Modifier.testTag("gallery-geometry"))
            }
            Column(Modifier.fillMaxWidth().selectableGroup()) {
                MadRadio(label = "Online", selected = mode == "Online", onSelect = { mode = "Online"; requests++ },
                    modifier = Modifier.fillMaxWidth().testTag("gallery-online"))
                MadRadio(label = "Offline", selected = mode == "Offline", onSelect = { mode = "Offline"; requests++ },
                    modifier = Modifier.fillMaxWidth().testTag("gallery-offline"))
            }
            MadText("Mode: $mode / $requests", modifier = Modifier.testTag("gallery-mode"))
        }
    }
}

@Composable
private fun PaletteSample(label: String, tag: String) {
    MadButton(label, onClick = {}, modifier = Modifier.width(180.dp).testTag(tag))
}

package dev.mad.synthetic.typography

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mad.maduikit.MadButton
import com.mad.maduikit.MadProvideTypography
import com.mad.maduikit.MadSpacingDefaults
import com.mad.maduikit.MadText
import com.mad.maduikit.MadTextRole
import com.mad.maduikit.MadTypography

private val hostTypography = MadTypography(
    body = TextStyle(fontSize = 18.sp),
    title = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold),
    label = TextStyle(fontSize = 22.sp),
)

@Composable
fun TypographyAdopter(onTapObserved: () -> Unit = {}) {
    var count by remember { mutableIntStateOf(0) }
    val hostGap = MadSpacingDefaults.Standard.mediumDp.dp

    // Use exported Compose UI rather than adding a direct Foundation dependency.
    Layout(content = {
        MadProvideTypography(hostTypography) {
            MadText("Books", role = MadTextRole.Title)
            MadButton("Select book", onClick = {
                count++
                onTapObserved()
            })
        }
        // Same text and semantic role, explicitly outside the provider.
        MadText("Books", role = MadTextRole.Title)
        MadText("Selections: $count")
    }) { measurables, constraints ->
        val gap = hostGap.roundToPx()
        val childConstraints = constraints.copy(minWidth = 0, minHeight = 0)
        val rows = measurables.map { it.measure(childConstraints) }
        val width = (rows.maxOfOrNull { it.width } ?: 0)
            .coerceIn(constraints.minWidth, constraints.maxWidth)
        val height = (rows.sumOf { it.height } + gap * (rows.size - 1).coerceAtLeast(0))
            .coerceIn(constraints.minHeight, constraints.maxHeight)
        layout(width, height) {
            var y = 0
            rows.forEach {
                it.placeRelative(0, y)
                y += it.height + gap
            }
        }
    }
}

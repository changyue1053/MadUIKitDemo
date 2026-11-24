package dev.mad.synthetic.typography

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.constrainWidth
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.sp
import com.mad.maduikit.*
import kotlin.math.roundToInt

private val samples = listOf("metric-scoped", "metric-raw-scoped", "metric-outside",
    "metric-raw-outside", "metric-no-provider", "metric-raw-repeat")
private val candidateRoles = MadTypography(
    body = TextStyle(fontSize = 18.sp),
    title = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold),
    label = TextStyle(fontSize = 22.sp),
)
internal data class Geometry(val density: Float, val tokenPx: Int, val gaps: List<Int>) {
    fun publicReceipt(): String = "density=$density tokenPx=$tokenPx gaps=${gaps.joinToString(",")}"
}

@Composable
internal fun TypographyMetrics(
    onRow: (String, IntRect) -> Unit = { _, _ -> },
    onGeometry: (Geometry) -> Unit = {},
) {
    MaterialTheme(colorScheme = lightColorScheme(onSurface = Color.Black, background = Color.White)) {
        Surface(color = Color.White, contentColor = Color.Black) {
            val baseline = MaterialTheme.typography.titleLarge
            val density = LocalDensity.current
            val expectedPx = with(density) { 8.dp.roundToPx() }
            val sevenPx = with(density) { 7.dp.roundToPx() }
            val positions = remember { mutableStateMapOf<String, IntRect>() }
            val geometry = if (positions.keys.containsAll(samples)) {
                fun gap(a: Int, b: Int) = positions.getValue(samples[b]).top - positions.getValue(samples[a]).bottom
                Geometry(density.density, expectedPx, listOf(gap(0, 1), gap(2, 3), gap(4, 5)))
            } else null
            androidx.compose.runtime.LaunchedEffect(geometry) { geometry?.let(onGeometry) }
            fun tracked(i: Int) = Modifier.testTag(samples[i]).onGloballyPositioned {
                val p = it.positionInRoot()
                val rect = IntRect(p.x.roundToInt(), p.y.roundToInt(), p.x.roundToInt() + it.size.width, p.y.roundToInt() + it.size.height)
                positions[samples[i]] = rect
                onRow(samples[i], rect)
            }

            Layout(content = {
                MadProvideTypography(candidateRoles) {
                    MadText("Books", modifier = tracked(0), role = MadTextRole.Title)
                }
                // Independent known-good oracle: the test states the contract explicitly,
                // not via candidateRoles or the SDK provider under test.
                Text("Books", modifier = tracked(1),
                    style = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold))
                MadText("Books", modifier = tracked(2), role = MadTextRole.Title)
                Text("Books", modifier = tracked(3), style = baseline)
                // Semantic negative: same MadText call with missing provider.
                MadText("Books", modifier = tracked(4), role = MadTextRole.Title)
                Text("Books", modifier = tracked(5), style = baseline)
                Text(
                    geometry?.publicReceipt() ?: "pending",
                    modifier = Modifier.testTag("metric-geometry"),
                    style = MaterialTheme.typography.bodySmall,
                )
            }) { measurables, constraints ->
                val row = measurables.map { it.measure(constraints.copy(minWidth = 0, minHeight = 0)) }
                val actualSdkGap = MadSpacingDefaults.Standard.mediumDp.dp.roundToPx()
                val gaps = listOf(actualSdkGap, expectedPx, sevenPx, expectedPx, 8, expectedPx)
                check(row.size == 7)
                val height = row.sumOf { it.height } + gaps.sum()
                layout(constraints.constrainWidth(row.maxOf { it.width }), constraints.constrainHeight(height)) {
                    var y = 0
                    row.forEachIndexed { i, it ->
                        it.placeRelative(0, y)
                        y += it.height + gaps.getOrElse(i) { 0 }
                    }
                }
            }
        }
    }
}

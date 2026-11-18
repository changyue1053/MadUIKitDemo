package dev.maduikit.demo

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadFilterTabs
import com.mad.maduikit.MadFilterTab
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.mad.maduikit.MadTheme
import dev.maduikit.demo.generated.FigmaProfileScreen

/** Isolated P5 screenshot host for unchanged generated source and the staged SDK. */
@Composable
fun DemoScreen() {
    MadTheme(darkTheme = false) {
        Scaffold { insets ->
            Column(Modifier.fillMaxSize().padding(insets)) {
                FigmaProfileScreen()
                SyntheticBookFilterSmoke()
            }
        }
    }
}


// Public source-only fixture for the standard hosted iOS simulator UI test.
@Composable
private fun SyntheticBookFilterSmoke() {
    var selected by remember { mutableIntStateOf(0) }
    var requests by remember { mutableIntStateOf(0) }
    val titles = listOf("All books", "Favorites", "Unavailable")
    val tags = listOf("books-all", "books-favorites", "books-unavailable")
    Column(Modifier.padding(start = 12.dp, end = 12.dp, top = 8.dp)) {
        MadFilterTabs(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            titles.forEachIndexed { i, title ->
                val active = i == selected
                MadFilterTab(
                    selected = active,
                    enabled = i != 2,
                    onSelect = { requests++; selected = i },
                    modifier = Modifier.testTag(tags[i]).sizeIn(minHeight = 48.dp).background(
                        if (active) Color(0xFF314C81) else Color(0xFFE3E9F4)
                    ),
                ) {
                    Text(title, Modifier.align(Alignment.Center).padding(horizontal = 8.dp),
                         color = if (active) Color.White else Color(0xFF23304B))
                }
            }
        }
        Text("Selected filter: ${titles[selected]}")
        Text("Selection requests: $requests")
    }
}

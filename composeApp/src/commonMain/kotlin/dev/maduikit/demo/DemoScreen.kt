package dev.maduikit.demo

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
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
            }
        }
    }
}

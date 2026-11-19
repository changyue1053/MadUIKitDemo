package dev.mad.adoption
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import com.mad.maduikit.MadTheme
import com.mad.maduikit.MadFilterTabs
import com.mad.maduikit.MadFilterTab
class MainActivity : ComponentActivity() {
 override fun onCreate(savedInstanceState: Bundle?) {
  super.onCreate(savedInstanceState)
  setContent {
   MadTheme {
    var selected by remember { mutableIntStateOf(0) }
    MadFilterTabs {
     listOf("All books", "Favorites").forEachIndexed { i, label ->
      MadFilterTab(selected = selected == i, onSelect = { selected = i }) { BasicText(label) }
     }
    }
   }
  }
 }
}

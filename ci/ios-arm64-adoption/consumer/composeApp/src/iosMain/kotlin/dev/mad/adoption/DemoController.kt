package dev.mad.adoption
import androidx.compose.ui.window.ComposeUIViewController
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.text.BasicText
import com.mad.maduikit.MadTheme
import com.mad.maduikit.MadFilterTabs
import com.mad.maduikit.MadFilterTab
fun makeDemoViewController() = ComposeUIViewController {
 MadTheme { Column {
  BasicText("Independent iOS SDK consumer")
  MadFilterTabs {
   MadFilterTab(selected=true,onSelect={}) { BasicText("All books") }
   MadFilterTab(selected=false,onSelect={}) { BasicText("Favorites") }
  }
 } }
}

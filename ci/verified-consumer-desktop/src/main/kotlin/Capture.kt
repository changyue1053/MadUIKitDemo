import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.unit.Density
import dev.maduikit.demo.DemoScreen
import java.io.File
import org.jetbrains.skia.EncodedImageFormat
import kotlin.system.exitProcess

/** Native Desktop evidence only; no Android/iOS/Harmony runtime assertion. */
@OptIn(ExperimentalComposeUiApi::class)
fun main(args: Array<String>) {
    require(args.size == 1) { "Pass output PNG path" }
    val scene = ImageComposeScene(width = 390, height = 560, density = Density(1f, 1f)) {
        DemoScreen()
    }
    try {
        scene.render(0L).close()
        scene.render(16_666_667L).use { image ->
            checkNotNull(image.encodeToData(EncodedImageFormat.PNG)).use {
                File(args.single()).writeBytes(it.bytes)
            }
        }
    } finally { scene.close() }
    println("Native Desktop rendered actual DemoScreen with verified synthetic source and SDK theme source adapter.")
    exitProcess(0)
}

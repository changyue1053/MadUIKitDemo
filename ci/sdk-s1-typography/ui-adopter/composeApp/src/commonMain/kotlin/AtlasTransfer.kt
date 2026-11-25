package dev.mad.synthetic.typography

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mad.maduikit.*

private val navy = Color(0xff132a35)
private val jade = Color(0xff136657)
private val paper = Color(0xffedf2ee)
private val mint = Color(0xffc5eedb)
private val hair = Color(0xffccdbd3)

private class AtlasMark(private val route: Int) : Painter() {
    override val intrinsicSize = Size(24f, 24f)
    override fun DrawScope.onDraw() {
        val g = size.width / 24f
        fun line(x: Float, y: Float, u: Float, v: Float) =
            drawLine(jade, Offset(x*g,y*g), Offset(u*g,v*g), strokeWidth = 1.8f*g)
        if (route == 0) {
            line(3f,11f,12f,4f); line(12f,4f,21f,11f)
            line(6f,9f,6f,20f); line(18f,9f,18f,20f); line(6f,20f,18f,20f)
        } else {
            line(4f,8f,20f,8f); line(15f,3f,20f,8f); line(15f,13f,20f,8f)
            line(20f,17f,4f,17f); line(4f,17f,9f,12f); line(4f,17f,9f,22f)
        }
    }
}

@Composable
private fun TransferMeta(text: String, color: Color = jade) {
    BasicText(text, style = TextStyle(color = color, fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium, fontSize = 11.sp, letterSpacing = 0.7.sp))
}

@Composable
fun AtlasTransfer() {
    val tabs = remember { listOf(
        MadNavigationItem("overview", "Overview", AtlasMark(0)),
        MadNavigationItem("transfers", "Transfers", AtlasMark(1)),
    ) }
    var destination by remember { mutableStateOf("overview") }
    var requests by remember { mutableStateOf(0) }
    var fraction by remember { mutableStateOf<Float?>(null) }
    var showing by remember { mutableStateOf(false) }
    var paused by remember { mutableStateOf(false) }
    var cancels by remember { mutableStateOf(0) }
    var confirms by remember { mutableStateOf(0) }
    var dismissals by remember { mutableStateOf(0) }
    var details by remember { mutableStateOf(0) }
    MadTheme(darkTheme = false, colors = MadColors(jade, Color.White)) {
        Column(Modifier.fillMaxSize().background(paper).padding(15.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Row(Modifier.fillMaxWidth(),horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                TransferMeta("ATLAS STUDIO")
                MadActionButton("Workspace details", MadButtonVariant.Text, onClick = { details++ },
                    modifier = Modifier.testTag("transfer-details"))
            }
            MadCard(Modifier.fillMaxWidth(), cornerRole = MadCornerRole.Large) {
                Box(Modifier.fillMaxWidth().background(navy)) {
                    Canvas(Modifier.matchParentSize()) {
                        val focal = Offset(size.width * .88f, size.height * .65f)
                        for (n in 1..6) drawCircle(Color(0xff427265), radius = n * 16.dp.toPx(),
                            center = focal, style = Stroke(1.dp.toPx()))
                        drawCircle(mint, radius = 4.dp.toPx(), center = focal)
                    }
                    Column(Modifier.padding(14.dp)) {
                        TransferMeta("ATLAS / WORKSPACE TRANSFER", mint)
                        BasicText("Transfer center", Modifier.testTag("transfer-title"),
                            style = TextStyle(color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.SemiBold))
                        BasicText("Move files without losing your place.", style = TextStyle(color = mint, fontSize = 13.sp))
                    }
                }
            }
            MadCard(Modifier.fillMaxWidth(), borderRole = MadBorderRole.Subtle) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    TransferMeta("TRANSFER #A–042")
                    MadText("Export design system", role = MadTextRole.Title)
                    MadDivider(color = hair)
                    val progress = if (fraction == null) "Estimating" else "42%"
                    MadText("Progress: $progress", modifier = Modifier.testTag("transfer-progress-text"))
                    MadLinearProgress(fraction, label = "Workspace transfer progress")
                    MadText(if(fraction == null) "Preparing the file list." else "42 of 100 sample files copied.")
                    MadActionButton("Resolve estimate", MadButtonVariant.Secondary, onClick = { fraction = .42f },
                        enabled = fraction == null, modifier = Modifier.testTag("transfer-resolve"))
                }
            }
            MadCard(Modifier.fillMaxWidth(), borderRole = MadBorderRole.Subtle) {
                MadNavigationBar(tabs, destination, { requests++; if (requests > 1) destination = it })
            }
            val route = if(destination == "overview") "Overview" else "Transfers"
            MadText("Selected: $route / Requests: $requests", modifier = Modifier.testTag("transfer-route"))
            MadActionButton("Pause transfer", MadButtonVariant.Primary, onClick = { showing = true },
                enabled = fraction != null && !paused, modifier = Modifier.testTag("transfer-pause"))
            MadText(if(paused) "Status: Paused" else "Status: Running", modifier = Modifier.testTag("transfer-status"))
            MadText("Details: $details / Cancel: $cancels / Confirm: $confirms / Dismiss: $dismissals",
                modifier = Modifier.testTag("transfer-events"))
            TransferMeta("SYNTHETIC WORKSPACE · MADUIKIT ALPHA19")
        }
        MadConfirmDialog(showing, "Pause this transfer?",
            "Your 42 copied files will stay in place.",
            confirmLabel = "Pause now", cancelLabel = "Keep transferring",
            onConfirm = { confirms++; paused = true; showing = false },
            onCancel = { cancels++; showing = false },
            onDismissRequest = { dismissals++; showing = false },
            dismissOnClickOutside = false,
        )
    }
}

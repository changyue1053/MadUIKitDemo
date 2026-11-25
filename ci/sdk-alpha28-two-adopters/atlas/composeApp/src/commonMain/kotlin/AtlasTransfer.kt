package dev.mad.synthetic.adopters.atlas

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import com.mad.maduikit.*

private val navy = Color(0xff132a35)
private val muted = Color(0xff46616a)
private val jade = Color(0xff136657)
private val paper = Color(0xffedf2ee)
private val hair = Color(0xffccdcd6)
private val scheme = lightColorScheme(
    primary=jade,onPrimary=Color.White, surface=Color.White, surfaceContainer=Color.White,
    surfaceContainerHigh=Color(0xfff2faf5), onSurface=navy,onSurfaceVariant=muted,
    outlineVariant=hair, secondaryContainer=Color(0xffcfe9db), onSecondaryContainer=navy,
)

private class AtlasMark(private val kind:Int):Painter() {
    override val intrinsicSize=Size(24f,24f)
    override fun DrawScope.onDraw() {
        val g=size.width/24f
        fun p(x:Float,y:Float)=Offset(x*g,y*g)
        fun line(x:Float,y:Float,u:Float,v:Float)=drawLine(jade,p(x,y),p(u,v),strokeWidth=1.8f*g)
        when(kind) {
            0 -> {
                line(3f,11f,12f,4f);line(12f,4f,21f,11f)
                line(6f,9f,6f,20f);line(18f,9f,18f,20f);line(6f,20f,18f,20f)
            }
            1 -> {
                line(4f,8f,20f,8f);line(15f,3f,20f,8f);line(15f,13f,20f,8f)
                line(20f,17f,4f,17f);line(4f,17f,9f,12f);line(4f,17f,9f,22f)
            }
            else -> {
                drawCircle(jade,8f*g,p(12f,12f),style=Stroke(1.7f*g))
                line(12f,7f,12f,12f);line(12f,12f,15f,14f)
            }
        }
    }
}

@Composable private fun Meta(text:String,color:Color=muted) {
    Text(text,color=color,fontFamily=FontFamily.Monospace,fontSize=12.sp,
        fontWeight=FontWeight.Medium,letterSpacing=1.1.sp)
}

@Composable private fun Hero() {
    MaterialTheme(colorScheme=scheme.copy(surfaceContainer=navy,onSurface=Color.White)) {
        MadCard(Modifier.fillMaxWidth(),cornerRole=MadCornerRole.Large) {
            Box(Modifier.fillMaxWidth().height(177.dp)) {
                Canvas(Modifier.fillMaxSize()) {
                    val anchor=Offset(size.width*.80f,size.height*.70f)
                    for(n in 1..6) drawCircle(Color(0xff386f62),n*25.dp.toPx(),anchor,style=Stroke(1.dp.toPx()))
                    drawCircle(Color(0xff8cd2ad),7.dp.toPx(),anchor)
                    drawCircle(Color(0xff68a387),4.dp.toPx(),anchor+Offset(28.dp.toPx(),-39.dp.toPx()))
                }
                Column(Modifier.padding(25.dp)) {
                    Meta("ATLAS / WORKSPACE TRANSFER",Color(0xffc1e8d4))
                    Spacer(Modifier.height(10.dp))
                    Text("Transfer center",color=Color.White,fontSize=42.sp,lineHeight=48.sp,
                        fontWeight=FontWeight.SemiBold,letterSpacing=(-1).sp)
                    Spacer(Modifier.height(7.dp))
                    Text("Move workspace files without losing your place.",color=Color(0xffdae9e2),fontSize=16.sp)
                }
            }
        }
    }
}

@Composable private fun Gallery(
    destination:String, onDestination:(String)->Unit,
    fraction:Float?, showing:Boolean, show:()->Unit,
    confirming:()->Unit, cancel:()->Unit, dismiss:()->Unit,
    paused:Boolean, background:()->Unit,
) {
    val destinations=remember { listOf(
        MadNavigationItem("overview","Overview",AtlasMark(0)),
        MadNavigationItem("transfers","Transfers",AtlasMark(1)),
        MadNavigationItem("activity","Activity",AtlasMark(2),enabled=false),
    ) }
    MaterialTheme(colorScheme=scheme) {
        Box(Modifier.fillMaxSize().background(paper)) {
            Column(Modifier.align(Alignment.TopCenter).width(650.dp).padding(top=33.dp),
                verticalArrangement=Arrangement.spacedBy(15.dp)) {
                Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically) {
                    Text("Atlas Studio",fontSize=20.sp,color=navy,fontWeight=FontWeight.Bold)
                    Meta("MADUIKIT / NAVIGATION & FEEDBACK",jade)
                }
                Hero()
                Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically) {
                    Column {
                        Meta("01 / ACTIVE WORKSPACE")
                        Text(if(destination=="transfers") "Workspace transfers" else "Workspace overview",
                            fontSize=26.sp,color=navy,fontWeight=FontWeight.SemiBold)
                    }
                    MadBadge(if(paused) "Paused" else if(fraction==null) "Preparing" else "In progress")
                }
                MadCard(Modifier.fillMaxWidth(),borderRole=MadBorderRole.Subtle) {
                    Column(Modifier.fillMaxWidth().padding(22.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
                        Meta("TRANSFER #A–042",jade)
                        Text("Export design system",fontSize=24.sp,color=navy,fontWeight=FontWeight.SemiBold)
                        Text("Components and style references · Atlas workspace",color=muted)
                        MadDivider(color=hair)
                        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
                            Text("Transfer progress",color=navy,fontWeight=FontWeight.Medium)
                            Text(when { paused -> "Paused"; fraction==null -> "Estimating…"; else -> "${(fraction*100).toInt()}%" },
                                color=jade,fontWeight=FontWeight.SemiBold)
                        }
                        MadLinearProgress(fraction,label="Workspace transfer progress")
                        Text(if(fraction==null) "Preparing the file list." else "42 of 100 files copied to the sample workspace.",color=muted)
                    }
                }
                MadCard(Modifier.fillMaxWidth(),borderRole=MadBorderRole.Subtle) {
                    Row(Modifier.fillMaxWidth().padding(horizontal=22.dp,vertical=14.dp),
                        verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.SpaceBetween) {
                        Column {
                            Meta("02 / TRANSFER CONTROL",jade)
                            Text("Pause without losing your place.",color=navy,fontSize=16.sp)
                        }
                        MadActionButton("Pause transfer",MadButtonVariant.Secondary,show,enabled=!paused)
                    }
                }
                MadCard(Modifier.fillMaxWidth(),borderRole=MadBorderRole.Subtle) {
                    MadNavigationBar(destinations,destination,onDestination,Modifier.fillMaxWidth())
                }
                Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,
                    verticalAlignment=Alignment.CenterVertically) {
                    MadActionButton("Workspace details",MadButtonVariant.Text,background)
                    Meta("SAMPLE DATA · COMPILE FIXTURE")
                }
            }
            MadConfirmDialog(showing,title="Pause this transfer?",
                message="Your 42 copied files will stay in place. You can resume from the Transfers tab.",
                confirmLabel="Pause transfer",cancelLabel="Keep transferring",
                onConfirm=confirming,onCancel=cancel,onDismissRequest=dismiss)
        }
    }
}

@Composable
fun AtlasTransfer() {
    var selected by remember { mutableStateOf("transfers") }
    var paused by remember { mutableStateOf(false) }
    var confirming by remember { mutableStateOf(false) }
    var fraction by remember { mutableStateOf<Float?>(0.42f) }
    Gallery(
        destination = selected, onDestination = { selected = it },
        fraction = fraction, showing = confirming, show = { confirming = true },
        confirming = { paused = true; confirming = false },
        cancel = { confirming = false }, dismiss = { confirming = false },
        paused = paused, background = { fraction = null },
    )
}

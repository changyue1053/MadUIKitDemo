package dev.mad.synthetic.adopters.orchid

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import com.mad.maduikit.*

private val berry=Color(0xff89374f)
private val shell=Color(0xfffcebdd)
private val peach=Color(0xfff4c1ad)
private val ink=Color(0xff351e24)
private val scheme=lightColorScheme(
    primary=berry,onPrimary=Color.White,onSurface=ink,onSurfaceVariant=Color(0xff64444b),
    surfaceContainer=Color(0xfffff9f3), secondaryContainer=peach,onSecondaryContainer=ink,
    outlineVariant=Color(0xffddb4a6),
)
private val typography=MadTypography(
    body=TextStyle(fontFamily=FontFamily.Serif,fontSize=17.sp,lineHeight=23.sp),
    title=TextStyle(fontFamily=FontFamily.Serif,fontSize=30.sp,lineHeight=39.sp,fontWeight=FontWeight.Bold),
    label=TextStyle(fontFamily=FontFamily.Monospace,fontSize=13.sp,lineHeight=18.sp),
)
private val space=MadSpacing(6,12,22)
private val corners=MadCornerRadii(2,10,22)

@Composable private fun Catalog(eligible:Boolean,selected:Boolean,include:(Boolean)->Unit,detail:Int,open:(Int)->Unit){
    MaterialTheme(colorScheme=scheme){
        MadProvideTypography(typography){
            Column(Modifier.fillMaxSize().background(shell).padding(space.largeDp.dp),
                verticalArrangement=Arrangement.spacedBy(space.mediumDp.dp)){
                MadText("ORCHID / COMMUNITY TOOL LIBRARY",role=MadTextRole.Label)
                MadText("Reserve equipment",role=MadTextRole.Title)
                MadCard(Modifier.fillMaxWidth(),cornerRole=MadCornerRole.Large,cornerRadii=corners,borderRole=MadBorderRole.Subtle){
                    Column(Modifier.padding(space.mediumDp.dp),verticalArrangement=Arrangement.spacedBy(space.smallDp.dp)){
                        MadBadge("2 items available")
                        MadListItem("Field recorder",supportingText="Audio kit · morning pickup",onClick={open(7)})
                        MadListItem("Tripod",supportingText="Camera support · afternoon pickup",onClick={open(11)})
                    }
                }
                MadCard(Modifier.fillMaxWidth(),cornerRole=MadCornerRole.Small,cornerRadii=corners){
                    Column(Modifier.padding(space.mediumDp.dp)){
                        MadText(if(detail==11) "Tripod reservation" else "Field recorder reservation",role=MadTextRole.Title)
                        MadCheckbox("Include the protective case",selected,include,enabled=eligible)
                    }
                }
            }
        }
    }
}

@Composable
fun OrchidCatalog() {
    var selected by remember { mutableStateOf(false) }
    var detail by remember { mutableStateOf(7) }
    Catalog(eligible = detail == 7, selected = selected,
        include = { selected = it }, detail = detail, open = { detail = it })
}

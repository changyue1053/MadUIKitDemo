package dev.mad.synthetic.typography

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mad.maduikit.*

private val navy = Color(0xff132a35)
private val muted = Color(0xff486269)
private val teal = Color(0xff136657)
private val paper = Color(0xffedf2ee)
private val mint = Color(0xffc5eedb)
private val hair = Color(0xffccdbd3)
private data class Person(val id: Int, val name: String, val initials: String, val role: String, val status: String)
private val people = listOf(
    Person(1,"Mira Chen","MC","Product design · Mobile foundations","Available"),
    Person(2,"Jonah Reed","JR","Systems design · Accessibility","In review"),
    Person(3,"Sofia Park","SP","Content design · Research operations","New"),
)

@Composable
private fun Meta(text: String, color: Color = muted) {
    BasicText(text, style = TextStyle(color = color, fontFamily = FontFamily.Monospace,
        fontSize = 11.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.7.sp))
}

@Composable
private fun AtlasHero() {
    MadCard(Modifier.fillMaxWidth(), cornerRole = MadCornerRole.Large) {
        Box(Modifier.fillMaxWidth().background(navy)) {
            Canvas(Modifier.matchParentSize()) {
                val focal = Offset(size.width * .88f, size.height * .65f)
                for (n in 1..6) drawCircle(Color(0xff427265), radius = n * 16.dp.toPx(),
                    center = focal, style = Stroke(1.dp.toPx()))
                drawCircle(mint, radius = 4.dp.toPx(), center = focal)
            }
            Column(Modifier.padding(14.dp)) {
                Meta("ATLAS / PEOPLE OPERATIONS", mint)
                BasicText("Team directory", Modifier.testTag("atlas-title"), style = TextStyle(
                    color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.SemiBold))
                BasicText("Find a person, team, or specialty.", style = TextStyle(color = mint,fontSize = 13.sp))
            }
        }
    }
}

@Composable
fun AtlasDirectory() {
    var query by remember { mutableStateOf(TextFieldValue()) }
    var submitted by remember { mutableStateOf("") }
    var submissions by remember { mutableStateOf(0) }
    var project by remember { mutableStateOf(TextFieldValue("Review mobile navigation")) }
    var selected by remember { mutableStateOf(1) }
    val focus = LocalFocusManager.current
    fun search() {
        submitted = query.text
        submissions++
        focus.clearFocus()
    }
    MadTheme(darkTheme = false, colors = MadColors(teal, Color.White)) {
        val shown = people.filter { it.role.contains(submitted, true) || it.name.contains(submitted, true) }
        val empty = shown.isEmpty()
        val active = people.single { it.id == selected }
        Column(Modifier.fillMaxSize().background(paper).verticalScroll(rememberScrollState()).padding(15.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp)) {
            AtlasHero()
            MadCard(Modifier.fillMaxWidth(), borderRole = MadBorderRole.Subtle) {
                Column(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 5.dp)) {
                    Meta("01 / SEARCH")
                    MadSearchField("Search team", query, { query = it }, onSearch = { search() },
                        modifier = Modifier.fillMaxWidth().testTag("atlas-search"),
                        supportingText = "Try a name or specialty, such as design.",
                        errorMessage = if (empty) "No team members match this search." else null)
                    MadText("Query: ${query.text.ifEmpty { "—" }}", modifier = Modifier.testTag("atlas-query"))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically) {
                        MadText("Searches: $submissions", modifier = Modifier.testTag("atlas-count"))
                        MadButton("Search directory", onClick = { search() }, modifier = Modifier.testTag("atlas-submit"))
                    }
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Meta("02 / DIRECTORY")
                    MadText(if (empty) "No results" else "Search results", role = MadTextRole.Title,
                        modifier = Modifier.testTag("atlas-heading"))
                }
                MadBadge("${shown.size} matches", modifier = Modifier.testTag("atlas-matches"), spokenLabel = "${shown.size} matches")
            }
            MadCard(Modifier.fillMaxWidth(), borderRole = MadBorderRole.Subtle) {
                if (empty) {
                    Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Meta("SEARCH SUMMARY", teal)
                        MadText("Try a broader search", role = MadTextRole.Title, modifier = Modifier.testTag("atlas-empty"))
                        MadText("Try a specialty or a teammate’s first name.")
                    }
                } else {
                    Column(Modifier.fillMaxWidth().padding(horizontal = 7.dp, vertical = 2.dp)) {
                        shown.forEachIndexed { index, person ->
                            if (index > 0) MadDivider(color = hair)
                            Row(Modifier.fillMaxWidth()
                                .background(if (person.id == selected) Color(0xffeaf6ee) else Color.Transparent),
                                verticalAlignment = Alignment.CenterVertically) {
                                MadAvatar(null, initials = person.initials)
                                MadListItem(person.name, modifier = Modifier.weight(1f).testTag("atlas-row-${person.id}"),
                                    supportingText = person.role, onClick = { selected = person.id })
                                MadBadge(person.status)
                            }
                        }
                    }
                }
            }
            MadCard(Modifier.fillMaxWidth(), borderRole = MadBorderRole.Subtle) {
                Column(Modifier.fillMaxWidth().padding(10.dp)) {
                    Meta("03 / WORKSPACE NOTE", teal)
                    MadText("Note for ${active.name.substringBefore(' ')}", role = MadTextRole.Title,
                        modifier = Modifier.testTag("atlas-note-heading"))
                    MadTextField("Project note", project, { project = it }, modifier = Modifier.fillMaxWidth(),
                        supportingText = "Draft only. Nothing is saved or sent.")
                }
            }
            Meta("SYNTHETIC TEAM DATA · MADUIKIT ALPHA16")
        }
    }
}

package dev.mad.synthetic.typography

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import com.mad.maduikit.MadTypography

fun readAppSuppliedBody(): TextStyle {
    val expected = TextStyle(fontSize = 17.sp)
    val roles = MadTypography(body = expected, title = TextStyle.Default, label = TextStyle.Default)
    check(roles.body === expected)
    return roles.body
}

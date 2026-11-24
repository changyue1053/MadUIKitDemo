package dev.mad.synthetic.typography

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

class FixtureActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { TypographyAdopter() }
    }
}

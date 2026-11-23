package com.mad.maduikit

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** A text role supplied by the nearest MadProvideTypography or Material theme. */
public enum class MadTextRole { Body, Title, Label }

/** Static text. Color and platform font scaling are supplied by the Compose environment. */
@Composable
public fun MadText(
    text: String,
    modifier: Modifier = Modifier,
    role: MadTextRole = MadTextRole.Body,
) {
    val typography = MaterialTheme.typography
    Text(
        text = text,
        modifier = modifier,
        style = when (role) {
            MadTextRole.Body -> typography.bodyLarge
            MadTextRole.Title -> typography.titleLarge
            MadTextRole.Label -> typography.labelLarge
        },
    )
}

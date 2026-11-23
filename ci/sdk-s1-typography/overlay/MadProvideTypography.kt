package com.mad.maduikit

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember

/**
 * Applies [typography] only to [content], preserving the nearest Material theme's
 * colors, shapes, and unmapped typography roles. This deliberately also affects
 * Material 3 components in the subtree that use bodyLarge, titleLarge, or
 * labelLarge. For example, the SDK's [MadTypography.label] styles its button label.
 *
 * Use inside or around MadTheme. Calling MadTheme alone is unchanged.
 */
@Composable
public fun MadProvideTypography(
    typography: MadTypography,
    content: @Composable () -> Unit,
) {
    val inherited = MaterialTheme.typography
    val applied = remember(inherited, typography) {
        inherited.copy(
            bodyLarge = typography.body,
            titleLarge = typography.title,
            labelLarge = typography.label,
        )
    }
    MaterialTheme(typography = applied, content = content)
}

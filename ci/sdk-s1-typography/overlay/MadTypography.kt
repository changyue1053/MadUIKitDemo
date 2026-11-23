package com.mad.maduikit

import androidx.compose.ui.text.TextStyle

/**
 * App-supplied text styles for shared UI code. Instantiating these roles does not
 * change the current theme or any SDK component. Pass a role explicitly or use
 * [MadProvideTypography] for a subtree.
 *
 * @param body Default style for paragraph and ordinary content.
 * @param title Style for headings and section titles.
 * @param label Style for compact labels and control text.
 */
public class MadTypography(
    public val body: TextStyle,
    public val title: TextStyle,
    public val label: TextStyle,
)

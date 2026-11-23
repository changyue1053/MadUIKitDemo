package com.mad.maduikit

/**
 * Opt-in semantic spacing in density-independent pixels, for shared layout code.
 * In Compose use e.g. `spacing.mediumDp.dp`. This does not change MadTheme or
 * the spacing of existing SDK components.
 */
public data class MadSpacing(
    public val smallDp: Int,
    public val mediumDp: Int,
    public val largeDp: Int,
) {
    init {
        require(0 <= smallDp && smallDp <= mediumDp && mediumDp <= largeDp) {
            "Spacing must be nonnegative and ordered: small <= medium <= large"
        }
    }
}

/** Starting points for apps that opt into semantic layout spacing. */
public object MadSpacingDefaults {
    public val Standard: MadSpacing = MadSpacing(4, 8, 16)
}

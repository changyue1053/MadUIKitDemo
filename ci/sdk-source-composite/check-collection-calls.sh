#!/usr/bin/env bash
# Only consumes javap output from the unique, freshly compiled CollectionProbeKt class.
set -euo pipefail
[[ $# == 1 && -s "$1" ]]
prefix='^[[:blank:]]*[0-9]+:[[:blank:]]+invokestatic[[:blank:]].*// Method com/mad/maduikit/'
shape() {
    count=$(grep -E -c "${prefix}$1:" "$3" || :)
    exact=$(grep -E -c "${prefix}$1:$2$" "$3" || :)
    [[ "$count" = "$4" && "$exact" = "$4" ]]
}
shape 'MadSearchFieldKt\.MadSearchField' '\(Ljava/lang/String;Landroidx/compose/ui/text/input/TextFieldValue;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;ZZLjava/lang/String;Ljava/lang/String;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape 'MadCardKt\.MadCard' '\(Landroidx/compose/ui/Modifier;Lcom/mad/maduikit/MadCornerRole;Lcom/mad/maduikit/MadCornerRadii;Lcom/mad/maduikit/MadBorderRole;Lcom/mad/maduikit/MadBorderWidths;Lkotlin/jvm/functions/Function3;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape 'MadAvatarKt\.MadAvatar' '\(Ljava/lang/String;Landroidx/compose/ui/Modifier;Landroidx/compose/ui/graphics/painter/Painter;Ljava/lang/String;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape 'MadListItemKt\.MadListItem' '\(Ljava/lang/String;Landroidx/compose/ui/Modifier;Ljava/lang/String;ZLkotlin/jvm/functions/Function0;Landroidx/compose/runtime/Composer;II\)V' "$1" 1

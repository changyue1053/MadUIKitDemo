#!/usr/bin/env bash
# Only consumes javap output from the unique, freshly compiled TrialFormKt class.
set -euo pipefail
[[ $# == 1 && -s "$1" ]]
prefix='^[[:blank:]]*[0-9]+:[[:blank:]]+invokestatic[[:blank:]].*// Method com/mad/maduikit/'
shape() {
    count=$(grep -E -c "${prefix}$1:" "$3" || :)
    exact=$(grep -E -c "${prefix}$1:$2$" "$3" || :)
    [[ "$count" = "$4" && "$exact" = "$4" ]]
}
shape 'MadTextFieldKt\.MadTextField' '\(Ljava/lang/String;Landroidx/compose/ui/text/input/TextFieldValue;Lkotlin/jvm/functions/Function1;Landroidx/compose/ui/Modifier;ZZLjava/lang/String;Ljava/lang/String;Landroidx/compose/foundation/text/KeyboardOptions;Landroidx/compose/foundation/text/KeyboardActions;Landroidx/compose/runtime/Composer;II\)V' "$1" 4
shape 'MadBadgeKt\.MadBadge' '\(Ljava/lang/String;Landroidx/compose/ui/Modifier;Ljava/lang/String;Landroidx/compose/runtime/Composer;II\)V' "$1" 1

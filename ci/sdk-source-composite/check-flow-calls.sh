#!/usr/bin/env bash
# Only consumes javap output from independent freshly generated FlowProbeKt.
set -euo pipefail
[[ $# == 1 && -s "$1" ]]
shape() {
    local prefix="^[[:blank:]]*[0-9]+:[[:blank:]]+$1[[:blank:]].*// Method com/mad/maduikit/"
    local count exact
    count=$(grep -E -c "${prefix}$2:" "$4" || :)
    exact=$(grep -E -c "${prefix}$2:$3$" "$4" || :)
    [[ "$count" = "$5" && "$exact" = "$5" ]]
}
shape invokespecial 'MadNavigationItem\."<init>"' '\(Ljava/lang/String;Ljava/lang/String;Landroidx/compose/ui/graphics/painter/Painter;Z\)V' "$1" 2
shape invokestatic 'MadNavigationBarKt\.MadNavigationBar' '\(Ljava/util/List;Ljava/lang/String;Lkotlin/jvm/functions/Function1;Landroidx/compose/ui/Modifier;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape invokestatic 'MadLinearProgressKt\.MadLinearProgress' '\(Ljava/lang/Float;Landroidx/compose/ui/Modifier;Ljava/lang/String;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape invokestatic 'MadConfirmDialogKt\.MadConfirmDialog' '\(ZLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function0;Lkotlin/jvm/functions/Function0;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;ZZLandroidx/compose/runtime/Composer;III\)V' "$1" 1

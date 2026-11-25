#!/usr/bin/env bash
# Only consumes javap output from independent freshly generated WorkspaceProbeKt.
set -euo pipefail
[[ $# == 1 && -s "$1" ]]
shape() {
    local prefix="^[[:blank:]]*[0-9]+:[[:blank:]]+$1[[:blank:]].*// Method com/mad/maduikit/"
    local count exact
    count=$(grep -E -c "${prefix}$2:" "$4" || :)
    exact=$(grep -E -c "${prefix}$2:$3$" "$4" || :)
    [[ "$count" = "$5" && "$exact" = "$5" ]]
}
shape invokestatic 'MadScaffoldKt\.MadScaffold' '\(Landroidx/compose/ui/Modifier;Lkotlin/jvm/functions/Function2;Lkotlin/jvm/functions/Function2;Lkotlin/jvm/functions/Function2;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape invokestatic 'MadBottomSheetKt\.MadBottomSheet' '\(ZLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function0;Landroidx/compose/runtime/Composer;I\)V' "$1" 1
shape invokestatic 'MadTopAppBarKt\.MadTopAppBar' '\(Ljava/lang/String;Landroidx/compose/ui/Modifier;Lcom/mad/maduikit/MadTopAppBarAction;Lcom/mad/maduikit/MadTopAppBarAction;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape invokestatic 'MadBannerKt\.MadBanner' '\(Lcom/mad/maduikit/MadBannerTone;Ljava/lang/String;Ljava/lang/String;Landroidx/compose/ui/Modifier;Lcom/mad/maduikit/MadBannerAction;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape invokestatic 'MadStatePanelKt\.MadStatePanel' '\(Lcom/mad/maduikit/MadPanelState;Ljava/lang/String;Landroidx/compose/ui/Modifier;Ljava/lang/String;Lcom/mad/maduikit/MadStatePanelAction;Landroidx/compose/runtime/Composer;II\)V' "$1" 1
shape invokestatic 'MadTextAreaKt\.MadTextArea' '\(Ljava/lang/String;Landroidx/compose/ui/text/input/TextFieldValue;Lkotlin/jvm/functions/Function1;Landroidx/compose/ui/Modifier;ZZLjava/lang/String;Ljava/lang/String;Ljava/lang/String;IILandroidx/compose/foundation/text/KeyboardOptions;Landroidx/compose/foundation/text/KeyboardActions;Landroidx/compose/runtime/Composer;III\)V' "$1" 1
shape invokestatic 'MadDecoratedTextFieldKt\.MadDecoratedTextField' '\(Ljava/lang/String;Landroidx/compose/ui/text/input/TextFieldValue;Lkotlin/jvm/functions/Function1;Landroidx/compose/ui/Modifier;ZZLjava/lang/String;Landroidx/compose/ui/graphics/painter/Painter;Landroidx/compose/ui/graphics/painter/Painter;Ljava/lang/String;Ljava/lang/String;Landroidx/compose/foundation/text/KeyboardOptions;Landroidx/compose/foundation/text/KeyboardActions;Landroidx/compose/runtime/Composer;III\)V' "$1" 1
shape invokestatic 'MadSearchFieldWithClearKt\.MadSearchFieldWithClear' '\(Ljava/lang/String;Landroidx/compose/ui/text/input/TextFieldValue;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function0;Ljava/lang/String;Landroidx/compose/ui/graphics/painter/Painter;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;ZZLjava/lang/String;Ljava/lang/String;Landroidx/compose/runtime/Composer;III\)V' "$1" 1

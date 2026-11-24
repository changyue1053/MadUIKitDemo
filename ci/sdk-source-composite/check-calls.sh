#!/usr/bin/env bash
# Takes javap -c -p over the unique fresh caller class; never inspects SDK declarations.
set -euo pipefail
[[ $# == 1 && -s "$1" ]]
check() {
  grep -E -q "^[[:blank:]]*[0-9]+:[[:blank:]]+invokestatic[[:blank:]].*// Method com/mad/maduikit/$1:" "$2"
}
check 'MadSwitchKt\.MadSwitch' "$1"
check 'MadIconKt\."?MadIcon-[A-Za-z0-9_-]+"?' "$1"
check 'MadIconKt\.MadIconButton' "$1"
check 'MadCheckboxKt\.MadCheckbox' "$1"
check 'MadRadioKt\.MadRadio' "$1"
check 'MadDividerKt\."?MadDivider-[A-Za-z0-9_-]+"?' "$1"
check 'MadActionButtonKt\.MadActionButton' "$1"
for variant in Primary Secondary Text Danger; do
  grep -Eq "^[[:blank:]]*[0-9]+:[[:blank:]]+getstatic[[:blank:]].*// Field com/mad/maduikit/MadButtonVariant\.$variant:" "$1"
done
# Four independently emitted variant calls verify the complete example.
test "$(grep -E -c '^[[:blank:]]*[0-9]+:[[:blank:]]+invokestatic[[:blank:]].*// Method com/mad/maduikit/MadActionButtonKt\.MadActionButton:' "$1")" = 4
# Two independently emitted radio calls verify exactly the grouped example.
test "$(grep -E -c '^[[:blank:]]*[0-9]+:[[:blank:]]+invokestatic[[:blank:]].*// Method com/mad/maduikit/MadRadioKt\.MadRadio:' "$1")" = 2

#!/bin/bash

test_path="tests/hardening"
failure=0
failed_checks=""

for check in "$@"; do
    base_name=$(basename "$check")
    if [ ! -f $test_path/"$base_name" ]; then
        failure=1
        failed_checks="$failed_checks $base_name"
    fi
done

if [ $failure -ne 0 ]; then
    for check in $failed_checks; do
        echo "missing file $test_path/$check"
    done
fi

exit $failure

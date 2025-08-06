#!/bin/bash

for script in "$@"; do
    shfmt -l -i 4 -w "$script"
done

exit 0

#!/bin/bash

for script in "$@"; do
    chmod +x "$script"
done

exit 0

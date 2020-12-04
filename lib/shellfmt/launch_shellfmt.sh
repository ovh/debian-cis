#!/bin/bash
# run-shellcheck

if [ ! -f tmp/shfmt ]; then
    wget -O tmp/shfmt https://github.com/mvdan/sh/releases/download/v3.2.0/shfmt_v3.2.0_linux_amd64
fi

chmod +x tmp/shfmt

files=""
retval=0

if [ "$#" -eq 0 ]; then
    files=$(find . -name "*.sh" | sort -V)
else
    files="$*"
fi

for f in $files; do
    ./tmp/shfmt -l -i 4 -w "$f"
done

exit "$retval"

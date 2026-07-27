#!/bin/bash

# script to extract the content for a specific recommendation from a debian CIS file
# steps to use the script:
# - install mutool (for pdf parsing)
# - configure the cfg file set as the "script_conf" var below
# - execute the script with a recommendation number
# ex: ./cis_extract_recommendation.sh 5.2.3.4

# what it does:
# - extract the index from the pdf file (if not already done)
# - find the page for the recommendation number passed as argument
# - print the recommendation to stdout

script_conf="cis_extract.cfg"

if [ $# -lt 1 ]; then
    echo "please pass recommendation number as argument"
    echo "example: ./cis_extract_recommendation.sh 5.2.3.4"
    exit 1
fi

recommendation_number=$1

mutool_bin=$(which mutool)
if [ -z "$mutool_bin" ]; then
    echo "Please install mutool"
    echo "try 'sudo apt install mupdf-tools'"
    exit 1
fi

# where is the script located
script_path="$(realpath "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$script_path")"

source "$script_dir"/"$script_conf"

# extract index
# we'll use it to get the pages for a recommendation
if [ ! -s "$index_file" ]; then
    "$mutool_bin" draw -o - -F text "$pdf_file" "$index_start"-"$index_end" >"$index_file"_tmp

    while IFS= read -r line; do
        # sometimes a line starts with the recommendation number, but the page is on the next line
        # look for what start with a recommendation number and ends with a page number
        echo -n "$line" | grep "^\([0-9].\)\+.*[0-9]$" >/dev/null
        if [ $? -ne 0 ]; then
            if IFS= read -r next; then
                line="$line $next"
            fi
        fi
        echo "$line" | sed 's/\ *//' >>"$index_file"
    done <"$index_file"_tmp
fi

# get the start page for the recommendation we are looking for
page_start=$(grep -E ^\([0-9].[0-9]\) "$index_file" | grep ^"$recommendation_number"[[:space:]] | awk '{print $NF}' | sed 's/[^0-9]//g')
# get the start page for the recommendation following the one we are looking for
page_end=$(grep -E ^\([0-9].[0-9]\) "$index_file" | grep ^"$recommendation_number"[[:space:]] -A 1 | tail -n 1 | awk '{print $NF}' | sed 's/[^0-9]//g')

if [ -z $page_start ]; then
    echo "recommendation $recommendation_number not found"
    exit 1
fi

# a page may start with the end of a previous recommendation, we'll keep reading until we found the recommendation
# line_start is a boolean (not a number)
line_start=1
# stop at page before next recommendation
"$mutool_bin" draw -o - -F text "$pdf_file" "$page_start"-"$((page_end - 1))" | while read line; do
    if [ $line_start -eq 1 ]; then
        if [[ "$line" =~ ^$recommendation_number ]]; then
            line_start=0
            echo "$line"
        else
            continue
        fi
    else
        # stop before listing all "references", we don t care for them
        [[ "$line" =~ References: ]] && break
        [[ "$line" =~ ^Page ]] && continue
        echo "$line"
    fi
done

exit 0

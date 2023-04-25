hardening.sh --audit-all > cis_report.log
sed 's/\[\(;*[0-9][0-9]*\)*[fhlmpsuABCDEFGHJKST]//g;s/ \[[I ]/,/g;s/[O ]\]/,/g;s/,NF,/,INFO,/g' cis_results.log > cis_results.csv

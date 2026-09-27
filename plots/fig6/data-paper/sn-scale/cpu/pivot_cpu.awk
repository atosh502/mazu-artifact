# Pivot the per-component CPU .dat files into one row per RPS step:
#   rps  proxy_istio proxy_mazu  istiod_istio istiod_mazu  api_istio api_mazu
# Column order follows the order the files are passed on the command line.
# Usage: awk -v want="400 800" -f pivot_cpu.awk f1.dat f2.dat f3.dat
FNR == 1 { nfile++ }
/^#/     { next }
NF >= 3  { istio[nfile "_" $1] = $2; mazu[nfile "_" $1] = $3 }
END {
    n = split(want, rps, " ")
    for (k = 1; k <= n; k++) {
        printf "%s", rps[k]
        for (c = 1; c <= nfile; c++)
            printf "\t%s\t%s", istio[c "_" rps[k]], mazu[c "_" rps[k]]
        printf "\n"
    }
}

# Turn -Rpass-analysis=kernel-resource-usage remarks into one line per kernel.
/Function Name:/ { if (n != "") emit(); n = $0
    sub(/.*Function Name: /, "", n); sub(/EEEvPK.*/, "", n)
    sub(/_ZN12_GLOBAL__N_16k_projILi/, "k_proj<", n)
    sub(/_ZN12_GLOBAL__N_113k_down_singleILi/, "k_down_single<", n)
    sub(/_ZN12_GLOBAL__N_17k_prep4ILb/, "k_prep4<", n)
    gsub(/ELi/, ",", n); gsub(/ELb/, ",", n); v = occ = sp = lds = "" }
/VGPRs: /     && v == "" { v = val() }
/LDS Size/    { lds = val() }
/Occupancy/   { occ = val() }
/VGPRs Spill/ { sp = val() }
END { emit() }
function val(  x) { x = $0; sub(/.*: /, "", x); sub(/ \[.*/, "", x); return x }
function emit() { printf "%-36s vgpr=%-4s lds=%-6s waves/SIMD=%-3s spill=%s\n", n, v, lds, occ, sp }

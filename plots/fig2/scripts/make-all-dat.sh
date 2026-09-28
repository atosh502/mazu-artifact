#!/bin/bash

# Consolidates the `go test -bench` output of etclab/rbe, etclab/ibe and
# etclab/cryptofun into the all.dat that crypto-scheme-microbenchmarks.gpi
# plots. The RBE numbers are taken at the largest number of users benchmarked
# (the paper ran rbe with -max-users=1024).
#   $1 = directory holding rbe-go-benchmark.txt, ibe-go-benchmark.txt and
#        cryptofun-go-benchmark.txt; all.dat is written next to them

set -e

dir=$1
rbe="$dir/rbe-go-benchmark.txt"
ibe="$dir/ibe-go-benchmark.txt"
cryptofun="$dir/cryptofun-go-benchmark.txt"

for file in "$rbe" "$ibe" "$cryptofun"; do
    if [[ ! -f "$file" ]]; then
        echo "$file not found" >&2
        exit 1
    fi
done

# Prints the ns/op of the first of benchmarks $2... found in $1. go test
# appends -GOMAXPROCS to the name unless GOMAXPROCS is 1, so that suffix is
# optional. cryptofun renamed its sub-benchmarks after the paper's run
# (RSASignSHA256-3072 became keyLength:3072), so its benchmarks are looked up
# under both names.
ns() {
    local file=$1 name value
    shift
    for name in "$@"; do
        value=$(awk -v name="$name" '
            $4 == "ns/op" && ($1 == name ||
                (index($1, name "-") == 1 && substr($1, length(name) + 2) ~ /^[0-9]+$/)) {
                print $3; exit
            }
        ' "$file")
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    done
    echo "$* not found in $file" >&2
    exit 1
}

users=$(sed -nE 's/^BenchmarkEncrypt\/Encrypt-([0-9]+)(-[0-9]+)?[[:space:]].*/\1/p' "$rbe" | sort -n | tail -1)
if [[ -z "$users" ]]; then
    echo "No BenchmarkEncrypt results in $rbe" >&2
    exit 1
fi

# Assigned one by one so that set -e stops on a missing benchmark, which it
# would not inside the arguments of a command
ibe_extract=$(ns "$ibe" BenchmarkExtract)
ibe_decrypt=$(ns "$ibe" BenchmarkDecrypt)
ibe_encrypt=$(ns "$ibe" BenchmarkEncrypt)
rbe_decrypt=$(ns "$rbe" "BenchmarkDecrypt/Decrypt-$users")
rbe_encrypt=$(ns "$rbe" "BenchmarkEncrypt/Encrypt-$users")
rbe_verify_membership=$(ns "$rbe" "BenchmarkVerifyMembership/VerifyMembership-$users")
rsa_keygen=$(ns "$cryptofun" BenchmarkGenerateRSAKeyPair/{GenerateRSAKeyPair-,keyLength:}3072)
rsa_sign=$(ns "$cryptofun" BenchmarkRSASignSHA256/{RSASignSHA256-,keyLength:}3072)
rsa_verify=$(ns "$cryptofun" BenchmarkRSAVerifySHA256/{RSAVerifySHA256-,keyLength:}3072)
ecdsa_keygen=$(ns "$cryptofun" BenchmarkGenerateECDSAKeyPair/{GenerateECDSAKeyPair/,curve:}P-256)
ecdsa_sign=$(ns "$cryptofun" BenchmarkECDSASignASN1/{ECDSASignASN1/,curve:}P-256)
ecdsa_verify=$(ns "$cryptofun" BenchmarkECDSAVerifyASN1/{ECDSAVerifyASN1/,curve:}P-256)
ed25519_keygen=$(ns "$cryptofun" BenchmarkGenerateEd25519KeyPair)
ed25519_sign=$(ns "$cryptofun" BenchmarkEd25519phSign)
ed25519_verify=$(ns "$cryptofun" BenchmarkEd2519phVerify)

row() {
    printf '%-24s%-12s%-12s%-12s%-16s%s\n' "$@"
}

{
    echo "# - measurements are in ns"
    echo "# - rsa/3072, ecdsa/p-256 and ed25519 all have a security strength of about 128 bits"
    echo "# - RBE.GenKey depends on the size of the ID space"
    echo "# - RBE.ProveMembership is essentially just an hash lookup"
    echo "# - RBE is measured with $users users"
    echo "#"
    row "#" rbe ibe rsa/3072 ecdsa/p-256 ed25519
    row '"KeyGen\n(Extract)"' 0 "$ibe_extract" "$rsa_keygen" "$ecdsa_keygen" "$ed25519_keygen"
    row '"Sign\n(Decrypt)"' "$rbe_decrypt" "$ibe_decrypt" "$rsa_sign" "$ecdsa_sign" "$ed25519_sign"
    row '"Verify\n(Encrypt)"' "$rbe_encrypt" "$ibe_encrypt" "$rsa_verify" "$ecdsa_verify" "$ed25519_verify"
    row '"Verify\nMembership"' "$rbe_verify_membership" 0 0 0 0
} > "$dir/all.dat"

echo "Wrote $dir/all.dat (RBE with $users users)"

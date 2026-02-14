#!/usr/bin/env bash
set -euo pipefail

ORG="OBS Orange Linux"
LE="Nonprod"   # ou Dev/Prod/Sandbox selon ton survey AAP

PUB_DIR="/pub/kernel-constraints"
mkdir -p "$PUB_DIR"

# ---- LISTE DES CCV ----
# 4 CCV standard => 1 ligne via --packages-restrict-latest true
STD_CCVS=(
  "CCV RHEL 7 x86_64"
  "CCV RHEL 8 x86_64"
  "CCV RHEL 9.6 x86_64"
  "CCV RHEL 9.4 x86_64"
)

# CCV global RHEL9 => 2 lignes (el9_4 + el9_6)
GLOBAL_CCV9="CCV RHEL 9 x86_64"

sanitize() { echo "$1" | sed -E 's/[^A-Za-z0-9._-]+/_/g'; }

latest_kernel_std() {
  local ccv="$1"
  hammer --csv --no-headers package list \
    --organization "$ORG" \
    --content-view "$ccv" \
    --lifecycle-environment "$LE" \
    --search 'name = kernel' \
    --packages-restrict-latest true \
    --fields filename \
  | head -n1 | sed 's/"//g' | tr -d '\r' || true
}

latest_kernel_stream() {
  # stream = el9_4 ou el9_6
  local ccv="$1" stream="$2"
  hammer --csv --no-headers package list \
    --organization "$ORG" \
    --content-view "$ccv" \
    --lifecycle-environment "$LE" \
    --search "name = kernel and filename ~ ${stream}" \
    --order "id DESC" \
    --per-page 1 \
    --fields filename \
  | head -n1 | sed 's/"//g' | tr -d '\r' || true
}

echo "ORG=$ORG  LE=$LE  PUB_DIR=$PUB_DIR"
echo

# ---- 1) 4 CCV standard ----
for ccv in "${STD_CCVS[@]}"; do
  out="${PUB_DIR}/constraints_$(sanitize "$ccv")__${LE}.txt"
  k="$(latest_kernel_std "$ccv")"

  if [[ -z "${k}" ]]; then
    echo "WARN: No kernel found for [$ccv] @ [$LE]"
    : > "$out"
  else
    printf "%s\n" "$k" > "$out"
  fi

  echo "OK  -> $out"
done

# ---- 2) CCV global RHEL9 : 2 lignes el9_4 + el9_6 ----
out9="${PUB_DIR}/constraints_$(sanitize "$GLOBAL_CCV9")__${LE}__el9_4_el9_6.txt"
k94="$(latest_kernel_stream "$GLOBAL_CCV9" "el9_4")"
k96="$(latest_kernel_stream "$GLOBAL_CCV9" "el9_6")"

# On écrit toujours 2 lignes (même si l'une manque) + warning si vide
{
  [[ -n "$k94" ]] && echo "$k94" || echo ""
  [[ -n "$k96" ]] && echo "$k96" || echo ""
} > "$out9"

if [[ -z "$k94" || -z "$k96" ]]; then
  echo "WARN: Missing stream in [$GLOBAL_CCV9] @ [$LE] (el9_4='${k94:-}', el9_6='${k96:-}')"
fi

echo "OK  -> $out9"
echo
echo "Done."
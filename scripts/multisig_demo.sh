#!/usr/bin/env bash
# Simple multisig demo: create 2-of-3 (k1/k2/k3), fund from Alice & Bob, sign, combine, broadcast.

set -euo pipefail

# Fixed defaults: 2-of-3 multisig using k1, k2, k3.
MSIG_NAME="multisig0"
MSIG_MEMBERS=(k1 k2 k3)
MSIG_THRESHOLD=2
KEYRING="test"
CHAIN_ID="demo"
DENOM="stake"
FUND_FROM_ALICE="1000000${DENOM}"
FUND_FROM_BOB="1000000${DENOM}"
MSIG_SEND_AMT="500000${DENOM}"

KEYRING_ARGS=(--keyring-backend "$KEYRING")

echo "Using chain-id=$CHAIN_ID keyring=$KEYRING multisig=$MSIG_NAME threshold=$MSIG_THRESHOLD"

# Ensure member keys exist
for k in "${MSIG_MEMBERS[@]}"; do
  if ! simd keys show "$k" "${KEYRING_ARGS[@]}" >/dev/null 2>&1; then
    simd keys add "$k" "${KEYRING_ARGS[@]}"
  fi
done

# Create the multisig key if missing
if ! simd keys show "$MSIG_NAME" "${KEYRING_ARGS[@]}" >/dev/null 2>&1; then
  simd keys add "$MSIG_NAME" \
    --multisig "$(IFS=,; echo "${MSIG_MEMBERS[*]}")" \
    --multisig-threshold "$MSIG_THRESHOLD" \
    "${KEYRING_ARGS[@]}"
fi

MSIG_ADDR="$(simd keys show "$MSIG_NAME" -a "${KEYRING_ARGS[@]}")"
ALICE_ADDR="$(simd keys show alice -a "${KEYRING_ARGS[@]}")"
BOB_ADDR="$(simd keys show bob -a "${KEYRING_ARGS[@]}")"

echo "Multisig address: $MSIG_ADDR \n"

echo "Fund Multisig wallet from Alice and Bob \n"
simd tx bank send alice "$MSIG_ADDR" "$FUND_FROM_ALICE" \
  --chain-id "$CHAIN_ID" "${KEYRING_ARGS[@]}" -y
simd tx bank send bob "$MSIG_ADDR" "$FUND_FROM_BOB" \
  --chain-id "$CHAIN_ID" "${KEYRING_ARGS[@]}" -y

echo "Generate unsigned tx that send from multisig wallet to Alice \n"
simd tx bank send "$MSIG_ADDR" "$ALICE_ADDR" "$MSIG_SEND_AMT" \
  --generate-only --chain-id "$CHAIN_ID" > unsigned.json

echo "Sign unsigned tx with each member of multisig wallet \n"
for k in "${MSIG_MEMBERS[@]}"; do
  simd tx sign unsigned.json \
    --from "$k" \
    --multisig "$MSIG_NAME" \
    --sign-mode amino-json \
    --chain-id "$CHAIN_ID" \
    "${KEYRING_ARGS[@]}" \
    --signature-only > "${k}.sig"
done

# Combine partial signatures into the multisig and produce the final tx
sig_files=()
for k in "${MSIG_MEMBERS[@]}"; do
  sig_files+=("${k}.sig")
done
simd tx multisign unsigned.json "$MSIG_NAME" "${sig_files[@]}" \
  --chain-id "$CHAIN_ID" "${KEYRING_ARGS[@]}" > signed.json

# Broadcast
simd tx broadcast signed.json --chain-id "$CHAIN_ID" "${KEYRING_ARGS[@]}"

# Show resulting balances
echo "Balances after tx:"
echo "balance of multisig0:"
simd q bank balances "$MSIG_ADDR"
echo "balance of Alice:"
simd q bank balances "$ALICE_ADDR"

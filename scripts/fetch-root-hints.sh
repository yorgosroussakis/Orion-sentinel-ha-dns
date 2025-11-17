#!/usr/bin/env bash
set -u
OUT1=stacks/dns/unbound1/root.hints
OUT2=stacks/dns/unbound2/root.hints
mkdir -p stacks/dns/unbound1 stacks/dns/unbound2
curl -fsSL https://www.internic.net/domain/named.root -o "$OUT1"
cp "$OUT1" "$OUT2"
echo "Downloaded root hints to $OUT1 and $OUT2"

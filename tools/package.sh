#!/usr/bin/env bash
# Build a distributable zip containing only the addon (no tests, no lint config).
set -euo pipefail
cd "$(dirname "$0")/../addon"
VERSION=$(grep -m1 '^## Version:' SummonNetwork/SummonNetwork.toc | awk '{print $3}')
OUT="../SummonNetwork-${VERSION}.zip"
rm -f "$OUT"
zip -rq "$OUT" SummonNetwork -x 'SummonNetwork/tests/*' 'SummonNetwork/.luacheckrc'
echo "built $OUT"

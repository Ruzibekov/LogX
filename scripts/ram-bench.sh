#!/bin/bash
# RAM o'lchovi: har ssenariy alohida jarayonda yuradi. Bitta jarayonda ketma-ket
# yurgizilsa allocator oldingi testning yuqori chizig'ini ushlab turadi va
# keyingi o'lchov noldan past chiqadi.
set -uo pipefail
cd "$(dirname "$0")/.."
swift build --build-tests >/dev/null 2>&1 || { echo "build failed"; exit 1; }
for test in testRealisticSessionFootprint testHeavySessionFootprint testIncompressibleBodiesStayInsideBudget testBodiesAreStoredCompressed testMetadataFootprint; do
    swift test --filter "MemoryBaselineTests/$test" 2>&1 | grep -E "^LOGX-MEM|XCTAssert"
done

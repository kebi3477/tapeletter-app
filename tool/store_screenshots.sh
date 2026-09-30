#!/bin/bash
# 스토어 제출용 스크린샷 (문구 합성 없이 화면 그대로).
# 쓰는 법: tool/store_screenshots.sh [시뮬레이터 UDID] [출력 폴더]
#   기본: iPhone 17 Pro Max(6.9인치, 1320×2868), ~/Desktop/tapeletter-release/screenshots
# 결과: <출력>/ios/NN_*.png (시뮬레이터 네이티브 해상도, 상태바 9:41)
#       <출력>/android/NN_*.png (위 상태바·아래 홈 인디케이터를 잘라 비율 ≤ 2:1)
# 장면은 integration_test/store_screenshots_test.dart. 앱이 로그에 `TAPELETTER_SHOT <이름>`을
# 찍으면 simctl로 저장한다.
set -uo pipefail
DEV="${1:-7A3BEC3E-7875-4555-812D-068B7DB6F1D6}"
OUT="${2:-$HOME/Desktop/tapeletter-release/screenshots}"
mkdir -p "$OUT/ios" "$OUT/android"

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null
xcrun simctl status_bar "$DEV" override --time 9:41 --dataNetwork wifi \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/store_screenshots_test.dart -d "$DEV" 2>&1 |
  while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *TAPELETTER_SHOT* ]]; then
      name="${line##*TAPELETTER_SHOT }"
      name="${name%$'\r'}"
      sleep 0.8
      xcrun simctl io "$DEV" screenshot "$OUT/ios/$name.png" >/dev/null 2>&1
      echo "  → $OUT/ios/$name.png"
    fi
  done

# Google Play: 긴 변 ≤ 짧은 변 × 2. 위(상태바)와 아래(홈 인디케이터)를 잘라 맞춘다.
python3 - "$OUT" <<'PY'
import subprocess, sys, pathlib
out = pathlib.Path(sys.argv[1])
TOP, BOTTOM = 186, 42   # 6.9인치(3x): 상태바 62pt, 홈 인디케이터 영역 일부
for src in sorted((out / 'ios').glob('*.png')):
    w, h = [int(x) for x in subprocess.check_output(
        ['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(src)], text=True
    ).split()[-3::2]]
    dst = out / 'android' / src.name
    new_h = h - TOP - BOTTOM
    assert new_h <= 2 * w, (src, w, new_h)
    subprocess.run(['sips', '--cropOffset', str(TOP), '0', '-c', str(new_h), str(w),
                    str(src), '--out', str(dst)], check=True, capture_output=True)
    print(f'{dst.name}: {w}x{new_h} ({new_h / w:.3f}:1)')
PY
xcrun simctl status_bar "$DEV" clear

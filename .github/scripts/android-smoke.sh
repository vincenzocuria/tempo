#!/usr/bin/env bash
set -euo pipefail
mkdir -p smoke-evidence
package=com.tempo.app.tempo
activity="$package/.MainActivity"
check_launch() {
  local name="$1"
  adb logcat -c
  adb shell am start -W -n "$activity" > "smoke-evidence/$name-start.txt"
  sleep 15
  adb logcat -d > "smoke-evidence/$name-logcat.txt"
  adb shell pidof "$package" > "smoke-evidence/$name-pid.txt"
  adb shell dumpsys activity activities > "smoke-evidence/$name-activity.txt"
  adb shell uiautomator dump /sdcard/window.xml >/dev/null
  adb pull /sdcard/window.xml "smoke-evidence/$name-ui.xml"
  adb exec-out screencap -p > "smoke-evidence/$name.png"
  if grep -E 'FATAL EXCEPTION|Fatal signal|Unhandled Exception|Zone mismatch' "smoke-evidence/$name-logcat.txt"; then
    echo "Crash detected: $name" >&2
    return 1
  fi
  grep -q "$package" "smoke-evidence/$name-ui.xml"
}
adb install Tempo.apk
check_launch baseline-1.0.23 || true
adb shell am force-stop "$package"
adb install -r build/app/outputs/flutter-apk/app-release.apk
check_launch upgrade-1.0.24
adb shell pm clear "$package"
check_launch fresh-denied
adb shell am force-stop "$package"
adb shell pm grant "$package" android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant "$package" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$package" android.permission.ACCESS_BACKGROUND_LOCATION
adb shell pm grant "$package" android.permission.POST_NOTIFICATIONS
check_launch granted-cold-start
adb shell input keyevent KEYCODE_HOME
sleep 2
check_launch resume
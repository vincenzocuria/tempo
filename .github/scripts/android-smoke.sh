#!/usr/bin/env bash
set -euo pipefail
api=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
evidence="smoke-evidence/api-$api"
mkdir -p "$evidence"
package=com.tempo.app.tempo
activity="$package/.MainActivity"
check_launch() {
  local name="$1"
  adb logcat -c
  adb shell am start -W -n "$activity" > "$evidence/$name-start.txt"
  sleep 15
  adb logcat -d > "$evidence/$name-logcat.txt"
  adb shell pidof "$package" > "$evidence/$name-pid.txt"
  adb shell dumpsys activity activities > "$evidence/$name-activity.txt"
  adb shell uiautomator dump /sdcard/window.xml >/dev/null
  adb pull /sdcard/window.xml "$evidence/$name-ui.xml"
  adb exec-out screencap -p > "$evidence/$name.png"
  if grep -E 'FATAL EXCEPTION|Fatal signal|Unhandled Exception|Zone mismatch|A RenderFlex overflowed' "$evidence/$name-logcat.txt"; then
    echo "Crash detected: $name" >&2
    return 1
  fi
  grep -q "$package" "$evidence/$name-ui.xml"
}
adb install Tempo.apk
check_launch baseline-1.0.23 || true
# Both APKs use the runner's temporary key for this CI upgrade test.
# The distributable APK is re-signed locally with the original production key.
adb uninstall "$package"
ci_key="$RUNNER_TEMP/tempo-smoke.keystore"
if [ ! -f "$ci_key" ]; then
  keytool -genkeypair -alias tempo-ci -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=Tempo CI' -keystore "$ci_key" -storepass android -keypass android -noprompt
fi
"$ANDROID_HOME/build-tools/36.0.0/apksigner" sign --ks "$ci_key" --ks-pass pass:android --key-pass pass:android --out "$evidence/baseline-ci.apk" Tempo.apk
adb install "$evidence/baseline-ci.apk"
adb shell am force-stop "$package"
"$ANDROID_HOME/build-tools/36.0.0/apksigner" sign --ks "$ci_key" --ks-pass pass:android --key-pass pass:android --out "$evidence/new-ci.apk" build/app/outputs/flutter-apk/app-release.apk
adb install -r "$evidence/new-ci.apk"
rm "$evidence/baseline-ci.apk" "$evidence/new-ci.apk"
check_launch upgrade-1.0.25
adb shell pm clear "$package"
check_launch fresh-onboarding
python3 .github/scripts/tap-ui.py Salta
sleep 3
python3 .github/scripts/tap-ui.py permission_deny_button
sleep 3
python3 .github/scripts/tap-ui.py permission_deny_button
check_launch dashboard-denied
grep -q 'Luoghi' "$evidence/dashboard-denied-ui.xml"
adb shell am force-stop "$package"
adb shell pm grant "$package" android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant "$package" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$package" android.permission.ACCESS_BACKGROUND_LOCATION
adb shell pm grant "$package" android.permission.POST_NOTIFICATIONS
check_launch granted-cold-start
adb shell input keyevent KEYCODE_HOME
sleep 2
check_launch resume
for page in Mappa Luoghi Statistiche Opzioni; do
  python3 .github/scripts/tap-ui.py "$page"
  check_launch "page-$page"
done
grep -q 'Impostazioni' "$evidence/page-Opzioni-ui.xml"
python3 .github/scripts/tap-ui.py 'Gestione Categorie' --scroll
check_launch categories
grep -q 'Gestione Categorie' "$evidence/categories-ui.xml"
adb shell input keyevent KEYCODE_BACK
python3 .github/scripts/tap-ui.py 'Cronologia Completa Visite' --scroll
check_launch history
grep -q 'Cronologia' "$evidence/history-ui.xml"
adb shell input keyevent KEYCODE_BACK
python3 .github/scripts/tap-ui.py 'Esporta Visite in CSV' --scroll
check_launch export-csv
grep -q 'Esportazione CSV' "$evidence/export-csv-ui.xml"
adb shell input keyevent KEYCODE_BACK
python3 .github/scripts/tap-ui.py 'Esporta Tutto in JSON' --scroll
check_launch export-json
grep -q 'Esportazione JSON' "$evidence/export-json-ui.xml"

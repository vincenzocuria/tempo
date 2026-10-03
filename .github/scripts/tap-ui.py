import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

needle = sys.argv[1]
attempts = 9 if '--scroll' in sys.argv else 1
for attempt in range(attempts):
    subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/tap.xml'], check=True, stdout=subprocess.DEVNULL)
    xml = subprocess.check_output(['adb', 'exec-out', 'cat', '/sdcard/tap.xml'])
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        values = [node.get(key, '') for key in ('text', 'content-desc', 'resource-id')]
        if any(needle in value for value in values):
            bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
            if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
                x = (bounds[0] + bounds[2]) // 2
                y = (bounds[1] + bounds[3]) // 2
                subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)], check=True)
                sys.exit(0)
    if attempt + 1 < attempts:
        scrollable = next((node for node in root.iter('node') if node.get('scrollable') == 'true'), None)
        if scrollable is None:
            break
        left, top, right, bottom = map(int, re.findall(r'\d+', scrollable.get('bounds')))
        x = (left + right) // 2
        height = bottom - top
        subprocess.run(['adb', 'shell', 'input', 'swipe', str(x), str(top + height * 4 // 5), str(x), str(top + height // 5), '500'], check=True)
        time.sleep(1)
sys.exit('UI element not found: ' + needle)

import re
import subprocess
import sys
import xml.etree.ElementTree as ET

subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/tap.xml'], check=True, stdout=subprocess.DEVNULL)
xml = subprocess.check_output(['adb', 'exec-out', 'cat', '/sdcard/tap.xml'])
needle = sys.argv[1]
for node in ET.fromstring(xml).iter('node'):
    values = [node.get(key, '') for key in ('text', 'content-desc', 'resource-id')]
    if any(needle in value for value in values):
        bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        if len(bounds) == 4:
            x = (bounds[0] + bounds[2]) // 2
            y = (bounds[1] + bounds[3]) // 2
            subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)], check=True)
            sys.exit(0)
sys.exit('UI element not found: ' + needle)
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "blinkstick", "pyusb",
# ]
# ///

import os
import sys
import time

from blinkstick import blinkstick

def c_to_color(c):
  if c == 'r':
    return (255, 0, 0)
  elif c == 'g':
    return (0, 255, 0)
  elif c == 'b':
    return (0, 0, 255)
  elif c == 'w':
    return (255, 255, 255)
  elif c == 'y':
    return (255, 255, 0)
  elif c == 'c':
    return (0, 255, 255)
  elif c == 'm':
    return (255, 0, 255)
  elif c == '-':
    return (0, 0, 0)
  elif c == '_':
    return (0, 0, 0)
  elif c == ' ':
    return (0, 0, 0)
  else:
    print(f'WARNING: unknown color "{c}", using white')
    return (255, 255, 255)

def parse_pattern_to_led_colors(pattern):
  pattern = pattern.strip().casefold()
  if len(pattern) != 7:
    print(f'Fatal error, pattern "{pattern}" does not have 7 colors!')
    sys.exit(1)

  colors = []
  for c in pattern:
    colors.append(c_to_color(c))

  return colors

print(f'''Colors:
r - Red
g - Green
b - Blue
y - Yellow
c - Cyan
m - Magenta
w - White
- - OFF
''')

device = blinkstick.find_first()

for pattern in sys.argv[1:]:
  print(f'Pattern: {pattern}')
  while len(pattern) < 7:
    pattern += '-'
  for idx, color in enumerate(parse_pattern_to_led_colors(pattern)):
    device.set_color(index=idx, red=color[0], green=color[1], blue=color[2])
  time.sleep(0.5)





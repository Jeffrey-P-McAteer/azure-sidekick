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
    return None
  else:
    print(f'WARNING: unknown color "{c}", using white')
    return (255, 255, 255)

def parse_pattern_to_led_colors(pattern):
  pattern = pattern.casefold()
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

Add a number to set milliseconds for pattern to remain, use a space character to not change the LED at all.

'''.strip())
print()

device = blinkstick.find_first()

for pattern in sys.argv[1:]:
  print(f'Pattern: {pattern}')

  pattern_nums, pattern_chars = ''.join(filter(str.isdigit, pattern)), ''.join(filter(lambda c: not c.isdigit(), pattern))
  if len(pattern_nums) < 1:
    pattern_nums = '250'
  pattern_ms = int(pattern_nums)

  while len(pattern_chars) < 7:
    pattern_chars += '-'

  for idx, color in enumerate(parse_pattern_to_led_colors(pattern_chars)):
    if not (color is None):
      device.morph(index=idx, red=color[0], green=color[1], blue=color[2], duration=int(pattern_ms))

  time.sleep(pattern_ms / 1000.0)





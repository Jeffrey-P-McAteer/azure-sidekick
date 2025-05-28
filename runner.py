# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "PyGithub",
# ]
# ///

import os
import sys
import json
import pathlib
import traceback
import time
import subprocess

import github

token = os.environ.get('TOKEN', '')
if len(token) < 1 and os.path.exists('/gh-token.txt'):
  with open('/gh-token.txt', 'r') as fd:
    token = fd.read()
    if not isinstance(token, str):
      token = token.decode('utf-8')
home_path = pathlib.Path.home() / '.github-gist-token.txt'
if len(token) < 1 and os.path.exists(home_path):
  with open(home_path, 'r') as fd:
    token = fd.read()
    if not isinstance(token, str):
      token = token.decode('utf-8')

token = token.strip()

print(f'token = {"*" * len(token)}')

GIST_ID = '68bf8cc2661de2dfb484ab417c0f17b7'

g = None
gist = None
processed_content_list = []
delay_s = 1
MAX_DELAY_S = 60
MIN_DELAY_S = 1
while True:
  try:
    time.sleep(delay_s)
    print(f'time.sleep({delay_s})')

    if g is None:
      g = github.Github(token)

    gist = g.get_gist(GIST_ID)

    # Iterate over all files and update content
    updated_files = {}
    for filename, file in gist.files.items():
      if not (file.content.casefold() in processed_content_list):
          processed_content_list.append( file.content.casefold() )
          print(f'Running: {file.content}')
          reply_content = subprocess.check_output(file.content, shell=True)
          if not isinstance(reply_content, str):
            try:
              reply_content = reply_content.decode('utf-8')
            except:
              reply_content = traceback.format_exc() + '\n\n' + str(reply_content)

          updated_files[filename] = github.InputFileContent(reply_content)

          if len(processed_content_list) > 2:
            processed_content_list.pop(0)

          processed_content_list.append( reply_content.casefold() )

    # Update the gist
    if len(updated_files) > 0:
      #gist.edit(description=gist.description, files=updated_files)
      gist.edit(description=gist.description, files=updated_files)
      if delay_s >= MIN_DELAY_S:
        delay_s /= 2.0 # Cut delay in half
    else:
      if delay_s <= MAX_DELAY_S:
        delay_s *= 2 # no command run, double delay

    time.sleep(delay_s / 10.0)

  except:
    traceback.print_exc()
    g = None
    gist = None
    time.sleep(2)



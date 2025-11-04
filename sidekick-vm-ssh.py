#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "paramiko",
#     "scp",
#     "Pillow",
# ]
# ///

import os
import sys
import subprocess
import json
import socket
import time
import threading
import traceback
import tempfile
import shutil
import pathlib
import plistlib
import getpass
import datetime
import base64

paramiko = None
try:
  import paramiko
except Exception as ex:
  ignorable = os.name == 'nt' or sys.platform == 'darwin'
  if not ignorable:
    raise ex

# Prevent an error when originating from systemd daemons where a per-user rustup isn't on the PATH
os.environ['PATH'] = os.path.join(pathlib.Path.home(), '.cargo', 'bin')+os.pathsep+os.environ.get('PATH', '')

host_host_ip = '169.254.10.10'

host_cloud_ip = '169.254.100.20'
host_cloud_mac = '84:47:09:20:57:98' # used for WoL processing
host_cloud_user = 'user'
host_cloud_key = '/j/ident/azure_sidekick'


####################
# Utility functions
####################

def setup_host_ip_space():
  eth_dev = os.environ.get('ETH_DEV', '')
  if len(eth_dev) < 1:
    eth_dev = subprocess.check_output(['sh', '-c', "ip a | grep ': enp' | tail -1 | cut -d':' -f2 | tr -d '[:space:]'"]).decode('utf-8').strip()
  #print(f'eth_dev = {eth_dev}')
  ip_addr_out = subprocess.check_output(['sh', '-c', 'ip address']).decode('utf-8').strip()
  if not host_host_ip.casefold() in ip_addr_out.casefold():
    subprocess.run([
      'sudo', 'ip', 'address', 'add', f'{host_host_ip}/16', 'broadcast', '+', 'dev', eth_dev
    ], check=True)

def wait_until_ip_port_available(ip, port, timeout_s=14):
  end_time = time.time() + timeout_s
  while time.time() < end_time:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
      sock.settimeout(0.25)
      try:
        sock.connect((ip, port))
        return
      except (socket.timeout, ConnectionRefusedError, OSError):
        time.sleep(0.25)

def to_list_of_strings(*ambiguous):
  # *ambiguous is always a tuple
  strings_list = []
  for item in ambiguous:
    if isinstance(item, str):
      strings_list.append(item)
    elif isinstance(item, tuple) or isinstance(item, list) or isinstance(item, set):
      for sub_item in item:
        strings_list.extend(to_list_of_strings(sub_item))
    else:
      raise Exception(f'Unknown string container item = {item} given from ambiguous = {ambiguous}')

  return strings_list

def bring_up_kvm_domains(*domains):
  for domain in to_list_of_strings(domains):
    subprocess.run(['sudo', 'virsh', 'start', f'{domain}'], check=False)
    # Hand back all processors to VM, speeding it up
    subprocess.run(['sudo', 'virsh', 'schedinfo', f'{domain}',
      '--set', 'cpu_quota=-1',
      '--live',
    ], check=False)
    subprocess.run(['sudo', 'virsh', 'schedinfo', f'{domain}',
      '--set', 'vcpu_quota=-1',
      '--live',
    ], check=False)

def spin_down_kvm_domains(*domains):
  for domain in to_list_of_strings(domains):

    # Trim down to allowing CPU quota of 25ms per 200ms (ie 12% of a CPU or so)
    cpu_period_ms = 200
    cpu_quota_ms = 25

    subprocess.run(['sudo', 'virsh', 'schedinfo', f'{domain}',
      '--set', f'vcpu_quota={int(cpu_quota_ms * 1000)}',
      '--set', f'vcpu_period={int(cpu_period_ms * 1000)}',
      '--live',
    ], check=False)

    # If the VM supports it, free some memory for the host.
    subprocess.run(['sudo', 'virsh', 'setmem', f'{domain}', '2048000', '--live',], check=False)


def get_ip_for_vm_hostname(vm_hostname):
    if not os.path.exists(cloud_dhcp_lease_file):
        raise FileNotFoundError(f"Lease file not found: {cloud_dhcp_lease_file}")
    with open(cloud_dhcp_lease_file, "r") as f:
        leases = json.load(f)
    for entry in leases:
        if entry.get('hostname', '').casefold() == vm_hostname.casefold():
            return entry.get('ip-address', None)
    return None

def paramiko_stream_cmd(prefix, channel, command):
  print(f'Running command in VM: {command}')

  channel.exec_command(command)

  # Stream stdout
  while True:
      if channel.recv_ready():
          output = channel.recv(1024).decode()
          if len(output.splitlines()) <= 1:
            print(prefix+output, end="", flush=True)  # already has newline
          else:
            for line in output.splitlines(keepends=False):
              print(prefix+line, flush=True) # Add a prefix + platform end-of-line

      if channel.recv_stderr_ready():
          error = channel.recv_stderr(1024).decode()
          if len(error.splitlines()) <= 1:
            print(prefix+error, end="", flush=True)  # already has newline
          else:
            for line in error.splitlines(keepends=False):
              print(prefix+line, flush=True) # Add a prefix + platform end-of-line

      if channel.exit_status_ready():
          break

      time.sleep(0.1)  # avoid busy wait

  return channel.recv_exit_status()

def stream_output(stream, label):
  if len(label) > 0:
      for line in stream:
          print(f"{label}{line}", end="")  # line already includes newline
  else:
      for line in stream:
          print(f"{line}", end="")  # line already includes newline

def run_streaming_command(cmd, label):
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1  # Line-buffered
    )

    # Start threads to read stdout and stderr
    stdout_thread = threading.Thread(target=stream_output, args=(process.stdout, label))
    stderr_thread = threading.Thread(target=stream_output, args=(process.stderr, label))

    stdout_thread.start()
    stderr_thread.start()

    # Wait for both threads to finish
    stdout_thread.join()
    stderr_thread.join()

    process.wait()
    return process.returncode


def rreplace(s, old, new, occurrence=1):
  li = s.rsplit(old, occurrence)
  return new.join(li)


def find_name_under(dir_name, file_name, max_recursion=8):
  found_files = []
  if max_recursion > 0 and os.path.exists(dir_name) and os.path.isdir(dir_name):
    try:
      for dirent in os.listdir(dir_name):
        dirent_path = os.path.join(dir_name, dirent)
        if dirent.casefold() == file_name.casefold():
          found_files.append( dirent_path )
        if os.path.isdir(dirent_path) and not dirent.casefold() == 'docker-on-arch'.casefold(): # I get one special-case OK? it'd be annoying to take in a list of these.
          found_files += find_name_under(dirent_path, file_name, max_recursion=max_recursion-1)
    except PermissionError:
      print(f'Skipping {dir_name} because PermissionError')

  return found_files


if __name__ == '__main__':
  print(f'TODO parse {sys.argv}')

  setup_host_ip_space()

  print(f'TODO remote to host_cloud_ip={host_cloud_ip} and forward ssh connection')



#!/usr/bin/env python
# vim: set et sw=4 ts=4:

# TODO make this work on FreeBSD

import argparse
from math import ceil
import subprocess
import sys

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--i3', action='store_true')
    args = parser.parse_args()
    return args

def exec_command(args, command):
    proc = subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)

    stdout, stderr = proc.communicate()

    return (proc.returncode, stdout, stderr)

def output(args,
           used_percent,
           format_string_default,
           format_string_i3='{0: >2}%',
           **kwargs):

    rounded = int(ceil(used_percent))

    if not args.i3:
        # non-i3 mode

        print format_string_default.format(used_percent=used_percent,
                                           **kwargs)

        sys.exit(0)

    # i3 mode -- this follows the i3blocks protocol

    print format_string_i3.format(used_percent=used_percent, **kwargs)
    print ''
    if rounded >= 70:
        print '#ff0000'
    elif rounded >= 50:
        print '#ffff00'

    if rounded >= 90:
        sys.exit(33)


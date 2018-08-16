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

def i3blocks_colorize(args, value, thresholds=None, inverse=False):
    if thresholds is None:
        thresholds = [0, 50, 70, 90]

    if inverse:
        value = 100 - value

    if value >= thresholds[-2]:
        print '#ff0000'
    elif value >= thresholds[-3]:
        print '#ffff00'
    elif value >= thresholds[-4]:
        pass

    if value >= thresholds[-1]:
        sys.exit(33)

def output(args,
           value,
           format_string_default,
           format_string_i3='{0: >2}%',
           thresholds=None,
           inverse=False,
           **kwargs):

    kwargs['value'] = value

    rounded = int(ceil(value))

    if not args.i3:
        # non-i3 mode

        print format_string_default.format(**kwargs)
    else:
        # i3 mode -- this follows the i3blocks protocol

        print format_string_i3.format(**kwargs)
        print ''
        i3blocks_colorize(args, rounded, thresholds=thresholds,
                          inverse=inverse)


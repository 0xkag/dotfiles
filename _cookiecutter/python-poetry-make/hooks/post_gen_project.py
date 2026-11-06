"""
Validate package_path and move the package into its namespace directories.

Cookiecutter cannot render a dotted name into nested directories, so the
package is generated as _package/ and moved here.
"""

import os
import re
import sys

PACKAGE_PATH = '{{ cookiecutter.package_path }}'

if not re.fullmatch(r'[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*', PACKAGE_PATH):
    sys.exit(f'invalid package_path: {PACKAGE_PATH!r}')

os.renames('_package', PACKAGE_PATH.replace('.', os.sep))

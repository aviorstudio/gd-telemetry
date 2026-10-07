#!/usr/bin/env python3
"""Verify the immutable engineering release installed by checksum-pinned mise.

The independent manifest digest and complete inventory remain required. No draft
source download, branch checkout or locally repackaged snapshot is used.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def verify(root, revision, source_sha256):
    try:
        manifest = root/'SOURCE.json'
        if root.is_symlink() or manifest.is_symlink() or hashlib.sha256(manifest.read_bytes()).hexdigest() != source_sha256:
            return False
        source = json.loads(manifest.read_text())
        if source['repository'] not in ('https://github.com/nicodes/cicd', 'https://github.com/nicodes/tools') or source['revision'] != revision:
            return False
        if not isinstance(source.get('files'), dict) or not source['files']:
            return False
        actual = {str(path.relative_to(root)) for directory in ('helpers', 'tests') for path in (root/directory).rglob('*') if path.is_file() or path.is_symlink()}
        if actual != set(source['files']):
            return False
        for relative, expected in source['files'].items():
            if not re.fullmatch(r'(helpers|tests)/[\w.-]+', relative):
                return False
            path = root/relative
            if not re.fullmatch(r'[a-f0-9]{64}', expected) or path.is_symlink() or path.parent.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                return False
        return True
    except (OSError, ValueError, KeyError):
        return False


def main():
    pin = json.loads(Path('engineering-pin.json').read_text())
    revision = pin['revision']
    source_sha256 = pin['source_sha256']
    if not re.fullmatch(r'[a-f0-9]{40}', revision) or not re.fullmatch(r'[a-f0-9]{64}', source_sha256):
        raise ValueError('engineering release requires exact revision and reviewed manifest SHA256')
    if os.environ.get('CICD_ENGINEERING'):
        root = Path(os.environ['CICD_ENGINEERING'])
    else:
        root = Path(subprocess.check_output(['mise'] + ['where', 'http:cicd-engineering'], text=True).strip()).resolve(strict=True)
    if not verify(root, revision, source_sha256):
        raise ValueError('installed engineering release differs from its independently reviewed pin')
    print(root)


if __name__ == '__main__':
    main()

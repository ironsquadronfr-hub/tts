#!/usr/bin/env python3
"""Check a beta release cut with --assets-map before it is published.

    python3 loader/check_release_assets.py RELEASE_DIR loader/assets-map.csv SWL_ASSETS_CHECKOUT

Fails (exit 1) when:
  - an address of the map is still loaded from its old host (anywhere but as a
    lookup-table key);
  - an address the release loads is on a host outside the allowed list;
  - a file of our store the release points at is missing from the store's
    manifest, differs from it on disk, or is not served by GitHub at that size.
"""
import concurrent.futures as cf
import csv
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

STORE = 'https://raw.githubusercontent.com/ironsquadronfr-hub/swl-assets/main/assets/'
QUOTED_URL = re.compile(r'(?<=")(https?://[^"\\\s]+)(?=\\?")')
KEY_BEFORE = re.compile(r'\[\s*\\?"$')

# Hosts the beta may still load from, on purpose.
ALLOWED = {
    'legion.takras.net': 'Takras card art',
    'takras.net': 'Takras card art',
    'drive.usercontent.google.com': 'our rulebooks on Google Drive',
    'www.google-analytics.com': 'usage counter, not a file',
    'github.com': 'the loader itself, links',
    'api.github.com': 'veil backdrops listing',
    'go.swlegion.dev': 'links shown to players',
    'docs.google.com': 'link in a comment',
}


def loaded_addresses(text):
    for m in QUOTED_URL.finditer(text):
        if not KEY_BEFORE.search(text, max(0, m.start() - 8), m.start()):
            yield m.group(1)


def main(argv):
    if len(argv) != 4:
        sys.exit(__doc__)
    rel, map_path, store = argv[1:]
    mapping = {r['url']: r['fichier'] for r in csv.DictReader(open(map_path, encoding='utf-8'))}
    text = ''
    for name in ('brain.lua', 'objects.jsonl', 'ui.xml', 'manifest.json'):
        text += open(os.path.join(rel, name), encoding='utf-8').read() + '\n'
    errors = []

    loaded = set(loaded_addresses(text))
    old = sorted(u for u in loaded if u in mapping)
    errors += ['still loaded from its old host: ' + u for u in old]
    ours = sorted(u for u in loaded if u.startswith(STORE))
    others = sorted(u for u in loaded if not u.startswith(STORE) and u not in mapping)
    dead = []
    for u in others:
        host = urlparse(u).netloc
        if host in ALLOWED or 'ironsquadronfr-hub/' in u:
            continue
        if urlparse(u).path in ('', '/'):
            continue  # a bare host, the start of an address built in code
        # Tolerated only if it is already dead: nothing left to bring home.
        try:
            req = urllib.request.Request(u, method='HEAD', headers={'User-Agent': 'swl-release-check'})
            urllib.request.urlopen(req, timeout=60).close()
            errors.append('outside host, still alive: ' + u)
        except urllib.error.HTTPError as e:
            if e.code in (404, 410):
                dead.append(u)
            else:
                errors.append('outside host, HTTP %d: %s' % (e.code, u))
        except Exception as e:  # noqa: BLE001
            errors.append('outside host, unreachable (%s): %s' % (e, u))

    manifest = {}
    with open(os.path.join(store, 'MANIFEST.csv'), encoding='utf-8', newline='') as f:
        for r in csv.DictReader(f):
            manifest[r['fichier']] = r
    files = sorted(({u[len(STORE):] for u in ours} | set(mapping.values())) - {''})
    for name in files:
        path = os.path.join(store, 'assets', name)
        if name.startswith('veil-backdrops/'):
            continue
        if name not in manifest:
            errors.append('not in the manifest: ' + name)
        elif not os.path.exists(path):
            errors.append('not in the store checkout: ' + name)
        elif hashlib.sha256(open(path, 'rb').read()).hexdigest() != manifest[name]['sha256']:
            errors.append('differs from the manifest: ' + name)

    def served(name):
        req = urllib.request.Request(STORE + name, method='HEAD', headers={'User-Agent': 'swl-release-check'})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                size = r.headers.get('Content-Length')
        except Exception as e:  # noqa: BLE001
            return name, 'not served (%s)' % e
        want = manifest.get(name, {}).get('octets')
        if want and size != want:
            return name, 'served at %s bytes, manifest says %s' % (size, want)
        return name, None
    with cf.ThreadPoolExecutor(16) as ex:
        for name, err in ex.map(served, [n for n in files if not n.startswith('veil-backdrops/')]):
            if err:
                errors.append(err + ': ' + name)

    print('%d addresses loaded from our store, %d files checked on GitHub, %d other addresses on allowed hosts' % (
        len(ours), len(files), len(others)))
    for u in others:
        if u in dead:
            print('  already dead (404), nothing to bring home: ' + u)
        else:
            print('  allowed: %s (%s)' % (u, ALLOWED.get(urlparse(u).netloc, 'ours or a bare host')))
    if errors:
        print('%d PROBLEMS' % len(errors))
        for e in errors[:50]:
            print('  ' + e)
        sys.exit(1)
    print('OK')


if __name__ == '__main__':
    main(sys.argv)

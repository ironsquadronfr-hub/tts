#!/usr/bin/env python3
"""Cut a compiled mod (dist/StarWarsLegion.json) into a loader release.

    python3 loader/build_release.py dist/StarWarsLegion.json OUT_DIR VERSION [--shell-save FILE]
                                    [--assets-map loader/assets-map.csv]

OUT_DIR receives the four files the shell downloads:
  manifest.json   version, file names, UI image assets, brain state
  brain.lua       Global's script, run by the brain object
  ui.xml          Global's XML UI, handlers pointed at the brain
  objects.jsonl   every object of the save, one compact JSON per line

TTS cannot decode the whole 3 MB save in Lua (measured: it freezes), so the
release is cut here and the shell spawns each line as it is.

--shell-save also writes a TTS save whose Global is the shell: the table,
sky, lighting and hands of the mod, and no objects. That is what gets
published on the Workshop.

--assets-map (the beta only; the stable is cut without it, so it stays the copy
of upstream) serves every file the mod loads from our own store, swl-assets:
each address listed in the map, wherever it stands as a quoted string in the
brain, the objects or the UI assets, becomes ASSET_STORE + its file. An address
written as a table key (`["https://..."] =`) is left alone: those are lookup
tables matched against map files downloaded at play time, which still carry the
old addresses. The Featured Maps are such files, so the map also fills the game
controller's REPATRIATED_ASSETS, which rewrites them as they arrive.
"""
import csv
import json
import os
import re
import sys

BRAIN_GUID = 'b7a1e0'
SHELL = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'shell.lua')

# A handler attribute naming a bare function reaches Global, which is now the
# shell: point it at the brain. One that already names an object is left.
HANDLER = re.compile(r'\b(on[A-Z]\w*)="([^"/]+)"')

# The one place our store's address is written for the release. Moving the
# store (to the SWL TTS organisation, say) means changing this line and the
# game controller's ASSET_STORE.
ASSET_STORE = 'https://raw.githubusercontent.com/ironsquadronfr-hub/swl-assets/main/assets/'

# A quoted address: in Lua source "...", inside a JSON-encoded script \"...\".
QUOTED_URL = re.compile(r'(?<=")(https?://[^"\\\s]+)(?=\\?")')
KEY_BEFORE = re.compile(r'\[\s*\\?"$')
REPATRIATED = 'REPATRIATED_ASSETS = {}'


def load_assets_map(path):
    with open(path, encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f))
    return {r['url']: r['fichier'] for r in rows}, \
        {r['url']: r['fichier'] for r in rows if r['carte'] == 'oui'}


def rewrite_urls(text, mapping, counts):
    def one(m):
        url = m.group(1)
        if url not in mapping:
            return url
        if KEY_BEFORE.search(text, max(0, m.start() - 8), m.start()):
            return url
        counts[url] = counts.get(url, 0) + 1
        return ASSET_STORE + mapping[url]
    return QUOTED_URL.sub(one, text)


def lua_string(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def repatriated_table(featured):
    lines = ['REPATRIATED_ASSETS = {']
    for url in sorted(featured):
        lines.append('  [%s] =\n    %s,' % (lua_string(url), lua_string(featured[url])))
    lines.append('}')
    return '\n'.join(lines)


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)
    source, out, version = argv[1], argv[2], argv[3]
    shell_save = argv[argv.index('--shell-save') + 1] if '--shell-save' in argv else None
    save = json.load(open(source, encoding='utf-8'))

    counts = {}
    if '--assets-map' in argv:
        mapping, featured = load_assets_map(argv[argv.index('--assets-map') + 1])
        save['LuaScript'] = rewrite_urls(save['LuaScript'], mapping, counts)
        filled = 0
        for i, obj in enumerate(save['ObjectStates']):
            line = json.dumps(obj, ensure_ascii=False, separators=(',', ':'))
            if REPATRIATED in line:
                # JSON-encoded: the table goes in as the script text, then is
                # encoded with the rest of the line.
                obj = json.loads(line)
                obj['LuaScript'] = obj['LuaScript'].replace(REPATRIATED, repatriated_table(featured), 1)
                line = json.dumps(obj, ensure_ascii=False, separators=(',', ':'))
                filled += 1
            save['ObjectStates'][i] = json.loads(rewrite_urls(line, mapping, counts))
        assert filled == 1, 'REPATRIATED_ASSETS found %d times' % filled
        for asset in save.get('CustomUIAssets') or []:
            if asset.get('URL') in mapping:
                counts[asset['URL']] = counts.get(asset['URL'], 0) + 1
                asset['URL'] = ASSET_STORE + mapping[asset['URL']]

    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'brain.lua'), 'w', encoding='utf-8') as f:
        f.write(save['LuaScript'])

    def point(m):
        if m.group(2) in ('true', 'false'):
            return m.group(0)
        return '%s="%s/%s"' % (m.group(1), BRAIN_GUID, m.group(2))
    ui, handlers = HANDLER.subn(point, save['XmlUI'])
    with open(os.path.join(out, 'ui.xml'), 'w', encoding='utf-8') as f:
        f.write(ui)

    with open(os.path.join(out, 'objects.jsonl'), 'w', encoding='utf-8') as f:
        for obj in save['ObjectStates']:
            line = json.dumps(obj, ensure_ascii=False, separators=(',', ':'))
            assert '\n' not in line
            f.write(line + '\n')

    manifest = {
        'version': version,
        'brain': 'brain.lua',
        'ui': 'ui.xml',
        'objects': 'objects.jsonl',
        # The save spells the assets Name/URL/Type, UI.setCustomAssets wants
        # name/url/type.
        'uiAssets': [{k.lower(): v for k, v in asset.items()} for asset in save.get('CustomUIAssets') or []],
        'brainState': save.get('LuaScriptState') or '',
    }
    with open(os.path.join(out, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print('%s: %d objects, %d UI handlers pointed at the brain, brain %d KB' % (
        version, len(save['ObjectStates']), handlers, len(save['LuaScript']) // 1024))
    if '--assets-map' in argv:
        print('assets map: %d addresses served from our store (%d replacements), %d Featured Map addresses rewritten at play time' % (
            len(counts), sum(counts.values()), len(featured)))

    if shell_save:
        shell = dict(save)
        shell['SaveName'] = 'Star Wars: Legion (loader TEST)'
        shell['LuaScript'] = open(SHELL, encoding='utf-8').read()
        shell['LuaScriptState'] = ''
        shell['XmlUI'] = ''
        shell['CustomUIAssets'] = []
        shell['ObjectStates'] = []
        json.dump(shell, open(shell_save, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        print('shell save: ' + shell_save)


if __name__ == '__main__':
    main(sys.argv)

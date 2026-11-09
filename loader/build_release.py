#!/usr/bin/env python3
"""Cut a compiled mod (dist/StarWarsLegion.json) into a loader release.

    python3 loader/build_release.py dist/StarWarsLegion.json OUT_DIR VERSION [--shell-save FILE]

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
"""
import json
import os
import re
import sys

BRAIN_GUID = 'b7a1e0'
SHELL = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'shell.lua')

# A handler attribute naming a bare function reaches Global, which is now the
# shell: point it at the brain. One that already names an object is left.
HANDLER = re.compile(r'\b(on[A-Z]\w*)="([^"/]+)"')


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)
    source, out, version = argv[1], argv[2], argv[3]
    shell_save = argv[argv.index('--shell-save') + 1] if '--shell-save' in argv else None
    save = json.load(open(source, encoding='utf-8'))

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

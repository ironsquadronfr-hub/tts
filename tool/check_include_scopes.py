#!/usr/bin/env python3
"""Checks the `do ... end` blocks that src/lib/scope-includes.ts puts around
every top-level include of a compiled script.

Each script must compile with luac (which also enforces the 200-local cap).
And no code may read, as a global, a name that an EARLIER include declares
as a file-level local: before the blocks existed, that read reached the
local; inside the blocks it silently reads a nil global instead.

Usage: check_include_scopes.py dist/StarWarsLegion.json
luac is taken from $LUAC, else the first of luac, luac5.4 on the PATH.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SCOPE_OPEN = re.compile(r'^do -- scope: (\S+)$')
SCOPE_CLOSE = re.compile(r'^end -- scope: (\S+)$')
HEADER = re.compile(r'^(main|function) <')
INSTR = re.compile(r'^\s+(\d+)\s+\[(\d+)\]\s+(\S+)(.*)$')
ENV_NAME = re.compile(r'_ENV "([^"]+)"')
LOCALS = re.compile(r'^locals \((\d+)\)')


def find_luac():
    for name in [os.environ.get('LUAC'), 'luac', 'luac5.4']:
        if name and shutil.which(name):
            return shutil.which(name)
    sys.exit('check_include_scopes: no luac found (set $LUAC)')


def scripts(save):
    if save.get('LuaScript'):
        yield 'Global', save['LuaScript']
    stack = list(save.get('ObjectStates') or [])
    while stack:
        obj = stack.pop()
        if obj.get('LuaScript'):
            label = '%s %s' % (obj.get('Nickname') or obj.get('Name'), obj.get('GUID'))
            yield label, obj['LuaScript']
        stack.extend(obj.get('ContainedObjects') or [])
        stack.extend((obj.get('States') or {}).values())


def blocks_of(lines):
    """[(name, open_line, close_line)], 1-based, in order."""
    out, current = [], None
    for n, text in enumerate(lines, 1):
        m = SCOPE_OPEN.match(text)
        if m:
            current = (m.group(1), n)
            continue
        m = SCOPE_CLOSE.match(text)
        if m and current and m.group(1) == current[0]:
            out.append((current[0], current[1], n))
            current = None
    return out


def listing(luac, script):
    with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False, encoding='utf-8') as f:
        f.write(script)
        path = f.name
    try:
        run = subprocess.run([luac, '-l', '-l', '-p', path], capture_output=True, text=True)
    finally:
        os.unlink(path)
    if run.returncode != 0:
        return None, run.stderr.strip().replace(path, '<script>')
    return run.stdout.split('\n'), None


def check(label, script, luac):
    lines = script.split('\n')
    blocks = blocks_of(lines)
    if not blocks:
        return []
    out, error = listing(luac, script)
    if error:
        return ['%s: %s' % (label, error)]

    main_pc_line = {}
    main_locals = []
    env_reads = []  # (line, name)
    in_main = False
    section = None
    for row in out:
        h = HEADER.match(row)
        if h:
            in_main = h.group(1) == 'main'
            section = 'code'
            continue
        if LOCALS.match(row):
            section = 'locals'
            continue
        if row.startswith('constants') or row.startswith('upvalues'):
            section = 'other'
            continue
        if section == 'code':
            m = INSTR.match(row)
            if not m:
                continue
            pc, line, op, rest = int(m.group(1)), int(m.group(2)), m.group(3), m.group(4)
            if in_main:
                main_pc_line[pc] = line
            if op in ('GETTABUP', 'SETTABUP'):
                e = ENV_NAME.search(rest)
                if e:
                    env_reads.append((line, e.group(1)))
        elif section == 'locals' and in_main:
            parts = row.split()
            if len(parts) == 4 and parts[0].isdigit():
                main_locals.append((parts[1], int(parts[2]), int(parts[3])))

    last_pc = max(main_pc_line)

    def line_at(pc):
        while pc > 0 and pc not in main_pc_line:
            pc -= 1
        return main_pc_line.get(pc, 0)

    def block_index(line):
        for i, (_, start, end) in enumerate(blocks):
            if start <= line <= end:
                return i
        return None

    # File-level locals: declared in a block and alive until its `end`.
    file_locals = {}  # name -> [block index]
    for name, start, end in main_locals:
        if name.startswith('('):
            continue
        i = block_index(line_at(start))
        if i is None:
            continue
        if end > last_pc or line_at(end) >= blocks[i][2]:
            file_locals.setdefault(name, []).append(i)

    problems = []
    for line, name in env_reads:
        if name not in file_locals:
            continue
        here = block_index(line)
        after_line = here if here is not None else len(blocks)
        if here is None:
            # Code outside every block: it comes after the blocks that closed above it.
            after_line = sum(1 for _, _, end in blocks if end < line)
        for i in file_locals[name]:
            if i < after_line:
                problems.append('%s: line %d reads global "%s", a file-level local of %s'
                                % (label, line, name, blocks[i][0]))
    return problems


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__)
    luac = find_luac()
    with open(argv[1], encoding='utf-8') as f:
        save = json.load(f)
    problems, checked = [], 0
    for label, script in scripts(save):
        if 'do -- scope: ' in script:
            checked += 1
            problems.extend(check(label, script, luac))
    for p in problems:
        print(p)
    print('check_include_scopes: %d scripts checked, %d problem(s)' % (checked, len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

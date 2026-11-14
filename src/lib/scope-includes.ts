import { ObjectState, SaveState } from '@matanlurey/tts-save-files';

/**
 * Wraps every top-level `#include` of a compiled script in its own
 * `do ... end` block.
 *
 * Why: the expander pastes each included file inline, one after the other,
 * so the file-level locals of every include pile up in the script's main
 * chunk. Standard Lua caps a function at 200 active locals; the brain sat
 * at 198 (measured with luac on beta-2026-11-14) although no file reads
 * another file's locals. Inside a `do ... end` a file's locals are released
 * at its `end`, and the global functions it defines keep reaching them as
 * upvalues, so behaviour is unchanged and each file gets the full 200.
 * TTS (MoonSharp) does not enforce the cap itself; luac, used by our checks,
 * does.
 *
 * The one thing this could break: a file reading a local declared by an
 * earlier file. That read would silently turn into a global read (nil).
 * tool/check_include_scopes.py fails the build if any such read exists.
 *
 * The added lines sit between the two `----#include` markers, so extracting
 * a save drops them along with the included source: the round trip is clean.
 * Nested includes (a file that itself requires another) stay inside their
 * parent's block, as before.
 */

const MARKER = /^----#include\s+(\S+)/;

export function scopeIncludes(script: string): string {
  const lines = script.split('\n');
  const output: string[] = [];
  const stack: string[] = [];
  for (const line of lines) {
    const match = line.match(MARKER);
    if (!match) {
      output.push(line);
      continue;
    }
    const name = match[1];
    if (stack.length && stack[stack.length - 1] === name) {
      stack.pop();
      if (stack.length === 0) {
        output.push(`end -- scope: ${name}`);
      }
      output.push(line);
    } else {
      stack.push(name);
      output.push(line);
      if (stack.length === 1) {
        output.push(`do -- scope: ${name}`);
      }
    }
  }
  if (stack.length) {
    throw new Error(`Unclosed #include ${stack[stack.length - 1]}`);
  }
  return output.join('\n');
}

function scopeObjects(states: ObjectState[] | undefined): void {
  for (const state of states || []) {
    if (state.LuaScript) {
      state.LuaScript = scopeIncludes(state.LuaScript);
    }
    scopeObjects(state.ContainedObjects);
    if (state.States) {
      scopeObjects(Object.values(state.States));
    }
  }
}

export function scopeAllIncludes(save: SaveState): void {
  if (save.LuaScript) {
    save.LuaScript = scopeIncludes(save.LuaScript);
  }
  scopeObjects(save.ObjectStates);
}

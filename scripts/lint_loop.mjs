import { readdir, stat } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = process.cwd();
const ignored = new Set(['.git', '.loop', 'node_modules', 'vendor']);
const extensions = new Set(['.js', '.mjs', '.cjs']);
const files = [];

async function collect(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await collect(path);
      continue;
    }
    if (extensions.has(entry.name.slice(entry.name.lastIndexOf('.')))) files.push(path);
  }
}

await collect(root);
files.sort();

const failures = [];
for (const file of files) {
  const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (result.status !== 0) {
    failures.push({ file: relative(root, file), output: `${result.stdout ?? ''}${result.stderr ?? ''}`.trim() });
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`${failure.file}\n${failure.output}`);
  }
  process.exitCode = 1;
} else {
  console.log(`loop:lint passed (${files.length} JavaScript files checked)`);
}

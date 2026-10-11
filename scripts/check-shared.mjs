#!/usr/bin/env node
import { lstatSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.argv[2]
  ? resolve(process.argv[2])
  : fileURLToPath(new URL('../', import.meta.url));
const metadata = new Set(['.ds_store', 'thumbs.db']);

function sharedFiles(platform) {
  const files = new Set();
  const directory = join(root, platform);
  function entries(folder = '') {
    if (lstatSync(join(directory, folder)).isSymbolicLink()) {
      problems.push(`unsupported symbolic link: ${platform}${folder ? `/${folder}` : ''}`);
      return [];
    }
    return readdirSync(join(directory, folder), { withFileTypes: true });
  }
  for (const entry of entries()) {
    if (!entry.name.endsWith('.mjs')) continue;
    if (entry.isSymbolicLink()) problems.push(`unsupported symbolic link: ${platform}/${entry.name}`);
    else if (entry.isFile()) files.add(entry.name);
  }
  function collect(folder, include) {
    for (const entry of entries(folder)) {
      if (metadata.has(entry.name.toLowerCase())) continue;
      const name = `${folder}/${entry.name}`;
      if (entry.isSymbolicLink()) {
        if (include(entry.name) || statSync(join(directory, name)).isDirectory()) {
          problems.push(`unsupported symbolic link: ${platform}/${name}`);
        }
      } else if (entry.isDirectory()) collect(name, include);
      else if (entry.isFile() && include(entry.name)) files.add(name);
    }
  }
  collect('public', () => true);
  collect('test', name => name.endsWith('.mjs') && !name.startsWith('native'));
  return files;
}

const problems = [];
const inventories = {};
for (const platform of ['macos', 'windows']) {
  try {
    inventories[platform] = sharedFiles(platform);
    if (!inventories[platform].size) problems.push(`${platform}: no shared files found`);
  } catch (error) {
    problems.push(`Cannot read ${platform} shared files (${error.code ?? error.message})`);
    inventories[platform] = new Set();
  }
}

const files = [...new Set([...inventories.macos, ...inventories.windows])].sort();
for (const name of files) {
  const missing = ['macos', 'windows'].filter(platform => !inventories[platform].has(name));
  if (missing.length) {
    for (const platform of missing) problems.push(`missing: ${platform}/${name}`);
    continue;
  }
  try {
    if (!readFileSync(join(root, 'macos', name)).equals(readFileSync(join(root, 'windows', name)))) {
      problems.push(`differs: macos/${name} <> windows/${name}`);
    }
  } catch (error) {
    problems.push(`Cannot compare ${name} (${error.code ?? error.message})`);
  }
}

if (problems.length) {
  console.error(`Shared file check failed:\n${problems.join('\n')}`);
  console.error('Keep shared changes aligned with the approved macOS baseline; see AGENTS.md and CONTRIBUTING.md.');
  process.exitCode = 1;
} else {
  console.log(`Shared file check passed: ${files.length} shared files match across macOS and Windows.`);
}

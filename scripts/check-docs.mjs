#!/usr/bin/env node
import { existsSync, readFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const files = ['README.md', 'README.zh-CN.md', 'CONTRIBUTING.md',
  'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md', 'macos/README.md',
  'macos/README.zh-CN.md', 'windows/README.md', 'windows/README.zh-CN.md',
  'docs/TERMINOLOGY.md', 'docs/TERMINOLOGY.zh-CN.md'];
const problems = [];
let count = 0;
for (const name of files) {
  const path = resolve(root, name);
  const markdown = readFileSync(path, 'utf8');
  for (const match of markdown.matchAll(/\[[^\]]+\]\(([^\s)]+)(?:\s+"[^"]*")?\)/g)) {
    const target = match[1];
    if (/^(?:[a-z][a-z\d+.-]*:|#)/i.test(target)) continue;
    const destination = resolve(dirname(path), decodeURIComponent(target.split('#')[0]));
    if (relative(root, destination).startsWith('..') || !existsSync(destination)) {
      problems.push(`${name}: missing or outside-repository link ${target}`);
    }
    count++;
  }
}
const version = readFileSync(resolve(root, 'VERSION'), 'utf8').trim();
if (!/^\d+\.\d+\.\d+$/.test(version)) problems.push('VERSION must contain a semantic version');
if (!readFileSync(resolve(root, 'CHANGELOG.md'), 'utf8').includes(`## ${version}`)) {
  problems.push('CHANGELOG.md is missing the current version');
}
if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}
console.log(`Documentation checks passed: ${files.length} files, ${count} local links, version ${version}`);

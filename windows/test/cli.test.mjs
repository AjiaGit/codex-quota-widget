import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, chmod, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { resolveCodex } from '../cli.mjs';
test('a vanished discovered override falls back to the updated CLI on PATH',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-'));
  try{
    const binary=join(directory,'codex');await writeFile(binary,'#!/bin/sh\n');await chmod(binary,0o700);
    assert.equal(resolveCodex({platform:'linux',env:{CODEX_CLI_PATH:join(directory,'old-codex'),PATH:directory},home:directory}).command,binary);
  }finally{await rm(directory,{recursive:true,force:true});}
});
test('npm command shims use the bundled Node without interpolating a shell command',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli space-'));
  try{
    const shim=join(directory,'codex.cmd'),script=join(directory,'node_modules','@openai','codex','bin','codex.js');
    await mkdir(join(directory,'node_modules','@openai','codex','bin'),{recursive:true});await writeFile(shim,'@echo off\r\n');await writeFile(script,'');
    assert.deepEqual(resolveCodex({platform:'win32',env:{CODEX_CLI_PATH:shim},home:directory}),{command:process.execPath,args:[script,'app-server']});
  }finally{await rm(directory,{recursive:true,force:true});}
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, chmod, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { resolveCodex } from '../cli.mjs';
function consolePE() {
  const bytes=Buffer.alloc(256);bytes.writeUInt16LE(0x5a4d,0);bytes.writeInt32LE(64,60);
  bytes.writeUInt32LE(0x4550,64);bytes.writeUInt16LE(0x20b,88);bytes.writeUInt16LE(3,156);return bytes;
}
test('a vanished discovered override falls back to the updated CLI on PATH',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-'));
  try{
    const binary=join(directory,'codex');await writeFile(binary,'#!/bin/sh\n');await chmod(binary,0o700);
    assert.equal(resolveCodex({platform:'linux',env:{CODEX_CLI_PATH:join(directory,'old-codex'),PATH:directory},home:directory}).command,binary);
  }finally{await rm(directory,{recursive:true,force:true});}
});
test('Windows npm shims launch the platform executable directly without a wrapper process',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli space-'));
  try{
    const shim=join(directory,'codex.cmd');
    const binary=join(directory,'node_modules','@openai','codex-win32-x64','vendor','x86_64-pc-windows-msvc','bin','codex.exe');
    await mkdir(join(binary,'..'),{recursive:true});await writeFile(shim,'@echo off\r\n');await writeFile(binary,consolePE());
    assert.deepEqual(resolveCodex({platform:'win32',arch:'x64',env:{CODEX_CLI_PATH:shim},home:directory}),{command:binary,args:['app-server']});
  }finally{await rm(directory,{recursive:true,force:true});}
});
test('Windows npm discovery supports the legacy vendor directory and ARM64 packages',async()=>{
  for(const [arch,triple,packageName,folder] of [['x64','x86_64-pc-windows-msvc','codex','codex'],['arm64','aarch64-pc-windows-msvc','codex-win32-arm64','bin']]){
    const directory=await mkdtemp(join(tmpdir(),'quota-cli-'));
    try{
      const shim=join(directory,'codex.cmd'),binary=join(directory,'node_modules','@openai',packageName,'vendor',triple,folder,'codex.exe');
      await mkdir(join(binary,'..'),{recursive:true});await writeFile(shim,'');await writeFile(binary,consolePE());
      assert.equal(resolveCodex({platform:'win32',arch,env:{CODEX_CLI_PATH:shim},home:directory}).command,binary);
    }finally{await rm(directory,{recursive:true,force:true});}
  }
});
test('an incomplete npm installation cannot fall back to a wrapper that leaves a child process behind',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-'));
  try{
    const shim=join(directory,'codex.cmd'),script=join(directory,'node_modules','@openai','codex','bin','codex.js');
    await mkdir(join(script,'..'),{recursive:true});await writeFile(shim,'');await writeFile(script,'');
    assert.throws(()=>resolveCodex({platform:'win32',arch:'x64',env:{CODEX_CLI_PATH:shim,PATH:''},home:directory}),{code:'cli_missing'});
  }finally{await rm(directory,{recursive:true,force:true});}
});

test('Windows rejects desktop GUI hosts on PATH and explicit overrides',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-gui-'));
  try{
    const binary=join(directory,'codex.exe'),bytes=Buffer.alloc(256);
    bytes.writeUInt16LE(0x5a4d,0);bytes.writeInt32LE(64,60);bytes.writeUInt32LE(0x4550,64);bytes.writeUInt16LE(0x20b,88);bytes.writeUInt16LE(2,156);
    await writeFile(binary,bytes);
    for(const env of [{CODEX_CLI_PATH:binary,PATH:''},{PATH:directory}]){
      assert.throws(()=>resolveCodex({platform:'win32',arch:'x64',env,home:directory}),{code:'cli_missing'});
    }
  }finally{await rm(directory,{recursive:true,force:true});}
});

test('a running Windows service rediscovers Codex after both inherited CLI paths vanish',async()=>{
  // FABRICATED PE DATA: the native discovery boundary is substituted; nothing runs.
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-update-'));
  try{
    const stale=join(directory,'removed-version','codex.exe');
    const current=join(directory,'current-version','codex.exe');
    await mkdir(join(current,'..'),{recursive:true});await writeFile(current,consolePE());
    const result=resolveCodex({platform:'win32',arch:'x64',home:directory,
      env:{CODEX_CLI_PATH:stale,PATH:join(directory,'removed-version'),LOCALAPPDATA:directory},
      discoverWindows:()=>current});
    assert.deepEqual(result,{command:current,args:['app-server']});
  }finally{await rm(directory,{recursive:true,force:true});}
});

test('rediscovery cannot launch a GUI executable or arbitrary script as Codex',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-update-invalid-'));
  try{
    const gui=join(directory,'Codex.exe'),script=join(directory,'codex.ps1');
    const bytes=consolePE();bytes.writeUInt16LE(2,156);
    await writeFile(gui,bytes);await writeFile(script,'FABRICATED TEST DATA - never executed');
    for(const discovered of [gui,script,join(directory,'missing.exe'),null]){
      assert.throws(()=>resolveCodex({platform:'win32',arch:'x64',env:{PATH:''},home:directory,
        discoverWindows:()=>discovered}),{code:'cli_missing'});
    }
  }finally{await rm(directory,{recursive:true,force:true});}
});

test('a valid Windows override avoids native rediscovery and failed discovery remains unavailable',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli-update-existing-'));
  try{
    const binary=join(directory,'codex.exe');await writeFile(binary,consolePE());let lookups=0;
    const result=resolveCodex({platform:'win32',arch:'x64',env:{CODEX_CLI_PATH:binary,PATH:''},home:directory,
      discoverWindows:()=>{lookups++;return null;}});
    assert.equal(result.command,binary);assert.equal(lookups,0);
    assert.throws(()=>resolveCodex({platform:'win32',arch:'x64',env:{PATH:''},home:directory,
      discoverWindows:()=>{throw new Error('FABRICATED discovery failure');}}),{code:'cli_missing'});
  }finally{await rm(directory,{recursive:true,force:true});}
});

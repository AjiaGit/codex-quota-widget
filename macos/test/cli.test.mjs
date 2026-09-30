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
test('Windows npm shims launch the platform executable directly without a wrapper process',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-cli space-'));
  try{
    const shim=join(directory,'codex.cmd');
    const binary=join(directory,'node_modules','@openai','codex-win32-x64','vendor','x86_64-pc-windows-msvc','bin','codex.exe');
    await mkdir(join(binary,'..'),{recursive:true});await writeFile(shim,'@echo off\r\n');await writeFile(binary,'');
    assert.deepEqual(resolveCodex({platform:'win32',arch:'x64',env:{CODEX_CLI_PATH:shim},home:directory}),{command:binary,args:['app-server']});
  }finally{await rm(directory,{recursive:true,force:true});}
});
test('Windows npm discovery supports the legacy vendor directory and ARM64 packages',async()=>{
  for(const [arch,triple,packageName,folder] of [['x64','x86_64-pc-windows-msvc','codex','codex'],['arm64','aarch64-pc-windows-msvc','codex-win32-arm64','bin']]){
    const directory=await mkdtemp(join(tmpdir(),'quota-cli-'));
    try{
      const shim=join(directory,'codex.cmd'),binary=join(directory,'node_modules','@openai',packageName,'vendor',triple,folder,'codex.exe');
      await mkdir(join(binary,'..'),{recursive:true});await writeFile(shim,'');await writeFile(binary,'');
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

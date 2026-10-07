import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { dirname } from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
const MAX_RECORDS=50, MAX_ACCOUNTS=5;
const percent=value=>Number.isInteger(value)&&value>=0&&value<=100;
const stamp=value=>Number.isSafeInteger(value)&&value>0;
const validRecord=row=>row&&stamp(row.observedFrom)&&stamp(row.detectedAt)&&row.detectedAt>row.observedFrom&&
  percent(row.beforePercent)&&percent(row.afterPercent)&&row.afterPercent>row.beforePercent&&
  (row.previousResetsAt===null||stamp(row.previousResetsAt))&&stamp(row.resetsAt);
const recordFields=row=>({observedFrom:row.observedFrom,detectedAt:row.detectedAt,beforePercent:row.beforePercent,
  afterPercent:row.afterPercent,previousResetsAt:row.previousResetsAt,resetsAt:row.resetsAt});

// Records describe observed quota increases, never the cause or a global delivery.
export async function createRecoveryStore({file,now=Date.now}={}) {
  let salt=randomBytes(32).toString('hex'), accounts={}, writes=Promise.resolve();
  try {
    const saved=JSON.parse(await readFile(file,'utf8'));
    if(saved.version===1&&/^[a-f0-9]{64}$/.test(saved.salt)&&saved.accounts&&typeof saved.accounts==='object') {
      salt=saved.salt;
      for(const [id,value] of Object.entries(saved.accounts).slice(-MAX_ACCOUNTS)) {
        const previous=value?.previous;
        if(!/^[a-f0-9]{64}$/.test(id)||!previous||!percent(previous.remainingPercent)||!stamp(previous.resetsAt)||
          !stamp(previous.observedAt)||previous.observedAt>now()||!stamp(value.trackingSince)||value.trackingSince>previous.observedAt)continue;
        accounts[id]={trackingSince:value.trackingSince,previous:{remainingPercent:previous.remainingPercent,resetsAt:previous.resetsAt,
          observedAt:previous.observedAt,plan:typeof previous.plan==='string'?previous.plan:null},
          records:(Array.isArray(value.records)?value.records:[]).filter(validRecord).filter(row=>row.detectedAt<=now())
            .sort((a,b)=>b.detectedAt-a.detectedAt).slice(0,MAX_RECORDS).map(recordFields)};
      }
    }
  }catch{}
  const persist=()=>{
    if(!file)return Promise.resolve(true);
    const body=JSON.stringify({version:1,salt,accounts});
    const task=writes.catch(()=>{}).then(async()=>{
      await mkdir(dirname(file),{recursive:true});
      const temporary=file+'.'+process.pid+'.tmp';
      await writeFile(temporary,body,{mode:0o600});await rename(temporary,file);
    });
    writes=task;
    return task.then(()=>true,()=>false);
  };
  return {
    async observe(identity,quota) {
      const detectedAt=now();
      if(typeof identity!=='string'||!identity.trim()||identity.length>1000||!percent(quota?.remainingPercent)||
        !stamp(quota?.resetsAt)||quota.resetsAt*1000<=detectedAt)return {status:'unavailable',records:[]};
      const id=createHash('sha256').update(salt+'\0'+identity).digest('hex');
      const account=accounts[id]??{trackingSince:detectedAt,previous:null,records:[]};
      const previous=account.previous;
      if(previous&&detectedAt<=previous.observedAt)return {status:'ok',trackingSince:account.trackingSince,records:account.records.map(row=>({...row}))};
      if(previous&&previous.plan===quota.plan&&quota.remainingPercent>previous.remainingPercent) {
        account.records.unshift({observedFrom:previous.observedAt,detectedAt,beforePercent:previous.remainingPercent,
          afterPercent:quota.remainingPercent,previousResetsAt:previous.resetsAt,resetsAt:quota.resetsAt});
        account.records=account.records.slice(0,MAX_RECORDS);
      }
      account.previous={remainingPercent:quota.remainingPercent,resetsAt:quota.resetsAt,plan:quota.plan,observedAt:detectedAt};
      accounts[id]=account;
      const keep=Object.keys(accounts).sort((a,b)=>accounts[b].previous.observedAt-accounts[a].previous.observedAt).slice(0,MAX_ACCOUNTS);
      accounts=Object.fromEntries(keep.map(key=>[key,accounts[key]]));
      const saved=await persist();
      return {status:saved?'ok':'unsaved',trackingSince:account.trackingSince,records:account.records.map(row=>({...row}))};
    },
    flush:()=>writes.catch(()=>{}),
  };
}

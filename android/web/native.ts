import {applyRequest,readSnapshot,type Snapshot} from './database';
export type DriveStatus={snapshot:Snapshot;revision:number;pending:boolean;connected:boolean;fileName:string;lastSavedAt:string;error:string};
declare global {interface Window{BukuNative?:{call:(value:string)=>void};BukuReply?:(reply:string)=>void;BukuBack?:()=>boolean;BukuAuthLock?:()=>Promise<void>}}
const waiting=new Map<string,{resolve:(value:unknown)=>void;reject:(error:Error)=>void}>();
window.BukuReply=(raw:string)=>{const message=JSON.parse(raw),entry=waiting.get(message.id);if(!entry)return;waiting.delete(message.id);if(message.ok)entry.resolve(message.result);else entry.reject(new Error(message.error||'Operasi belum selesai.'));};
export function native<T=unknown>(operation:string,payload:object={}):Promise<T>{return new Promise((resolve,reject)=>{if(!window.BukuNative){reject(new Error('Buka aplikasi dari APK Buku Pupuk.'));return;}const id=crypto.randomUUID();waiting.set(id,{resolve:value=>resolve(value as T),reject});try{window.BukuNative.call(JSON.stringify({id,operation,payload}));}catch(error){waiting.delete(id);reject(error as Error);}});}
export async function saveDrive(bytes:Uint8Array|string,mime:string,filename:string){const data=typeof bytes==='string'?new TextEncoder().encode(bytes):bytes;let binary='';for(let i=0;i<data.length;i+=16384)binary+=String.fromCharCode(...data.subarray(i,i+16384));return native('saveExport',{base64:btoa(binary),mime,filename});}
let status:DriveStatus|null=null, queue:Promise<unknown>=Promise.resolve();
const originalFetch=window.fetch.bind(window);
const publish=(value:DriveStatus)=>{value.snapshot=readSnapshot(value.snapshot);status=value;window.dispatchEvent(new CustomEvent('drive-status',{detail:value}));return value;};
export const currentStatus=()=>status;
export const clearSession=()=>{status=null;};
export async function initialize(){return publish(await native<DriveStatus>('load'));}
export function exclusive<T>(task:()=>Promise<T>):Promise<T>{const next=queue.then(task,task);queue=next.catch(()=>{});return next;}
export async function driveAction(operation:'sync'|'refresh'){return exclusive(async()=>{
  return publish(await native<DriveStatus>(operation==='sync'||status?.pending?'sync':'refresh'));
});}
export async function selectDatabase(create=false){return exclusive(async()=>{const candidate=await native<{token:string;snapshot:unknown;fileName:string}>(create?'createDatabase':'openDatabase',{filename:'buku-pupuk-database.json'});readSnapshot(candidate.snapshot);return publish(await native<DriveStatus>('acceptDatabase',{token:candidate.token}));});}
window.fetch=(async(input:RequestInfo|URL,init?:RequestInit)=>{
  const url=new URL(input instanceof Request?input.url:String(input),window.location.href);
  if(url.origin!==window.location.origin||!url.pathname.startsWith('/api/'))return originalFetch(input,init);
  return exclusive(async()=>{if(!status)throw new Error('Data belum selesai dimuat.');const req=new Request(url,input instanceof Request?input:init);const method=(init?.method||req.method||'GET').toUpperCase();let data:unknown;
    if(method!=='GET'&&method!=='HEAD'){const body=init?.body!==undefined?init.body:await req.text();if(typeof body!=='string')throw new Error('Isi permintaan tidak valid.');data=JSON.parse(body);}
    const next=readSnapshot(JSON.parse(JSON.stringify(status.snapshot)));const result=applyRequest(next,url.pathname,method,data);
    if(result.changed){next.createdAt=new Date().toISOString();const saved=await native<DriveStatus>('commit',{snapshot:next,revision:status.revision});publish(saved);}
    return new Response(JSON.stringify(result.body),{status:result.status,headers:{'Content-Type':'application/json'}});
  });
}) as typeof fetch;

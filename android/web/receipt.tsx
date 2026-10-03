import {useState} from 'react';
import {saveDrive} from './native';
type Value={receiptName:string;receiptData:string};
export default function Receipt({name,data,onChange}:{name:string;data:string;onChange:(value:Value)=>void}){
 const [busy,setBusy]=useState(false),[error,setError]=useState('');
 async function read(file?:File){if(!file)return;setBusy(true);setError('');try{
  if(file.size>15_000_000)throw Error('Kwitansi maksimal 15 MB sebelum diperkecil.');
  if(!['image/jpeg','image/png','image/webp','application/pdf'].includes(file.type))throw Error('Gunakan foto JPG, PNG, WebP, atau PDF.');
  let result=await new Promise<string>((resolve,reject)=>{const r=new FileReader();r.onload=()=>resolve(String(r.result));r.onerror=()=>reject(Error('Kwitansi tidak dapat dibaca.'));r.readAsDataURL(file);});let filename=file.name;
  if(file.type.startsWith('image/')){const image=await new Promise<HTMLImageElement>((resolve,reject)=>{const i=new Image();i.onload=()=>resolve(i);i.onerror=()=>reject(Error('Foto tidak dapat dibaca.'));i.src=result;});const scale=Math.min(1,1600/Math.max(image.width,image.height)),canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(image.width*scale));canvas.height=Math.max(1,Math.round(image.height*scale));const context=canvas.getContext('2d');if(!context)throw Error('Foto belum dapat diperkecil.');context.fillStyle='white';context.fillRect(0,0,canvas.width,canvas.height);context.drawImage(image,0,0,canvas.width,canvas.height);result=canvas.toDataURL('image/jpeg',.82);filename=file.name.replace(/\.[^.]+$/,'')+'.jpg';}
  if(result.length>2_000_000)throw Error('Kwitansi terlalu besar. Gunakan PDF lebih kecil atau foto dengan resolusi lebih rendah.');onChange({receiptName:filename.slice(0,200),receiptData:result});
 }catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function exportReceipt(){setBusy(true);setError('');try{const parts=data.split(',');if(parts.length!==2)throw Error('Kwitansi belum dapat dibaca.');const binary=atob(parts[1]);await saveDrive(Uint8Array.from(binary,c=>c.charCodeAt(0)),data.slice(5,data.indexOf(';')),name);}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 return <div className="android-receipt"><label>Kwitansi / bukti transaksi<input type="file" accept="image/jpeg,image/png,image/webp,application/pdf" disabled={busy} onChange={e=>read(e.target.files?.[0])}/></label>{busy&&<p>Memproses kwitansi…</p>}{name&&<><p>{name}</p>{data.startsWith('data:image/')&&<img src={data} alt="Kwitansi terlampir"/>}<div><button type="button" disabled={busy} onClick={exportReceipt}>Simpan kwitansi ke Drive</button><button type="button" disabled={busy} onClick={()=>onChange({receiptName:'',receiptData:''})}>Lepas dari transaksi</button></div></>}{error&&<p role="alert" className="error">{error}</p>}<small>Kwitansi ikut tersimpan di file data Google Drive setelah transaksi disimpan.</small></div>;
}

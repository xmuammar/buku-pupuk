import {useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import Page from '../../app/page';
import {currentStatus,driveAction,initialize,native,selectDatabase,type DriveStatus} from './native';
import {Cloud,RefreshCw,FolderOpen,ShieldCheck} from 'lucide-react';
function App(){
 const [state,setState]=useState<DriveStatus|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(''),[version,setVersion]=useState(0);
 useEffect(()=>{const handler=(e:Event)=>setState((e as CustomEvent).detail);window.addEventListener('drive-status',handler);initialize().then(setState).catch(e=>setError(e.message));let syncing=false;
  const sync=()=>{if(syncing||!currentStatus()?.pending)return;syncing=true;driveAction('sync').catch(e=>setError(e.message)).finally(()=>syncing=false);};const timer=setInterval(sync,60000);window.addEventListener('buku-native-resume',sync);window.addEventListener('online',sync);
  window.BukuBack=()=>{const close=document.querySelector<HTMLButtonElement>('.dialog button[aria-label="Tutup"]');if(close){close.click();return true;}return false;};
  return()=>{clearInterval(timer);window.removeEventListener('drive-status',handler);window.removeEventListener('buku-native-resume',sync);window.removeEventListener('online',sync);};
 },[]);
 async function act(action:string){setError('');setBusy(action);try{
  if(action==='folder')await native('driveFolder');
  else if(action==='refresh'){if(!confirm('Muat data dari Drive? Isian form yang belum disimpan akan ditutup.'))return;await driveAction('refresh');setVersion(n=>n+1);}
  else if(action==='sync')await driveAction('sync');
  else {if(state?.connected&&!confirm('Ganti file data? Pastikan semua perubahan sudah dikirim. Isian form akan ditutup.'))return;await selectDatabase(action==='create');setVersion(n=>n+1);}
 }catch(e){setError((e as Error).message);}finally{setBusy('');}}
 const ready=state&&(state.connected||state.snapshot.records.length>0||state.snapshot.members.length>0||state.pending);
 return <><div className={'android-drive '+(state?.pending?'pending':'')}><div><Cloud size={18}/><strong>Buku Pupuk Android</strong><span>{state?.fileName||'Hubungkan Google Drive'}</span></div>{ready&&<p role="status">{state?.pending?'Tersimpan di HP · Drive belum diperbarui':state?.connected?'Data dibaca / ditulis ke file Drive':'Salinan HP · pilih file Drive'}{state?.pending&&state.error?' — '+state.error:''}</p>}<div className="android-drive-actions"><button disabled={!!busy} onClick={()=>act('open')}><FolderOpen size={15}/>{state?.connected?'File Drive':'Pilih file Drive'}</button>{ready&&<><button disabled={!!busy} onClick={()=>act('sync')}><RefreshCw size={15}/>{busy==='sync'?'Mengirim…':'Kirim ke Drive'}</button><button disabled={!!busy} onClick={()=>act('refresh')}>Muat dari Drive</button></>}</div></div>
 {error&&<div className="android-error" role="alert">{error}<button onClick={()=>setError('')}>Tutup</button></div>}
 {ready?<Page key={version}/>:<main className="android-setup"><ShieldCheck size={36}/><h1>Data Buku Pupuk di Drive Bapak</h1><p>Untuk melanjutkan data usaha, pilih file <strong>buku-pupuk-database-android-2026-10-03.json</strong> di folder <strong>laporan pupuk</strong>.</p><ol><li>Pastikan aplikasi Google Drive terpasang dan akun Bapak sudah masuk.</li><li>Tekan “Pilih file Drive”. Di pemilih file, buka menu ☰ lalu Google Drive.</li><li>Buka folder laporan pupuk dan pilih file data. Berikan izin baca dan tulis.</li></ol><button className="primary" disabled={!!busy||!state} onClick={()=>act('open')}>Pilih file Drive untuk melanjutkan</button><button disabled={!!busy} onClick={()=>act('folder')}>Buka folder laporan pupuk</button><details><summary>Mulai buku baru tanpa transaksi</summary><p>Gunakan hanya jika ingin buku yang kosong. Data lama tetap berada dalam file lainnya.</p><button disabled={!!busy||!state} onClick={()=>act('create')}>Buat file data baru di Drive</button></details><p className="report-help">Transaksi dan kwitansi disimpan dalam file JSON ini. PDF / Excel dapat disimpan ke Drive melalui menu Laporan & cadangan. Salinan HP membantu saat offline. Gunakan satu HP aktif untuk menghindari perubahan bersamaan.</p></main>}
 </>;
}
createRoot(document.getElementById('root')!).render(<App/>);

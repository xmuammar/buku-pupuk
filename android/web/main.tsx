import {useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import Page from '../../app/page';
import {currentStatus,driveAction,initialize,native,selectDatabase,type DriveStatus} from './native';
import {ShieldCheck,FolderOpen} from 'lucide-react';
import AppCopyright from './copyright';
import {DriveContext} from './drive-panel';
function App(){
 const [state,setState]=useState<DriveStatus|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(''),[version,setVersion]=useState(0);
 useEffect(()=>{const handler=(e:Event)=>setState((e as CustomEvent).detail);window.addEventListener('drive-status',handler);initialize().then(setState).catch(e=>setError(e.message));let syncing=false;
  const sync=()=>{if(syncing||!currentStatus()?.pending)return;syncing=true;driveAction('sync').catch(e=>setError(e.message)).finally(()=>syncing=false);};const timer=setInterval(sync,60000);window.addEventListener('buku-native-resume',sync);window.addEventListener('online',sync);
  window.BukuBack=()=>{if(document.querySelector('.mobile-menu-overlay')){window.dispatchEvent(new Event('buku-close-menu'));return true;}const close=document.querySelector<HTMLButtonElement>('.dialog button[aria-label="Tutup"],.dialog button[aria-label="Tutup anggota"]');if(close){close.click();return true;}return false;};
  return()=>{clearInterval(timer);window.removeEventListener('drive-status',handler);window.removeEventListener('buku-native-resume',sync);window.removeEventListener('online',sync);};
 },[]);
 async function act(action:string){setError('');setBusy(action);try{
  if(action==='folder')await native('driveFolder');
  else if(action==='refresh'){if(!confirm('Muat data dari Drive? Isian form yang belum disimpan akan ditutup.'))return;await driveAction('refresh');setVersion(n=>n+1);}
  else if(action==='sync')await driveAction('sync');
  else {if(state?.connected&&!confirm('Ganti file data? Pastikan semua perubahan sudah dikirim. Isian form akan ditutup.'))return;await selectDatabase(action==='create');setVersion(n=>n+1);}
 }catch(e){setError((e as Error).message);}finally{setBusy('');}}
 const ready=state&&(state.connected||state.snapshot.records.length>0||state.snapshot.members.length>0||state.pending);
 return <DriveContext.Provider value={{state,error,busy,act,dismiss:()=>setError('')}}>
 {ready?<Page key={version}/>:<main className="android-setup"><ShieldCheck size={36}/><h1>Data Buku Pupuk di Drive Bapak</h1><p>Untuk melanjutkan data usaha, pilih file <strong>buku-pupuk-database-android-2026-10-03.json</strong> di folder <strong>laporan pupuk</strong>.</p><ol><li>Pastikan aplikasi Google Drive terpasang dan akun Bapak sudah masuk.</li><li>Tekan “Pilih file Drive”. Di pemilih file, buka menu ☰ lalu Google Drive.</li><li>Buka folder laporan pupuk dan pilih file data. Berikan izin baca dan tulis.</li></ol><button className="primary" disabled={!!busy||!state} onClick={()=>act('open')}><FolderOpen size={18}/>Pilih file Drive untuk melanjutkan</button><button disabled={!!busy} onClick={()=>act('folder')}>Buka folder laporan pupuk</button><details><summary>Mulai buku baru tanpa transaksi</summary><p>Gunakan hanya jika ingin buku yang kosong. Data lama tetap berada dalam file lainnya.</p><button disabled={!!busy||!state} onClick={()=>act('create')}>Buat file data baru di Drive</button></details><p className="report-help">Transaksi dan kwitansi disimpan dalam file JSON ini. PDF / Excel dapat disimpan ke Drive melalui menu Laporan dan Cadangan. Salinan HP membantu saat offline. Gunakan satu HP aktif untuk menghindari perubahan bersamaan.</p><AppCopyright/></main>}
 {error&&!ready&&<div className="android-error" role="alert">{error}</div>}
 </DriveContext.Provider>;
}
createRoot(document.getElementById('root')!).render(<App/>);

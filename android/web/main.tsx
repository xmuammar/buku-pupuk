import {useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import Page from '../../app/page';
import {clearSession,currentStatus,driveAction,initialize,native,type DriveStatus} from './native';
import {ShieldCheck} from 'lucide-react';
import AppCopyright from './copyright';
import Login from './login';
type AuthStatus={configured:boolean;unlocked:boolean;biometricAvailable?:boolean};
function App(){
 const [state,setState]=useState<DriveStatus|null>(null),[error,setError]=useState(''),[version,setVersion]=useState(0);
 const [authenticated,setAuthenticated]=useState(false),[authChecked,setAuthChecked]=useState(false),[authConfigured,setAuthConfigured]=useState(false),[biometricAvailable,setBiometricAvailable]=useState(false);
 useEffect(()=>{let active=true;const locked=()=>{clearSession();setAuthenticated(false);setState(null);setError('');};window.addEventListener('buku-auth-locked',locked);window.BukuAuthLock=async()=>{await native('lockAuth');locked();};native<AuthStatus>('authStatus').then(v=>{if(active){setAuthenticated(v.unlocked);setAuthConfigured(v.configured);setBiometricAvailable(!!v.biometricAvailable);setAuthChecked(true);}}).catch(e=>{if(active){setError(e.message);setAuthChecked(true);}});return()=>{active=false;window.removeEventListener('buku-auth-locked',locked);delete window.BukuAuthLock;};},[]);
 useEffect(()=>{if(!authenticated)return;const handler=(e:Event)=>setState((e as CustomEvent).detail);window.addEventListener('drive-status',handler);initialize().then(v=>{setState(v);setError(v.error||'');}).catch(e=>setError(e.message));let syncing=false;
  const sync=async()=>{if(syncing)return;syncing=true;const before=currentStatus()?.revision;try{const result=await driveAction(currentStatus()?.pending?'sync':'refresh');if(before!==undefined&&result.revision!==before)setVersion(n=>n+1);}catch{}finally{syncing=false;}};const timer=setInterval(sync,30000);window.addEventListener('buku-native-resume',sync);window.addEventListener('online',sync);
  window.BukuBack=()=>{if(document.querySelector('.mobile-menu-overlay')){window.dispatchEvent(new Event('buku-close-menu'));return true;}const close=document.querySelector<HTMLButtonElement>('.dialog button[aria-label="Tutup"],.dialog button[aria-label="Tutup anggota"]');if(close){close.click();return true;}return false;};
  return()=>{clearInterval(timer);window.removeEventListener('drive-status',handler);window.removeEventListener('buku-native-resume',sync);window.removeEventListener('online',sync);};
 },[authenticated]);
 const ready=!!state;
 async function unlock(){setError('');const next=await initialize();setState(next);setError(next.error||'');setAuthConfigured(true);setAuthenticated(true);}
 if(!authChecked)return <main className="login-loading"><section className="login-loading-card" role="status"><ShieldCheck className="spinning" size={28}/><p>Memeriksa keamanan aplikasi…</p></section></main>;
 if(!authenticated)return <Login configured={authConfigured} biometricAvailable={biometricAvailable} onUnlock={unlock}/>;
 return <>
 {error&&<div className="android-error firebase-global-error" role="alert">{error}<button onClick={()=>setError('')}>Tutup</button></div>}
 {ready?<Page key={version}/>:<main className="login-loading"><section className="login-loading-card" role="status"><ShieldCheck className="spinning" size={28}/><p>Menyiapkan data Buku Pupuk…</p></section><AppCopyright/></main>}
 </>;
}
createRoot(document.getElementById('root')!).render(<App/>);

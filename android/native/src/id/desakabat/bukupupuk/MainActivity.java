package id.desakabat.bukupupuk;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.ProviderInfo;
import android.database.Cursor;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.OpenableColumns;
import android.util.AtomicFile;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.JsResult;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONObject;

/** Only bundled app content can call the bridge. All private data stays out of APK/source. */
public final class MainActivity extends Activity {
    private static final String ORIGIN="https://appassets.androidplatform.net";
    private static final int SAVE_EXPORT=13, PICK_UPLOAD=14;
    private static final int MAX_BYTES=64*1024*1024;
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private WebView web;
    private SyncEngine engine;
    private FirebaseAuth auth;
    private FirebaseDatabase cloudDatabase;
    private android.content.SharedPreferences authPrefs;
    private String pickerId="";
    private byte[] exportBytes;
    private ValueCallback<Uri[]> uploadCallback;
    private long backgroundAt=0;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().getDecorView().setSystemUiVisibility(android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        authPrefs=getSharedPreferences("auth",MODE_PRIVATE);
        try{auth=new FirebaseAuth(this,authPrefs);cloudDatabase=new FirebaseDatabase(auth);}
        catch(Exception e){throw new IllegalStateException("Konfigurasi Firebase Buku Pupuk tidak dapat dibaca.",e);}
        getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);
        web=new WebView(this);setContentView(web);
        web.setOnApplyWindowInsetsListener((view,insets)->{view.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets.consumeSystemWindowInsets();});
        WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(false);s.setAllowFileAccess(false);s.setAllowContentAccess(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);s.setSafeBrowsingEnabled(true);s.setJavaScriptCanOpenWindowsAutomatically(false);s.setSupportMultipleWindows(false);
        web.addJavascriptInterface(new Bridge(),"BukuNative");
        web.setWebViewClient(new WebViewClient(){
            @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest request){
                Uri uri=request.getUrl();
                if(!isLocal(uri))return response(403,"Forbidden","text/plain",new ByteArrayInputStream(new byte[0]));
                String path=uri.getPath();if(path==null||path.equals("/"))path="/index.html";
                if(path.contains("..")||!request.getMethod().equals("GET"))return response(403,"Forbidden","text/plain",new ByteArrayInputStream(new byte[0]));
                try{return response(200,"OK",mime(path),getAssets().open(path.substring(1)));}
                catch(Exception e){return response(404,"Not Found","text/plain",new ByteArrayInputStream(new byte[0]));}
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !isLocal(r.getUrl());}
        });
        web.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onShowFileChooser(WebView view,ValueCallback<Uri[]> callback,FileChooserParams params){
                if(uploadCallback!=null){uploadCallback.onReceiveValue(null);uploadCallback=null;}
                uploadCallback=callback;
                Intent intent=params.createIntent();intent.setAction(Intent.ACTION_OPEN_DOCUMENT);intent.addCategory(Intent.CATEGORY_OPENABLE);intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                try{startActivityForResult(intent,PICK_UPLOAD);}catch(Exception e){uploadCallback.onReceiveValue(null);uploadCallback=null;}
                return true;
            }
            @Override public boolean onJsConfirm(WebView v,String url,String message,JsResult result){new AlertDialog.Builder(MainActivity.this).setMessage(message).setPositiveButton("Lanjutkan",(d,w)->result.confirm()).setNegativeButton("Batal",(d,w)->result.cancel()).setOnCancelListener(d->result.cancel()).show();return true;}
            @Override public boolean onJsAlert(WebView v,String url,String message,JsResult result){new AlertDialog.Builder(MainActivity.this).setMessage(message).setPositiveButton("OK",(d,w)->result.confirm()).show();return true;}
        });
        web.loadUrl(ORIGIN+"/index.html");
    }
    private boolean isLocal(Uri uri){return "https".equals(uri.getScheme())&&"appassets.androidplatform.net".equals(uri.getHost())&&(uri.getPort()==-1||uri.getPort()==443);}
    private String mime(String path){if(path.endsWith(".html"))return "text/html";if(path.endsWith(".js"))return "application/javascript";if(path.endsWith(".css"))return "text/css";if(path.endsWith(".ttf"))return "font/ttf";if(path.endsWith(".svg"))return "image/svg+xml";return "application/octet-stream";}
    private WebResourceResponse response(int code,String reason,String mime,InputStream body){
        Map<String,String> headers=new HashMap<>();headers.put("Cache-Control","no-store");headers.put("X-Content-Type-Options","nosniff");
        headers.put("Content-Security-Policy","default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; object-src 'none'; frame-src 'none'; base-uri 'none'");
        return new WebResourceResponse(mime,"UTF-8",code,reason,headers,body);
    }
    private final class Bridge {
        @JavascriptInterface public void call(String envelope){worker.execute(()->{
            String id="";
            try{
                JSONObject request=new JSONObject(envelope);id=request.getString("id");String operation=request.getString("operation");JSONObject payload=request.optJSONObject("payload");if(payload==null)payload=new JSONObject();
                if("authStatus".equals(operation)){reply(id,authStatus(),null);return;}
                if("setupAuth".equals(operation)){reply(id,auth.signUp(payload.optString("email",""),payload.optString("password","")),null);return;}
                if("loginAuth".equals(operation)){reply(id,auth.signIn(payload.optString("email",""),payload.optString("password","")),null);return;}
                if("resetPassword".equals(operation)){reply(id,auth.resetPassword(payload.optString("email","")),null);return;}
                if("logoutAuth".equals(operation)){auth.logout();reply(id,authStatus(),null);return;}
                if("lockAuth".equals(operation)){auth.lock();reply(id,authStatus(),null);return;}
                if(!auth.unlocked())throw new Exception("Sesi terkunci. Masukkan PIN untuk membuka Buku Pupuk.");
                switch(operation){
                    case "load":if(engine==null)engine=new SyncEngine(new AppStorage());try{engine.refresh();}catch(Exception e){reply(id,engine.status().put("error",e.getMessage()==null?"Database online belum dapat dimuat.":e.getMessage()),null);return;}reply(id,engine.status(),null);break;
                    case "commit":reply(id,engine.commit(payload.getJSONObject("snapshot"),payload.getLong("revision")),null);break;
                    case "sync":reply(id,engine.sync(),null);break;
                    case "refresh":reply(id,engine.refresh(),null);break;
                    case "saveExport":startExport(id,payload);break;
                    default:throw new Exception("Operasi tidak dikenal.");
                }
            }catch(Exception e){reply(id,null,e.getMessage());}
        });}
    }
    private JSONObject authStatus()throws Exception{
        return auth.status().put("lockRemainingSeconds",0);
    }
    private void reply(String id,JSONObject result,String error){
        if(web==null)return;
        try{JSONObject response=new JSONObject().put("id",id).put("ok",error==null).put("result",result==null?JSONObject.NULL:result).put("error",error==null?"":error);
            String js="window.BukuReply && window.BukuReply("+JSONObject.quote(response.toString())+")";
            runOnUiThread(()->{if(web!=null)web.evaluateJavascript(js,null);});
        }catch(Exception ignored){}
    }
    private void startExport(String id,JSONObject payload) throws Exception {
        if(!pickerId.isEmpty())throw new Exception("Selesaikan pemilihan file terlebih dahulu.");
        byte[] bytes=Base64.decode(payload.getString("base64"),Base64.DEFAULT);if(bytes.length>MAX_BYTES)throw new Exception("File terlalu besar. Pilih periode laporan yang lebih singkat.");
        exportBytes=bytes;pickerId=id;
        Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(payload.getString("mime"));intent.putExtra(Intent.EXTRA_TITLE,payload.getString("filename"));intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        runOnUiThread(()->{try{startActivityForResult(intent,SAVE_EXPORT);}catch(Exception e){pickerId="";exportBytes=null;reply(id,null,"Pemilih penyimpanan belum tersedia.");}});
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==PICK_UPLOAD){if(uploadCallback!=null){uploadCallback.onReceiveValue(result==RESULT_OK&&data!=null&&data.getData()!=null?new Uri[]{data.getData()}:null);uploadCallback=null;}return;}
        if(request!=SAVE_EXPORT)return;
        final String id=pickerId;pickerId="";
        if(result!=RESULT_OK||data==null||data.getData()==null){exportBytes=null;reply(id,null,"Pemilihan dibatalkan. File belum disimpan.");return;}
        final Uri uri=data.getData();final byte[] bytes=exportBytes;exportBytes=null;
        worker.execute(()->{try{
            requireDrive(uri);
            if(bytes==null)throw new Exception("Isi file tidak tersedia. Buat laporan ulang.");
            writeBytes(uri,bytes);
            if(!java.util.Arrays.equals(readBytes(uri),bytes))throw new Exception("Isi file belum cocok setelah ditulis.");
            reply(id,new JSONObject().put("filename",displayName(uri)).put("providerWritten",true),null);
        }catch(Exception e){reply(id,null,e.getMessage());}});
    }
    private void requireDrive(Uri uri) throws Exception {
        if(!"content".equals(uri.getScheme()))throw new Exception("Pilih Google Drive dari menu penyimpanan.");
        ProviderInfo info=getPackageManager().resolveContentProvider(uri.getAuthority(),0);
        if(info==null||!"com.google.android.apps.docs".equals(info.packageName))throw new Exception("File harus dipilih dari Google Drive. Buka menu ☰ lalu pilih Drive dan akun Bapak.");
    }
    private String displayName(Uri uri){try(Cursor c=getContentResolver().query(uri,new String[]{OpenableColumns.DISPLAY_NAME},null,null,null)){if(c!=null&&c.moveToFirst())return c.getString(0);}catch(Exception ignored){}return "File Google Drive";}
    private byte[] readBytes(Uri uri) throws Exception {
        try(InputStream in=getContentResolver().openInputStream(uri);ByteArrayOutputStream out=new ByteArrayOutputStream()){
            if(in==null)throw new Exception("Drive belum menyediakan file. Periksa koneksi internet.");
            byte[] buffer=new byte[8192];int count;while((count=in.read(buffer))!=-1){if(out.size()+count>MAX_BYTES)throw new Exception("File melebihi batas 64 MB.");out.write(buffer,0,count);}return out.toByteArray();
        }
    }
    private void writeBytes(Uri uri,byte[] bytes) throws Exception {try(OutputStream out=getContentResolver().openOutputStream(uri,"wt")){if(out==null)throw new Exception("File Drive belum dapat ditulis.");out.write(bytes);out.flush();}}
    private boolean online(){ConnectivityManager manager=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);Network active=manager.getActiveNetwork();NetworkCapabilities caps=manager.getNetworkCapabilities(active);return caps!=null&&caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED);}
    private final class AppStorage implements SyncEngine.Storage {
        private final AtomicFile cache=new AtomicFile(new File(getFilesDir(),"database-journal.json"));
        public String readLocal() throws Exception {if(!cache.getBaseFile().exists())return null;return new String(cache.readFully(),StandardCharsets.UTF_8);}
        public void writeLocal(String value) throws Exception {
            byte[] bytes=value.getBytes(StandardCharsets.UTF_8);if(bytes.length>MAX_BYTES)throw new Exception("Data melebihi kapasitas. Simpan cadangan dan kurangi ukuran kwitansi.");
            // Keep dated local snapshots without removing older copies. One daily safety copy is enough.
            File folder=new File(getFilesDir(),"history");folder.mkdirs();File history=new File(folder,"journal-"+java.time.LocalDate.now().toString()+".json");
            if(cache.getBaseFile().exists()&&!history.exists()){try(FileInputStream in=cache.openRead();FileOutputStream out=new FileOutputStream(history)){byte[] b=new byte[8192];int n;while((n=in.read(b))!=-1)out.write(b,0,n);out.getFD().sync();}}
            FileOutputStream out=cache.startWrite();try{out.write(bytes);cache.finishWrite(out);}catch(Exception e){cache.failWrite(out);throw e;}
        }
        public String readCloud() throws Exception {return cloudDatabase.read();}
        public void writeCloud(String value) throws Exception {cloudDatabase.write(value);}
        public boolean connected(){return auth!=null&&auth.unlocked();}
        public boolean online(){return MainActivity.this.online();}
        public String fileName(){return "Firebase · buku-pupuk";}
    }
    @Override protected void onPause(){if(pickerId.isEmpty())backgroundAt=SystemClock.elapsedRealtime();super.onPause();}
    @Override protected void onResume(){super.onResume();boolean timedOut=auth!=null&&auth.unlocked()&&backgroundAt>0&&pickerId.isEmpty()&&SystemClock.elapsedRealtime()-backgroundAt>15*60*1000L;if(timedOut)auth.lock();backgroundAt=0;if(web!=null){String event=(timedOut?"window.dispatchEvent(new Event('buku-auth-locked'));":"")+"window.dispatchEvent(new Event('buku-native-resume'))";web.postDelayed(()->web.evaluateJavascript(event,null),700);}}
    @Override public void onBackPressed(){if(web!=null)web.evaluateJavascript("window.BukuBack ? window.BukuBack() : false",value->{if(!"true".equals(value))new AlertDialog.Builder(this).setMessage("Tutup Buku Pupuk?").setPositiveButton("Tutup",(d,w)->finish()).setNegativeButton("Batal",null).show();});else super.onBackPressed();}
    @Override protected void onDestroy(){if(auth!=null)auth.lock();if(uploadCallback!=null)uploadCallback.onReceiveValue(null);if(web!=null){web.removeJavascriptInterface("BukuNative");web.destroy();web=null;}worker.shutdown();super.onDestroy();}
}

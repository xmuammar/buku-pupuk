package id.desakabat.bukupupuk;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ProviderInfo;
import android.database.Cursor;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Bundle;
import android.provider.DocumentsContract;
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
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONObject;

/** Only bundled app content can call the bridge. All private data stays out of APK/source. */
public final class MainActivity extends Activity {
    private static final String ORIGIN="https://appassets.androidplatform.net";
    private static final int PICK_DATABASE=11, CREATE_DATABASE=12, SAVE_EXPORT=13, PICK_UPLOAD=14;
    private static final int MAX_BYTES=64*1024*1024;
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private WebView web;
    private SharedPreferences prefs;
    private SyncEngine engine;
    private String pickerId="", candidateToken="", candidateRaw="", candidateName="";
    private Uri candidateUri;
    private int candidateFlags;
    private byte[] exportBytes;
    private ValueCallback<Uri[]> uploadCallback;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        prefs=getSharedPreferences("drive",MODE_PRIVATE);
        try {engine=new SyncEngine(new AppStorage());} catch(Exception e) {new AlertDialog.Builder(this).setTitle("Data HP perlu diperiksa").setMessage("Salinan lokal tidak dapat dibaca. Data tidak dihapus. "+e.getMessage()).setPositiveButton("Tutup",(d,w)->finish()).show();return;}
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
                switch(operation){
                    case "load":reply(id,engine.status(),null);break;
                    case "commit":reply(id,engine.commit(payload.getJSONObject("snapshot"),payload.getLong("revision")),null);break;
                    case "sync":reply(id,engine.sync(),null);break;
                    case "previewDrive":
                        if(engine.pending())throw new Exception("Kirim perubahan HP terlebih dahulu.");
                        if(!online())throw new Exception("Internet belum tersedia. Salinan HP tetap dapat dipakai.");
                        candidateUri=Uri.parse(prefs.getString("uri",""));requireDrive(candidateUri);
                        candidateFlags=Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
                        candidateRaw=new String(readBytes(candidateUri),StandardCharsets.UTF_8);SyncEngine.validateDocument(new JSONObject(candidateRaw));
                        candidateName=displayName(candidateUri);candidateToken=UUID.randomUUID().toString();
                        reply(id,new JSONObject().put("token",candidateToken).put("snapshot",new JSONObject(candidateRaw)),null);break;
                    case "openDatabase":if(engine.pending())throw new Exception("Ada data HP belum dikirim. Simpan cadangan JSON dan selesaikan pengiriman sebelum mengganti file.");startPicker(id,false,payload);break;
                    case "createDatabase":if(engine.pending())throw new Exception("Kirim data HP yang tertunda terlebih dahulu.");startPicker(id,true,payload);break;
                    case "acceptDatabase":acceptCandidate(id,payload.getString("token"));break;
                    case "saveExport":startExport(id,payload);break;
                    case "driveFolder":final String rid=id;runOnUiThread(()->{try{startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse("https://drive.google.com/drive/folders/1M3aYNQZhcHUwjsnv4CODV00DbgRuzIbp")));reply(rid,new JSONObject(),null);}catch(Exception e){reply(rid,null,e.getMessage());}});break;
                    default:throw new Exception("Operasi tidak dikenal.");
                }
            }catch(Exception e){reply(id,null,e.getMessage());}
        });}
    }
    private void reply(String id,JSONObject result,String error){
        if(web==null)return;
        try{JSONObject response=new JSONObject().put("id",id).put("ok",error==null).put("result",result==null?JSONObject.NULL:result).put("error",error==null?"":error);
            String js="window.BukuReply && window.BukuReply("+JSONObject.quote(response.toString())+")";
            runOnUiThread(()->{if(web!=null)web.evaluateJavascript(js,null);});
        }catch(Exception ignored){}
    }
    private void startPicker(String id,boolean create,JSONObject payload) throws Exception {
        if(!pickerId.isEmpty())throw new Exception("Selesaikan pemilihan file yang sedang terbuka.");
        pickerId=id;
        Intent intent=new Intent(create?Intent.ACTION_CREATE_DOCUMENT:Intent.ACTION_OPEN_DOCUMENT);intent.addCategory(Intent.CATEGORY_OPENABLE);intent.setType(create?"application/json":"*/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        if(create)intent.putExtra(Intent.EXTRA_TITLE,payload.optString("filename","buku-pupuk-database.json"));
        runOnUiThread(()->{try{startActivityForResult(intent,create?CREATE_DATABASE:PICK_DATABASE);}catch(Exception e){pickerId="";reply(id,null,"Aplikasi Files / Google Drive belum tersedia.");}});
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
        if(request!=PICK_DATABASE&&request!=CREATE_DATABASE&&request!=SAVE_EXPORT)return;
        final String id=pickerId;pickerId="";
        if(result!=RESULT_OK||data==null||data.getData()==null){exportBytes=null;reply(id,null,"Pemilihan dibatalkan. File belum disimpan.");return;}
        final Uri uri=data.getData();final int flags=data.getFlags();final byte[] bytes=exportBytes;exportBytes=null;
        worker.execute(()->{try{
            requireDrive(uri);
            if(request==SAVE_EXPORT){if(bytes==null)throw new Exception("Isi file tidak tersedia. Buat laporan ulang.");writeBytes(uri,bytes);if(!java.util.Arrays.equals(readBytes(uri),bytes))throw new Exception("Isi file belum cocok setelah ditulis.");reply(id,new JSONObject().put("filename",displayName(uri)).put("providerWritten",true),null);return;}
            requireWritable(uri);
            if(request==CREATE_DATABASE){String current=engine.status().getJSONObject("snapshot").toString();writeBytes(uri,current.getBytes(StandardCharsets.UTF_8));}
            String raw=new String(readBytes(uri),StandardCharsets.UTF_8);SyncEngine.validateDocument(new JSONObject(raw));
            candidateUri=uri;candidateFlags=flags;candidateRaw=raw;candidateName=displayName(uri);candidateToken=UUID.randomUUID().toString();
            reply(id,new JSONObject().put("token",candidateToken).put("snapshot",new JSONObject(raw)).put("fileName",candidateName),null);
        }catch(Exception e){reply(id,null,e.getMessage());}});
    }
    private void acceptCandidate(String id,String token) throws Exception {
        if(candidateUri==null||!token.equals(candidateToken))throw new Exception("Pemilihan file kedaluwarsa. Pilih ulang.");
        int flags=candidateFlags&(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        if((flags&Intent.FLAG_GRANT_WRITE_URI_PERMISSION)==0)throw new Exception("Drive belum memberi izin menulis. Pilih file milik akun Bapak.");
        getContentResolver().takePersistableUriPermission(candidateUri,flags);
        engine.acceptCloud(candidateRaw);
        if(!prefs.edit().putString("uri",candidateUri.toString()).putString("filename",candidateName).commit())throw new Exception("Sambungan Drive belum dapat disimpan di HP. Pilih file ulang.");
        candidateUri=null;candidateToken="";candidateRaw="";
        reply(id,engine.status(),null);
    }
    private void requireDrive(Uri uri) throws Exception {
        if(!"content".equals(uri.getScheme()))throw new Exception("Pilih Google Drive dari menu penyimpanan.");
        ProviderInfo info=getPackageManager().resolveContentProvider(uri.getAuthority(),0);
        if(info==null||!"com.google.android.apps.docs".equals(info.packageName))throw new Exception("File harus dipilih dari Google Drive. Buka menu ☰ lalu pilih Drive dan akun Bapak.");
    }
    private void requireWritable(Uri uri) throws Exception {
        try(Cursor cursor=getContentResolver().query(uri,new String[]{DocumentsContract.Document.COLUMN_FLAGS},null,null,null)){
            if(cursor!=null&&cursor.moveToFirst()&&(cursor.getInt(0)&DocumentsContract.Document.FLAG_SUPPORTS_WRITE)==0)throw new Exception("File Drive ini tidak dapat diedit. Pilih file JSON milik Bapak.");
        }
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
        private Uri uri() throws Exception {String value=prefs.getString("uri","");if(value.isEmpty())throw new Exception("Pilih file Google Drive terlebih dahulu.");return Uri.parse(value);}
        public String readCloud() throws Exception {Uri target=uri();requireDrive(target);return new String(readBytes(target),StandardCharsets.UTF_8);}
        public void writeCloud(String value) throws Exception {Uri target=uri();requireDrive(target);writeBytes(target,value.getBytes(StandardCharsets.UTF_8));}
        public boolean connected(){return !prefs.getString("uri","").isEmpty();}
        public boolean online(){return MainActivity.this.online();}
        public String fileName(){return prefs.getString("filename","");}
    }
    @Override protected void onResume(){super.onResume();if(web!=null)web.postDelayed(()->web.evaluateJavascript("window.dispatchEvent(new Event('buku-native-resume'))",null),700);}
    @Override public void onBackPressed(){if(web!=null)web.evaluateJavascript("window.BukuBack ? window.BukuBack() : false",value->{if(!"true".equals(value))new AlertDialog.Builder(this).setMessage("Tutup Buku Pupuk?").setPositiveButton("Tutup",(d,w)->finish()).setNegativeButton("Batal",null).show();});else super.onBackPressed();}
    @Override protected void onDestroy(){if(uploadCallback!=null)uploadCallback.onReceiveValue(null);if(web!=null){web.removeJavascriptInterface("BukuNative");web.destroy();web=null;}worker.shutdown();super.onDestroy();}
}

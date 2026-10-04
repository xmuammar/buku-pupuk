package id.desakabat.bukupupuk;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

/** Single canonical Firebase RTDB document. ETags reject concurrent writes from another phone. */
final class FirebaseDatabase {
    private static final String ENDPOINT="https://buku-pupuk-desa-kabat-default-rtdb.asia-southeast1.firebasedatabase.app/buku-pupuk.json";
    private final FirebaseAuth auth;
    private String etag="";
    FirebaseDatabase(FirebaseAuth auth){this.auth=auth;}

    synchronized String read()throws Exception{
        HttpURLConnection c=open("GET");c.setRequestProperty("X-Firebase-ETag","true");int code=c.getResponseCode();String raw=body(c,code);
        if(code<200||code>=300)throw new Exception("Database Firebase belum dapat dimuat (HTTP "+code+").");
        etag=c.getHeaderField("ETag");c.disconnect();
        if(raw.trim().equals("null"))return emptyDocument();
        return new JSONObject(raw).toString();
    }

    synchronized void write(String value)throws Exception{
        HttpURLConnection c=open("PUT");if(!etag.isEmpty())c.setRequestProperty("If-Match",etag);c.setDoOutput(true);c.setRequestProperty("Content-Type","application/json; charset=utf-8");
        try(OutputStream out=c.getOutputStream()){out.write(value.getBytes(StandardCharsets.UTF_8));}
        int code=c.getResponseCode();body(c,code);
        if(code==412)throw new Exception("Database berubah di HP lain. Muat ulang data Firebase sebelum menyimpan lagi.");
        if(code<200||code>=300)throw new Exception("Firebase belum menerima perubahan (HTTP "+code+").");
        etag=c.getHeaderField("ETag");c.disconnect();
    }

    private HttpURLConnection open(String method)throws Exception{
        String url=ENDPOINT+"?auth="+URLEncoder.encode(auth.idToken(),"UTF-8");HttpURLConnection c=(HttpURLConnection)new URL(url).openConnection();c.setRequestMethod(method);c.setConnectTimeout(15000);c.setReadTimeout(20000);c.setDoInput(true);return c;
    }
    private static String body(HttpURLConnection c,int code)throws Exception{
        InputStream stream=code>=200&&code<300?c.getInputStream():c.getErrorStream();if(stream==null)return "";
        try(InputStream in=stream;ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1)out.write(b,0,n);return out.toString("UTF-8");}
    }
    static String emptyDocument()throws Exception{return new JSONObject().put("app","buku-pupuk").put("version",1).put("createdAt","2026-01-01T00:00:00.000Z").put("records",new org.json.JSONArray()).put("recordCount",0).put("members",new org.json.JSONArray()).put("simulation",JSONObject.NULL).toString();}
}

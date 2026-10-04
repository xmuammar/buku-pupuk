package id.desakabat.bukupupuk;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONArray;
import org.json.JSONObject;

/** Firebase email/password authentication. Refresh credentials are encrypted with Android Keystore. */
final class FirebaseAuth {
    private static final String OWNER = "xmuammar@gmail.com";
    private static final String KEY_ALIAS = "buku-pupuk-firebase-auth-v1";
    private static final String AUTH = "https://identitytoolkit.googleapis.com/v1";
    private static final String TOKEN = "https://securetoken.googleapis.com/v1/token";
    private final SharedPreferences prefs;
    private final String apiKey;
    private volatile boolean unlocked;

    FirebaseAuth(Context context, SharedPreferences prefs) throws Exception {
        this.prefs=prefs;
        JSONObject config=new JSONObject(readAsset(context,"google-services.json"));
        JSONObject client=config.getJSONArray("client").getJSONObject(0);
        String packageName=client.getJSONObject("client_info").getJSONObject("android_client_info").getString("package_name");
        if(!"id.desakabat.bukupupuk".equals(packageName))throw new Exception("Konfigurasi Firebase tidak cocok dengan aplikasi Buku Pupuk.");
        apiKey=client.getJSONArray("api_key").getJSONObject(0).getString("current_key");
    }

    synchronized JSONObject status() throws Exception {
        boolean signed=!secret("refreshToken").isEmpty();
        return new JSONObject().put("configured",signed).put("unlocked",unlocked).put("email",prefs.getString("email",""));
    }
    synchronized boolean unlocked(){return unlocked;}
    synchronized void lock(){unlocked=false;}

    synchronized JSONObject signUp(String email,String password) throws Exception {
        validate(email,password);
        JSONObject account=post(AUTH+"/accounts:signUp?key="+apiKey,new JSONObject().put("email",email).put("password",password).put("returnSecureToken",true));
        save(account);
        post(AUTH+"/accounts:sendOobCode?key="+apiKey,new JSONObject().put("requestType","VERIFY_EMAIL").put("idToken",secret("idToken")));
        unlocked=false;return new JSONObject().put("verificationSent",true).put("email",OWNER);
    }

    synchronized JSONObject signIn(String email,String password) throws Exception {
        validate(email,password);
        JSONObject account=post(AUTH+"/accounts:signInWithPassword?key="+apiKey,new JSONObject().put("email",email).put("password",password).put("returnSecureToken",true));
        JSONObject lookup=post(AUTH+"/accounts:lookup?key="+apiKey,new JSONObject().put("idToken",account.getString("idToken")));
        JSONArray users=lookup.optJSONArray("users");
        if(users==null||users.length()==0)throw new Exception("Firebase tidak mengembalikan akun yang dapat diverifikasi.");
        JSONObject user=users.getJSONObject(0);
        if(!user.optBoolean("emailVerified",false)){
            save(account);
            post(AUTH+"/accounts:sendOobCode?key="+apiKey,new JSONObject().put("requestType","VERIFY_EMAIL").put("idToken",secret("idToken")));
            throw new Exception("Email belum diverifikasi. Tautan verifikasi baru dikirim ke "+OWNER+". Buka tautan itu, lalu masuk kembali.");
        }
        save(account);unlocked=true;return status();
    }

    synchronized JSONObject resetPassword(String email)throws Exception{
        if(!OWNER.equalsIgnoreCase(email.trim()))throw new Exception("Pemulihan dibatasi ke akun BUMDes "+OWNER+".");
        post(AUTH+"/accounts:sendOobCode?key="+apiKey,new JSONObject().put("requestType","PASSWORD_RESET").put("email",OWNER));
        return new JSONObject().put("sent",true).put("email",OWNER);
    }

    synchronized void logout() throws Exception {
        unlocked=false;if(!prefs.edit().remove("refreshTokenEnc").remove("idTokenEnc").remove("expiresAt").remove("email").commit())throw new Exception("Sesi belum berhasil dihapus dari HP.");
    }

    synchronized String idToken() throws Exception {
        long expires=prefs.getLong("expiresAt",0);
        if(expires>System.currentTimeMillis()+60_000){String current=secret("idToken");if(!current.isEmpty())return current;}
        String refresh=secret("refreshToken");if(refresh.isEmpty())throw new Exception("Sesi Firebase berakhir. Masuk kembali dengan email dan kata sandi.");
        JSONObject response=postForm(TOKEN+"?key="+apiKey,"grant_type=refresh_token&refresh_token="+java.net.URLEncoder.encode(refresh,"UTF-8"));
        String token=response.getString("id_token"),nextRefresh=response.getString("refresh_token");
        saveSecret("idToken",token);saveSecret("refreshToken",nextRefresh);prefs.edit().putLong("expiresAt",System.currentTimeMillis()+response.optLong("expires_in",3600)*1000L).commit();
        return token;
    }

    private void validate(String email,String password)throws Exception{
        if(!OWNER.equalsIgnoreCase(email.trim()))throw new Exception("Login untuk aplikasi ini dibatasi ke akun BUMDes "+OWNER+".");
        if(password==null||password.length()<6)throw new Exception("Kata sandi Firebase minimal 6 karakter.");
    }
    private void save(JSONObject account)throws Exception{
        saveSecret("idToken",account.getString("idToken"));saveSecret("refreshToken",account.getString("refreshToken"));
        if(!prefs.edit().putLong("expiresAt",System.currentTimeMillis()+account.optLong("expiresIn",3600)*1000L).putString("email",OWNER).commit())throw new Exception("Sesi belum berhasil disimpan di HP.");
    }
    private String secret(String name)throws Exception{
        String encoded=prefs.getString(name+"Enc","");if(encoded.isEmpty())return "";
        byte[] packed=Base64.decode(encoded,Base64.NO_WRAP),iv=Arrays.copyOfRange(packed,0,12),ciphertext=Arrays.copyOfRange(packed,12,packed.length);
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,iv));
        return new String(cipher.doFinal(ciphertext),StandardCharsets.UTF_8);
    }
    private void saveSecret(String name,String value)throws Exception{
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key());byte[] iv=cipher.getIV(),data=cipher.doFinal(value.getBytes(StandardCharsets.UTF_8)),packed=new byte[iv.length+data.length];
        System.arraycopy(iv,0,packed,0,iv.length);System.arraycopy(data,0,packed,iv.length,data.length);
        if(!prefs.edit().putString(name+"Enc",Base64.encodeToString(packed,Base64.NO_WRAP)).commit())throw new Exception("Sesi Firebase belum berhasil disimpan dengan aman di HP.");
    }
    private SecretKey key()throws Exception{
        KeyStore store=KeyStore.getInstance("AndroidKeyStore");store.load(null);java.security.Key existing=store.getKey(KEY_ALIAS,null);if(existing instanceof SecretKey)return (SecretKey)existing;
        KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");generator.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setRandomizedEncryptionRequired(true).build());return generator.generateKey();
    }
    private static String readAsset(Context context,String filename)throws Exception{try(InputStream in=context.getAssets().open(filename);ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] b=new byte[2048];int n;while((n=in.read(b))!=-1)out.write(b,0,n);return out.toString("UTF-8");}}
    private JSONObject post(String url,JSONObject body)throws Exception{return jsonRequest(url,"POST",body.toString(),null);}
    private JSONObject postForm(String url,String body)throws Exception{return jsonRequest(url,"POST",body,"application/x-www-form-urlencoded");}
    static JSONObject jsonRequest(String endpoint,String method,String body,String contentType)throws Exception{
        HttpURLConnection c=(HttpURLConnection)new URL(endpoint).openConnection();c.setRequestMethod(method);c.setConnectTimeout(15000);c.setReadTimeout(20000);c.setDoInput(true);
        if(body!=null){c.setDoOutput(true);c.setRequestProperty("Content-Type",contentType==null?"application/json":contentType);try(OutputStream out=c.getOutputStream()){out.write(body.getBytes(StandardCharsets.UTF_8));}}
        int code=c.getResponseCode();InputStream stream=code>=200&&code<300?c.getInputStream():c.getErrorStream();String raw;
        try(InputStream in=stream;ByteArrayOutputStream out=new ByteArrayOutputStream()){if(in==null)throw new Exception("Firebase tidak memberikan jawaban. Periksa koneksi internet.");byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1)out.write(b,0,n);raw=out.toString("UTF-8");}
        c.disconnect();JSONObject parsed=raw.isEmpty()?new JSONObject():new JSONObject(raw);if(code<200||code>=300)throw new Exception(userError(parsed));return parsed;
    }
    private static String userError(JSONObject body){String code=body.optJSONObject("error")!=null?body.optJSONObject("error").optString("message",""):"";if(code.contains("EMAIL_EXISTS"))return "Akun Firebase sudah ada. Pilih Masuk.";if(code.contains("EMAIL_NOT_FOUND")||code.contains("INVALID_PASSWORD")||code.contains("INVALID_LOGIN_CREDENTIALS"))return "Email atau kata sandi Firebase salah.";if(code.contains("WEAK_PASSWORD"))return "Kata sandi terlalu lemah. Gunakan minimal 6 karakter.";if(code.contains("TOO_MANY_ATTEMPTS_TRY_LATER"))return "Terlalu banyak percobaan. Tunggu sebentar sebelum mencoba lagi.";if(code.contains("INVALID_EMAIL"))return "Format email tidak valid.";return "Firebase: "+(code.isEmpty()?"permintaan belum berhasil":code)+".";}
}

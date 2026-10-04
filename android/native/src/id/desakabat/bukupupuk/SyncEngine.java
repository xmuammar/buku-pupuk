package id.desakabat.bukupupuk;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import org.json.JSONArray;
import org.json.JSONObject;

/** Local journal is durable before cloud writes. A cloud mismatch never overwrites another snapshot. */
public final class SyncEngine {
    public interface Storage {
        String readLocal() throws Exception;
        void writeLocal(String value) throws Exception;
        String readCloud() throws Exception;
        void writeCloud(String value) throws Exception;
        boolean connected();
        boolean online();
        String fileName();
    }
    private final Storage storage;
    private JSONObject journal;
    public SyncEngine(Storage storage) throws Exception {
        this.storage = storage;
        String text = storage.readLocal();
        if (text == null || text.isEmpty()) {
            JSONObject empty = new JSONObject().put("app","buku-pupuk").put("version",1).put("createdAt",Instant.now().toString())
                .put("records",new JSONArray()).put("recordCount",0).put("members",new JSONArray()).put("simulation",JSONObject.NULL);
            journal = new JSONObject().put("snapshot",empty).put("revision",0).put("pending",false).put("cloudHash","").put("lastSavedAt","").put("error","");
        } else {
            journal = new JSONObject(text);
            validateDocument(journal.getJSONObject("snapshot"));
        }
    }
    public static void validateDocument(JSONObject doc) throws Exception {
        if (!"buku-pupuk".equals(doc.optString("app")) || doc.optInt("version")!=1 || doc.optJSONArray("records")==null ||
            doc.optInt("recordCount",-1)!=doc.getJSONArray("records").length() || doc.getJSONArray("records").length()>10000 ||
            doc.has("members") && doc.optJSONArray("members")==null) throw new Exception("Pilih file JSON data Buku Pupuk yang valid.");
    }
    public static String hash(String text) throws Exception {
        byte[] digest=MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
        StringBuilder out=new StringBuilder(); for(byte b:digest)out.append(String.format("%02x",b&255)); return out.toString();
    }
    private void saveJournal() throws Exception {storage.writeLocal(journal.toString());}
    public synchronized JSONObject status() throws Exception {
        JSONObject out=new JSONObject(journal.toString());
        out.put("connected",storage.connected()).put("fileName",storage.fileName()); return out;
    }
    public synchronized boolean pending() {return journal.optBoolean("pending");}
    public synchronized void acceptCloud(String raw) throws Exception {
        if (pending()) throw new Exception("Ada data HP yang belum ditulis ke Firebase. Sinkronkan atau ekspor cadangan dahulu.");
        JSONObject doc=new JSONObject(raw);validateDocument(doc);
        JSONObject next=new JSONObject().put("snapshot",doc).put("revision",journal.optLong("revision")+1).put("pending",false)
            .put("cloudHash",hash(raw)).put("lastSavedAt",Instant.now().toString()).put("error","");
        storage.writeLocal(next.toString());journal=next;
    }
    public synchronized JSONObject commit(JSONObject doc,long expectedRevision) throws Exception {
        validateDocument(doc);
        if(expectedRevision!=journal.optLong("revision"))throw new Exception("Data berubah. Muat ulang sebelum menyimpan.");
        long nextRevision=expectedRevision+1;
        JSONObject next=new JSONObject(journal.toString()).put("snapshot",new JSONObject(doc.toString())).put("revision",nextRevision)
            .put("pending",true).put("error","");
        storage.writeLocal(next.toString());journal=next;
        try {return sync();} catch(Exception error) {
            // The new snapshot is already durable. Never report a failed transaction just because acknowledgement failed.
            journal.put("pending",true).put("error","Data sudah tersimpan di HP; penulisan Firebase belum selesai. "+error.getMessage());
            return status();
        }
    }
    public synchronized JSONObject sync() throws Exception {
        if(!pending())return status();
        if(!storage.connected()) {journal.put("error","Data tersimpan di HP. Masuk ke akun Firebase untuk menyambungkan.");saveJournal();return status();}
        if(!storage.online()) {journal.put("error","Data tersimpan di HP. Belum ditulis ke Firebase karena internet belum tersedia.");saveJournal();return status();}
        try {
            String current=storage.readCloud();
            JSONObject desired=new JSONObject(journal.getJSONObject("snapshot").toString());
            desired.put("_android",new JSONObject().put("revision",journal.optLong("revision")));
            String payload=desired.toString(),currentHash=hash(current),desiredHash=hash(payload);
            // Recover a crash after a successful cloud write but before the local acknowledgement.
            if(!currentHash.equals(desiredHash)) {
                if(!currentHash.equals(journal.optString("cloudHash")))throw new Exception("Database Firebase telah berubah. Data HP tetap aman; muat data terbaru lalu ulangi perubahan jika perlu.");
                storage.writeCloud(payload);
                String check=storage.readCloud();
                if(!hash(check).equals(desiredHash))throw new Exception("Isi Firebase belum cocok setelah ditulis. Salinan HP tetap tersedia.");
            }
            journal.put("cloudHash",desiredHash).put("pending",false).put("lastSavedAt",Instant.now().toString()).put("error","");
            saveJournal();
        } catch(Exception error) {
            journal.put("pending",true).put("error",error.getMessage()==null?"Firebase belum diperbarui. Salinan HP tetap tersimpan.":error.getMessage());saveJournal();
        }
        return status();
    }
    public synchronized JSONObject refresh() throws Exception {
        if(pending()&&!storage.online())return sync();
        if(!storage.connected())throw new Exception("Masuk ke akun Firebase terlebih dahulu.");
        if(!storage.online())throw new Exception("Internet belum tersedia. Salinan HP tetap dapat dipakai.");
        String current=storage.readCloud();
        JSONObject cloud=new JSONObject(current),local=journal.getJSONObject("snapshot");
        // A newly-created Firebase node is the safe one-time migration target for an existing local book.
        // Only seed when the server is truly empty; never merge over a non-empty cloud database.
        if(isEmpty(cloud)&&!isEmpty(local)){
            journal.put("cloudHash",hash(current)).put("pending",true).put("error","");saveJournal();
            return sync();
        }
        if(pending())return sync();
        if(!hash(current).equals(journal.optString("cloudHash")))acceptCloud(current);
        return status();
    }
    private static boolean isEmpty(JSONObject doc){
        JSONArray records=doc.optJSONArray("records"),members=doc.optJSONArray("members");
        return (records==null||records.length()==0)&&(members==null||members.length()==0)&&
            !doc.has("finance")&&(!doc.has("simulation")||doc.isNull("simulation"));
    }
}

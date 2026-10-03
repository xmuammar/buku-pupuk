package id.desakabat.bukupupuk;
import org.json.JSONObject;
import org.json.JSONArray;
public final class SyncEngineTest {
    static final class Store implements SyncEngine.Storage {
        String local="",cloud="";boolean on=true,connected=true,fail=false,mismatch=false,ackFail=false;int writes=0;
        public String readLocal(){return local;}
        public void writeLocal(String value) throws Exception {if(ackFail&&!new JSONObject(value).optBoolean("pending"))throw new Exception("local acknowledgement failed");local=value;}
        public String readCloud(){return cloud;}
        public void writeCloud(String value) throws Exception {if(!new JSONObject(local).optBoolean("pending"))throw new Exception("write before durable journal");if(fail)throw new Exception("drive denied");writes++;cloud=mismatch?value+" ":value;}
        public boolean connected(){return connected;}public boolean online(){return on;}public String fileName(){return "test.json";}
    }
    static JSONObject doc(int count) throws Exception {JSONArray rows=new JSONArray();for(int i=0;i<count;i++)rows.put(new JSONObject().put("id","r"+i));return new JSONObject().put("app","buku-pupuk").put("version",1).put("createdAt","2026-10-03T00:00:00Z").put("recordCount",count).put("records",rows).put("members",new JSONArray()).put("simulation",JSONObject.NULL);}
    static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
    public static void main(String[] args) throws Exception {
        Store s=new Store();s.cloud=doc(0).toString();SyncEngine e=new SyncEngine(s);e.acceptCloud(s.cloud);long revision=e.status().getLong("revision");
        s.on=false;JSONObject offline=e.commit(doc(1),revision);check(offline.getBoolean("pending"),"offline pending");check(new JSONObject(s.local).getJSONObject("snapshot").getInt("recordCount")==1,"offline durable");check(s.writes==0,"offline no cloud write");
        e=new SyncEngine(s);s.on=true;e.sync();check(!e.pending()&&s.writes==1,"restart and sync");
        int writes=s.writes;e.sync();check(s.writes==writes,"idempotent sync");
        revision=e.status().getLong("revision");s.fail=true;e.commit(doc(2),revision);check(e.pending(),"provider failure pending");check(new JSONObject(s.local).getJSONObject("snapshot").getInt("recordCount")==2,"failure keeps transaction");
        s.fail=false;s.cloud=doc(3).toString();e.sync();check(e.pending()&&s.writes==writes,"cloud conflict not overwritten");
        Store m=new Store();m.cloud=doc(0).toString();SyncEngine mismatch=new SyncEngine(m);mismatch.acceptCloud(m.cloud);m.mismatch=true;mismatch.commit(doc(1),mismatch.status().getLong("revision"));check(mismatch.pending(),"readback mismatch pending");
        Store crash=new Store();crash.cloud=doc(0).toString();SyncEngine ce=new SyncEngine(crash);ce.acceptCloud(crash.cloud);crash.ackFail=true;JSONObject acknowledged=ce.commit(doc(1),ce.status().getLong("revision"));check(acknowledged.getBoolean("pending"),"ack failure never reports failed transaction");crash.ackFail=false;ce=new SyncEngine(crash);ce.sync();check(!ce.pending()&&crash.writes==1,"crash recovers without repeated write");
        Store refresh=new Store();refresh.cloud=doc(0).toString();SyncEngine re=new SyncEngine(refresh);re.acceptCloud(refresh.cloud);refresh.cloud=doc(2).toString();check(re.refresh().getJSONObject("snapshot").getInt("recordCount")==2,"external refresh");
        boolean stale=false;try{re.commit(doc(4),0);}catch(Exception expected){stale=true;}check(stale,"stale revision rejected");
        System.out.println("PASS: durable offline journal, provider failure, conflict protection, readback verification, crash recovery, refresh, stale revision.");
    }
}

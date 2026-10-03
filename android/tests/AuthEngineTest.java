package id.desakabat.bukupupuk;

import java.util.HashMap;
import java.util.Map;

/** Native-only auth verification, rate limiting, persistence, and session locking. */
public final class AuthEngineTest {
    private static final class Store implements AuthEngine.Store {
        final Map<String,Object> values=new HashMap<>();
        public String getString(String k,String d){return (String)values.getOrDefault(k,d);}
        public int getInt(String k,int d){return (Integer)values.getOrDefault(k,d);}
        public long getLong(String k,long d){return (Long)values.getOrDefault(k,d);}
        public void putString(String k,String v){values.put(k,v);}
        public void putInt(String k,int v){values.put(k,v);}
        public void putLong(String k,long v){values.put(k,v);}
        public void putCredentials(String salt,String hash){values.put("pinSalt",salt);values.put("pinHash",hash);values.put("pinFailures",0);values.put("pinLockUntil",0L);}
        public void remove(String k){values.remove(k);}
    }
    private static void check(boolean ok,String name){if(!ok)throw new AssertionError(name);}
    private static void fails(Throwing action,String name)throws Exception{try{action.run();throw new AssertionError(name);}catch(AssertionError e){throw e;}catch(Exception expected){}}
    private interface Throwing{void run()throws Exception;}
    public static void main(String[]args)throws Exception{
        Store store=new Store();final long[] now={1_800_000_000_000L};AuthEngine.Clock clock=()->now[0];AuthEngine auth=new AuthEngine(store,clock);
        check(!auth.configured()&&!auth.unlocked(),"fresh install is locked");fails(()->auth.setInitialPin("111111"),"repeated PIN rejected");fails(()->auth.setInitialPin("123456"),"sequential PIN rejected");fails(()->auth.setInitialPin("1234"),"short PIN rejected");
        auth.setInitialPin("284716");check(auth.configured()&&auth.unlocked(),"set PIN unlocks first run");check(!store.values.containsKey("pin"),"plaintext PIN never stored");check(!store.getString("pinHash","").equals("284716"),"salted hash stored");
        check(!store.getString("pinSalt","").isEmpty()&&!store.getString("pinHash","").isEmpty(),"salted digest persisted");
        auth.lock();check(!auth.unlocked(),"session locks");AuthEngine reopened=new AuthEngine(store,clock);fails(()->reopened.login("284715"),"wrong PIN rejected");
        for(int i=1;i<5;i++)fails(()->reopened.login("284715"),"wrong attempt " + i);
        check(reopened.lockRemainingSeconds()==300,"fifth failure imposes five minute lock");fails(()->reopened.login("284716"),"right PIN remains blocked during lockout");
        now[0]+=300000;reopened.login("284716");check(reopened.unlocked()&&reopened.lockRemainingSeconds()==0,"valid PIN unlocks after lockout");
        reopened.changePin("284716","935178");reopened.lock();AuthEngine finalEngine=new AuthEngine(store,clock);finalEngine.login("935178");check(finalEngine.unlocked(),"changed PIN persists for next session");
        System.out.println("PASS: first-run PIN, nonreversible salted hash, wrong PIN, lockout, persistent verification, changed PIN, locked session.");
    }
}

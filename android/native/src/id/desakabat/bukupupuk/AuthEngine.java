package id.desakabat.bukupupuk;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Device-local PIN verifier. Only salted PBKDF2 hashes and throttling state are persisted. */
final class AuthEngine {
    interface Store {
        String getString(String key, String fallback);
        int getInt(String key, int fallback);
        long getLong(String key, long fallback);
        void putString(String key, String value) throws Exception;
        void putInt(String key, int value) throws Exception;
        void putLong(String key, long value) throws Exception;
        void putCredentials(String salt, String hash) throws Exception;
        void remove(String key) throws Exception;
    }
    interface Clock { long now(); }

    private static final int ITERATIONS = 180000;
    private static final int KEY_BITS = 256;
    private static final long MAX_LOCK_MINUTES = 60;
    private static final SecureRandom RANDOM = new SecureRandom();
    private final Store store;
    private final Clock clock;
    private volatile boolean unlocked;

    AuthEngine(Store store) { this(store, System::currentTimeMillis); }
    AuthEngine(Store store, Clock clock) { this.store = store; this.clock = clock; }
    boolean configured() { return !store.getString("pinHash", "").isEmpty(); }
    boolean unlocked() { return unlocked; }

    synchronized void setInitialPin(String pin) throws Exception {
        if (configured()) throw new Exception("PIN sudah dibuat di HP ini. Masukkan PIN untuk melanjutkan.");
        validatePin(pin);
        savePin(pin);
        unlocked = true;
    }

    synchronized long login(String pin) throws Exception {
        long remaining = lockRemainingSeconds();
        if (remaining > 0) throw new Exception("PIN dikunci sementara. Coba lagi dalam " + remaining + " detik.");
        if (!configured()) throw new Exception("Buat PIN aplikasi terlebih dahulu.");
        byte[] actual = derive(pin.toCharArray(), Base64Compat.decode(store.getString("pinSalt", "")));
        byte[] expected = Base64Compat.decode(store.getString("pinHash", ""));
        if (!MessageDigest.isEqual(expected, actual)) {
            int failures = store.getInt("pinFailures", 0) + 1;
            store.putInt("pinFailures", failures);
            if (failures >= 5) {
                int tier = Math.min(4, failures - 5);
                long minutes = Math.min(MAX_LOCK_MINUTES, 5L << tier);
                store.putLong("pinLockUntil", clock.now() + minutes * 60000L);
                throw new Exception("5 PIN salah. Coba lagi dalam " + minutes + " menit.");
            }
            throw new Exception("PIN salah. Sisa percobaan sebelum dikunci: " + (5 - failures) + ".");
        }
        store.putInt("pinFailures", 0);
        store.putLong("pinLockUntil", 0);
        unlocked = true;
        return 0;
    }

    synchronized void changePin(String oldPin, String newPin) throws Exception {
        if (!unlocked) throw new Exception("Masuk kembali untuk mengganti PIN.");
        if (!verifyWithoutThrottle(oldPin)) throw new Exception("PIN lama tidak cocok.");
        validatePin(newPin);
        savePin(newPin);
    }

    synchronized void lock() { unlocked = false; }

    long lockRemainingSeconds() {
        long remaining = store.getLong("pinLockUntil", 0) - clock.now();
        return remaining <= 0 ? 0 : (remaining + 999) / 1000;
    }

    private boolean verifyWithoutThrottle(String pin) throws Exception {
        if (pin == null) return false;
        byte[] actual = derive(pin.toCharArray(), Base64Compat.decode(store.getString("pinSalt", "")));
        return MessageDigest.isEqual(Base64Compat.decode(store.getString("pinHash", "")), actual);
    }

    private void savePin(String pin) throws Exception {
        byte[] salt = new byte[16];
        RANDOM.nextBytes(salt);
        byte[] hash = derive(pin.toCharArray(), salt);
        store.putCredentials(Base64Compat.encode(salt), Base64Compat.encode(hash));
        store.putInt("pinFailures", 0);
        store.putLong("pinLockUntil", 0);
    }

    private static byte[] derive(char[] pin, byte[] salt) throws Exception {
        PBEKeySpec spec = new PBEKeySpec(pin, salt, ITERATIONS, KEY_BITS);
        try { return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded(); }
        finally { spec.clearPassword(); Arrays.fill(pin, '\0'); }
    }

    private static void validatePin(String pin) throws Exception {
        if (pin == null || !pin.matches("[0-9]{6,12}")) throw new Exception("PIN harus terdiri dari 6 sampai 12 angka.");
        boolean repeated = true, ascending = true, descending = true;
        for (int i = 1; i < pin.length(); i++) {
            repeated &= pin.charAt(i) == pin.charAt(0);
            ascending &= pin.charAt(i) == pin.charAt(i - 1) + 1;
            descending &= pin.charAt(i) == pin.charAt(i - 1) - 1;
        }
        if (repeated || ascending || descending) throw new Exception("Hindari angka berulang atau urutan sederhana untuk PIN.");
    }

    /** Android bridge uses Android Base64, while keeping this class unit-testable on a regular JVM. */
    static final class Base64Compat {
        static String encode(byte[] value) { return java.util.Base64.getEncoder().encodeToString(value); }
        static byte[] decode(String value) throws Exception { return java.util.Base64.getDecoder().decode(value); }
    }
}

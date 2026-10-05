# Buku Pupuk — Flutter + Firebase

Antarmuka native Flutter (Dart), Firebase Authentication email/sandi dan Firebase Realtime Database. Tidak menggunakan React, Next.js, WebView, PHP, atau server aplikasi tambahan.

Diperiksa menggunakan Flutter 3.47.6 / Dart 3.13.5, JDK 17 dan Android SDK 36.

## Menjalankan

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
flutter run
```

Target awal Android, akun `xmuammar@gmail.com`, project Firebase `buku-pupuk-desa-kabat`. Konfigurasi klien berasal dari repositori lama, bukan kredensial administrator. Jangan mengganti aturan database dengan akses publik. Aturan yang sudah ada dalam `firebase/database.rules.json` tetap berlaku; kode ini tidak menerapkan aturan atau mengubah data secara otomatis.

## Fitur

- Ringkasan kas, pembelian, penjualan, biaya, utang, piutang dan laba FIFO.
- Penarikan bank, pembelian, penjualan subsidi/non subsidi, biaya, bayar distributor dan pelunasan piutang; edit dengan pemeriksaan konflik.
- Input rupiah dengan titik ribuan, sak/kg, harga per sak, stok dan validasi pembayaran.
- Anggota petani, NIK unik opsional, kelompok tani dan alamat.
- Lampiran foto/PDF kwitansi maksimal 1,5 MB dan tampilan foto/berbagi PDF.
- Simulasi penjualan Urea/Phoska dari stok dan biaya aktual.
- Rencana pembagian laba, default 15% ketua, 10% bendahara, 5% kelompok pengawas, 70% modal. Tidak otomatis membuat pembayaran honor.
- Laporan PDF/Excel dengan rentang tanggal, ringkasan, rincian, stok dan tagihan. Cadangan JSON lengkap, termasuk pengaturan dan lampiran.
- Sesi Firebase bertahan, reset sandi dan kunci biometrik manual dalam sesi aplikasi.

## Data dan sinkronisasi

Memakai node `buku-pupuk` serta schema versi 1 yang sama dengan APK lama. Data dibaca langsung; tidak ada impor yang menimpa database. Semua perubahan memakai transaksi Firebase untuk menghindari pembaruan dari snapshot lama. Urutan properti JSON diabaikan saat membandingkan konflik.

Listener realtime menggantikan polling REST 30 detik. Cache Firebase serta antrean perubahan privat lokal memungkinkan input saat offline setelah database pernah dimuat. Setiap perubahan dicatat dahulu pada SharedPreferences sebelum sinkronisasi. Antrean dijalankan ulang saat aplikasi dibuka/koneksi kembali; pengulangan identik tidak membuat transaksi ganda. Jangan hapus data aplikasi sebelum antrean tersinkron.

Konflik tidak menimpa transaksi HP lain: antrean berhenti, data lokal tetap tersimpan dan aplikasi menampilkan masalah. Ekspor cadangan sebelum membuang antrean lalu isi ulang berdasarkan data terbaru. Perubahan lokal antrean yang gagal validasi tidak masuk tampilan laporan; cadangan JSON menyertakan `pendingChanges` agar antrean konflik dapat diperiksa tanpa kehilangan catatan perubahan.

Kompatibilitas sengaja mempertahankan satu snapshot lama, termasuk lampiran. Ini menghindari migrasi destruktif, tetapi membaca seluruh snapshot dan pemeriksaan transaksi masih bertambah mahal seiring jumlah catatan/lampiran. Klaim kecepatan harus dibuktikan pada HP nyata dalam build release; proyek ini belum memuat benchmark.

Firebase menyinkronkan database otomatis. Ekspor Google Drive memakai lembar berbagi Android dan **manual**; tidak ada janji backup Excel/PDF harian saat aplikasi tertutup. JSON tidak memiliki menu pemulihan yang menimpa database.

## APK dan pembaruan

```bash
flutter build apk --debug
```

GitHub Actions memeriksa format, analyzer, test dan membuat APK profile untuk Android ARM64. APK unduhan langsung disediakan setelah build; arsip workflow hanya menjadi transport internal. APK debug tidak dapat dipasang sebagai pembaruan APK produksi bertanda tangan lama. Jangan uninstall aplikasi lama jika masih ada antrean transaksi. Build debug/profile otomatis memakai paket `id.desakabat.bukupupuk.dev` agar dapat dipasang berdampingan. Konfigurasi Firebase masih project asli: transaksi uji akan memengaruhi data asli jika masuk. Gunakan project Firebase uji untuk pengujian transaksi.

Paket produksi tetap `id.desakabat.bukupupuk`. Untuk update tanpa uninstall, wajib memakai keystore dan alias APK lama serta versionCode lebih tinggi. Keystore/password tidak ada di repositori. Atur signing release dengan `android/key.properties` lokal, lalu:

```bash
flutter build apk --release
```

Isi `android/key.properties` (jangan commit):

```properties
storeFile=/absolute/path/keystore.p12
storePassword=PASSWORD
keyPassword=PASSWORD
keyAlias=buku-pupuk
```

Peralihan tidak membaca jurnal privat Java lama. Sebelum update, buka APK lama, pastikan semua transaksi sudah masuk Firebase, ekspor cadangan, dan cocokkan jumlah transaksi/saldo. Jangan gunakan APK lama dan baru untuk mengedit catatan bersamaan. Uji login, antrean offline/restart, konflik dua HP, biometrik, laporan dan pemilih Drive sebelum pemakaian produksi.

Flutter memakai Firebase SDK resmi untuk penyimpanan sesi. Biometrik di versi ini mengunci sesi aplikasi yang sedang terbuka; sesi tidak dikunci otomatis setelah aplikasi dimatikan, sesuai perilaku aplikasi sebelumnya.

## Validasi penulisan ulang

Pengujian lokal mencakup 18 kasus: pembacaan fixture versi lama, kas dan total Rp9.750.000, utang/piutang, FIFO lintas periode, stok/pembayaran tidak valid, konflik edit, pembulatan laba, tanggal/NIK, antrean offline dan restart, urutan koneksi/data awal, konflik dua klien, pengulangan setelah crash, ekspor Excel numerik, PDF dengan font tertanam, cadangan antrean JSON, escaping CSV dan input/formulir pembelian. PDF uji telah dirender dan diperiksa.

Pengujian sinkronisasi memakai backend tiruan; belum membuktikan integrasi Firebase atau Drive pada HP nyata. Build APK lokal terkendala jaringan Gradle. Workflow GitHub Actions memeriksa build Android. Belum ada pengukuran performa pada perangkat.


## Tampilan modern — 2.1.0

Dashboard dengan kartu saldo hijau, ringkasan usaha dua kolom, tombol Beli/Jual pupuk dan transaksi terbaru. Navigasi bawah berisi Ringkasan, Pembelian, Penjualan, Anggota dan Lainnya; menu Lainnya menyediakan ikon serta penjelasan singkat. Kartu transaksi menampilkan nominal pada baris sendiri agar tidak bertabrakan dengan nama panjang. Login, input rupiah, pemilih tanggal dan formulir memakai desain yang konsisten.

Pengujian tambahan memeriksa layar 320/390/768 piksel, perpindahan menu dan login dengan ukuran teks 140%. Total 22 pengujian, termasuk pengujian logika dan ekspor sebelumnya. Tangkapan layar dashboard dan menu telah diperiksa. Filter tanggal hanya berlaku pada Laporan; ringkasan dan stok selalu menampilkan keseluruhan usaha.

Workflow membuat APK profile ARM64 dengan paket `.dev` dan menyimpan keystore uji dalam cache untuk konsistensi build berikutnya. Ini APK uji, tidak menggantikan keystore produksi. Build profile menggunakan kompilasi AOT untuk pengujian performa, tetapi belum ada benchmark perangkat nyata. Perangkat Android ARM64 minimum Android 8.0 diperlukan.

# Buku Pupuk Android

Aplikasi Android pribadi untuk BUMDes. Menu transaksi, anggota, simulasi dari stok aktual, kwitansi, serta laporan PDF dan Excel memakai komponen Buku Pupuk yang sama dengan website. Ini aplikasi terpasang dengan antarmuka yang dibundel, sehingga tidak perlu membuka website atau masuk ke ChatGPT untuk mencatat.

## Pemasangan dan data awal

1. Pasang Google Drive di HP, masuk ke akun pemilik data, dan perbarui Android System WebView bila diperlukan.
2. Unduh APK Buku Pupuk. Buka file dan izinkan pemasangan dari aplikasi yang dipakai untuk mengunduh. Android minimum 8.0.
3. Buka Buku Pupuk lalu tekan **Pilih file Drive**.
4. Pada pemilih file Android, buka menu ☰, pilih **Drive** dan akun yang benar, lalu folder **laporan pupuk**.
5. Pilih **buku-pupuk-database-android-2026-10-03.json** yang disiapkan untuk migrasi. Izinkan akses baca dan tulis. Nama file muncul di bagian atas aplikasi.

File database tidak disertakan dalam APK atau repository. File awal dibuat sebagai salinan baru dari data website dan diverifikasi dengan unduhan ulang. Cadangan lama tetap disimpan.

## Penyimpanan

- Database berupa satu file JSON Buku Pupuk di Google Drive, diakses melalui Storage Access Framework Android. Tidak perlu Firebase berbayar, server tambahan, API key, atau konfigurasi OAuth Google Cloud.
- Transaksi, anggota, pengaturan simulasi, dan kwitansi dalam bentuk data gambar/PDF termasuk dalam JSON tersebut. Foto kwitansi diperkecil; batas lampiran sekitar 1,5 MB setelah encoding dan batas database 64 MB.
- Sebelum menulis Drive, aplikasi menyimpan jurnal atomik di penyimpanan privat HP. Saat internet tidak tersedia, transaksi tetap tersimpan dan status menunjukkan **Drive belum diperbarui**.
- Penulisan dicoba saat menyimpan, ketika aplikasi dibuka kembali, setiap menit selama aplikasi aktif, dan melalui **Kirim ke Drive**. Tidak ada janji sinkronisasi latar belakang ketika aplikasi ditutup.
- Setelah menulis, aplikasi membaca ulang file dari penyedia Drive dan membandingkan SHA-256. Status **ditulis ke file Drive** berarti penyedia file telah menerima isi yang cocok. Aplikasi Google Drive sendiri menyelesaikan unggahan ke server; ini bukan bukti terpisah bahwa server sudah menerima unggahan. Periksa status unggahan di aplikasi Drive, terutama sebelum mengganti HP.
- **Muat dari Drive** membaca dan memvalidasi data sebelum mengganti salinan HP. File rusak atau transaksi tidak valid tidak digunakan.
- Gunakan **satu HP aktif**. Pemeriksaan perubahan file mencegah banyak penimpaan tidak sengaja, tetapi penyedia file Android tidak menyediakan transaksi atau compare-and-swap atomik untuk penulisan bersamaan dari beberapa HP.

## Laporan, cadangan, dan pemulihan

PDF dan Excel mempertahankan ringkasan pada halaman / sheet pertama, rincian transaksi, stok dalam kg dan sak, harga per sak, kas, utang, piutang, dan nama bendahara. Setiap ekspor memakai tanggal serta jam dalam nama file.

Di **Laporan & cadangan**, pilih JSON, Excel, atau PDF kemudian pilih Google Drive pada pemilih tujuan. Android membuat file baru dan tidak menghapus cadangan lama. Ekspor JSON mencakup seluruh database; PDF dan Excel adalah laporan dan tidak digunakan untuk memulihkan transaksi.

Jika pemasangan diulang atau pindah HP, pilih file database Drive yang sama. Untuk mengimpor JSON tambahan, gunakan **Pulihkan dari cadangan**. ID yang sama dengan isi berbeda ditolak; data tidak ditimpa secara diam-diam. Jika terjadi konflik Drive saat ada perubahan HP tertunda, ekspor JSON HP terlebih dahulu dan periksa kedua salinan sebelum melakukan pemulihan.

Website ChatGPT dan APK memiliki penyimpanan utama berbeda setelah migrasi. Perubahan pada APK tidak otomatis masuk ke database website, dan perubahan website tidak otomatis masuk ke APK. Cadangan terjadwal website tetap mengambil database website. Gunakan APK sebagai buku utama jika memilih penyimpanan Drive ini.

## Build

Komponen web memakai dependensi dan lockfile project utama. Native app memakai Java platform Android tanpa dependensi AndroidX. SDK / build tools 35.0.0 dan platform Android 35 diperlukan. `esbuild` tersedia sebagai dependensi tooling project; pasang dependensi memakai workflow project yang berlaku.

Siapkan keystore PKCS12 privat dengan alias `buku-pupuk` dan satu file password privat. Gunakan keystore yang sama untuk semua pembaruan; jangan membuat ulang keystore untuk update instalasi yang sudah ada. Keystore, password, data usaha, APK, dan aset hasil build tidak boleh masuk ke Git.

```bash
export ANDROID_SDK_ROOT=/path/to/android-sdk
export BUKU_KEYSTORE=/private/buku-pupuk-release.p12
export BUKU_KEY_PASSWORD_FILE=/private/password.txt
# Opsional bila JDK tidak menyediakan javac:
export ECJ_JAR=/path/to/ecj.jar
bash android/scripts/build-apk.sh
```

Build mengompilasi UI lokal, resource, Java, dan DEX; menyelaraskan APK; menandatangani; lalu memverifikasi signature v2/v3 dan metadata instalasi. Output default `android/build/Buku-Pupuk-Android-v1.1.0.apk`.

## Pengujian

`android/tests/database.test.ts` memeriksa perhitungan kas / stok / pembayaran, anggota subsidi, pengeditan dengan data lama, impor JSON dan konflik ID. Bundle melalui esbuild lalu jalankan `node --test`.

`android/tests/SyncEngineTest.java` memakai penyimpanan tiruan untuk menguji jurnal sebelum penulisan Drive, offline, penolakan penyedia, konflik, ketidakcocokan hasil baca ulang, pemulihan setelah crash, dan revisi yang kedaluwarsa. Kompilasi dengan JDK / ECJ serta runtime `org.json` pada lingkungan test; `org.json` platform Android dipakai pada APK.

`android/tests/dom.cjs` memakai JSDOM untuk memeriksa menu anggota, pemilihan anggota subsidi, format uang, perhitungan sak / kg, status offline, simulasi aktual dan ketiga ekspor melalui bundle browser. Pasang JSDOM untuk lingkungan test atau set `BUKU_JSDOM_MODULE` ke package yang tersedia.

`android/tests/ui.mjs` menyediakan harness browser dengan bridge tiruan. Set `BUKU_TEST_CHROME` ke executable Chromium / Chrome yang dapat berjalan, dan opsional `BUKU_TEST_SNAPSHOT` ke file JSON uji. Harness tidak memberi bukti koneksi Drive pada HP nyata.

Pada build pertama, pengujian logika, integrasi DOM antarmuka, TypeScript, build native, tanda tangan, isi file migrasi di Drive, serta laporan PDF / Excel sudah lulus. Browser headless pada lingkungan build gagal diluncurkan, sehingga uji tampilan interaktif belum selesai di sana. Koneksi penyedia Google Drive dan pemasangan APK harus diperiksa pertama kali di HP pemilik data setelah memilih file.

Dokumentasi platform: [Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files) dan [konten lokal WebView](https://developer.android.com/develop/ui/views/layout/webapps/load-local-content).

## Antarmuka Android 1.1.0

Navigasi tetap di bawah: Ringkasan, Pembelian, Penjualan, Anggota, dan Lainnya. Menu Lainnya membuka panel dengan ikon untuk Stok pupuk, Simulasi, Buku kas, Laporan, dan Cadangan. Panel mendukung tombol kembali Android, Escape, dan fokus keyboard.

Header Buku Pupuk Android, nama file utama, status, File Drive, Kirim ke Drive, Muat dari Drive, dan Buka folder Drive hanya ditampilkan di Cadangan. Laporan memuat ekspor PDF / Excel / CSV; Cadangan memuat JSON / Excel / PDF dan pemulihan. Saat penulisan masih tertunda, pesan simpan transaksi mengarahkan pengguna ke Cadangan.

Kartu ringkasan hanya tampil pada Ringkasan agar halaman lain lebih ringkas. Daftar transaksi menjadi kartu pada HP; formulir, ukuran sentuh, ruang navigasi bawah, status bar dan navigation bar memakai tampilan mobile. Perubahan UI diterapkan oleh adapter Android, tanpa mengubah antarmuka website.

APK versionCode 2 menggunakan sertifikat yang sama dengan 1.0.0. Pasang sebagai pembaruan tanpa menghapus aplikasi lama agar jurnal lokal dan izin file Drive tetap tersimpan.

Validasi 1.1.0: TypeScript, lint, pengujian finansial, integrasi DOM navigasi dan seluruh ekspor, kompilasi native serta sertifikat pembaruan diperiksa. Browser headless tidak dapat merender antarmuka penuh pada lingkungan build ini (proses berhenti SIGSEGV); responsivitas visual dan integrasi Drive pada perangkat nyata masih perlu diperiksa di HP. Harness browser tetap tersedia untuk lingkungan yang mendukung Chromium.

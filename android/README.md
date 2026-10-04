# Buku Pupuk Android

Aplikasi Android pribadi untuk BUMDes. Menu transaksi, anggota, simulasi dari stok aktual, kwitansi, serta laporan PDF dan Excel memakai komponen Buku Pupuk yang sama dengan website. Ini aplikasi terpasang dengan antarmuka yang dibundel, sehingga tidak perlu membuka website atau masuk ke ChatGPT untuk mencatat.

## Pemasangan dan data awal

1. Pasang APK Buku Pupuk. Android minimum 8.0.
2. Pada HP pertama, buat akun Firebase dengan alamat **xmuammar@gmail.com**. Buat kata sandi yang Bapak simpan sendiri.
3. Buka email tersebut dan tekan tautan verifikasi dari Firebase, lalu kembali ke aplikasi dan masuk.
4. Aplikasi menghubungkan database Firebase. Jika database cloud masih kosong dan HP ini memiliki jurnal lokal lama, jurnal lokal itu disalin sebagai data awal. Jika database sudah berisi data, aplikasi memuat data cloud.
5. Di HP lain, pasang APK versi 1.4.0, lalu masuk dengan alamat dan kata sandi yang sama.

Gunakan Google Drive untuk menyimpan salinan PDF, Excel, atau JSON melalui menu Laporan / Cadangan. Jangan menghapus cadangan lama sebelum memeriksa file baru.

## Penyimpanan

- Database utama memakai Firebase Authentication dan Realtime Database project `buku-pupuk-desa-kabat` di region Singapore. Paket Spark gratis dipilih. Email/sandi Firebase mengautentikasi pengguna; aturan database hanya mengizinkan `xmuammar@gmail.com` yang sudah memverifikasi email.
- APK memakai `android/firebase/google-services.json`, yaitu konfigurasi klien Android Firebase. Ini bukan service account JSON dan tidak mengandung kunci privat server. Kata sandi tidak ditanam di APK.
- Transaksi, anggota, pengaturan simulasi, dan kwitansi dalam bentuk data gambar/PDF termasuk dalam JSON tersebut. Foto kwitansi diperkecil; batas lampiran sekitar 1,5 MB setelah encoding dan batas database 64 MB.
- Sebelum mengirim perubahan, aplikasi menyimpan jurnal atomik di penyimpanan privat HP. Saat internet putus, transaksi tetap tersimpan lokal dan menunggu sinkronisasi.
- Setiap perubahan dicoba langsung ke Firebase. Saat aplikasi terbuka, aplikasi memeriksa pembaruan cloud sekitar setiap 30 detik dan ketika HP kembali online/dibuka. Perubahan di HP lain biasanya muncul setelah pemeriksaan berikutnya; sinkronisasi tidak berjalan ketika aplikasi ditutup.
- Firebase ETag dipakai untuk menolak penulisan bila database berubah bersamaan dari HP lain. Jika konflik muncul, muat data terbaru dan ulangi perubahan. Hindari mengedit catatan yang sama bersamaan di dua HP.
- Token sesi disimpan terenkripsi memakai Android Keystore. Firebase Authentication dan aturan database menegakkan izin pada server.

## Laporan, cadangan, dan pemulihan

PDF dan Excel mempertahankan ringkasan pada halaman / sheet pertama, rincian transaksi, stok dalam kg dan sak, harga per sak, kas, utang, piutang, dan nama bendahara. Setiap ekspor memakai tanggal serta jam dalam nama file.

Di **Laporan & cadangan**, pilih JSON, Excel, atau PDF kemudian pilih Google Drive pada pemilih tujuan. Android membuat file baru dan tidak menghapus cadangan lama. Ekspor JSON mencakup seluruh database; PDF dan Excel adalah laporan dan tidak digunakan untuk memulihkan transaksi.

Jika pemasangan diulang atau pindah HP, masuk ke akun Firebase yang sama. Untuk memulihkan JSON tambahan, gunakan **Pulihkan dari cadangan** di Google Drive. Cadangan lama tidak dihapus.

Website lama tidak terhubung dengan database Firebase APK. Gunakan APK sebagai aplikasi utama; transaksi website tidak otomatis disalin ke database Firebase.

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

Build mengompilasi UI lokal, resource, Java, dan DEX; menyelaraskan APK; menandatangani; lalu memverifikasi signature v2/v3 dan metadata instalasi. Output default `android/build/Buku-Pupuk-Android-v1.4.0.apk`.

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

## Keuangan — Android 1.2.0

Lainnya → Keuangan mengatur pembagian laba. Default ketua/pengelola 15%, bendahara 10%, seluruh pengawas 5%, dan sisa 70% tambahan modal. Persentase dapat diubah hingga dua desimal; jumlah honor maksimal 100%. Pengawas memakai satu alokasi kelompok, bukan persentase untuk setiap orang. Jumlah pengawas dapat ditentukan. Pembulatan dialihkan ke modal, sehingga total rupiah selalu sesuai laba. Jika laba nol atau negatif, alokasi nol.

Sumber laba bisa dari transaksi atau laba manual/rencana. Laba transaksi dihitung sebagai penjualan periode dikurangi HPP terjual FIFO dan seluruh biaya operasional periode. Riwayat stok sebelum periode diproses untuk mengetahui harga pokok; pembelian pada hari sama diproses sebelum penjualan, dan lot pada hari sama diurutkan dengan ID. Penarikan bank, pembayaran distributor, dan pelunasan piutang bukan laba baru. Stok yang belum terjual masih berupa modal tertanam. Piutang termasuk penjualan; laba ini belum mencakup pajak/biaya yang belum dicatat. Riwayat penjualan yang mendahului stok akan menonaktifkan dasar laba otomatis.

Ini rencana pembagian; penyimpanan tidak membuat transaksi atau pembayaran honor. Pembayaran nyata tetap dicatat sekali lewat Biaya operasional. Hindari membagi laba yang belum diterima tunai.

Pengaturan disimpan sebagai properti `finance` di snapshot Drive dan cadangan JSON, dengan revision guard dan penolakan pemulihan apabila rencana berbeda. JSON lama tetap dapat dibaca. Gunakan APK terbaru sebagai satu perangkat aktif; APK lama tidak mengenali pengaturan Keuangan baru.

Pengujian `android/tests/finance.test.ts` mencakup alokasi Rp1 juta, pembulatan, banyak pengawas, laba negatif, persentase/tanggal tidak valid, FIFO per produk, periode, saldo kas berbeda dari laba, backup dan konflik rencana. Harness DOM memeriksa menu, format uang, penyimpanan/pembukaan ulang, dan finance dalam cadangan lengkap.

## Hak cipta — Android 1.2.1

Tulisan “© 2026 · Hak cipta aplikasi milik Muammar, SST, M.Kom” ditampilkan pada footer setiap halaman, panel Menu lainnya, dan halaman pengaturan pertama. APK versionCode 4 memakai sertifikat pembaruan yang sama.

## Login Firebase — Android 1.4.0

Aplikasi hanya menerima akun BUMDes `xmuammar@gmail.com`. Pembuatan akun mengirim tautan verifikasi; database tetap menolak akses sebelum verifikasi email selesai. Menu login menyediakan reset kata sandi Firebase. Kata sandi tidak disimpan aplikasi. Refresh token disimpan terenkripsi oleh Android Keystore. Kunci aplikasi di Menu lainnya mengunci sesi pada HP; masuk kembali diperlukan.

`google-services.json` cocok dengan project dan package ID Android `id.desakabat.bukupupuk`. Aturan Firebase membatasi baca/tulis ke email terverifikasi yang ditentukan. Jangan mengganti aturan menjadi akses publik.

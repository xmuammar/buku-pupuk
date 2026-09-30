# Cadangan Buku Pupuk

Status saat perubahan ini: ekspor PDF/XLSX dan cadangan/pemulihan JSON tersedia. Google Drive dan jadwal harian belum diaktifkan, karena koneksi pengguna belum tersedia. Jangan menganggap unduhan manual atau penyimpanan D1 sebagai bukti cadangan harian ke Drive.

## Data lengkap

Project ID: `appgprj_6abc9a031be88191989dbbb43a5cfa06`.

`GET /api/backup` pada Site privat mengembalikan satu snapshot JSON dengan `app`, `version`, `createdAt`, `recordCount`, dan `records`. Semua kolom `records` termasuk ID transaksi dan referensi pembayaran disertakan. Pengambilan tidak membatasi periode. Respons gagal harus membatalkan pencadangan, bukan diperlakukan sebagai daftar kosong.

`POST /api/backup` di aplikasi memvalidasi JSON, memeriksa ID yang bertentangan, referensi pembayaran, saldo stok dan pembayaran berlebih. Pemulihan hanya menambahkan ID yang belum ada; transaksi yang sama tidak diduplikasi. Tidak menghapus atau mengganti transaksi.

## Melanjutkan pencadangan harian yang diminta pengguna

1. Verifikasi plugin Google Drive sudah terhubung dengan panggilan baca yang berhasil. Temukan aksi unggah file dan baca balik yang benar dari alat yang tersedia; jangan menganggap plugin baca saja dapat mengunggah.
2. Buka Site yang sama lewat Sites. Pastikan akses masih hanya pemilik. Ambil service-access credential dari `get_site` setiap eksekusi; gunakan hanya dalam header `OAI-Sites-Authorization: Bearer ...` untuk URL Site ini. Jangan tulis token ke file, instruksi jadwal, log atau pesan.
3. Verifikasi GET snapshot di atas melalui akses layanan tanpa sesi browser. Pastikan jumlah catatan sama dengan isi, snapshot tidak terpotong, dan skema cocok. Bila native database viewer memotong data, jangan mengunggahnya sebagai backup lengkap.
4. Siapkan folder Drive milik pengguna (nama yang disarankan: `Buku Pupuk - Cadangan`). Simpan folder ID persis dari hasil layanan.
5. Buat satu JSON lengkap, satu laporan Excel .xlsx dengan seluruh transaksi, serta PDF bila diinginkan. Nama file memuat tanggal dan waktu Asia/Jakarta. Simpan cadangan bertanggal, jangan hapus atau menimpa salinan sebelumnya.
6. Unggah file, lalu baca balik metadata dan kontennya/ukuran untuk memastikan unggahan berhasil. Hindari duplikasi saat kegagalan tidak jelas: periksa nama atau ID file sebelum mencoba lagi. Jangan menyatakan cadangan sukses jika hanya sebagian file berhasil.
7. Baru buat jadwal harian yang diminta setelah akses pembaca dan pengunggah terbukti bisa berjalan tanpa browser terbuka. Gunakan Asia/Jakarta; default yang dapat dipilih adalah setiap malam. Jangan membuat jadwal pengingat sebagai pengganti tugas pencadangan.
8. Simpan jadwal/target/hasil cadangan dengan status yang benar dan tampilkan terakhir sukses atau kegagalan pada aplikasi setelah jalur penulisan status terautentikasi tersedia. Jangan mengubah status UI menjadi aktif sebelum jadwal dan unggahan berhasil.

Laporan dihitung lewat `lib/report-data.ts`. Ekspor browser tersedia di `lib/export-reports.ts`; pengambilan data dilakukan ulang sebelum membuat file. Transaksi mengikuti periode pilihan; kas, stok, utang dan piutang dihitung hingga akhir periode termasuk transaksi sebelum awal periode. Penarikan bank adalah perpindahan dana ke kas, bukan pendapatan.

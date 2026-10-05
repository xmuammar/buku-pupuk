Aturan ini disalin tanpa perubahan dari versi Android sebelumnya dan hanya mengizinkan akun pemilik. Tidak ada deploy otomatis dalam workflow Flutter. Firebase Authentication harus tetap mengaktifkan provider email/password.

Aplikasi memakai project/URL database yang sama. Untuk uji terisolasi, ubah FirebaseOptions di `lib/main.dart` ke project uji sebelum menjalankan. Jangan gunakan akun atau data usaha asli pada emulator/test otomatis.

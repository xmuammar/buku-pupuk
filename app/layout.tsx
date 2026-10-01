import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Buku Pupuk",
  description: "Catatan pembelian, stok, kas dan penjualan pupuk desa.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="id">
      <body className="antialiased">{children}</body>
    </html>
  );
}

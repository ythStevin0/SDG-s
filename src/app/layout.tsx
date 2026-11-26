import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { getSessionUser } from '@/lib/auth';
import { Navbar } from '@/components/Navbar';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'SimpanJual — Platform Keputusan Tahan atau Jual Hasil Panen',
  description:
    'Platform keputusan tahan atau jual hasil panen berbasis data yang menghubungkan petani, gudang SRG, dan pembeli lokal (SDG 8).',
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const user = await getSessionUser();

  return (
    <html lang="id" suppressHydrationWarning>
      <body className={`${inter.className} min-h-screen antialiased`} suppressHydrationWarning>
        <Navbar user={user} />
        <main className="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6">{children}</main>
      </body>
    </html>
  );
}

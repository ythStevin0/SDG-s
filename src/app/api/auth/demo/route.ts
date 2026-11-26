import { NextResponse } from 'next/server';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '@/db';
import { users } from '@/db/schema';
import { SESSION_COOKIE, createSessionToken, getHomePathForRole } from '@/lib/auth';

const DEMO_EMAILS = [
  'petani@demo.id',
  'poktan@demo.id',
  'gudang@demo.id',
  'pembeli@demo.id',
  'admin@demo.id',
] as const;

const demoSchema = z.object({
  email: z.enum(DEMO_EMAILS),
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = demoSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: 'Akun demo tidak dikenali' }, { status: 400 });
    }

    const [user] = await db.select().from(users).where(eq(users.email, parsed.data.email));
    if (!user || !user.isDemo) {
      return NextResponse.json(
        { error: 'Akun demo belum tersedia. Jalankan npm run db:seed terlebih dahulu.' },
        { status: 404 }
      );
    }

    const token = await createSessionToken({
      userId: user.id,
      email: user.email,
      role: user.role,
      nama: user.nama,
      kabupaten: user.kabupaten,
    });

    const response = NextResponse.json({
      ok: true,
      redirectTo: getHomePathForRole(user.role),
      user: { nama: user.nama, role: user.role },
    });

    response.cookies.set(SESSION_COOKIE, token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      maxAge: 60 * 60 * 24 * 7,
    });

    return response;
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Gagal masuk akun demo' },
      { status: 500 }
    );
  }
}

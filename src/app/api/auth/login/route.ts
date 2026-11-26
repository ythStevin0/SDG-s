import { NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '@/db';
import { users } from '@/db/schema';
import { SESSION_COOKIE, createSessionToken, getHomePathForRole } from '@/lib/auth';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = loginSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: 'Format email atau kata sandi tidak valid' }, { status: 400 });
    }

    const [user] = await db
      .select()
      .from(users)
      .where(eq(users.email, parsed.data.email.toLowerCase().trim()));

    if (!user) {
      return NextResponse.json({ error: 'Email atau kata sandi salah' }, { status: 401 });
    }

    const match = await bcrypt.compare(parsed.data.password, user.passwordHash);
    if (!match) {
      return NextResponse.json({ error: 'Email atau kata sandi salah' }, { status: 401 });
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
      { error: err instanceof Error ? err.message : 'Gagal masuk' },
      { status: 500 }
    );
  }
}

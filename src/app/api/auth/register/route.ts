import { NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '@/db';
import { users } from '@/db/schema';
import { SESSION_COOKIE, createSessionToken, getHomePathForRole } from '@/lib/auth';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  nama: z.string().min(2).max(100),
  role: z.enum(['petani', 'gudang', 'pembeli']),
  kabupaten: z.string().min(2).max(60),
  noWa: z.string().max(25).optional(),
  namaOrg: z.string().max(120).optional(),
  tipePembeli: z.enum(['koperasi', 'penggiling', 'pabrik', 'sppg', 'umkm']).optional(),
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = registerSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: 'Data pendaftaran belum lengkap atau tidak valid' }, { status: 400 });
    }

    const email = parsed.data.email.toLowerCase().trim();
    const [existing] = await db.select({ id: users.id }).from(users).where(eq(users.email, email));
    if (existing) {
      return NextResponse.json({ error: 'Email sudah terdaftar' }, { status: 409 });
    }

    const passwordHash = await bcrypt.hash(parsed.data.password, 10);
    const [created] = await db
      .insert(users)
      .values({
        email,
        passwordHash,
        role: parsed.data.role,
        nama: parsed.data.nama.trim(),
        kabupaten: parsed.data.kabupaten.trim(),
        noWa: parsed.data.noWa?.trim() || null,
        namaOrg: parsed.data.namaOrg?.trim() || null,
        tipePembeli: parsed.data.role === 'pembeli' ? parsed.data.tipePembeli || 'koperasi' : null,
        isDemo: false,
      })
      .returning();

    const token = await createSessionToken({
      userId: created.id,
      email: created.email,
      role: created.role,
      nama: created.nama,
      kabupaten: created.kabupaten,
    });

    const response = NextResponse.json({
      ok: true,
      redirectTo: getHomePathForRole(created.role),
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
      { error: err instanceof Error ? err.message : 'Gagal mendaftar' },
      { status: 500 }
    );
  }
}

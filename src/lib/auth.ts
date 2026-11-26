import { SignJWT, jwtVerify } from 'jose';
import { cookies } from 'next/headers';
import type { UserRole } from '@/db/schema';

export const SESSION_COOKIE = 'simpanjual_session';

export interface SessionUser {
  userId: string;
  email: string;
  role: UserRole;
  nama: string;
  kabupaten: string;
}

function getSecretKey(): Uint8Array {
  const secret =
    process.env.JWT_SECRET || 'simpanjual-dev-secret-change-in-production-2026';
  return new TextEncoder().encode(secret);
}

export async function createSessionToken(user: SessionUser): Promise<string> {
  return new SignJWT({
    userId: user.userId,
    email: user.email,
    role: user.role,
    nama: user.nama,
    kabupaten: user.kabupaten,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(getSecretKey());
}

export async function verifySessionToken(token: string): Promise<SessionUser | null> {
  try {
    const { payload } = await jwtVerify(token, getSecretKey());
    if (
      typeof payload.userId !== 'string' ||
      typeof payload.email !== 'string' ||
      typeof payload.role !== 'string' ||
      typeof payload.nama !== 'string'
    ) {
      return null;
    }
    return {
      userId: payload.userId,
      email: payload.email,
      role: payload.role as UserRole,
      nama: payload.nama,
      kabupaten: typeof payload.kabupaten === 'string' ? payload.kabupaten : 'Banyumas',
    };
  } catch {
    return null;
  }
}

export async function getSessionUser(): Promise<SessionUser | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  return verifySessionToken(token);
}

export function getHomePathForRole(role: UserRole): string {
  switch (role) {
    case 'petani':
      return '/petani';
    case 'gudang':
      return '/gudang';
    case 'pembeli':
      return '/pembeli';
    case 'admin':
      return '/admin';
  }
}

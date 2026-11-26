import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE, getHomePathForRole, verifySessionToken } from '@/lib/auth';

const ROLE_PREFIXES: Array<{ prefix: string; role: 'petani' | 'gudang' | 'pembeli' | 'admin' }> = [
  { prefix: '/petani', role: 'petani' },
  { prefix: '/gudang', role: 'gudang' },
  { prefix: '/pembeli', role: 'pembeli' },
  { prefix: '/admin', role: 'admin' },
];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const matched = ROLE_PREFIXES.find(
    (entry) => pathname === entry.prefix || pathname.startsWith(`${entry.prefix}/`)
  );

  if (!matched) {
    return NextResponse.next();
  }

  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = token ? await verifySessionToken(token) : null;

  if (!session) {
    const loginUrl = new URL('/masuk', request.url);
    loginUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (session.role !== matched.role) {
    return NextResponse.redirect(new URL(getHomePathForRole(session.role), request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/petani/:path*', '/gudang/:path*', '/pembeli/:path*', '/admin/:path*'],
};

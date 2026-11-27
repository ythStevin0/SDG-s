const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

export function getStoredToken(): string | null {
  return localStorage.getItem('simpanjual_jwt');
}

export function setStoredToken(tok: string | null) {
  if (tok) localStorage.setItem('simpanjual_jwt', tok);
  else localStorage.removeItem('simpanjual_jwt');
}

export async function apiFetch<T = Record<string, unknown>>(
  path: string,
  options: RequestInit & { idempotent?: boolean } = {}
): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set('Content-Type', 'application/json');
  const tok = getStoredToken();
  if (tok) headers.set('Authorization', `Bearer ${tok}`);
  if (options.idempotent) {
    headers.set('Idempotency-Key', `web-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
  }

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data?.error || `HTTP ${res.status}`);
  }
  return data as T;
}

export function formatRp(n: number, plus = false): string {
  const r = Math.round(n);
  if (r < 0) return `-Rp${Math.abs(r).toLocaleString('id-ID')}`;
  return `${plus && r > 0 ? '+' : ''}Rp${r.toLocaleString('id-ID')}`;
}

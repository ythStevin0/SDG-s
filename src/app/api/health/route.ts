import { NextResponse } from 'next/server';
import { count } from 'drizzle-orm';
import { db } from '@/db';
import { buyerDemands, commodities, warehouses } from '@/db/schema';

export async function GET() {
  try {
    const [[cCount], [wCount], [dCount]] = await Promise.all([
      db.select({ total: count() }).from(commodities),
      db.select({ total: count() }).from(warehouses),
      db.select({ total: count() }).from(buyerDemands),
    ]);

    return NextResponse.json({
      ok: true,
      database: 'connected',
      timestamp: new Date().toISOString(),
      counts: {
        commodities: Number(cCount?.total ?? 0),
        warehouses: Number(wCount?.total ?? 0),
        demands: Number(dCount?.total ?? 0),
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        database: 'error',
        message: error instanceof Error ? error.message : 'Database connection failed',
      },
      { status: 500 }
    );
  }
}

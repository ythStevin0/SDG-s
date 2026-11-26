import 'dotenv/config';
import { count, eq } from 'drizzle-orm';
import { db, pgClient } from '@/db';
import { respondRental, submitRental } from '@/db/transactions';
import { buyerDemands, commodities, pricePoints, rentalRequests, stocks, users, warehouses } from '@/db/schema';

async function verify() {
  const [[u], [c], [p], [w], [d]] = await Promise.all([
    db.select({ n: count() }).from(users),
    db.select({ n: count() }).from(commodities),
    db.select({ n: count() }).from(pricePoints),
    db.select({ n: count() }).from(warehouses),
    db.select({ n: count() }).from(buyerDemands),
  ]);

  console.log('Counts:', {
    users: Number(u.n),
    commodities: Number(c.n),
    pricePoints: Number(p.n),
    warehouses: Number(w.n),
    buyerDemands: Number(d.n),
  });

  if (Number(u.n) < 5 || Number(c.n) < 2 || Number(p.n) < 128 || Number(w.n) < 4 || Number(d.n) < 4) {
    throw new Error('Seed counts incomplete!');
  }

  // Test atomic transaction cycle on Podman DB (submitRental -> respondRental terima -> selesai)
  const [petani] = await db.select().from(users).where(eq(users.email, 'petani@demo.id'));
  const [gudangOwner] = await db.select().from(users).where(eq(users.email, 'gudang@demo.id'));
  const [stok] = await db.select().from(stocks).where(eq(stocks.ownerId, petani.id));
  const [wh] = await db.select().from(warehouses).where(eq(warehouses.ownerId, gudangOwner.id));

  const initialAvail = wh.tersediaKg;
  const req = await submitRental(petani.id, {
    stockId: stok.id,
    warehouseId: wh.id,
    qtyKg: 5000,
    hari: 30,
  });

  await respondRental(gudangOwner.id, req.id, 'terima');
  const [whAfterAccept] = await db.select().from(warehouses).where(eq(warehouses.id, wh.id));
  if (whAfterAccept.tersediaKg !== initialAvail - 5000) {
    throw new Error('Kapasitas gudang tidak berkurang tepat setelah terima!');
  }

  await respondRental(gudangOwner.id, req.id, 'selesai');
  const [whAfterFinish] = await db.select().from(warehouses).where(eq(warehouses.id, wh.id));
  if (whAfterFinish.tersediaKg !== initialAvail) {
    throw new Error('Kapasitas gudang tidak pulih tepat setelah selesai!');
  }

  // Bersihkan request uji agar data demo tetap bersih
  await db.delete(rentalRequests).where(eq(rentalRequests.id, req.id));
  console.log('Atomic Podman PostgreSQL transaction test (submit -> terima -> selesai) PASSED!');
  await pgClient.end();
}

verify().catch(async (err) => {
  console.error(err);
  await pgClient.end();
  process.exit(1);
});

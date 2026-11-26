import { eq } from 'drizzle-orm';
import { db } from './index';
import {
  buyerDemands,
  farmerGroups,
  impactEvents,
  lotContributions,
  lots,
  rentalRequests,
  saleOffers,
  stocks,
  warehouses,
  type StockStatus,
} from './schema';

type DbTransaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

function computeStockStatus(qtyKg: number, reservedKg: number, soldKg: number): StockStatus {
  if (soldKg >= qtyKg) return 'terjual';
  const freeKg = qtyKg - reservedKg - soldKg;
  if (freeKg <= 0) return 'teralokasi_penuh';
  if (reservedKg > 0 || soldKg > 0) return 'teralokasi_sebagian';
  return 'tersedia';
}

async function reserveStock(tx: DbTransaction, stockId: string, deltaKg: number) {
  const [st] = await tx.select().from(stocks).where(eq(stocks.id, stockId)).for('update');
  if (!st) throw new Error('Stok tidak ditemukan');
  const freeKg = st.qtyKg - st.reservedKg - st.soldKg;
  if (freeKg < deltaKg) {
    throw new Error(`Stok bebas tidak mencukupi (tersisa ${freeKg} kg)`);
  }
  const newReserved = st.reservedKg + deltaKg;
  const newStatus = computeStockStatus(st.qtyKg, newReserved, st.soldKg);
  await tx
    .update(stocks)
    .set({ reservedKg: newReserved, status: newStatus })
    .where(eq(stocks.id, st.id));
  return st;
}

async function releaseStockReserve(tx: DbTransaction, stockId: string, deltaKg: number) {
  const [st] = await tx.select().from(stocks).where(eq(stocks.id, stockId)).for('update');
  if (!st) return;
  const newReserved = Math.max(0, st.reservedKg - deltaKg);
  const newStatus = computeStockStatus(st.qtyKg, newReserved, st.soldKg);
  await tx
    .update(stocks)
    .set({ reservedKg: newReserved, status: newStatus })
    .where(eq(stocks.id, st.id));
}

async function finalizeStockSale(tx: DbTransaction, stockId: string, deltaKg: number) {
  const [st] = await tx.select().from(stocks).where(eq(stocks.id, stockId)).for('update');
  if (!st) return;
  const newReserved = Math.max(0, st.reservedKg - deltaKg);
  const newSold = Math.min(st.qtyKg, st.soldKg + deltaKg);
  const newStatus = computeStockStatus(st.qtyKg, newReserved, newSold);
  await tx
    .update(stocks)
    .set({ reservedKg: newReserved, soldKg: newSold, status: newStatus })
    .where(eq(stocks.id, st.id));
}

export async function submitRental(
  userId: string,
  input: {
    stockId?: string | null;
    lotId?: string | null;
    warehouseId: string;
    qtyKg: number;
    hari: number;
  }
) {
  if ((!input.stockId && !input.lotId) || (input.stockId && input.lotId)) {
    throw new Error('Pilih tepat satu sumber: stok mandiri atau lot kolektif');
  }
  if (input.qtyKg <= 0 || input.hari <= 0) {
    throw new Error('Jumlah dan lama simpan harus lebih besar dari nol');
  }

  return db.transaction(async (tx) => {
    const [wh] = await tx
      .select()
      .from(warehouses)
      .where(eq(warehouses.id, input.warehouseId))
      .for('update');

    if (!wh) throw new Error('Gudang tidak ditemukan');
    if (wh.tersediaKg < input.qtyKg) {
      throw new Error(`Kapasitas gudang tidak cukup (tersisa ${wh.tersediaKg} kg)`);
    }
    if (input.qtyKg < wh.minVolumeKg) {
      throw new Error(`Volume di bawah batas minimum gudang (${wh.minVolumeKg} kg)`);
    }
    if (input.hari < wh.minHari) {
      throw new Error(`Lama simpan di bawah batas minimum gudang (${wh.minHari} hari)`);
    }

    if (input.stockId) {
      const [st] = await tx.select().from(stocks).where(eq(stocks.id, input.stockId)).for('update');
      if (!st) throw new Error('Stok tidak ditemukan');
      if (st.ownerId !== userId) throw new Error('FORBIDDEN: Bukan pemilik stok');
      await reserveStock(tx, st.id, input.qtyKg);
    } else if (input.lotId) {
      const [lot] = await tx.select().from(lots).where(eq(lots.id, input.lotId)).for('update');
      if (!lot) throw new Error('Lot tidak ditemukan');
      const [grp] = await tx.select().from(farmerGroups).where(eq(farmerGroups.id, lot.groupId));
      if (!grp || grp.ketuaId !== userId) {
        throw new Error('FORBIDDEN: Hanya ketua kelompok tani yang dapat mengajukan sewa lot');
      }
      if (lot.status !== 'siap_ajukan' && lot.status !== 'mengumpulkan') {
        throw new Error('Status lot belum/tidak siap diajukan');
      }
      await tx
        .update(lots)
        .set({ status: 'diajukan_sewa', warehouseId: wh.id })
        .where(eq(lots.id, lot.id));
    }

    const estimasiBiaya = Math.round(input.qtyKg * wh.tarifPerKgHari * input.hari);

    const [created] = await tx
      .insert(rentalRequests)
      .values({
        requesterId: userId,
        stockId: input.stockId ?? null,
        lotId: input.lotId ?? null,
        warehouseId: wh.id,
        qtyKg: input.qtyKg,
        hari: input.hari,
        estimasiBiaya,
        status: 'diajukan',
      })
      .returning();

    return created;
  });
}

export async function respondRental(
  actorUserId: string,
  requestId: string,
  action: 'terima' | 'tolak' | 'selesai' | 'batal',
  reason?: string
) {
  return db.transaction(async (tx) => {
    const [req] = await tx
      .select()
      .from(rentalRequests)
      .where(eq(rentalRequests.id, requestId))
      .for('update');

    if (!req) throw new Error('Pengajuan sewa tidak ditemukan');

    const [wh] = await tx
      .select()
      .from(warehouses)
      .where(eq(warehouses.id, req.warehouseId))
      .for('update');

    if (!wh) throw new Error('Gudang tidak ditemukan');

    if (action === 'batal') {
      if (req.requesterId !== actorUserId) {
        throw new Error('FORBIDDEN: Hanya pengaju yang dapat membatalkan');
      }
      if (req.status !== 'diajukan' && req.status !== 'diterima') {
        throw new Error('Pengajuan tidak dapat dibatalkan pada status ini');
      }
      if (req.status === 'diterima') {
        await tx
          .update(warehouses)
          .set({ tersediaKg: Math.min(wh.kapasitasKg, wh.tersediaKg + req.qtyKg) })
          .where(eq(warehouses.id, wh.id));
      }
      if (req.stockId) {
        await releaseStockReserve(tx, req.stockId, req.qtyKg);
      } else if (req.lotId) {
        await tx.update(lots).set({ status: 'siap_ajukan' }).where(eq(lots.id, req.lotId));
      }
      const [updated] = await tx
        .update(rentalRequests)
        .set({ status: 'dibatalkan', alasanTolak: reason ?? null, updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id))
        .returning();
      return updated;
    }

    if (wh.ownerId !== actorUserId) {
      throw new Error('FORBIDDEN: Hanya pemilik gudang yang dapat memproses permintaan ini');
    }

    if (action === 'terima' && req.status === 'diajukan') {
      if (wh.tersediaKg < req.qtyKg) {
        throw new Error(`Kapasitas gudang tersisa ${wh.tersediaKg} kg, tidak mencukupi`);
      }
      await tx
        .update(warehouses)
        .set({ tersediaKg: wh.tersediaKg - req.qtyKg })
        .where(eq(warehouses.id, wh.id));
      if (req.lotId) {
        await tx.update(lots).set({ status: 'disimpan' }).where(eq(lots.id, req.lotId));
      }
      const [updated] = await tx
        .update(rentalRequests)
        .set({ status: 'diterima', updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id))
        .returning();
      return updated;
    }

    if (action === 'tolak' && req.status === 'diajukan') {
      if (req.stockId) {
        await releaseStockReserve(tx, req.stockId, req.qtyKg);
      } else if (req.lotId) {
        await tx.update(lots).set({ status: 'siap_ajukan' }).where(eq(lots.id, req.lotId));
      }
      const [updated] = await tx
        .update(rentalRequests)
        .set({ status: 'ditolak', alasanTolak: reason ?? null, updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id))
        .returning();
      return updated;
    }

    if (action === 'selesai' && req.status === 'diterima') {
      await tx
        .update(warehouses)
        .set({ tersediaKg: Math.min(wh.kapasitasKg, wh.tersediaKg + req.qtyKg) })
        .where(eq(warehouses.id, wh.id));
      if (req.stockId) {
        await releaseStockReserve(tx, req.stockId, req.qtyKg);
      } else if (req.lotId) {
        await tx.update(lots).set({ status: 'selesai' }).where(eq(lots.id, req.lotId));
      }
      await tx.insert(impactEvents).values({
        jenis: 'susut_dicegah',
        userId: req.requesterId,
        refId: req.id,
        nilai: Math.round(req.qtyKg * 0.02 * (req.hari / 30)),
        meta: { warehouseId: wh.id, qtyKg: req.qtyKg, hari: req.hari },
      });
      const [updated] = await tx
        .update(rentalRequests)
        .set({ status: 'selesai', updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id))
        .returning();
      return updated;
    }

    throw new Error(`Transisi status tidak valid dari ${req.status} ke ${action}`);
  });
}

export async function submitSale(
  userId: string,
  input: {
    stockId?: string | null;
    lotId?: string | null;
    demandId: string;
    qtyKg: number;
    hargaTawar: number;
  }
) {
  if ((!input.stockId && !input.lotId) || (input.stockId && input.lotId)) {
    throw new Error('Pilih tepat satu sumber: stok mandiri atau lot kolektif');
  }
  if (input.qtyKg <= 0 || input.hargaTawar <= 0) {
    throw new Error('Volume dan harga tawar harus positif');
  }

  return db.transaction(async (tx) => {
    const [demand] = await tx
      .select()
      .from(buyerDemands)
      .where(eq(buyerDemands.id, input.demandId))
      .for('update');

    if (!demand || demand.status !== 'aktif') {
      throw new Error('Kebutuhan pembeli tidak ditemukan atau sudah ditutup');
    }
    const remaining = demand.qtyKg - demand.terpenuhiKg;
    if (remaining < input.qtyKg) {
      throw new Error(`Sisa kuota pembeli tinggal ${remaining} kg`);
    }

    if (input.stockId) {
      const [st] = await tx.select().from(stocks).where(eq(stocks.id, input.stockId)).for('update');
      if (!st) throw new Error('Stok tidak ditemukan');
      if (st.ownerId !== userId) throw new Error('FORBIDDEN: Bukan pemilik stok');
      await reserveStock(tx, st.id, input.qtyKg);
    } else if (input.lotId) {
      const [lot] = await tx.select().from(lots).where(eq(lots.id, input.lotId)).for('update');
      if (!lot) throw new Error('Lot tidak ditemukan');
      const [grp] = await tx.select().from(farmerGroups).where(eq(farmerGroups.id, lot.groupId));
      if (!grp || grp.ketuaId !== userId) {
        throw new Error('FORBIDDEN: Hanya ketua poktan yang berhak menjual lot');
      }
      await tx.update(lots).set({ status: 'diajukan_jual' }).where(eq(lots.id, lot.id));
    }

    const [created] = await tx
      .insert(saleOffers)
      .values({
        sellerId: userId,
        stockId: input.stockId ?? null,
        lotId: input.lotId ?? null,
        demandId: demand.id,
        qtyKg: input.qtyKg,
        hargaTawar: Math.round(input.hargaTawar),
        status: 'diajukan',
      })
      .returning();

    return created;
  });
}

export async function respondSale(
  actorUserId: string,
  offerId: string,
  action: 'terima' | 'tolak' | 'selesai' | 'batal',
  reason?: string
) {
  return db.transaction(async (tx) => {
    const [offer] = await tx
      .select()
      .from(saleOffers)
      .where(eq(saleOffers.id, offerId))
      .for('update');

    if (!offer) throw new Error('Penawaran jual tidak ditemukan');

    const [demand] = await tx
      .select()
      .from(buyerDemands)
      .where(eq(buyerDemands.id, offer.demandId))
      .for('update');

    if (!demand) throw new Error('Kebutuhan pembeli tidak ditemukan');

    if (action === 'batal') {
      if (offer.sellerId !== actorUserId) {
        throw new Error('FORBIDDEN: Hanya penjual yang dapat membatalkan');
      }
      if (offer.status !== 'diajukan' && offer.status !== 'diterima') {
        throw new Error('Status penawaran tidak dapat dibatalkan');
      }
      if (offer.status === 'diterima') {
        const nextFulfilled = Math.max(0, demand.terpenuhiKg - offer.qtyKg);
        await tx
          .update(buyerDemands)
          .set({
            terpenuhiKg: nextFulfilled,
            status: nextFulfilled >= demand.qtyKg ? 'terpenuhi' : 'aktif',
          })
          .where(eq(buyerDemands.id, demand.id));
      }
      if (offer.stockId) {
        await releaseStockReserve(tx, offer.stockId, offer.qtyKg);
      } else if (offer.lotId) {
        await tx.update(lots).set({ status: 'siap_ajukan' }).where(eq(lots.id, offer.lotId));
      }
      const [updated] = await tx
        .update(saleOffers)
        .set({ status: 'dibatalkan', alasanTolak: reason ?? null, updatedAt: new Date() })
        .where(eq(saleOffers.id, offer.id))
        .returning();
      return updated;
    }

    if (demand.buyerId !== actorUserId) {
      throw new Error('FORBIDDEN: Hanya pembeli pemilik kebutuhan yang berwenang');
    }

    if (action === 'terima' && offer.status === 'diajukan') {
      const remaining = demand.qtyKg - demand.terpenuhiKg;
      if (remaining < offer.qtyKg) {
        throw new Error(`Sisa kebutuhan tinggal ${remaining} kg`);
      }
      const nextFulfilled = demand.terpenuhiKg + offer.qtyKg;
      await tx
        .update(buyerDemands)
        .set({
          terpenuhiKg: nextFulfilled,
          status: nextFulfilled >= demand.qtyKg ? 'terpenuhi' : 'aktif',
        })
        .where(eq(buyerDemands.id, demand.id));
      const [updated] = await tx
        .update(saleOffers)
        .set({ status: 'diterima', updatedAt: new Date() })
        .where(eq(saleOffers.id, offer.id))
        .returning();
      return updated;
    }

    if (action === 'tolak' && offer.status === 'diajukan') {
      if (offer.stockId) {
        await releaseStockReserve(tx, offer.stockId, offer.qtyKg);
      } else if (offer.lotId) {
        await tx.update(lots).set({ status: 'siap_ajukan' }).where(eq(lots.id, offer.lotId));
      }
      const [updated] = await tx
        .update(saleOffers)
        .set({ status: 'ditolak', alasanTolak: reason ?? null, updatedAt: new Date() })
        .where(eq(saleOffers.id, offer.id))
        .returning();
      return updated;
    }

    if (action === 'selesai' && offer.status === 'diterima') {
      if (offer.stockId) {
        await finalizeStockSale(tx, offer.stockId, offer.qtyKg);
      } else if (offer.lotId) {
        const contribs = await tx
          .select()
          .from(lotContributions)
          .where(eq(lotContributions.lotId, offer.lotId));
        for (const c of contribs) {
          await finalizeStockSale(tx, c.stockId, c.qtyKg);
        }
        await tx.update(lots).set({ status: 'selesai' }).where(eq(lots.id, offer.lotId));
      }
      await tx.insert(impactEvents).values({
        jenis: 'stok_terserap',
        userId: offer.sellerId,
        refId: offer.id,
        nilai: offer.qtyKg,
        meta: { demandId: demand.id, hargaTawar: offer.hargaTawar },
      });
      const [updated] = await tx
        .update(saleOffers)
        .set({ status: 'selesai', updatedAt: new Date() })
        .where(eq(saleOffers.id, offer.id))
        .returning();
      return updated;
    }

    throw new Error(`Transisi status tidak valid dari ${offer.status} ke ${action}`);
  });
}

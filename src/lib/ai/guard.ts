export interface ExtractedMetric {
  raw: string;
  value: number;
  isAbbreviated: boolean;
}

const PHONE_REGEX = /(?:\+62|62|0)8[1-9][0-9\-.\s]{6,13}/g;
const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;

// Hanya mengekstrak angka yang terikat pada satuan/simbol nilai agar nomor urut (1., 2.) diabaikan
const UNIT_NUMBER_REGEX =
  /(?:Rp\.?\s*([\d.,]+)\s*(juta|jt|ribu|rb)?)|(?:([\d.,]+)\s*(%|persen|kg|ton|kuintal|kw|minggu|hari|bulan)\b)/gi;

export function stripPii(text: string): string {
  return text.replace(PHONE_REGEX, '[NOMOR_DIHAPUS]').replace(EMAIL_REGEX, '[EMAIL_DIHAPUS]');
}

export function parseIndonesianNumber(numStr: string): number {
  const cleaned = numStr.trim();
  if (cleaned.includes('.') && cleaned.includes(',')) {
    return Number(cleaned.replace(/\./g, '').replace(',', '.'));
  }
  if (cleaned.includes(',')) {
    return Number(cleaned.replace(',', '.'));
  }
  if (/^\d{1,3}(\.\d{3})+$/.test(cleaned)) {
    return Number(cleaned.replace(/\./g, ''));
  }
  return Number(cleaned);
}

export function extractUnitNumbers(text: string): ExtractedMetric[] {
  const results: ExtractedMetric[] = [];
  for (const match of text.matchAll(UNIT_NUMBER_REGEX)) {
    if (match[1] !== undefined) {
      const base = parseIndonesianNumber(match[1]);
      const multUnit = (match[2] || '').toLowerCase();
      const mult =
        multUnit === 'juta' || multUnit === 'jt'
          ? 1_000_000
          : multUnit === 'ribu' || multUnit === 'rb'
            ? 1_000
            : 1;
      results.push({ raw: match[0], value: base * mult, isAbbreviated: mult > 1 });
    } else if (match[3] !== undefined) {
      const base = parseIndonesianNumber(match[3]);
      const unit = (match[4] || '').toLowerCase();
      const mult =
        unit === 'ton' ? 1_000 : unit === 'kuintal' || unit === 'kw' ? 100 : unit === 'bulan' ? 4 : 1;
      results.push({ raw: match[0], value: base * mult, isAbbreviated: false });
    }
  }
  return results;
}

export function validateAiExplanationNumbers(
  aiTexts: string[],
  allowedValues: number[]
): { valid: boolean; offendingToken?: string } {
  const fullText = aiTexts.filter(Boolean).join(' ');
  const tokens = extractUnitNumbers(fullText);

  for (const token of tokens) {
    if (!Number.isFinite(token.value)) {
      return { valid: false, offendingToken: token.raw };
    }
    const tolerance = token.isAbbreviated ? 0.05 : 0.01;
    const matched = allowedValues.some((ref) => {
      if (ref === 0) return Math.abs(token.value) < 1;
      return Math.abs(token.value - ref) / Math.abs(ref) <= tolerance;
    });
    if (!matched) {
      return { valid: false, offendingToken: token.raw };
    }
  }
  return { valid: true };
}

export interface FallbackExplainInput {
  recommendation: 'TAHAN' | 'TAHAN_BERISIKO' | 'JUAL';
  horizonWeeks: number;
  titikImpasPerKg: number;
  selisihRp: number;
  totalBiayaSimpan: number;
}

export function buildTemplateExplanation(input: FallbackExplainInput) {
  const beStr = `Rp${input.titikImpasPerKg.toLocaleString('id-ID')}/kg`;
  const selisihStr = `Rp${Math.abs(input.selisihRp).toLocaleString('id-ID')}`;
  const biayaStr = `Rp${input.totalBiayaSimpan.toLocaleString('id-ID')}`;

  return {
    ringkasan:
      input.recommendation === 'JUAL'
        ? `Sebaiknya jual sekarang karena perkiraan kenaikan harga belum menutup biaya simpan (${biayaStr}).`
        : `Disarankan menahan selama ${input.horizonWeeks} minggu dengan perkiraan tambahan hasil ${selisihStr} jika harga minimal ${beStr}.`,
    alasan: [
      `Titik impas harga jual setelah simpan adalah ${beStr}.`,
      `Total biaya simpan, angkut, susut, dan bunga tercatat sebesar ${biayaStr}.`,
    ],
    langkah_berikut:
      input.recommendation === 'JUAL'
        ? ['Buka daftar kebutuhan pembeli di menu Jual.', 'Bandingkan harga tawar dengan harga pasar hari ini.']
        : ['Periksa kesiapan kadar air stok Anda.', 'Cari gudang terdekat atau gabung Lot Kolektif poktan.'],
    peringatan:
      input.recommendation === 'TAHAN_BERISIKO'
        ? 'Prediksi masih memiliki risiko turun di batas bawah. Pantau harga mingguan secara berkala.'
        : null,
  };
}

export function regexExtractOffer(rawText: string) {
  const cleaned = stripPii(rawText);
  let hargaPerKg: number | null = null;
  let jumlahKg: number | null = null;
  const uncertain: string[] = [];

  const priceMatch = cleaned.match(/Rp\.?\s*([\d.,]+)\s*(rb|ribu)?\s*(?:\/\s*kg|per\s*kg)?/i);
  if (priceMatch) {
    const val = parseIndonesianNumber(priceMatch[1]);
    const mult = priceMatch[2] ? 1000 : 1;
    const candidate = Math.round(val * mult);
    if (candidate >= 100 && candidate <= 200_000) {
      hargaPerKg = candidate;
    }
  }

  const qtyMatch = cleaned.match(/([\d.,]+)\s*(kg|ton|kuintal|kw|karung|sak)\b/i);
  if (qtyMatch) {
    const val = parseIndonesianNumber(qtyMatch[1]);
    const unit = qtyMatch[2].toLowerCase();
    if (unit === 'ton') jumlahKg = Math.round(val * 1000);
    else if (unit === 'kuintal' || unit === 'kw') jumlahKg = Math.round(val * 100);
    else if (unit === 'karung' || unit === 'sak') {
      jumlahKg = Math.round(val * 50);
      uncertain.push('jumlah_kg');
    } else {
      jumlahKg = Math.round(val);
    }
  }

  return {
    jenis: /panjar|ijon|tebas/i.test(cleaned) ? 'panjar' : 'pembelian',
    harga_per_kg: hargaPerKg,
    jumlah_kg: jumlahKg,
    field_tidak_pasti: uncertain,
    catatan: uncertain.includes('jumlah_kg')
      ? 'Satuan karung diasumsikan 50 kg per karung; mohon sesuaikan berat riil.'
      : null,
  };
}

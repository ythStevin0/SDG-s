import React, { useEffect, useState } from 'react';
import {
  AIExplanation,
  apiFetch,
  Commodity,
  formatKg,
  formatRp,
  getStoredToken,
  localExplainAI,
  localSimulate,
  resetBackendCircuit,
  setStoredToken,
  SimResponse,
  UserProfile,
} from './api';
import {
  BarnScaleLogo,
  ForecastBreakEvenChart,
  LedgerRow,
  QuickAuthModal,
  SplitGoldCtaButton,
  StampBadge,
  StatePanel,
  SvgGlyph,
  WarehouseMapPanel,
} from './components';
import {
  buildOfflineStockAnalysis,
  DemandItem,
  DEMO_USERS,
  INITIAL_OFFLINE_DEMANDS,
  INITIAL_OFFLINE_LOTS,
  INITIAL_OFFLINE_STOCKS,
  INITIAL_OFFLINE_WAREHOUSES,
  LotItem,
  OFFLINE_COMMODITIES,
  RentalItem,
  SaleItem,
  StockItem,
  WarehouseItem,
} from './offlineData';

const HERO_SLIDES = [
  {
    eyebrow: 'KOMODITAS PASCAPANEN',
    headline: 'PANEN RAYA',
    plain1: 'Hitungan jujur ',
    bold1: 'tahan gudang SRG',
    plain2: ' atau ',
    bold2: 'jual panen segera',
    ctaLabel: 'Hitung Titik Impas',
    ctaHref: '#kalkulator-impas',
    kode: 'jagung',
  },
  {
    eyebrow: 'KONVERSI KADAR AIR GKP KE GKG',
    headline: 'PADI GABAH',
    plain1: 'Potong susut jemur ',
    bold1: 'kadar air 22% ke 14%',
    plain2: ' sebelum adu dengan ',
    bold2: 'panjar tengkulak',
    ctaLabel: 'Uji Simulasi Gabah',
    ctaHref: '#kalkulator-impas',
    kode: 'gabah',
  },
  {
    eyebrow: 'LOT KOLEKTIF & PEMBELI SIAGA',
    headline: 'LUMBUNG SRG',
    plain1: 'Gabung kode poktan ',
    bold1: 'TANIJAYA 10 ton',
    plain2: ' dan kunci kuota ',
    bold2: 'Janji Beli SPPG',
    ctaLabel: 'Masuk 5 Akun Demo',
    ctaHref: '',
    kode: 'jagung',
  },
] as const;

const CHECKLIST_LABELS: { key: string; label: string }[] = [
  { key: 'atap_tidak_bocor', label: 'Atap gudang tidak bocor' },
  { key: 'ventilasi', label: 'Sirkulasi ventilasi baik' },
  { key: 'lantai_palet_kering', label: 'Lantai berpalet & kering' },
  { key: 'kontrol_hama', label: 'Kontrol hama rutin' },
  { key: 'alat_ukur_ka', label: 'Tersedia alat ukur kadar air' },
  { key: 'keamanan_suhu', label: 'Pemantauan suhu ruang' },
];

export default function App() {
  const [darkMode, setDarkMode] = useState<boolean>(() => localStorage.getItem('sj_dark') === '1');
  const [fieldMode, setFieldMode] = useState<boolean>(() => localStorage.getItem('sj_field') === '1');
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [quickDrawerOpen, setQuickDrawerOpen] = useState(false);
  const [sidebarExpanded, setSidebarExpanded] = useState(true);

  const [user, setUser] = useState<UserProfile | null>(null);
  const [offlineMode, setOfflineMode] = useState(false);
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [heroSlide, setHeroSlide] = useState(0);
  const [impactState, setImpactState] = useState<'loading' | 'ready' | 'error'>('loading');
  const [impact, setImpact] = useState({
    tambahanPendapatanRp: 4250000,
    stokTerserapKg: 10000,
    susutDicegahKg: 240,
  });

  const [simKode, setSimKode] = useState('jagung');
  const [simQty, setSimQty] = useState(5000);
  const [simKa, setSimKa] = useState(18);
  const [simUseSrg, setSimUseSrg] = useState(true);
  const [simPanjarMode, setSimPanjarMode] = useState<'per_kg' | 'borongan'>('per_kg');
  const [simPanjar, setSimPanjar] = useState(3800);
  const [simBorongan, setSimBorongan] = useState(19000000);
  const [waText, setWaText] = useState('');
  const [waFeedback, setWaFeedback] = useState<string | null>(null);
  const [simResult, setSimResult] = useState<SimResponse>(() =>
    localSimulate({
      commodityKode: 'jagung',
      qtyKg: 5000,
      kadarAirAktual: 18,
      useSrgLoan: true,
      hargaPanjarPerKg: 3800,
    })
  );

  const [petaniTab, setPetaniTab] = useState<'stok' | 'gudang' | 'pasar'>('stok');
  const [dashState, setDashState] = useState<'loading' | 'ready' | 'error'>('ready');
  const [dashError, setDashError] = useState<string | null>(null);

  const [stocks, setStocks] = useState<StockItem[]>(INITIAL_OFFLINE_STOCKS);
  const [selectedAnalysis, setSelectedAnalysis] = useState<(SimResponse & { stock: StockItem }) | null>(null);
  const [aiExplain, setAiExplain] = useState<AIExplanation | null>(null);
  const [explainBusy, setExplainBusy] = useState(false);

  const [customRentRate, setCustomRentRate] = useState('2.5');
  const [customTransportRate, setCustomTransportRate] = useState('20');
  const [customBungaRate, setCustomBungaRate] = useState('0.06');
  const [customPanjarMode, setCustomPanjarMode] = useState<'per_kg' | 'borongan'>('per_kg');
  const [customPanjarVal, setCustomPanjarVal] = useState('3800');

  const [warehouses, setWarehouses] = useState<WarehouseItem[]>(INITIAL_OFFLINE_WAREHOUSES);
  const [selectedWhId, setSelectedWhId] = useState<string>(INITIAL_OFFLINE_WAREHOUSES[0].id);
  const [lots, setLots] = useState<LotItem[]>(INITIAL_OFFLINE_LOTS);
  const [demands, setDemands] = useState<DemandItem[]>(INITIAL_OFFLINE_DEMANDS);
  const [rentals, setRentals] = useState<RentalItem[]>([]);
  const [sales, setSales] = useState<SaleItem[]>([]);
  const [commodities, setCommodities] = useState<Commodity[]>(OFFLINE_COMMODITIES);
  const [healthInfo, setHealthInfo] = useState<Record<string, any> | null>(null);

  const [newStockKode, setNewStockKode] = useState('jagung');
  const [newStockQty, setNewStockQty] = useState('3500');
  const [newStockKa, setNewStockKa] = useState('16.5');
  const [joinCode, setJoinCode] = useState('');

  const [newDemandKode, setNewDemandKode] = useState('jagung');
  const [newDemandQty, setNewDemandQty] = useState('8000');
  const [newDemandPrice, setNewDemandPrice] = useState('5900');

  const [newCommKode, setNewCommKode] = useState('');
  const [newCommNama, setNewCommNama] = useState('');
  const [editingWh, setEditingWh] = useState<Record<string, { tersediaKg: string; tarifPerKgHari: string; checklist: Record<string, boolean> }>>({});
  const [editingComm, setEditingComm] = useState<Record<string, { ka: string; susut: string; kering: string }>>({});

  useEffect(() => {
    document.documentElement.classList.toggle('dark', darkMode);
    localStorage.setItem('sj_dark', darkMode ? '1' : '0');
  }, [darkMode]);

  useEffect(() => {
    document.documentElement.classList.toggle('field-mode', fieldMode);
    localStorage.setItem('sj_field', fieldMode ? '1' : '0');
  }, [fieldMode]);

  useEffect(() => {
    if (!quickDrawerOpen) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') setQuickDrawerOpen(false);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [quickDrawerOpen]);

  useEffect(() => {
    setImpactState('loading');
    apiFetch<{ tambahanPendapatanRp: number; stokTerserapKg: number; susutDicegahKg: number }>('/api/v1/impact')
      .then((d) => {
        setImpact({
          tambahanPendapatanRp: d.tambahanPendapatanRp ?? 4250000,
          stokTerserapKg: d.stokTerserapKg ?? 10000,
          susutDicegahKg: d.susutDicegahKg ?? 240,
        });
        setOfflineMode(false);
        setImpactState('ready');
      })
      .catch(() => {
        setOfflineMode(true);
        setImpactState('ready');
      });

    const tok = getStoredToken();
    if (tok) {
      if (tok.startsWith('offline-')) {
        const key = tok.replace('offline-', '');
        if (DEMO_USERS[key]) setUser(DEMO_USERS[key]);
      } else {
        apiFetch<{ user: UserProfile }>('/api/v1/auth/me')
          .then((res) => setUser(res.user))
          .catch(() => setStoredToken(null));
      }
    }
  }, []);

  useEffect(() => {
    void runSimulation(simKode, simQty, simKa, simUseSrg, simPanjarMode, simPanjar, simBorongan);
  }, [simKode, simUseSrg, simPanjarMode]);

  useEffect(() => {
    if (user) void loadWorkspace(user);
  }, [user]);

  async function runSimulation(
    kode = simKode,
    qty = simQty,
    ka = simKa,
    useSrg = simUseSrg,
    panjarMode = simPanjarMode,
    panjarPerKg = simPanjar,
    boronganTotal = simBorongan
  ) {
    try {
      const res = await apiFetch<SimResponse>('/api/v1/simulator', {
        method: 'POST',
        body: JSON.stringify({
          commodityKode: kode,
          qtyKg: qty,
          kadarAirAktual: ka,
          tarifSewaPerKgHari: 2.5,
          biayaAngkutPerKg: 20,
          biayaTetap: 100000,
          rasioPinjaman: useSrg ? 0.7 : 0,
          bungaTahunan: 0.06,
          hargaPanjarPerKg: panjarMode === 'per_kg' ? panjarPerKg : null,
          totalBoronganRp: panjarMode === 'borongan' ? boronganTotal : null,
        }),
      });
      setSimResult(res);
      setOfflineMode(false);
    } catch {
      setOfflineMode(true);
      setSimResult(
        localSimulate({
          commodityKode: kode,
          qtyKg: qty,
          kadarAirAktual: ka,
          useSrgLoan: useSrg,
          panjarMode,
          hargaPanjarPerKg: panjarPerKg,
          totalBoronganRp: boronganTotal,
        })
      );
    }
  }

  async function handleExtractWa(e: React.FormEvent) {
    e.preventDefault();
    if (!waText.trim()) {
      setWaFeedback('Tempel isi pesan WhatsApp tawaran tengkulak terlebih dahulu.');
      return;
    }
    try {
      const res = await apiFetch<{ extracted: { harga_per_kg?: number; harga_total_borongan?: number } }>(
        '/api/v1/ai/extract',
        {
          method: 'POST',
          body: JSON.stringify({ rawText: waText }),
        }
      );
      const borongan = res.extracted?.harga_total_borongan;
      const perKg = res.extracted?.harga_per_kg;
      if (borongan && borongan > 200000) {
        setSimPanjarMode('borongan');
        setSimBorongan(borongan);
        setWaFeedback(`Nilai tebasan borongan ${formatRp(borongan)} berhasil dibaca dan diterapkan.`);
        await runSimulation(simKode, simQty, simKa, simUseSrg, 'borongan', simPanjar, borongan);
        return;
      }
      if (perKg && perKg > 0) {
        setSimPanjarMode('per_kg');
        setSimPanjar(perKg);
        setWaFeedback(`Harga panjar ${formatRp(perKg)}/kg berhasil dibaca dan dihitung ulang.`);
        await runSimulation(simKode, simQty, simKa, simUseSrg, 'per_kg', perKg, simBorongan);
        return;
      }
    } catch {
      // Gunakan pembaca angka lokal bila server tidak aktif.
    }

    const match = waText.match(/(\d[\d.,]*)\s*(jt|juta|rb|ribu)?/i);
    if (match) {
      const raw = Number(match[1].replace(/\./g, '').replace(',', '.'));
      const unit = (match[2] || '').toLowerCase();
      const mult = unit === 'jt' || unit === 'juta' ? 1000000 : unit === 'rb' || unit === 'ribu' ? 1000 : 1;
      const parsed = Math.round(raw * mult);
      if (parsed > 200000) {
        setSimPanjarMode('borongan');
        setSimBorongan(parsed);
        setWaFeedback(`Nilai tebasan borongan ${formatRp(parsed)} diterapkan ke simulasi.`);
        await runSimulation(simKode, simQty, simKa, simUseSrg, 'borongan', simPanjar, parsed);
        return;
      }
      if (parsed >= 500 && parsed <= 50000) {
        setSimPanjarMode('per_kg');
        setSimPanjar(parsed);
        setWaFeedback(`Harga panjar ${formatRp(parsed)}/kg diterapkan ke simulasi.`);
        await runSimulation(simKode, simQty, simKa, simUseSrg, 'per_kg', parsed, simBorongan);
        return;
      }
    }
    setWaFeedback('Tidak ditemukan angka harga pada teks tersebut. Contoh: "Saya ambil jagung Rp3.900/kg".');
  }

  function speakId(text: string) {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utt = new SpeechSynthesisUtterance(text);
      utt.lang = 'id-ID';
      window.speechSynthesis.speak(utt);
      setNotice('Membacakan ringkasan suara Bahasa Indonesia.');
    } else {
      setNotice('Peramban ini tidak menyediakan fitur pembaca suara.');
    }
  }

  async function handleDemoLogin(preset: string) {
    setAuthBusy(true);
    setAuthError(null);
    try {
      const res = await apiFetch<{ token: string; user: UserProfile }>('/api/v1/auth/demo', {
        method: 'POST',
        body: JSON.stringify({ preset }),
      });
      setStoredToken(res.token);
      setOfflineMode(false);
      setUser(res.user);
      setSelectedAnalysis(null);
      setAiExplain(null);
      setAuthModalOpen(false);
      setQuickDrawerOpen(false);
    } catch {
      const fallbackUser = DEMO_USERS[preset] || DEMO_USERS.petani;
      setStoredToken(`offline-${preset}`);
      setOfflineMode(true);
      setUser(fallbackUser);
      setSelectedAnalysis(null);
      setAiExplain(null);
      setAuthModalOpen(false);
      setQuickDrawerOpen(false);
    } finally {
      setAuthBusy(false);
    }
  }

  async function handleManualLogin(email: string, password: string) {
    setAuthBusy(true);
    setAuthError(null);
    try {
      const res = await apiFetch<{ token: string; user: UserProfile }>('/api/v1/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      setStoredToken(res.token);
      setOfflineMode(false);
      setUser(res.user);
      setAuthModalOpen(false);
    } catch (err: any) {
      const matchedEntry = Object.entries(DEMO_USERS).find(
        ([, u]) => u.email.toLowerCase() === email.toLowerCase()
      );
      if (matchedEntry && password === 'demo12345') {
        setStoredToken(`offline-${matchedEntry[0]}`);
        setOfflineMode(true);
        setUser(matchedEntry[1]);
        setAuthModalOpen(false);
      } else {
        setAuthError(err?.message || 'Email atau kata sandi tidak cocok (akun demo memakai demo12345).');
      }
    } finally {
      setAuthBusy(false);
    }
  }

  async function handleRegister(payload: {
    nama: string;
    email: string;
    password: string;
    role: 'petani' | 'gudang' | 'pembeli';
    kabupaten: string;
  }) {
    setAuthBusy(true);
    setAuthError(null);
    try {
      const res = await apiFetch<{ token: string; user: UserProfile }>('/api/v1/auth/register', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      setStoredToken(res.token);
      setOfflineMode(false);
      setUser(res.user);
      setAuthModalOpen(false);
      setNotice(`Akun ${res.user.nama} (${res.user.role}) berhasil didaftarkan.`);
    } catch (err: any) {
      const offlineUser: UserProfile = {
        id: `offline-${Date.now()}`,
        email: payload.email,
        role: payload.role,
        nama: payload.nama,
        kabupaten: payload.kabupaten,
      };
      setStoredToken(`offline-${payload.role}`);
      setOfflineMode(true);
      setUser(offlineUser);
      setAuthModalOpen(false);
      setNotice(err?.message ? `${err.message} (beralih ke sesi simulasi).` : `Akun simulasi ${payload.nama} aktif.`);
    } finally {
      setAuthBusy(false);
    }
  }

  async function loadWorkspace(u: UserProfile) {
    setDashState('loading');
    setDashError(null);
    if (offlineMode || (getStoredToken() || '').startsWith('offline-')) {
      setStocks(INITIAL_OFFLINE_STOCKS);
      setWarehouses(INITIAL_OFFLINE_WAREHOUSES);
      setSelectedWhId(INITIAL_OFFLINE_WAREHOUSES[0].id);
      setLots(INITIAL_OFFLINE_LOTS);
      setDemands(INITIAL_OFFLINE_DEMANDS);
      setCommodities(OFFLINE_COMMODITIES);
      setHealthInfo({
        status: 'offline_standalone',
        architecture: 'Mode Simulasi Mandiri (Mesin Hitung Lokal Web)',
        counts: { users: 5, commodities: OFFLINE_COMMODITIES.length, warehouses: INITIAL_OFFLINE_WAREHOUSES.length, demands: INITIAL_OFFLINE_DEMANDS.length },
      });
      setDashState('ready');
      return;
    }

    try {
      const comms = await apiFetch<{ commodities: Commodity[] }>('/api/v1/commodities');
      setCommodities(comms.commodities || OFFLINE_COMMODITIES);

      if (u.role === 'petani') {
        const [st, wh, lt, dm, rn, sl] = await Promise.all([
          apiFetch<{ stocks: StockItem[] }>('/api/v1/stocks'),
          apiFetch<{ warehouses: WarehouseItem[] }>(
            `/api/v1/warehouses?commodity=jagung&kabupaten=${encodeURIComponent(u.kabupaten)}&qtyKg=5000`
          ),
          apiFetch<{ lots: LotItem[] }>('/api/v1/lots'),
          apiFetch<{ demands: DemandItem[] }>('/api/v1/demands'),
          apiFetch<{ rentals: RentalItem[] }>('/api/v1/rentals'),
          apiFetch<{ sales: SaleItem[] }>('/api/v1/sales'),
        ]);
        setStocks(st.stocks || []);
        const whList = wh.warehouses || [];
        setWarehouses(whList);
        if (whList.length > 0) setSelectedWhId(whList[0].id);
        setLots(lt.lots || []);
        setDemands(dm.demands || []);
        setRentals(rn.rentals || []);
        setSales(sl.sales || []);
      } else if (u.role === 'gudang') {
        const [wh, rn] = await Promise.all([
          apiFetch<{ warehouses: WarehouseItem[] }>('/api/v1/warehouses?mine=true'),
          apiFetch<{ rentals: RentalItem[] }>('/api/v1/rentals'),
        ]);
        setWarehouses(wh.warehouses || []);
        setRentals(rn.rentals || []);
      } else if (u.role === 'pembeli') {
        const [dm, sl] = await Promise.all([
          apiFetch<{ demands: DemandItem[] }>('/api/v1/demands?mine=true'),
          apiFetch<{ sales: SaleItem[] }>('/api/v1/sales'),
        ]);
        setDemands(dm.demands || []);
        setSales(sl.sales || []);
      } else if (u.role === 'admin') {
        const h = await apiFetch('/api/v1/health');
        setHealthInfo(h);
      }
      setDashState('ready');
    } catch (err: any) {
      setDashError(err?.message || 'Gagal memuat data ruang kerja dari server.');
      setDashState('error');
    }
  }

  async function inspectStock(st: StockItem) {
    setAiExplain(null);
    if (offlineMode) {
      setSelectedAnalysis(buildOfflineStockAnalysis(st));
      return;
    }
    try {
      const res = await apiFetch<SimResponse & { stock: StockItem }>(`/api/v1/stocks/${st.id}/analysis`);
      setSelectedAnalysis(res);
    } catch {
      setSelectedAnalysis(buildOfflineStockAnalysis(st));
    }
  }

  async function applyCustomAssumptions(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedAnalysis) return;
    const st = selectedAnalysis.stock;
    const sewa = Number(customRentRate) || 2.5;
    const angkut = Number(customTransportRate) >= 0 ? Number(customTransportRate) : 20;
    const bunga = Number(customBungaRate) || 0.06;
    const panjarNum = Number(customPanjarVal) || (customPanjarMode === 'borongan' ? 19000000 : 3800);

    if (!offlineMode) {
      try {
        const res = await apiFetch<SimResponse>(`/api/v1/stocks/${st.id}/decide`, {
          method: 'POST',
          body: JSON.stringify({
            tarifSewaPerKgHari: sewa,
            biayaAngkutPerKg: angkut,
            bungaTahunan: bunga,
            panjarMode: customPanjarMode,
            hargaPanjarPerKg: customPanjarMode === 'per_kg' ? panjarNum : null,
            totalBoronganRp: customPanjarMode === 'borongan' ? panjarNum : null,
          }),
        });
        setSelectedAnalysis({ ...res, stock: st });
        setAiExplain(null);
        setNotice('Asumsi biaya dan skema bunga berhasil diperbarui dari server.');
        return;
      } catch {
        // Fallback ke kalkulasi lokal.
      }
    }
    const localRes = localSimulate({
      commodityKode: st.commodityKode,
      qtyKg: st.qtyKg,
      kadarAirAktual: st.kadarAir,
      useSrgLoan: bunga > 0,
      panjarMode: customPanjarMode,
      hargaPanjarPerKg: customPanjarMode === 'per_kg' ? panjarNum : 3800,
      totalBoronganRp: customPanjarMode === 'borongan' ? panjarNum : 19000000,
      tarifSewaPerKgHari: sewa,
      biayaAngkutPerKg: angkut,
      bungaTahunan: bunga,
    });
    setSelectedAnalysis({ ...localRes, stock: st });
    setAiExplain(null);
    setNotice('Asumsi biaya dan skema bunga diperbarui pada sesi lokal.');
  }

  async function requestAiExplanation() {
    if (!selectedAnalysis) return;
    setExplainBusy(true);
    try {
      if (!offlineMode) {
        const res = await apiFetch<{ explanation: AIExplanation }>('/api/v1/ai/explain', {
          method: 'POST',
          body: JSON.stringify({
            komoditas: selectedAnalysis.stock.commodityNama,
            rekomendasi: selectedAnalysis.decision.recommendation,
            horizonMinggu: selectedAnalysis.decision.bestHorizonWeeks,
            selisihRp: selectedAnalysis.decision.best.selisihRp,
            selisihPct: selectedAnalysis.decision.best.selisihPct,
            titikImpasPerKg: selectedAnalysis.decision.best.titikImpasPerKg,
            hargaSekarangPerKg: selectedAnalysis.latestPrice,
            totalBiayaSimpan: selectedAnalysis.decision.best.totalBiayaSimpan,
            mapePct: selectedAnalysis.forecast?.mapePct ?? 4.8,
          }),
        });
        setAiExplain(res.explanation);
        return;
      }
    } catch {
      // Jatuh ke penjelasan template deterministik.
    } finally {
      setExplainBusy(false);
    }
    setAiExplain(localExplainAI(selectedAnalysis.decision));
  }

  async function handleAddStock(e: React.FormEvent) {
    e.preventDefault();
    const qty = Number(newStockQty);
    const ka = Number(newStockKa);
    if (!qty || qty < 50) {
      setNotice('Volume stok panen minimal 50 kg.');
      return;
    }
    if (!ka || ka < 8 || ka > 40) {
      setNotice('Kadar air harus berada di rentang 8% sampai 40%.');
      return;
    }
    if (!offlineMode && user) {
      try {
        const comm = commodities.find((c) => c.kode === newStockKode) || commodities[0];
        await apiFetch('/api/v1/stocks', {
          method: 'POST',
          idempotent: true,
          body: JSON.stringify({
            commodityId: comm.id,
            commodityKode: newStockKode,
            qtyKg: qty,
            kadarAir: ka,
            kotoranPct: 2,
            rusakPct: 2.5,
            tglPanen: '2026-11-27',
            kabupaten: user.kabupaten,
          }),
        });
        setNotice(`Stok ${formatKg(qty)} berhasil disimpan.`);
        await loadWorkspace(user);
        return;
      } catch (err: any) {
        setNotice(err?.message || 'Gagal menyimpan ke server, ditambahkan ke sesi simulasi.');
      }
    }
    const nama = newStockKode === 'gabah' ? 'Gabah Kering Giling (GKG)' : 'Jagung Pipil';
    setStocks((prev) => [
      {
        id: `st-${Date.now()}`,
        commodityKode: newStockKode,
        commodityNama: nama,
        qtyKg: qty,
        reservedKg: 0,
        soldKg: 0,
        freeKg: qty,
        kadarAir: ka,
        tglPanen: '2026-11-27',
        kabupaten: user?.kabupaten || 'Banyumas',
        status: 'tersedia',
      },
      ...prev,
    ]);
    setNotice(`Stok ${nama} seberat ${formatKg(qty)} ditambahkan.`);
  }

  const activeSlide = HERO_SLIDES[heroSlide];

  return (
    <div className="min-h-dvh flex flex-col" style={{ backgroundColor: 'var(--sj-bg)', color: 'var(--sj-ink)' }}>
      <a href="#konten-utama" className="skip-link">
        Loncat ke isi utama
      </a>

      {!user ? (
        <>
          <div id="panggung" className="sj-stage-gradient w-full overflow-hidden">
            <header className="flex h-[68px] items-center justify-between pl-4 sm:pl-7 lg:pl-11">
              <div className="flex items-center gap-6 lg:gap-12">
                <BarnScaleLogo lightOnDark />
                <nav aria-label="Navigasi panggung utama" className="hidden md:flex items-center h-[68px]">
                  <a
                    href="#panggung"
                    className="relative flex h-full items-center px-2 text-[13.5px] font-extrabold"
                    style={{ color: 'var(--sj-gold-text)' }}
                  >
                    <span
                      aria-hidden="true"
                      className="absolute top-0 left-1 right-1 h-1 rounded-b"
                      style={{ backgroundColor: 'var(--sj-gold)' }}
                    />
                    Beranda
                  </a>
                  <span aria-hidden="true" className="px-3 text-white/70">
                    •
                  </span>
                  <a
                    href="#kalkulator-impas"
                    className="flex h-full items-center px-2 text-[13.5px] font-semibold text-white hover:underline"
                  >
                    Simulasi Impas
                  </a>
                  <span aria-hidden="true" className="px-3 text-white/70">
                    •
                  </span>
                  <a
                    href="#empat-peran"
                    className="flex h-full items-center px-2 text-[13.5px] font-semibold text-white hover:underline"
                  >
                    Panjar &amp; Peran
                  </a>
                </nav>
              </div>

              <div className="flex items-center gap-1.5 sm:gap-2.5">
                <button
                  type="button"
                  aria-pressed={darkMode}
                  aria-label={darkMode ? 'Aktifkan Mode Kertas Daun Terang' : 'Aktifkan Mode Rimbun Gelap'}
                  onClick={() => setDarkMode((v) => !v)}
                  className="inline-flex h-11 w-11 items-center justify-center rounded-lg text-white hover:bg-white/10"
                >
                  <SvgGlyph name={darkMode ? 'sun' : 'moon'} className="w-5 h-5" />
                </button>

                <button
                  type="button"
                  onClick={() => setAuthModalOpen(true)}
                  className="focus-dark inline-flex min-h-[44px] items-center px-1"
                  aria-label="Buka pilihan 5 akun demo siap pakai"
                >
                  <span
                    style={{ backgroundColor: 'var(--sj-gold)', color: '#193226' }}
                    className="tabular-nums inline-flex h-9 items-center gap-1.5 rounded-full px-3.5 text-xs font-black"
                  >
                    <span>5 Demo</span>
                    <SvgGlyph name="arrow-right" className="w-3.5 h-3.5" />
                  </span>
                </button>

                <button
                  type="button"
                  aria-expanded={quickDrawerOpen}
                  aria-controls="laci-navigasi-cepat"
                  aria-label="Buka menu navigasi cepat"
                  onClick={() => setQuickDrawerOpen((v) => !v)}
                  style={{ backgroundColor: 'var(--sj-menu-sq)' }}
                  className="inline-flex h-[68px] w-[62px] sm:w-[68px] flex-col items-center justify-center text-white hover:brightness-110"
                >
                  <SvgGlyph name="menu" className="w-5 h-5" />
                  <span className="text-[10px] font-bold tracking-wide mt-0.5 sm:sr-only">Menu</span>
                </button>
              </div>
            </header>

            {quickDrawerOpen && (
              <nav
                id="laci-navigasi-cepat"
                aria-label="Menu cepat ponsel dan peran"
                style={{ backgroundColor: '#193226' }}
                className="border-y border-white/15 px-5 py-4 text-white"
              >
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="flex flex-wrap gap-2">
                    <a
                      href="#kalkulator-impas"
                      onClick={() => setQuickDrawerOpen(false)}
                      className="inline-flex min-h-[44px] items-center rounded-lg border border-white/25 px-3.5 text-sm font-bold text-white hover:bg-white/10"
                    >
                      Kalkulator Tahan vs Panjar
                    </a>
                    <a
                      href="#empat-peran"
                      onClick={() => setQuickDrawerOpen(false)}
                      className="inline-flex min-h-[44px] items-center rounded-lg border border-white/25 px-3.5 text-sm font-bold text-white hover:bg-white/10"
                    >
                      Alur 4 Peran Pascapanen
                    </a>
                    <button
                      type="button"
                      onClick={() => {
                        setQuickDrawerOpen(false);
                        setAuthModalOpen(true);
                      }}
                      style={{ backgroundColor: 'var(--sj-gold)', color: '#193226' }}
                      className="focus-dark inline-flex min-h-[44px] items-center rounded-lg px-4 text-sm font-black"
                    >
                      Pilih 5 Akun Demo / Daftar
                    </button>
                  </div>
                  <button
                    type="button"
                    onClick={() => setQuickDrawerOpen(false)}
                    className="inline-flex min-h-[44px] items-center gap-1.5 rounded-lg border border-white/25 px-3 text-xs font-bold text-white"
                  >
                    <SvgGlyph name="close" className="w-4 h-4" />
                    <span>Tutup (Esc)</span>
                  </button>
                </div>
              </nav>
            )}

            <div className="grid grid-cols-1 md:grid-cols-12 items-stretch">
              <div className="md:col-span-7 lg:col-span-7 flex flex-col justify-center px-5 py-7 sm:px-8 md:py-10 lg:px-14 lg:py-12">
                <p className="text-xs font-extrabold tracking-[0.08em] text-white">
                  {activeSlide.eyebrow}
                </p>
                <h1 className="mt-2 font-black tracking-tight text-white leading-[0.95] text-[clamp(2.6rem,6.5vw,4.85rem)]">
                  {activeSlide.headline}
                </h1>
                <p className="mt-4 max-w-xl text-[15px] sm:text-base leading-relaxed text-[#EAF4EC]">
                  {activeSlide.plain1}
                  <strong className="font-black text-white">{activeSlide.bold1}</strong>
                  {activeSlide.plain2}
                  <strong className="font-black text-white">{activeSlide.bold2}</strong>.
                </p>
                <div className="mt-7 flex flex-wrap items-center gap-3">
                  {activeSlide.ctaHref ? (
                    <SplitGoldCtaButton
                      label={activeSlide.ctaLabel}
                      href={activeSlide.ctaHref}
                      onClick={() => {
                        setSimKode(activeSlide.kode);
                        void runSimulation(activeSlide.kode, simQty, simKa, simUseSrg, simPanjarMode, simPanjar, simBorongan);
                      }}
                    />
                  ) : (
                    <SplitGoldCtaButton
                      label={activeSlide.ctaLabel}
                      onClick={() => setAuthModalOpen(true)}
                    />
                  )}
                  <button
                    type="button"
                    onClick={() => setAuthModalOpen(true)}
                    style={{ color: 'var(--sj-gold-text)' }}
                    className="inline-flex min-h-[46px] items-center rounded-lg px-4 text-sm font-extrabold hover:bg-white/10"
                  >
                    Coba Akun Demo
                  </button>
                </div>
              </div>

              <div className="md:col-span-5 lg:col-span-5 relative min-h-[290px] sm:min-h-[340px] lg:min-h-[430px] pt-3 pl-4 sm:pt-6 sm:pl-3">
                <div
                  style={{ backgroundColor: 'var(--sj-arch-sage)' }}
                  className="h-full w-full rounded-tl-[52px] lg:rounded-tl-[88px] flex items-end justify-center pr-12 sm:pr-14 pt-4 overflow-hidden"
                >
                  <img
                    src="/images/hero_harvest.jpg"
                    alt="Rumpun batang jagung emas dan malai padi gabah siap panen"
                    width={1024}
                    height={1024}
                    fetchPriority="high"
                    className="max-h-[270px] sm:max-h-[320px] lg:max-h-[396px] w-auto object-contain select-none"
                  />
                </div>

                <div
                  role="group"
                  aria-label="Pilih fokus komoditas panggung"
                  className="absolute right-2 sm:right-3.5 top-1/2 -translate-y-1/2 flex flex-col gap-1"
                >
                  {HERO_SLIDES.map((sl, idx) => {
                    const active = idx === heroSlide;
                    return (
                      <button
                        key={sl.headline}
                        type="button"
                        aria-pressed={active}
                        aria-label={`Tampilkan panggung ${sl.headline}`}
                        onClick={() => {
                          setHeroSlide(idx);
                          setSimKode(sl.kode);
                        }}
                        className="focus-dark inline-flex h-11 w-11 items-center justify-center rounded-full"
                      >
                        <span
                          className={`inline-flex items-center justify-center rounded-full transition-all ${
                            active
                              ? 'h-5 w-5 border-2 border-[#193226]'
                              : 'h-2.5 w-2.5 bg-[#193226]/70'
                          }`}
                        >
                          {active && <span className="h-2 w-2 rounded-full bg-[#193226]" />}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-12 items-stretch">
              <div
                style={{ backgroundColor: 'var(--sj-stage-left)' }}
                className="hidden md:flex md:col-span-1 items-center justify-center min-h-[104px]"
              >
                <a
                  href="#kalkulator-impas"
                  aria-label="Gulir ke kalkulator titik impas"
                  className="inline-flex h-12 w-12 items-center justify-center rounded-full text-white hover:bg-white/10"
                >
                  <SvgGlyph name="arrow-down" className="w-5 h-5" />
                </a>
              </div>

              <div
                style={{ backgroundColor: '#193226' }}
                className="md:col-span-8 lg:col-span-9 flex flex-col sm:flex-row items-stretch"
              >
                <div
                  style={{ backgroundColor: 'var(--sj-gold)' }}
                  className="hidden sm:block w-36 lg:w-48 shrink-0 rounded-tl-[36px] overflow-hidden"
                >
                  <img
                    src="/images/crop_cluster.jpg"
                    alt="Ikatan malai padi kering dan tongkol jagung pipil"
                    width={1024}
                    height={1024}
                    loading="lazy"
                    className="h-full w-full object-cover object-bottom"
                  />
                </div>

                <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-4 px-5 py-4 lg:px-8 items-center">
                  <div className="flex items-center gap-3.5">
                    <div
                      style={{ backgroundColor: 'var(--sj-gold)' }}
                      className="sm:hidden w-20 h-16 shrink-0 rounded-tl-[24px] rounded-md overflow-hidden"
                    >
                      <img
                        src="/images/crop_cluster.jpg"
                        alt="Hasil panen padi dan jagung kering"
                        width={1024}
                        height={1024}
                        loading="lazy"
                        className="h-full w-full object-cover object-bottom"
                      />
                    </div>
                    <div>
                      <div className="tabular-nums text-[13.5px] font-extrabold text-[#F3F7F0]">
                        Pendapatan terlindungi: {formatRp(impact.tambahanPendapatanRp)}
                      </div>
                      <p className="mt-0.5 text-xs text-[#C2D6C4]">
                        Data simulasi terukur sesudah susut kadar air &amp; bunga S-SRG 6%.
                      </p>
                    </div>
                  </div>

                  <div>
                    <div className="tabular-nums text-[13.5px] font-extrabold text-[#F3F7F0]">
                      Pasokan terserap: {formatKg(impact.stokTerserapKg)} (Susut dicegah {formatKg(impact.susutDicegahKg)})
                    </div>
                    <p className="mt-0.5 text-xs text-[#C2D6C4]">
                      {impactState === 'loading'
                        ? 'Memuat ringkasan simulasi...'
                        : offlineMode
                          ? 'Mode simulasi mandiri aktif tanpa hambatan.'
                          : 'Terhubung langsung ke Go Modular Monolith & PostgreSQL.'}
                    </p>
                  </div>
                </div>
              </div>

              <div
                style={{ backgroundColor: 'var(--sj-sage-panel)' }}
                className="md:col-span-3 lg:col-span-2 flex items-center justify-between md:justify-center gap-2 px-5 py-3"
              >
                <span className="text-xs font-extrabold text-[#193226] md:sr-only">
                  Alat bantu lapangan:
                </span>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() =>
                      speakId(
                        'Selamat datang di SimpanJual. Hitung titik impas simpan gudang S R G dibanding tawaran panjar tengkulak.'
                      )
                    }
                    aria-label="Bacakan pengantar suara Bahasa Indonesia"
                    className="focus-dark inline-flex h-11 w-11 items-center justify-center rounded-full border-[1.5px] border-[#193226] text-[#193226] hover:bg-[#193226]/10"
                  >
                    <SvgGlyph name="speaker" className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    aria-pressed={fieldMode}
                    onClick={() => setFieldMode((v) => !v)}
                    aria-label="Perbesar ukuran huruf Mode Lapangan Aa+"
                    className={`focus-dark inline-flex h-11 w-11 items-center justify-center rounded-full border-[1.5px] border-[#193226] text-[#193226] ${
                      fieldMode ? 'bg-white' : 'hover:bg-[#193226]/10'
                    }`}
                  >
                    <SvgGlyph name="text-size" className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setAuthModalOpen(true)}
                    aria-label="Buka jendela akun dan demo"
                    className="focus-dark inline-flex h-11 w-11 items-center justify-center rounded-full bg-white text-[#193226] hover:brightness-95"
                  >
                    <SvgGlyph name="arrow-right" className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          <main id="konten-utama" className="mx-auto w-full max-w-[1180px] flex-1 px-4 py-8 sm:px-6 lg:py-11 space-y-10">
            {notice && (
              <div
                role="status"
                className="sj-card-alt flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm font-semibold"
              >
                <span>{notice}</span>
                <button type="button" onClick={() => setNotice(null)} className="sj-btn-outline px-3 py-1 text-xs">
                  Tutup pesan
                </button>
              </div>
            )}

            <section id="kalkulator-impas" aria-labelledby="judul-kalkulator" className="sj-card p-5 sm:p-7">
              <div className="flex flex-wrap items-start justify-between gap-3 pb-5 border-b" style={{ borderColor: 'var(--sj-border-subtle)' }}>
                <div>
                  <h2 id="judul-kalkulator" className="text-xl font-black">
                    Kalkulator Cepat Tahan Gudang vs Panjar Tengkulak
                  </h2>
                  <p className="mt-1 text-sm" style={{ color: 'var(--sj-ink-muted)' }}>
                    Harga acuan pasar kering saat ini:{' '}
                    <strong className="tabular-nums font-extrabold">{formatRp(simResult.latestPrice)}/kg</strong>{' '}
                    (Data ilustrasi Jawa Tengah)
                  </p>
                </div>
                <StampBadge label="TANPA LOGIN" />
              </div>

              <div className="mt-6 grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
                <div className="lg:col-span-6 space-y-4">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label htmlFor="sim-komoditas" className="block text-xs font-extrabold mb-1.5">
                        Komoditas Panen
                      </label>
                      <select
                        id="sim-komoditas"
                        value={simKode}
                        onChange={(e) => setSimKode(e.target.value)}
                        className="sj-input"
                      >
                        <option value="jagung">Jagung Pipil (Ambang KA 15%)</option>
                        <option value="gabah">Gabah GKG (Ambang KA 14%)</option>
                      </select>
                    </div>

                    <div>
                      <label htmlFor="sim-qty" className="block text-xs font-extrabold mb-1.5">
                        Volume Panen (kg)
                      </label>
                      <input
                        id="sim-qty"
                        type="number"
                        min={100}
                        max={100000}
                        step={100}
                        value={simQty}
                        onChange={(e) => setSimQty(Number(e.target.value))}
                        placeholder="Contoh: 5000"
                        className="sj-input tabular-nums"
                      />
                    </div>

                    <div>
                      <label htmlFor="sim-ka" className="block text-xs font-extrabold mb-1.5">
                        Kadar Air Aktual Saat Panen (%)
                      </label>
                      <input
                        id="sim-ka"
                        type="number"
                        min={10}
                        max={35}
                        step={0.5}
                        value={simKa}
                        onChange={(e) => setSimKa(Number(e.target.value))}
                        placeholder="Contoh: 18"
                        className="sj-input tabular-nums"
                      />
                    </div>

                    <div>
                      <span className="block text-xs font-extrabold mb-1.5">Bentuk Tawaran Tengkulak</span>
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          type="button"
                          aria-pressed={simPanjarMode === 'per_kg'}
                          onClick={() => setSimPanjarMode('per_kg')}
                          className={simPanjarMode === 'per_kg' ? 'sj-btn-primary text-xs px-2' : 'sj-btn-outline text-xs px-2'}
                        >
                          Per Kg
                        </button>
                        <button
                          type="button"
                          aria-pressed={simPanjarMode === 'borongan'}
                          onClick={() => setSimPanjarMode('borongan')}
                          className={simPanjarMode === 'borongan' ? 'sj-btn-primary text-xs px-2' : 'sj-btn-outline text-xs px-2'}
                        >
                          Tebasan Total
                        </button>
                      </div>
                    </div>
                  </div>

                  {simPanjarMode === 'per_kg' ? (
                    <div>
                      <label htmlFor="sim-panjar" className="block text-xs font-extrabold mb-1.5">
                        Harga Tawaran Panjar (Rp/kg)
                      </label>
                      <input
                        id="sim-panjar"
                        type="number"
                        min={500}
                        max={30000}
                        step={50}
                        value={simPanjar}
                        onChange={(e) => setSimPanjar(Number(e.target.value))}
                        placeholder="Contoh: 3800"
                        className="sj-input tabular-nums"
                      />
                    </div>
                  ) : (
                    <div>
                      <label htmlFor="sim-borongan" className="block text-xs font-extrabold mb-1.5">
                        Total Uang Tebasan Borongan (Rp)
                      </label>
                      <input
                        id="sim-borongan"
                        type="number"
                        min={100000}
                        max={2000000000}
                        step={500000}
                        value={simBorongan}
                        onChange={(e) => setSimBorongan(Number(e.target.value))}
                        placeholder="Contoh: 19000000"
                        className="sj-input tabular-nums"
                      />
                    </div>
                  )}

                  <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
                    <label htmlFor="sim-srg" className="inline-flex min-h-[44px] items-center gap-2.5 text-sm font-semibold">
                      <input
                        id="sim-srg"
                        type="checkbox"
                        checked={simUseSrg}
                        onChange={(e) => setSimUseSrg(e.target.checked)}
                        className="h-5 w-5 rounded accent-[#183D31]"
                      />
                      <span>Gunakan talangan subsidi S-SRG (bunga 6%/thn, plafon 70%)</span>
                    </label>

                    <button
                      type="button"
                      onClick={() =>
                        void runSimulation(simKode, simQty, simKa, simUseSrg, simPanjarMode, simPanjar, simBorongan)
                      }
                      className="sj-btn-primary"
                    >
                      Hitung Ulang Keputusan
                    </button>
                  </div>

                  <form
                    onSubmit={handleExtractWa}
                    className="pt-4 border-t space-y-2"
                    style={{ borderColor: 'var(--sj-border-subtle)' }}
                  >
                    <label htmlFor="wa-extract" className="block text-xs font-extrabold">
                      Punya pesan WhatsApp dari tengkulak? Tempel untuk membaca angkanya otomatis
                    </label>
                    <div className="flex flex-col sm:flex-row gap-2">
                      <input
                        id="wa-extract"
                        type="text"
                        value={waText}
                        onChange={(e) => setWaText(e.target.value)}
                        placeholder='Contoh: "Pak, jagung saya ambil tebas Rp19 juta atau Rp3.900/kg"'
                        className="sj-input flex-1"
                      />
                      <button type="submit" className="sj-btn-outline shrink-0">
                        Baca Pesan WA
                      </button>
                    </div>
                    {waFeedback && (
                      <p role="status" className="text-xs font-bold" style={{ color: 'var(--sj-ink-muted)' }}>
                        {waFeedback}
                      </p>
                    )}
                  </form>
                </div>

                <div className="lg:col-span-6 sj-card-alt p-5">
                  <div className="flex flex-wrap items-center justify-between gap-2 pb-3 border-b" style={{ borderColor: 'var(--sj-border-subtle)' }}>
                    <span className="text-xs font-extrabold tracking-wide" style={{ color: 'var(--sj-ink-muted)' }}>
                      REKAP HITUNGAN BERSIH
                    </span>
                    <StampBadge
                      label={
                        simResult.decision.recommendation === 'JUAL'
                          ? 'JUAL SEKARANG'
                          : `${simResult.decision.recommendation.replace('_', ' ')} ${simResult.decision.bestHorizonWeeks} MINGGU`
                      }
                      tone={
                        simResult.decision.recommendation === 'TAHAN'
                          ? 'ok'
                          : simResult.decision.recommendation === 'TAHAN_BERISIKO'
                            ? 'warn'
                            : 'danger'
                      }
                    />
                  </div>

                  <div className="mt-3 divide-y" style={{ borderColor: 'var(--sj-border-subtle)' }}>
                    <LedgerRow
                      label="Hasil jual langsung hari ini"
                      value={formatRp(simResult.decision.pendapatanJualSegera)}
                    />
                    {simResult.decision.perluPengeringan && (
                      <LedgerRow
                        label="Bobot kering siap simpan gudang"
                        value={`${formatKg(simResult.decision.qtySiap)} (-${formatKg(simResult.decision.susutPengeringanKg)})`}
                      />
                    )}
                    <LedgerRow
                      label="Total ongkos jemur, sewa, angkut, & bunga"
                      value={formatRp(simResult.decision.best.totalBiayaSimpan)}
                    />
                    <LedgerRow
                      label="Titik impas harga simpan"
                      value={`${formatRp(simResult.decision.best.titikImpasPerKg)}/kg`}
                      emphasize
                    />
                    <LedgerRow
                      label="Selisih bersih tahan vs jual segera"
                      value={`${formatRp(simResult.decision.best.selisihRp, true)} (${simResult.decision.best.selisihPct}%)`}
                      emphasize
                      tone={simResult.decision.best.selisihRp >= 0 ? 'ok' : 'danger'}
                    />
                    {simResult.panjar && (
                      <>
                        <LedgerRow
                          label="Tunai hari ini: Panjar vs Plafon S-SRG 70%"
                          value={`${formatRp(simResult.panjar.tunaiHariIniPanjarRp)} vs ${formatRp(simResult.panjar.tunaiHariIniSrgRp)}`}
                        />
                        <LedgerRow
                          label="Selisih hasil akhir diselamatkan dibanding panjar"
                          value={formatRp(simResult.panjar.selisihTerhadapTahanRp, true)}
                          emphasize
                          tone={simResult.panjar.selisihTerhadapTahanRp >= 0 ? 'ok' : 'danger'}
                        />
                      </>
                    )}
                  </div>

                  <p className="mt-3 text-xs leading-relaxed font-medium" style={{ color: 'var(--sj-ink-muted)' }}>
                    {simResult.decision.summarySentence}
                  </p>

                  <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
                    <button
                      type="button"
                      onClick={() => speakId(simResult.decision.summarySentence)}
                      className="sj-btn-outline"
                    >
                      <SvgGlyph name="speaker" className="w-4 h-4" />
                      <span>Bacakan Hasil</span>
                    </button>
                    <SplitGoldCtaButton
                      label="Lanjut ke Gudang & Pembeli"
                      onClick={() => setAuthModalOpen(true)}
                    />
                  </div>
                </div>
              </div>
            </section>

            <section id="empat-peran" aria-labelledby="judul-peran" className="space-y-4">
              <h2 id="judul-peran" className="text-xl font-black">
                Alur Terpadu Empat Peran Pascapanen
              </h2>

              <div
                style={{ backgroundColor: 'var(--sj-frame)', borderColor: 'var(--sj-gold)' }}
                className="rounded-tl-[28px] rounded-tr-lg rounded-br-xl rounded-bl-lg border-[1.5px] p-6 text-white"
              >
                <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-5">
                  <div className="max-w-2xl">
                    <span className="text-xs font-extrabold tracking-wide" style={{ color: 'var(--sj-gold-text)' }}>
                      01 · PELAKU UTAMA LAPANGAN
                    </span>
                    <h3 className="mt-1 text-xl font-black text-white">Petani Padi &amp; Jagung</h3>
                    <p className="mt-1.5 text-sm leading-relaxed text-[#F3F7F0]">
                      Mencatat berat serta kadar air hasil panen, mengadu tawaran panjar tengkulak dengan talangan S-SRG
                      6%, lalu mengajukan sewa gudang atau menawarkan stok ke pembeli siaga tanpa kehilangan hak milik.
                    </p>
                  </div>
                  <div className="shrink-0">
                    <SplitGoldCtaButton
                      label="Masuk sebagai Pak Slamet"
                      onClick={() => void handleDemoLogin('petani')}
                    />
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {[
                  {
                    no: 'Peran 02',
                    preset: 'poktan',
                    title: 'Kelompok Tani (Lot Kolektif)',
                    desc: 'Menggabungkan panen kecil 1 sampai 3 ton lewat kode TANIJAYA agar memenuhi syarat minimum 5 sampai 10 ton gudang SRG.',
                    btn: 'Coba Akun Ketua Poktan',
                  },
                  {
                    no: 'Peran 03',
                    preset: 'gudang',
                    title: 'Pengelola Gudang Daerah',
                    desc: 'Menayangkan kapasitas kosong dan 6 ceklis kelayakan fisik gudang, lalu menyetujui sewa secara atomik bebas bentrok kuota.',
                    btn: 'Coba Akun Gudang SRG',
                  },
                  {
                    no: 'Peran 04',
                    preset: 'pembeli',
                    title: 'Pembeli Siaga (Koperasi & SPPG)',
                    desc: 'Menerbitkan kontrak kebutuhan pasokan Janji Beli beserta harga acuan dan batas kadar air agar petani punya pembeli pasti.',
                    btn: 'Coba Akun Pembeli Siaga',
                  },
                ].map((roleCard) => (
                  <article key={roleCard.preset} className="sj-card p-5 flex flex-col justify-between">
                    <div>
                      <span
                        style={{ backgroundColor: 'var(--sj-surface-alt)', borderColor: 'var(--sj-border)' }}
                        className="tabular-nums inline-block rounded border px-2.5 py-1 text-xs font-extrabold"
                      >
                        {roleCard.no}
                      </span>
                      <h3 className="mt-3 text-base font-extrabold">{roleCard.title}</h3>
                      <p className="mt-1.5 text-sm leading-relaxed" style={{ color: 'var(--sj-ink-muted)' }}>
                        {roleCard.desc}
                      </p>
                    </div>
                    <div className="mt-4 pt-3 border-t" style={{ borderColor: 'var(--sj-border-subtle)' }}>
                      <button
                        type="button"
                        onClick={() => void handleDemoLogin(roleCard.preset)}
                        className="sj-btn-outline w-full"
                      >
                        <span>{roleCard.btn}</span>
                        <SvgGlyph name="arrow-right" className="w-4 h-4" />
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          </main>

          <footer
            style={{ backgroundColor: 'var(--sj-frame)' }}
            className="mt-6 border-t border-white/15 px-4 py-6 text-[#F3F7F0]"
          >
            <div className="mx-auto max-w-[1180px] flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
              <div className="flex items-center gap-4">
                <BarnScaleLogo lightOnDark compact />
                <p className="text-xs text-[#C2D6C4]">
                  {offlineMode
                    ? 'Berjalan dalam Mode Simulasi Mandiri (Mesin Hitung Web Aktif).'
                    : 'Terhubung ke Go Modular Monolith & PostgreSQL.'}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-3 text-xs font-bold">
                <a href="#panggung" className="min-h-[44px] inline-flex items-center px-2 text-white hover:underline">
                  Panggung Utama
                </a>
                <a
                  href="#kalkulator-impas"
                  className="min-h-[44px] inline-flex items-center px-2 text-white hover:underline"
                >
                  Kalkulator Impas
                </a>
                <button
                  type="button"
                  onClick={() => void handleDemoLogin('admin')}
                  className="min-h-[44px] inline-flex items-center rounded-lg border border-white/25 px-3 text-white hover:bg-white/10"
                >
                  Panel Admin Komoditas
                </button>
              </div>
            </div>
          </footer>
        </>
      ) : (
        <div className="flex min-h-dvh flex-col">
          <header
            style={{ backgroundColor: 'var(--sj-frame)' }}
            className="sticky top-0 z-30 border-b border-white/15 px-4 py-2.5 text-white"
          >
            <div className="mx-auto max-w-[1360px] flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <BarnScaleLogo lightOnDark compact />
                <span
                  style={{ backgroundColor: 'var(--sj-menu-sq)', color: 'var(--sj-gold-text)' }}
                  className="hidden sm:inline-block rounded px-2.5 py-1 text-xs font-extrabold"
                >
                  {user.nama} · {user.kabupaten}
                </span>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  aria-pressed={fieldMode}
                  onClick={() => setFieldMode((v) => !v)}
                  className="inline-flex min-h-[44px] items-center gap-1.5 rounded-lg border border-white/25 px-3 text-xs font-bold text-white hover:bg-white/10"
                >
                  <SvgGlyph name="text-size" className="w-4 h-4" />
                  <span className="hidden sm:inline">Aa+</span>
                </button>

                <button
                  type="button"
                  aria-pressed={darkMode}
                  onClick={() => setDarkMode((v) => !v)}
                  aria-label={darkMode ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Rimbun Gelap'}
                  className="inline-flex h-11 w-11 items-center justify-center rounded-lg border border-white/25 text-white hover:bg-white/10"
                >
                  <SvgGlyph name={darkMode ? 'sun' : 'moon'} className="w-4 h-4" />
                </button>

                <button
                  type="button"
                  onClick={() => {
                    resetBackendCircuit();
                    void loadWorkspace(user);
                  }}
                  aria-label="Muat ulang data ruang kerja"
                  className="inline-flex h-11 w-11 items-center justify-center rounded-lg border border-white/25 text-white hover:bg-white/10"
                >
                  <SvgGlyph name="refresh" className="w-4 h-4" />
                </button>

                <button
                  type="button"
                  onClick={() => setAuthModalOpen(true)}
                  style={{ backgroundColor: 'var(--sj-gold)', color: '#193226' }}
                  className="focus-dark inline-flex min-h-[44px] items-center rounded-lg px-3 text-xs font-black"
                >
                  Ganti Akun
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setStoredToken(null);
                    setUser(null);
                  }}
                  className="inline-flex min-h-[44px] items-center rounded-lg border border-white/25 px-3 text-xs font-bold text-white hover:bg-white/10"
                >
                  Keluar
                </button>
              </div>
            </div>
          </header>

          <div className="mx-auto flex w-full max-w-[1360px] flex-1">
            {user.role === 'petani' && (
              <aside
                aria-label="Menu kerja petani desktop"
                style={{ borderColor: 'var(--sj-border-subtle)', backgroundColor: 'var(--sj-surface)' }}
                className={`hidden lg:flex flex-col border-r p-3 transition-all ${
                  sidebarExpanded ? 'w-64' : 'w-20'
                }`}
              >
                <div className="flex items-center justify-between px-2 py-2">
                  {sidebarExpanded && (
                    <span className="text-xs font-extrabold uppercase tracking-wide" style={{ color: 'var(--sj-ink-muted)' }}>
                      Menu Petani
                    </span>
                  )}
                  <button
                    type="button"
                    aria-expanded={sidebarExpanded}
                    aria-label={sidebarExpanded ? 'Ciutkan bilah samping' : 'Bentangkan bilah samping'}
                    onClick={() => setSidebarExpanded((v) => !v)}
                    className="sj-btn-outline px-2.5 py-2"
                  >
                    <SvgGlyph name="collapse" className="w-4 h-4" />
                  </button>
                </div>

                <nav aria-label="Tahapan keputusan petani" className="mt-2 space-y-1.5">
                  {[
                    { id: 'stok' as const, label: 'Stok & Hitung Impas', icon: 'grain' as const },
                    { id: 'gudang' as const, label: 'Gudang & Lot Poktan', icon: 'barn' as const },
                    { id: 'pasar' as const, label: 'Janji Beli & Tawaran', icon: 'handshake' as const },
                  ].map((item) => {
                    const active = petaniTab === item.id;
                    return (
                      <button
                        key={item.id}
                        type="button"
                        aria-current={active ? 'page' : undefined}
                        aria-label={item.label}
                        title={item.label}
                        onClick={() => setPetaniTab(item.id)}
                        style={{
                          backgroundColor: active ? 'var(--sj-surface-alt)' : 'transparent',
                          borderLeft: active ? '4px solid var(--sj-gold)' : '4px solid transparent',
                        }}
                        className={`flex min-h-[48px] w-full items-center gap-3 rounded-lg px-3 text-left text-sm ${
                          active ? 'font-black' : 'font-semibold'
                        }`}
                      >
                        <SvgGlyph name={item.icon} className="w-5 h-5 shrink-0" />
                        {sidebarExpanded && <span>{item.label}</span>}
                      </button>
                    );
                  })}
                </nav>
              </aside>
            )}

            <main id="konten-utama" className="flex-1 px-4 py-6 pb-28 sm:px-6 lg:pb-10 space-y-6 min-w-0">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h1 className="text-2xl font-black">
                    {user.role === 'petani'
                      ? `Ruang Keputusan Pascapanen: ${user.nama}`
                      : user.role === 'gudang'
                        ? `Ruang Pengelola Gudang: ${user.nama}`
                        : user.role === 'pembeli'
                          ? `Ruang Pembeli Siaga: ${user.nama}`
                          : 'Panel Observabilitas & Standar Komoditas'}
                  </h1>
                  <p className="text-xs mt-0.5" style={{ color: 'var(--sj-ink-muted)' }}>
                    Wilayah {user.kabupaten} ·{' '}
                    {offlineMode ? 'Mode Simulasi Mandiri' : 'Terhubung ke API Go Modular Monolith'}
                  </p>
                </div>
                <StampBadge label={user.role.toUpperCase()} tone="ok" />
              </div>

              {user.role === 'petani' && (
                <nav
                  aria-label="Menu tahapan petani tablet"
                  className="hidden sm:flex lg:hidden flex-wrap gap-2"
                >
                  {[
                    { id: 'stok' as const, label: '1. Stok & Hitung Impas' },
                    { id: 'gudang' as const, label: '2. Gudang & Lot Poktan' },
                    { id: 'pasar' as const, label: '3. Janji Beli & Tawaran' },
                  ].map((tb) => (
                    <button
                      key={tb.id}
                      type="button"
                      onClick={() => setPetaniTab(tb.id)}
                      className={petaniTab === tb.id ? 'sj-btn-primary' : 'sj-btn-outline'}
                    >
                      {tb.label}
                    </button>
                  ))}
                </nav>
              )}

              {notice && (
                <div
                  role="status"
                  className="sj-card-alt flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm font-semibold"
                >
                  <span>{notice}</span>
                  <button type="button" onClick={() => setNotice(null)} className="sj-btn-outline px-3 py-1 text-xs">
                    Tutup
                  </button>
                </div>
              )}

              {dashState === 'loading' ? (
                <StatePanel
                  kind="loading"
                  title="Memuat data ruang kerja"
                  message="Sedang menyinkronkan catatan stok, kapasitas gudang, dan kuota pembeli siaga."
                />
              ) : dashState === 'error' ? (
                <StatePanel
                  kind="error"
                  title="Gagal terhubung ke server"
                  message={dashError || 'Periksa apakah server Go berjalan di port 8080, atau lanjutkan lewat Mode Simulasi Mandiri.'}
                  actionLabel="Gunakan Mode Simulasi Mandiri"
                  onAction={() => {
                    setOfflineMode(true);
                    void loadWorkspace(user);
                  }}
                />
              ) : user.role === 'petani' ? (
                petaniTab === 'stok' ? (
                  <div className="space-y-6">
                    <section aria-labelledby="judul-tambah-stok" className="sj-card p-5">
                      <h2 id="judul-tambah-stok" className="text-lg font-extrabold">
                        Catat Stok Panen Baru
                      </h2>
                      <form onSubmit={handleAddStock} className="mt-3 grid grid-cols-1 sm:grid-cols-4 gap-3 items-end">
                        <div>
                          <label htmlFor="st-kode" className="block text-xs font-bold mb-1">
                            Komoditas
                          </label>
                          <select
                            id="st-kode"
                            value={newStockKode}
                            onChange={(e) => setNewStockKode(e.target.value)}
                            className="sj-input"
                          >
                            <option value="jagung">Jagung Pipil</option>
                            <option value="gabah">Gabah GKG</option>
                          </select>
                        </div>
                        <div>
                          <label htmlFor="st-qty" className="block text-xs font-bold mb-1">
                            Berat Panen (kg)
                          </label>
                          <input
                            id="st-qty"
                            type="number"
                            value={newStockQty}
                            onChange={(e) => setNewStockQty(e.target.value)}
                            placeholder="Contoh: 3500"
                            className="sj-input tabular-nums"
                          />
                        </div>
                        <div>
                          <label htmlFor="st-ka" className="block text-xs font-bold mb-1">
                            Kadar Air (%)
                          </label>
                          <input
                            id="st-ka"
                            type="number"
                            step="0.5"
                            value={newStockKa}
                            onChange={(e) => setNewStockKa(e.target.value)}
                            placeholder="Contoh: 16.5"
                            className="sj-input tabular-nums"
                          />
                        </div>
                        <button type="submit" className="sj-btn-primary">
                          Simpan Catatan Stok
                        </button>
                      </form>
                    </section>

                    <section aria-labelledby="judul-daftar-stok" className="space-y-3">
                      <h2 id="judul-daftar-stok" className="text-lg font-extrabold">
                        Daftar Stok &amp; Evaluasi Titik Impas
                      </h2>
                      {stocks.length === 0 ? (
                        <StatePanel
                          kind="empty"
                          title="Belum ada stok tercatat"
                          message="Isi formulir Catat Stok Panen Baru di atas agar mesin dapat menghitung rekomendasi tahan atau jual."
                        />
                      ) : (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                          {stocks.map((st) => (
                            <article key={st.id} className="sj-card p-5 flex flex-col justify-between">
                              <div>
                                <div className="flex items-start justify-between gap-2">
                                  <h3 className="text-base font-extrabold">{st.commodityNama}</h3>
                                  <StampBadge label={st.status.toUpperCase()} tone="ok" />
                                </div>
                                <p className="mt-2 tabular-nums text-sm" style={{ color: 'var(--sj-ink-muted)' }}>
                                  Total <strong>{formatKg(st.qtyKg)}</strong> · Bebas dialokasikan{' '}
                                  <strong>{formatKg(st.freeKg)}</strong> · Kadar air <strong>{st.kadarAir}%</strong>
                                </p>
                              </div>
                              <div className="mt-4">
                                <button
                                  type="button"
                                  onClick={() => void inspectStock(st)}
                                  className="sj-btn-primary w-full"
                                >
                                  Lihat Hitungan &amp; Grafik Impas
                                </button>
                              </div>
                            </article>
                          ))}
                        </div>
                      )}

                      {selectedAnalysis && (
                        <div className="sj-card-alt p-5 space-y-4">
                          <div className="flex flex-wrap items-center justify-between gap-2">
                            <h3 className="text-base font-black">
                              Rekomendasi {selectedAnalysis.stock.commodityNama}:{' '}
                              {selectedAnalysis.decision.recommendation.replace('_', ' ')} (
                              {selectedAnalysis.decision.bestHorizonWeeks} Minggu)
                            </h3>
                            <div className="flex flex-wrap gap-2">
                              <button
                                type="button"
                                disabled={explainBusy}
                                onClick={() => void requestAiExplanation()}
                                className="sj-btn-primary text-xs"
                              >
                                {explainBusy ? 'Menyiapkan...' : 'Jelaskan dengan Bahasa Sederhana'}
                              </button>
                              <button
                                type="button"
                                onClick={() => speakId(selectedAnalysis.decision.summarySentence)}
                                className="sj-btn-outline text-xs"
                              >
                                <SvgGlyph name="speaker" className="w-4 h-4" />
                                <span>Bacakan Suara</span>
                              </button>
                            </div>
                          </div>

                          <p className="text-sm font-medium">{selectedAnalysis.decision.summarySentence}</p>

                          <div className="divide-y" style={{ borderColor: 'var(--sj-border-subtle)' }}>
                            <LedgerRow
                              label="Bobot siap simpan gudang"
                              value={formatKg(selectedAnalysis.decision.qtySiap)}
                            />
                            <LedgerRow
                              label="Titik impas simpan"
                              value={`${formatRp(selectedAnalysis.decision.best.titikImpasPerKg)}/kg`}
                              emphasize
                            />
                            <LedgerRow
                              label="Selisih bersih vs jual sekarang"
                              value={formatRp(selectedAnalysis.decision.best.selisihRp, true)}
                              emphasize
                              tone={selectedAnalysis.decision.best.selisihRp >= 0 ? 'ok' : 'danger'}
                            />
                            {selectedAnalysis.panjar && (
                              <LedgerRow
                                label="Selisih diselamatkan dibanding panjar"
                                value={formatRp(selectedAnalysis.panjar.selisihTerhadapTahanRp, true)}
                                emphasize
                                tone={selectedAnalysis.panjar.selisihTerhadapTahanRp >= 0 ? 'ok' : 'danger'}
                              />
                            )}
                          </div>

                          <div className="text-xs font-bold" style={{ color: 'var(--sj-ink-muted)' }}>
                            Status mutu: {selectedAnalysis.readiness?.status || 'LAYAK'}
                            {selectedAnalysis.readiness?.actions?.[0] ? ` · ${selectedAnalysis.readiness.actions[0]}` : ''}
                          </div>

                          {aiExplain && (
                            <div className="sj-card p-4 space-y-2">
                              <div className="flex items-center justify-between gap-2">
                                <strong className="text-sm font-extrabold">Penjelasan Bahasa Petani (F14)</strong>
                                <button
                                  type="button"
                                  onClick={() => speakId(`${aiExplain.ringkasan} ${aiExplain.alasan.join(' ')}`)}
                                  className="sj-btn-outline px-3 py-1 text-xs min-h-[44px]"
                                >
                                  Bacakan Penjelasan
                                </button>
                              </div>
                              <p className="text-sm font-semibold">{aiExplain.ringkasan}</p>
                              <ul className="list-disc pl-5 text-xs space-y-1" style={{ color: 'var(--sj-ink-muted)' }}>
                                {aiExplain.alasan.map((a, idx) => (
                                  <li key={idx}>{a}</li>
                                ))}
                                {aiExplain.langkah_berikut.map((l, idx) => (
                                  <li key={`step-${idx}`}>{l}</li>
                                ))}
                              </ul>
                              {aiExplain.peringatan && (
                                <p className="text-xs font-bold" style={{ color: 'var(--sj-warn-ink)' }}>
                                  Catatan: {aiExplain.peringatan}
                                </p>
                              )}
                            </div>
                          )}

                          <details className="sj-card p-4">
                            <summary className="text-sm font-extrabold">
                              Ubah Asumsi Biaya, Bunga (S-SRG 6% / Komersial 12%), &amp; Panjar (F4/F5)
                            </summary>
                            <form onSubmit={applyCustomAssumptions} className="mt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 items-end">
                              <div>
                                <label htmlFor="as-sewa" className="block text-xs font-bold mb-1">
                                  Tarif Sewa (Rp/kg/hari)
                                </label>
                                <input
                                  id="as-sewa"
                                  type="number"
                                  step="0.5"
                                  value={customRentRate}
                                  onChange={(e) => setCustomRentRate(e.target.value)}
                                  className="sj-input tabular-nums"
                                />
                              </div>
                              <div>
                                <label htmlFor="as-angkut" className="block text-xs font-bold mb-1">
                                  Ongkos Angkut (Rp/kg)
                                </label>
                                <input
                                  id="as-angkut"
                                  type="number"
                                  step="5"
                                  value={customTransportRate}
                                  onChange={(e) => setCustomTransportRate(e.target.value)}
                                  className="sj-input tabular-nums"
                                />
                              </div>
                              <div>
                                <label htmlFor="as-bunga" className="block text-xs font-bold mb-1">
                                  Skema Pembiayaan
                                </label>
                                <select
                                  id="as-bunga"
                                  value={customBungaRate}
                                  onChange={(e) => setCustomBungaRate(e.target.value)}
                                  className="sj-input"
                                >
                                  <option value="0.06">Subsidi S-SRG (6% / tahun)</option>
                                  <option value="0.12">Komersial (12% / tahun)</option>
                                </select>
                              </div>
                              <div>
                                <label htmlFor="as-pmode" className="block text-xs font-bold mb-1">
                                  Mode Panjar Tandingan
                                </label>
                                <select
                                  id="as-pmode"
                                  value={customPanjarMode}
                                  onChange={(e) => setCustomPanjarMode(e.target.value as 'per_kg' | 'borongan')}
                                  className="sj-input"
                                >
                                  <option value="per_kg">Harga per Kg (Rp/kg)</option>
                                  <option value="borongan">Tebasan Borongan Total (Rp)</option>
                                </select>
                              </div>
                              <div>
                                <label htmlFor="as-pval" className="block text-xs font-bold mb-1">
                                  {customPanjarMode === 'borongan' ? 'Nilai Tebasan (Rp)' : 'Harga Panjar (Rp/kg)'}
                                </label>
                                <input
                                  id="as-pval"
                                  type="number"
                                  value={customPanjarVal}
                                  onChange={(e) => setCustomPanjarVal(e.target.value)}
                                  className="sj-input tabular-nums"
                                />
                              </div>
                              <button type="submit" className="sj-btn-primary">
                                Terapkan Asumsi
                              </button>
                            </form>
                          </details>

                          {selectedAnalysis.forecast && (
                            <ForecastBreakEvenChart
                              latestPrice={selectedAnalysis.latestPrice}
                              breakEvenPerKg={selectedAnalysis.decision.best.titikImpasPerKg}
                              predictions={selectedAnalysis.forecast.predictions}
                            />
                          )}
                        </div>
                      )}
                    </section>
                  </div>
                ) : petaniTab === 'gudang' ? (
                  <div className="space-y-6">
                    {warehouses.length > 0 && (
                      <WarehouseMapPanel
                        farmerKabupaten={user.kabupaten}
                        warehouses={warehouses}
                        selectedId={selectedWhId}
                        onSelect={(w) => setSelectedWhId(w.id)}
                      />
                    )}

                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                      <section aria-labelledby="judul-gudang-skor" className="space-y-3">
                        <h2 id="judul-gudang-skor" className="text-lg font-extrabold">
                          Gudang Terdekat &amp; Skor Kelayakan Fisik
                        </h2>
                        {warehouses.length === 0 ? (
                          <StatePanel
                            kind="empty"
                            title="Belum ada gudang terdaftar di wilayah ini"
                            message="Perluas wilayah pencarian atau gabungkan stok melalui Lot Kolektif Poktan."
                          />
                        ) : (
                          warehouses.map((w) => {
                            const selected = w.id === selectedWhId;
                            return (
                              <article
                                key={w.id}
                                style={selected ? { borderColor: 'var(--sj-gold)', borderWidth: '2px' } : undefined}
                                className="sj-card p-5 space-y-2"
                              >
                                <div className="flex items-start justify-between gap-2">
                                  <h3 className="text-base font-extrabold">{w.nama}</h3>
                                  <StampBadge label={`SKOR ${w.score.totalScore}/100`} tone="ok" />
                                </div>
                                <p className="tabular-nums text-xs font-semibold" style={{ color: 'var(--sj-ink-muted)' }}>
                                  {w.kabupaten} (~{w.score.distanceKm} km) · Kosong {formatKg(w.tersediaKg)} · Tarif Rp
                                  {w.tarifPerKgHari}/kg/hari · Min {formatKg(w.minVolumeKg)}
                                </p>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    const st = stocks.find((s) => s.freeKg >= w.minVolumeKg) || stocks[0];
                                    if (!st) {
                                      setNotice('Tambahkan stok panen terlebih dahulu di tab Stok.');
                                      return;
                                    }
                                    if (!offlineMode) {
                                      try {
                                        await apiFetch('/api/v1/rentals', {
                                          method: 'POST',
                                          idempotent: true,
                                          body: JSON.stringify({
                                            stockId: st.id,
                                            warehouseId: w.id,
                                            qtyKg: Math.min(st.freeKg, w.minVolumeKg),
                                            hari: w.minHari,
                                          }),
                                        });
                                        setNotice(`Permintaan sewa ke ${w.nama} terkirim.`);
                                        await loadWorkspace(user);
                                        return;
                                      } catch (err: any) {
                                        setNotice(err?.message || 'Permintaan dicatat pada sesi simulasi.');
                                      }
                                    }
                                    setRentals((prev) => [
                                      {
                                        id: `rn-${Date.now()}`,
                                        requesterNama: user.nama,
                                        warehouseNama: w.nama,
                                        qtyKg: w.minVolumeKg,
                                        hari: w.minHari,
                                        kontakWa: w.kontakWa,
                                        status: 'diajukan',
                                      },
                                      ...prev,
                                    ]);
                                    setNotice(`Permintaan sewa ${formatKg(w.minVolumeKg)} ke ${w.nama} diajukan.`);
                                  }}
                                  className="sj-btn-primary mt-2"
                                >
                                  Ajukan Sewa Gudang ({formatKg(w.minVolumeKg)})
                                </button>
                              </article>
                            );
                          })
                        )}
                      </section>

                      <section aria-labelledby="judul-lot-poktan" className="space-y-3">
                        <h2 id="judul-lot-poktan" className="text-lg font-extrabold">
                          Lot Kolektif Kelompok Tani
                        </h2>
                        <form
                          onSubmit={async (e) => {
                            e.preventDefault();
                            if (!joinCode.trim()) {
                              setNotice('Masukkan kode gabung kelompok tani, misalnya TANIJAYA.');
                              return;
                            }
                            if (!offlineMode) {
                              try {
                                await apiFetch('/api/v1/groups/join', {
                                  method: 'POST',
                                  body: JSON.stringify({ kodeGabung: joinCode.trim().toUpperCase() }),
                                });
                                setNotice(`Berhasil bergabung ke kode poktan ${joinCode.toUpperCase()}.`);
                                await loadWorkspace(user);
                                return;
                              } catch (err: any) {
                                setNotice(err?.message || 'Kode poktan diverifikasi pada mode simulasi.');
                              }
                            }
                            setNotice(`Terhubung ke kelompok tani dengan kode ${joinCode.toUpperCase()}.`);
                          }}
                          className="sj-card p-4 flex flex-col sm:flex-row gap-2 items-end"
                        >
                          <div className="w-full flex-1">
                            <label htmlFor="kode-poktan" className="block text-xs font-bold mb-1">
                              Kode Gabung Poktan
                            </label>
                            <input
                              id="kode-poktan"
                              type="text"
                              value={joinCode}
                              onChange={(e) => setJoinCode(e.target.value)}
                              placeholder="Contoh: TANIJAYA"
                              className="sj-input"
                            />
                          </div>
                          <button type="submit" className="sj-btn-outline shrink-0">
                            Gabung Poktan
                          </button>
                        </form>

                        {lots.map((lt) => (
                          <article key={lt.id} className="sj-card p-5 space-y-2">
                            <div className="flex items-center justify-between gap-2">
                              <h3 className="text-base font-extrabold">
                                {lt.groupNama} · {lt.commodityNama}
                              </h3>
                              <StampBadge label={`KODE ${lt.kodeGabung}`} />
                            </div>
                            <p className="tabular-nums text-xs font-bold" style={{ color: 'var(--sj-ink-muted)' }}>
                              Terkumpul {formatKg(lt.terkumpulKg)} dari target {formatKg(lt.targetKg)} ({lt.progressPct}%)
                            </p>
                            <button
                              type="button"
                              onClick={() => {
                                setLots((prev) =>
                                  prev.map((item) =>
                                    item.id === lt.id
                                      ? {
                                          ...item,
                                          terkumpulKg: item.terkumpulKg + 1000,
                                          progressPct: Math.min(100, Math.round(((item.terkumpulKg + 1000) / item.targetKg) * 100)),
                                        }
                                      : item
                                  )
                                );
                                setNotice(`Setoran 1.000 kg ditambahkan ke Lot ${lt.groupNama}.`);
                              }}
                              className="sj-btn-outline"
                            >
                              Setor 1.000 kg ke Lot Kolektif
                            </button>
                          </article>
                        ))}
                      </section>
                    </div>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <section aria-labelledby="judul-bursa-janji" className="space-y-3">
                      <h2 id="judul-bursa-janji" className="text-lg font-extrabold">
                        Bursa Janji Beli Pembeli Siaga
                      </h2>
                      {demands.length === 0 ? (
                        <StatePanel
                          kind="empty"
                          title="Belum ada kontrak Janji Beli terbuka"
                          message="Pembeli siaga daerah belum menerbitkan kuota baru untuk komoditas ini."
                        />
                      ) : (
                        demands.map((d) => (
                          <article key={d.id} className="sj-card p-5 space-y-2">
                            <div className="flex items-start justify-between gap-2">
                              <h3 className="text-base font-extrabold">
                                {d.commodityNama} · {d.buyerNama}
                              </h3>
                              <StampBadge label={`${formatRp(d.hargaAcuan)}/kg`} tone="ok" />
                            </div>
                            <p className="tabular-nums text-xs font-semibold" style={{ color: 'var(--sj-ink-muted)' }}>
                              Sisa kuota {formatKg(d.sisaKuotaKg)} · Dibutuhkan sebelum {d.dibutuhkanPada}
                            </p>
                            <button
                              type="button"
                              onClick={async () => {
                                const st = stocks.find((s) => s.commodityKode === d.commodityKode && s.freeKg > 0);
                                if (!st) {
                                  setNotice(`Belum ada stok bebas untuk komoditas ${d.commodityNama}.`);
                                  return;
                                }
                                const offerKg = Math.min(st.freeKg, d.sisaKuotaKg);
                                if (!offlineMode) {
                                  try {
                                    await apiFetch('/api/v1/sales', {
                                      method: 'POST',
                                      idempotent: true,
                                      body: JSON.stringify({
                                        stockId: st.id,
                                        demandId: d.id,
                                        qtyKg: offerKg,
                                        hargaTawar: d.hargaAcuan,
                                      }),
                                    });
                                    setNotice(`Penawaran jual ${formatKg(offerKg)} berhasil dikirim ke ${d.buyerNama}.`);
                                    await loadWorkspace(user);
                                    return;
                                  } catch (err: any) {
                                    setNotice(err?.message || 'Penawaran dicatat pada sesi simulasi.');
                                  }
                                }
                                setSales((prev) => [
                                  {
                                    id: `sl-${Date.now()}`,
                                    sellerNama: user.nama,
                                    buyerNama: d.buyerNama,
                                    buyerNoWa: '6281234567804',
                                    commodityNama: d.commodityNama,
                                    qtyKg: offerKg,
                                    hargaTawar: d.hargaAcuan,
                                    status: 'diajukan',
                                  },
                                  ...prev,
                                ]);
                                setNotice(`Penawaran jual ${formatKg(offerKg)} diajukan ke ${d.buyerNama}.`);
                              }}
                              className="sj-btn-primary"
                            >
                              Ajukan Penawaran Jual
                            </button>
                          </article>
                        ))
                      )}
                    </section>

                    <section aria-labelledby="judul-riwayat-pengajuan" className="space-y-3">
                      <h2 id="judul-riwayat-pengajuan" className="text-lg font-extrabold">
                        Status Pengajuan Sewa &amp; Penjualan
                      </h2>
                      {rentals.length === 0 && sales.length === 0 ? (
                        <StatePanel
                          kind="empty"
                          title="Belum ada pengajuan aktif"
                          message="Pilih gudang di tab Gudang atau ajukan penawaran pada daftar Janji Beli di sebelah kiri."
                        />
                      ) : (
                        <div className="space-y-3">
                          {rentals.map((r) => (
                            <article key={r.id} className="sj-card p-4 space-y-2.5">
                              <div className="flex flex-wrap items-center justify-between gap-2">
                                <span className="text-sm font-bold">
                                  Sewa {r.warehouseNama} ({formatKg(r.qtyKg)} · {r.hari} hari)
                                </span>
                                <StampBadge label={r.status.toUpperCase()} tone={r.status === 'ditolak' || r.status === 'dibatalkan' ? 'warn' : 'ok'} />
                              </div>
                              <div className="flex flex-wrap gap-2">
                                {(r.status === 'diajukan' || r.status === 'diterima') && (
                                  <button
                                    type="button"
                                    onClick={async () => {
                                      if (!offlineMode) {
                                        await apiFetch(`/api/v1/rentals/${r.id}/respond`, {
                                          method: 'POST',
                                          body: JSON.stringify({ action: 'batal' }),
                                        });
                                        await loadWorkspace(user);
                                      } else {
                                        setRentals((prev) => prev.map((x) => (x.id === r.id ? { ...x, status: 'dibatalkan' } : x)));
                                      }
                                      setNotice('Pengajuan sewa dibatalkan dan kapasitas/stok dipulihkan.');
                                    }}
                                    className="sj-btn-outline text-xs"
                                  >
                                    Batalkan Pengajuan
                                  </button>
                                )}
                                {(r.status === 'diterima' || r.status === 'selesai') && r.kontakWa && (
                                  <a
                                    href={`https://wa.me/${r.kontakWa}`}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="sj-btn-primary text-xs"
                                  >
                                    Hubungi Gudang via WhatsApp
                                  </a>
                                )}
                              </div>
                            </article>
                          ))}
                          {sales.map((s) => (
                            <article key={s.id} className="sj-card p-4 space-y-2.5">
                              <div className="flex flex-wrap items-center justify-between gap-2">
                                <span className="text-sm font-bold">
                                  Jual {s.commodityNama} ({formatKg(s.qtyKg)} @ {formatRp(s.hargaTawar)}/kg)
                                </span>
                                <StampBadge label={s.status.toUpperCase()} tone={s.status === 'ditolak' || s.status === 'dibatalkan' ? 'warn' : 'ok'} />
                              </div>
                              <div className="flex flex-wrap gap-2">
                                {(s.status === 'diajukan' || s.status === 'diterima') && (
                                  <button
                                    type="button"
                                    onClick={async () => {
                                      if (!offlineMode) {
                                        await apiFetch(`/api/v1/sales/${s.id}/respond`, {
                                          method: 'POST',
                                          body: JSON.stringify({ action: 'batal' }),
                                        });
                                        await loadWorkspace(user);
                                      } else {
                                        setSales((prev) => prev.map((x) => (x.id === s.id ? { ...x, status: 'dibatalkan' } : x)));
                                      }
                                      setNotice('Penawaran jual dibatalkan dan alokasi stok dilepaskan.');
                                    }}
                                    className="sj-btn-outline text-xs"
                                  >
                                    Batalkan Penawaran
                                  </button>
                                )}
                                {(s.status === 'diterima' || s.status === 'selesai') && s.buyerNoWa && (
                                  <a
                                    href={`https://wa.me/${s.buyerNoWa}`}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="sj-btn-primary text-xs"
                                  >
                                    Hubungi Pembeli via WhatsApp
                                  </a>
                                )}
                              </div>
                            </article>
                          ))}
                        </div>
                      )}
                    </section>
                  </div>
                )
              ) : user.role === 'gudang' ? (
                <div className="space-y-8">
                  <section aria-labelledby="judul-antrean-sewa" className="space-y-3">
                    <h2 id="judul-antrean-sewa" className="text-lg font-extrabold">
                      Antrean Permintaan Sewa Gudang Masuk
                    </h2>
                    {rentals.length === 0 ? (
                      <StatePanel
                        kind="empty"
                        title="Belum ada pengajuan sewa masuk"
                        message="Saat petani atau kelompok tani mengajukan penitipan gabah atau jagung, daftar persetujuan muncul di sini."
                        actionLabel="Simulasikan Pengajuan Masuk"
                        onAction={() =>
                          setRentals([
                            {
                              id: `rn-sim-${Date.now()}`,
                              requesterNama: 'Pak Slamet (Banyumas)',
                              warehouseNama: 'Gudang SRG Banyumas',
                              qtyKg: 5000,
                              hari: 30,
                              status: 'diajukan',
                            },
                          ])
                        }
                      />
                    ) : (
                      rentals.map((r) => (
                        <article key={r.id} className="sj-card p-5 flex flex-wrap items-center justify-between gap-3">
                          <div>
                            <h3 className="text-base font-extrabold">
                              {r.requesterNama} · {r.warehouseNama}
                            </h3>
                            <p className="tabular-nums text-xs font-semibold mt-0.5" style={{ color: 'var(--sj-ink-muted)' }}>
                              Volume {formatKg(r.qtyKg)} · Durasi {r.hari} hari · Status: {r.status.toUpperCase()}
                            </p>
                          </div>
                          <div className="flex flex-wrap gap-2">
                            {r.status === 'diajukan' && (
                              <>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    if (!offlineMode && !r.id.startsWith('rn-sim-')) {
                                      await apiFetch(`/api/v1/rentals/${r.id}/respond`, {
                                        method: 'POST',
                                        body: JSON.stringify({ action: 'terima' }),
                                      });
                                      await loadWorkspace(user);
                                    } else {
                                      setRentals((prev) =>
                                        prev.map((x) => (x.id === r.id ? { ...x, status: 'diterima' } : x))
                                      );
                                    }
                                    setNotice(`Pengajuan sewa ${r.requesterNama} diterima secara atomik.`);
                                  }}
                                  className="sj-btn-primary"
                                >
                                  Terima Sewa
                                </button>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    if (!offlineMode && !r.id.startsWith('rn-sim-')) {
                                      await apiFetch(`/api/v1/rentals/${r.id}/respond`, {
                                        method: 'POST',
                                        body: JSON.stringify({ action: 'tolak', reason: 'Kapasitas blok sedang dijadwalkan ulang' }),
                                      });
                                      await loadWorkspace(user);
                                    } else {
                                      setRentals((prev) =>
                                        prev.map((x) => (x.id === r.id ? { ...x, status: 'ditolak' } : x))
                                      );
                                    }
                                    setNotice(`Pengajuan sewa ${r.requesterNama} ditolak dan stok petani dilepas.`);
                                  }}
                                  className="sj-btn-outline"
                                >
                                  Tolak
                                </button>
                              </>
                            )}
                            {r.status === 'diterima' && (
                              <button
                                type="button"
                                onClick={async () => {
                                  if (!offlineMode && !r.id.startsWith('rn-sim-')) {
                                    await apiFetch(`/api/v1/rentals/${r.id}/respond`, {
                                      method: 'POST',
                                      body: JSON.stringify({ action: 'selesai' }),
                                    });
                                    await loadWorkspace(user);
                                  } else {
                                    setRentals((prev) =>
                                      prev.map((x) => (x.id === r.id ? { ...x, status: 'selesai' } : x))
                                    );
                                  }
                                  setNotice(`Penyimpanan ${r.requesterNama} ditandai selesai.`);
                                }}
                                className="sj-btn-outline"
                              >
                                Tandai Selesai
                              </button>
                            )}
                          </div>
                        </article>
                      ))
                    )}
                  </section>

                  <section aria-labelledby="judul-kelola-gudang" className="space-y-3">
                    <h2 id="judul-kelola-gudang" className="text-lg font-extrabold">
                      Kelola Kapasitas &amp; 6 Ceklis Fisik Gudang
                    </h2>
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                      {warehouses.map((w) => {
                        const draft = editingWh[w.id] ?? {
                          tersediaKg: String(w.tersediaKg),
                          tarifPerKgHari: String(w.tarifPerKgHari),
                          checklist: { ...w.checklist },
                        };
                        return (
                          <article key={w.id} className="sj-card p-5 space-y-3">
                            <div className="flex items-center justify-between gap-2">
                              <h3 className="text-base font-extrabold">{w.nama}</h3>
                              <StampBadge label={w.isSrg ? 'SRG RESMI' : 'MITRA'} tone="ok" />
                            </div>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                              <div>
                                <label htmlFor={`wh-cap-${w.id}`} className="block text-xs font-bold mb-1">
                                  Kapasitas Tersedia (kg)
                                </label>
                                <input
                                  id={`wh-cap-${w.id}`}
                                  type="number"
                                  value={draft.tersediaKg}
                                  onChange={(e) =>
                                    setEditingWh((prev) => ({
                                      ...prev,
                                      [w.id]: { ...draft, tersediaKg: e.target.value },
                                    }))
                                  }
                                  className="sj-input tabular-nums"
                                />
                              </div>
                              <div>
                                <label htmlFor={`wh-tarif-${w.id}`} className="block text-xs font-bold mb-1">
                                  Tarif Sewa (Rp/kg/hari)
                                </label>
                                <input
                                  id={`wh-tarif-${w.id}`}
                                  type="number"
                                  step="0.5"
                                  value={draft.tarifPerKgHari}
                                  onChange={(e) =>
                                    setEditingWh((prev) => ({
                                      ...prev,
                                      [w.id]: { ...draft, tarifPerKgHari: e.target.value },
                                    }))
                                  }
                                  className="sj-input tabular-nums"
                                />
                              </div>
                            </div>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5 pt-1">
                              {CHECKLIST_LABELS.map((item) => (
                                <label
                                  key={item.key}
                                  htmlFor={`wh-chk-${w.id}-${item.key}`}
                                  className="inline-flex min-h-[40px] items-center gap-2 text-xs font-semibold"
                                >
                                  <input
                                    id={`wh-chk-${w.id}-${item.key}`}
                                    type="checkbox"
                                    checked={Boolean(draft.checklist[item.key])}
                                    onChange={(e) =>
                                      setEditingWh((prev) => ({
                                        ...prev,
                                        [w.id]: {
                                          ...draft,
                                          checklist: { ...draft.checklist, [item.key]: e.target.checked },
                                        },
                                      }))
                                    }
                                    className="h-4 w-4 accent-[#183D31]"
                                  />
                                  <span>{item.label}</span>
                                </label>
                              ))}
                            </div>
                            <button
                              type="button"
                              onClick={async () => {
                                const avail = Number(draft.tersediaKg) || w.tersediaKg;
                                const tarif = Number(draft.tarifPerKgHari) || w.tarifPerKgHari;
                                if (!offlineMode) {
                                  try {
                                    await apiFetch(`/api/v1/warehouses/${w.id}`, {
                                      method: 'PUT',
                                      body: JSON.stringify({
                                        tersediaKg: avail,
                                        tarifPerKgHari: tarif,
                                        checklist: draft.checklist,
                                      }),
                                    });
                                    setNotice(`Profil & ceklis ${w.nama} diperbarui di server.`);
                                    await loadWorkspace(user);
                                    return;
                                  } catch {
                                    // Perbarui daftar lokal jika mode simulasi.
                                  }
                                }
                                setWarehouses((prev) =>
                                  prev.map((x) =>
                                    x.id === w.id
                                      ? { ...x, tersediaKg: avail, tarifPerKgHari: tarif, checklist: draft.checklist }
                                      : x
                                  )
                                );
                                setNotice(`Profil & ceklis ${w.nama} diperbarui.`);
                              }}
                              className="sj-btn-primary"
                            >
                              Simpan Profil &amp; Ceklis Gudang
                            </button>
                          </article>
                        );
                      })}
                    </div>
                  </section>
                </div>
              ) : user.role === 'pembeli' ? (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <section aria-labelledby="judul-buat-janji" className="sj-card p-5">
                    <h2 id="judul-buat-janji" className="text-lg font-extrabold">
                      Terbitkan Kontrak Janji Beli Baru
                    </h2>
                    <form
                      onSubmit={async (e) => {
                        e.preventDefault();
                        const qty = Number(newDemandQty);
                        const prc = Number(newDemandPrice);
                        if (!qty || qty < 500 || !prc || prc < 1000) {
                          setNotice('Isi kuota minimal 500 kg dan harga acuan yang wajar.');
                          return;
                        }
                        if (!offlineMode) {
                          try {
                            const comm = commodities.find((c) => c.kode === newDemandKode) || commodities[0];
                            await apiFetch('/api/v1/demands', {
                              method: 'POST',
                              idempotent: true,
                              body: JSON.stringify({
                                commodityId: comm.id,
                                commodityKode: newDemandKode,
                                qtyKg: qty,
                                hargaAcuan: prc,
                                dibutuhkanPada: '2027-02-01',
                                kabupaten: user.kabupaten,
                              }),
                            });
                            setNotice('Kontrak Janji Beli berhasil diterbitkan.');
                            await loadWorkspace(user);
                            return;
                          } catch {
                            // Lanjut simpan di daftar lokal sesi.
                          }
                        }
                        setDemands((prev) => [
                          {
                            id: `dem-${Date.now()}`,
                            buyerNama: user.nama,
                            commodityKode: newDemandKode,
                            commodityNama:
                              newDemandKode === 'gabah' ? 'Gabah Kering Giling (GKG)' : 'Jagung Pipil',
                            qtyKg: qty,
                            terpenuhiKg: 0,
                            sisaKuotaKg: qty,
                            progressPct: 0,
                            hargaAcuan: prc,
                            dibutuhkanPada: '2027-02-01',
                            kabupaten: user.kabupaten,
                          },
                          ...prev,
                        ]);
                        setNotice('Kontrak Janji Beli baru ditambahkan.');
                      }}
                      className="mt-3 space-y-3"
                    >
                      <div>
                        <label htmlFor="dm-kode" className="block text-xs font-bold mb-1">
                          Komoditas Dibutuhkan
                        </label>
                        <select
                          id="dm-kode"
                          value={newDemandKode}
                          onChange={(e) => setNewDemandKode(e.target.value)}
                          className="sj-input"
                        >
                          <option value="jagung">Jagung Pipil</option>
                          <option value="gabah">Gabah Kering Giling (GKG)</option>
                        </select>
                      </div>
                      <div>
                        <label htmlFor="dm-qty" className="block text-xs font-bold mb-1">
                          Target Kuota Serap (kg)
                        </label>
                        <input
                          id="dm-qty"
                          type="number"
                          value={newDemandQty}
                          onChange={(e) => setNewDemandQty(e.target.value)}
                          placeholder="Contoh: 8000"
                          className="sj-input tabular-nums"
                        />
                      </div>
                      <div>
                        <label htmlFor="dm-price" className="block text-xs font-bold mb-1">
                          Harga Acuan Pembelian (Rp/kg)
                        </label>
                        <input
                          id="dm-price"
                          type="number"
                          value={newDemandPrice}
                          onChange={(e) => setNewDemandPrice(e.target.value)}
                          placeholder="Contoh: 5900"
                          className="sj-input tabular-nums"
                        />
                      </div>
                      <button type="submit" className="sj-btn-primary w-full">
                        Terbitkan Janji Beli
                      </button>
                    </form>
                  </section>

                  <section aria-labelledby="judul-penawaran-petani" className="space-y-3">
                    <h2 id="judul-penawaran-petani" className="text-lg font-extrabold">
                      Penawaran Masuk dari Petani &amp; Poktan
                    </h2>
                    {sales.length === 0 ? (
                      <StatePanel
                        kind="empty"
                        title="Belum ada penawaran masuk"
                        message="Penawaran pasokan petani pada kontrak Janji Beli Anda akan tampil di panel ini."
                        actionLabel="Simulasikan Penawaran Petani"
                        onAction={() =>
                          setSales([
                            {
                              id: `sl-sim-${Date.now()}`,
                              sellerNama: 'Poktan Tani Jaya',
                              commodityNama: 'Jagung Pipil',
                              qtyKg: 5000,
                              hargaTawar: 5850,
                              status: 'diajukan',
                            },
                          ])
                        }
                      />
                    ) : (
                      sales.map((s) => (
                        <article key={s.id} className="sj-card p-5 flex flex-wrap items-center justify-between gap-3">
                          <div>
                            <h3 className="text-base font-extrabold">
                              {s.sellerNama} · {s.commodityNama}
                            </h3>
                            <p className="tabular-nums text-xs font-semibold mt-0.5" style={{ color: 'var(--sj-ink-muted)' }}>
                              {formatKg(s.qtyKg)} @ {formatRp(s.hargaTawar)}/kg · Status: {s.status.toUpperCase()}
                            </p>
                          </div>
                          <div className="flex flex-wrap gap-2">
                            {s.status === 'diajukan' && (
                              <>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    if (!offlineMode && !s.id.startsWith('sl-sim-')) {
                                      await apiFetch(`/api/v1/sales/${s.id}/respond`, {
                                        method: 'POST',
                                        body: JSON.stringify({ action: 'terima' }),
                                      });
                                      await loadWorkspace(user);
                                    } else {
                                      setSales((prev) =>
                                        prev.map((x) => (x.id === s.id ? { ...x, status: 'diterima' } : x))
                                      );
                                    }
                                    setNotice(`Penawaran dari ${s.sellerNama} diterima.`);
                                  }}
                                  className="sj-btn-primary"
                                >
                                  Terima Penawaran
                                </button>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    if (!offlineMode && !s.id.startsWith('sl-sim-')) {
                                      await apiFetch(`/api/v1/sales/${s.id}/respond`, {
                                        method: 'POST',
                                        body: JSON.stringify({ action: 'tolak', reason: 'Jadwal kirim tidak sesuai' }),
                                      });
                                      await loadWorkspace(user);
                                    } else {
                                      setSales((prev) =>
                                        prev.map((x) => (x.id === s.id ? { ...x, status: 'ditolak' } : x))
                                      );
                                    }
                                    setNotice(`Penawaran dari ${s.sellerNama} ditolak.`);
                                  }}
                                  className="sj-btn-outline"
                                >
                                  Tolak
                                </button>
                              </>
                            )}
                            {s.status === 'diterima' && (
                              <button
                                type="button"
                                onClick={async () => {
                                  if (!offlineMode && !s.id.startsWith('sl-sim-')) {
                                    await apiFetch(`/api/v1/sales/${s.id}/respond`, {
                                      method: 'POST',
                                      body: JSON.stringify({ action: 'selesai' }),
                                    });
                                    await loadWorkspace(user);
                                  } else {
                                    setSales((prev) =>
                                      prev.map((x) => (x.id === s.id ? { ...x, status: 'selesai' } : x))
                                    );
                                  }
                                  setNotice(`Transaksi dengan ${s.sellerNama} ditandai selesai.`);
                                }}
                                className="sj-btn-primary"
                              >
                                Tandai Selesai
                              </button>
                            )}
                          </div>
                        </article>
                      ))
                    )}
                  </section>
                </div>
              ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <section aria-labelledby="judul-admin-komoditas" className="sj-card p-5 space-y-4">
                    <h2 id="judul-admin-komoditas" className="text-lg font-extrabold">
                      Tambah Komoditas Baru Tanpa Ubah Skema Tabel
                    </h2>
                    <form
                      onSubmit={async (e) => {
                        e.preventDefault();
                        if (!newCommKode.trim() || !newCommNama.trim()) {
                          setNotice('Isi kode singkat dan nama lengkap komoditas.');
                          return;
                        }
                        const kode = newCommKode.trim().toLowerCase();
                        const nama = newCommNama.trim();
                        if (!offlineMode) {
                          try {
                            await apiFetch('/api/v1/admin/commodities', {
                              method: 'POST',
                              body: JSON.stringify({
                                kode,
                                nama,
                                satuan: 'kg',
                                hargaAwalKg: 9200,
                                params: OFFLINE_COMMODITIES[0].params,
                              }),
                            });
                            setNotice(`Komoditas ${nama} berhasil didaftarkan.`);
                            setNewCommKode('');
                            setNewCommNama('');
                            await loadWorkspace(user);
                            return;
                          } catch {
                            // Simpan pada sesi lokal bila offline.
                          }
                        }
                        setCommodities((prev) => [
                          ...prev,
                          {
                            id: `c-${kode}`,
                            kode,
                            nama,
                            satuan: 'kg',
                            params: OFFLINE_COMMODITIES[0].params,
                          },
                        ]);
                        setNewCommKode('');
                        setNewCommNama('');
                        setNotice(`Komoditas ${nama} ditambahkan ke katalog aktif.`);
                      }}
                      className="space-y-3"
                    >
                      <div>
                        <label htmlFor="adm-kode" className="block text-xs font-bold mb-1">
                          Kode Komoditas
                        </label>
                        <input
                          id="adm-kode"
                          type="text"
                          value={newCommKode}
                          onChange={(e) => setNewCommKode(e.target.value)}
                          placeholder="Contoh: kedelai"
                          className="sj-input"
                        />
                      </div>
                      <div>
                        <label htmlFor="adm-nama" className="block text-xs font-bold mb-1">
                          Nama Komoditas
                        </label>
                        <input
                          id="adm-nama"
                          type="text"
                          value={newCommNama}
                          onChange={(e) => setNewCommNama(e.target.value)}
                          placeholder="Contoh: Kedelai Lokal Kering"
                          className="sj-input"
                        />
                      </div>
                      <button type="submit" className="sj-btn-primary">
                        Daftarkan Komoditas
                      </button>
                    </form>
                  </section>

                  <section aria-labelledby="judul-katalog-aktif" className="space-y-3">
                    <h2 id="judul-katalog-aktif" className="text-lg font-extrabold">
                      Standar Mutu Komoditas Aktif ({commodities.length})
                    </h2>
                    {healthInfo && (
                      <div className="sj-card-alt p-4 text-xs font-semibold">
                        Status sistem: <strong>{healthInfo.status}</strong> · {healthInfo.architecture}
                      </div>
                    )}
                    {commodities.map((c) => {
                      const draft = editingComm[c.id] ?? {
                        ka: String(c.params.kadar_air_maks_pct),
                        susut: String(c.params.susut_per_bulan),
                        kering: String(c.params.biaya_pengeringan_per_kg),
                      };
                      return (
                        <article key={c.id} className="sj-card p-4 space-y-3">
                          <h3 className="text-sm font-extrabold">
                            {c.nama} ({c.kode})
                          </h3>
                          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                            <div>
                              <label htmlFor={`cm-ka-${c.id}`} className="block text-[11px] font-bold mb-1">
                                Maks Kadar Air (%)
                              </label>
                              <input
                                id={`cm-ka-${c.id}`}
                                type="number"
                                step="0.5"
                                value={draft.ka}
                                onChange={(e) =>
                                  setEditingComm((prev) => ({
                                    ...prev,
                                    [c.id]: { ...draft, ka: e.target.value },
                                  }))
                                }
                                className="sj-input tabular-nums"
                              />
                            </div>
                            <div>
                              <label htmlFor={`cm-su-${c.id}`} className="block text-[11px] font-bold mb-1">
                                Susut/Bln (desimal)
                              </label>
                              <input
                                id={`cm-su-${c.id}`}
                                type="number"
                                step="0.001"
                                value={draft.susut}
                                onChange={(e) =>
                                  setEditingComm((prev) => ({
                                    ...prev,
                                    [c.id]: { ...draft, susut: e.target.value },
                                  }))
                                }
                                className="sj-input tabular-nums"
                              />
                            </div>
                            <div>
                              <label htmlFor={`cm-dr-${c.id}`} className="block text-[11px] font-bold mb-1">
                                Biaya Jemur (Rp/kg)
                              </label>
                              <input
                                id={`cm-dr-${c.id}`}
                                type="number"
                                step="10"
                                value={draft.kering}
                                onChange={(e) =>
                                  setEditingComm((prev) => ({
                                    ...prev,
                                    [c.id]: { ...draft, kering: e.target.value },
                                  }))
                                }
                                className="sj-input tabular-nums"
                              />
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={async () => {
                              const nextParams = {
                                ...c.params,
                                kadar_air_maks_pct: Number(draft.ka) || c.params.kadar_air_maks_pct,
                                susut_per_bulan: Number(draft.susut) || c.params.susut_per_bulan,
                                biaya_pengeringan_per_kg: Number(draft.kering) || c.params.biaya_pengeringan_per_kg,
                              };
                              if (!offlineMode) {
                                try {
                                  await apiFetch(`/api/v1/admin/commodities/${c.id}`, {
                                    method: 'PUT',
                                    body: JSON.stringify({ nama: c.nama, params: nextParams }),
                                  });
                                  setNotice(`Parameter JSONB ${c.nama} disimpan dan cache di-invalidate.`);
                                  await loadWorkspace(user);
                                  return;
                                } catch {
                                  // Perbarui di sesi lokal jika offline.
                                }
                              }
                              setCommodities((prev) =>
                                prev.map((x) => (x.id === c.id ? { ...x, params: nextParams } : x))
                              );
                              setNotice(`Parameter ${c.nama} diperbarui pada katalog sesi.`);
                            }}
                            className="sj-btn-outline text-xs"
                          >
                            Simpan Parameter
                          </button>
                        </article>
                      );
                    })}
                  </section>
                </div>
              )}
            </main>
          </div>

          {user.role === 'petani' && (
            <nav
              aria-label="Navigasi bawah petani ponsel"
              style={{ backgroundColor: 'var(--sj-frame)' }}
              className="fixed bottom-0 inset-x-0 z-30 flex sm:hidden items-center justify-around border-t border-white/15 pb-[env(safe-area-inset-bottom)]"
            >
              {[
                { id: 'stok' as const, label: 'Stok & Impas', icon: 'grain' as const },
                { id: 'gudang' as const, label: 'Gudang & Lot', icon: 'barn' as const },
                { id: 'pasar' as const, label: 'Janji Beli', icon: 'handshake' as const },
              ].map((item) => {
                const active = petaniTab === item.id;
                return (
                  <button
                    key={item.id}
                    type="button"
                    aria-current={active ? 'page' : undefined}
                    onClick={() => setPetaniTab(item.id)}
                    style={{ color: active ? 'var(--sj-gold-text)' : '#C2D6C4' }}
                    className="flex min-h-[60px] flex-1 flex-col items-center justify-center gap-1 text-[11.5px] font-extrabold"
                  >
                    <SvgGlyph name={item.icon} className="w-5 h-5" />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </nav>
          )}

          <footer
            style={{ backgroundColor: 'var(--sj-frame)' }}
            className="hidden sm:block border-t border-white/15 px-6 py-4 text-xs text-[#C2D6C4]"
          >
            <div className="mx-auto max-w-[1360px] flex items-center justify-between">
              <span>SimpanJual · Ruang Kerja Lintas Peran Pascapanen</span>
              <span>{offlineMode ? 'Mode Simulasi Mandiri' : 'Go Modular Monolith + PostgreSQL'}</span>
            </div>
          </footer>
        </div>
      )}

      <QuickAuthModal
        open={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        onDemoSelect={(preset) => void handleDemoLogin(preset)}
        onManualLogin={(em, pw) => void handleManualLogin(em, pw)}
        onRegister={(payload) => void handleRegister(payload)}
        busy={authBusy}
        authError={authError}
      />
    </div>
  );
}

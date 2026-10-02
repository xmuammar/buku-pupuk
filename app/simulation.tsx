'use client';
import {useEffect, useState} from 'react';
import {Calculator, Save, RefreshCw} from 'lucide-react';
import MoneyInput from './money-input';
import type {RecordRow} from '@/lib/report-data';
import {calculateSimulation, canonicalInputs, defaultSimulation, inputLimits, validSavedSimulation, validSimulationInput, type SimulationInput} from '@/lib/simulation';

const money = (value: number | null) => value === null ? 'Belum tersedia' : new Intl.NumberFormat('id-ID', {style: 'currency', currency: 'IDR', maximumFractionDigits: 0}).format(value);
const number = (value: number | null) => value === null ? '—' : new Intl.NumberFormat('id-ID', {maximumFractionDigits: 2}).format(value);
const date = (value: string) => new Date(value).toLocaleString('id-ID', {timeZone: 'Asia/Jakarta'}) + ' WIB';
const moneyFields = new Set<keyof SimulationInput>(['funding', 'ureaSubsidyPrice', 'phoskaSubsidyPrice', 'subsidyCommission', 'extraCosts', 'purchaseBudget', 'targetMargin', 'ureaBuyPrice', 'ureaSellPrice', 'phoskaBuyPrice', 'phoskaSellPrice']);
const decimalFields = new Set<keyof SimulationInput>(['subsidySacksPerBuyer', 'nonSubsidySacksPerBuyer', 'nonSubsidyKgPerSack']);
const emptyInputs = Object.fromEntries(Object.keys(defaultSimulation).map(key => [key, null])) as SimulationInput;

export default function Simulation({rows, active, recordsLoading, recordsError}: {rows: RecordRow[]; active: boolean; recordsLoading: boolean; recordsError: string}) {
  const [inputs, setInputs] = useState<SimulationInput>({...defaultSimulation});
  const [loaded, setLoaded] = useState(false), [busy, setBusy] = useState('load');
  const [revision, setRevision] = useState<string | null>(null), [savedInputs, setSavedInputs] = useState('');
  const [error, setError] = useState(''), [message, setMessage] = useState('');
  const dirty = loaded && canonicalInputs(inputs) !== savedInputs;
  async function loadPlan() {
    setBusy('load'); setError(''); setMessage('');
    try {
      const response = await fetch('/api/simulation', {cache: 'no-store'}), data = await response.json() as any;
      if (!response.ok) throw Error(data.error || 'Simulasi belum dapat dimuat.');
      if (data.plan !== null && !validSavedSimulation(data.plan)) throw Error('Isian simulasi tersimpan tidak dapat dibaca.');
      const next = data.plan?.inputs || {...defaultSimulation};
      setInputs(next); setRevision(data.plan?.updatedAt || null); setSavedInputs(canonicalInputs(next)); setLoaded(true);
    } catch (failure) {setError((failure as Error).message);} finally {setBusy('');}
  }
  useEffect(() => {void loadPlan();}, []);
  useEffect(() => {
    const restored = () => {if (!dirty) void loadPlan();};
    window.addEventListener('buku-pupuk-restored', restored);
    return () => window.removeEventListener('buku-pupuk-restored', restored);
  }, [dirty]);
  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => {event.preventDefault(); event.returnValue = '';};
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);
  async function save(event: React.FormEvent) {
    event.preventDefault(); setError(''); setMessage('');
    if (!validSimulationInput(inputs)) {setError('Periksa isian: angka harus sesuai batas dan jumlah orang harus bulat.'); return;}
    const snapshot = {...inputs}; setBusy('save');
    try {
      const response = await fetch('/api/simulation', {method: 'PUT', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({inputs: snapshot, updatedAt: revision})});
      const result = await response.json() as any;
      if (!response.ok) throw Error(result.error || 'Simulasi belum dapat disimpan.');
      setRevision(result.updatedAt); setSavedInputs(canonicalInputs(snapshot)); setMessage('Simulasi berhasil disimpan.');
    } catch (failure) {setError((failure as Error).message);} finally {setBusy('');}
  }
  const valid = validSimulationInput(inputs), result = calculateSimulation(rows, valid ? inputs : emptyInputs);
  const resultsReady = loaded && !recordsLoading && !recordsError && valid;
  function field(key: keyof SimulationInput, title: string, help?: string) {
    const value = inputs[key];
    function change(raw: string) {
      const next = raw === '' ? null : Number(raw);
      setInputs(previous => ({...previous, [key]: next})); setMessage('');
    }
    return <label key={key}>{title}{moneyFields.has(key)
      ? <MoneyInput required={false} max={String(inputLimits[key])} value={value === null ? '' : String(value)} onChange={change}/>
      : <input type="number" inputMode={decimalFields.has(key) ? 'decimal' : 'numeric'} min={key === 'nonSubsidyKgPerSack' ? '0.01' : '0'} max={inputLimits[key]} step={decimalFields.has(key) ? '0.01' : '1'} value={value ?? ''} onChange={event => change(event.target.value)}/>}
      {help && <small>{help}</small>}
    </label>;
  }
  const displayMoney = (value: number | null) => resultsReady ? money(value) : 'Belum tersedia';
  if (!active) return null;
  return <div className="simulation-stack">
    <form className="simulation-form" onSubmit={save}>
      <section className="panel">
        <div className="panel-heading simulation-toolbar"><div><h2><Calculator size={21}/> Rencana satu putaran penjualan</h2><small>{busy === 'load' ? 'Memuat simulasi…' : revision ? `Tersimpan ${date(revision)}${dirty ? ' · Ada perubahan belum disimpan' : ''}` : 'Rencana awal dari Excel · Belum disimpan'}</small></div>
          <div className="panel-actions"><button type="button" disabled={!!busy} onClick={() => {if (!dirty || window.confirm('Muat versi tersimpan? Perubahan yang belum disimpan akan diganti.')) void loadPlan();}}><RefreshCw size={16}/> Muat tersimpan</button><button className="primary" disabled={!!busy || !loaded || !valid}><Save size={17}/>{busy === 'save' ? 'Menyimpan…' : 'Simpan simulasi'}</button></div>
        </div>
        <div className="simulation-body">
          {error && <div className="error" role="alert">{error}{!loaded && <button type="button" onClick={() => void loadPlan()}>Coba lagi</button>}</div>}
          {message && <div className="notice" role="status">{message}</div>}
          <fieldset disabled={!!busy || !loaded}>
            <div className="simulation-capital">{field('funding', 'Total dana masuk (Rp)', 'Dana yang disampaikan pengelola; cocokkan saldo bank dengan rekening koran.')}</div>
            <div className="simulation-actual"><div><span>Penarikan tercatat</span><strong>{displayMoney(result.withdrawals)}</strong></div><div><span>Kas dari transaksi</span><strong>{displayMoney(result.cash)}</strong></div><div><span>Perkiraan saldo bank</span><strong>{displayMoney(result.bank)}</strong></div><div><span>Total bank + kas</span><strong>{displayMoney(result.liquid)}</strong></div></div>
            <div className="simulation-columns">
              <section className="simulation-input-group"><h3>Penjualan subsidi</h3><div className="simulation-grid">{field('subsidyBuyers', 'Jumlah pembeli (orang)')}{field('subsidySacksPerBuyer', 'Sak per pembeli')}{field('subsidyUreaPercent', 'Bagian Urea (%)', 'Sisanya Phoska. Urea dibulatkan ke sak penuh.')}{field('subsidyCommission', 'Komisi resmi per sak (Rp)', 'Isi 0 jika belum ada dasar tertulis. Di luar harga pupuk.')}{field('ureaSubsidyPrice', 'Harga jual Urea per sak (Rp)')}{field('phoskaSubsidyPrice', 'Harga jual Phoska per sak (Rp)')}</div><p className="simulation-help">1 sak subsidi = 50 kg. Sesuaikan harga dengan HET dan kuota penyaluran yang berlaku. Stok tercatat diasumsikan sebagai stok subsidi; periksa faktur dan kemasannya.</p></section>
              <section className="simulation-input-group"><h3>Penjualan non subsidi</h3><div className="simulation-grid">{field('nonSubsidyBuyers', 'Jumlah pembeli (orang)')}{field('nonSubsidySacksPerBuyer', 'Sak per pembeli')}{field('nonSubsidyUreaPercent', 'Bagian Urea (%)', 'Sisanya Phoska / NPK.')}{field('nonSubsidyKgPerSack', 'Berat per sak (kg)', 'Awal 50 kg; sesuaikan kemasan pemasok.')}</div><p className="simulation-help">Pengadaan non subsidi dihitung terpisah dari stok subsidi.</p>
                <div className="simulation-price-group"><h4>Urea non subsidi</h4><div className="simulation-grid">{field('ureaBuyPrice', 'Biaya pengadaan per sak (Rp)', 'Harga beli + angkut + bongkar.')}{field('ureaSellPrice', 'Harga jual per sak (Rp)')}</div></div>
                <div className="simulation-price-group"><h4>Phoska / NPK non subsidi</h4><div className="simulation-grid">{field('phoskaBuyPrice', 'Biaya pengadaan per sak (Rp)', 'Harga beli + angkut + bongkar.')}{field('phoskaSellPrice', 'Harga jual per sak (Rp)')}</div></div>
              </section>
            </div>
            <section className="simulation-input-group simulation-costs"><h3>Anggaran dan target</h3><div className="simulation-grid">{field('extraCosts', 'Biaya tambahan satu putaran (Rp)', 'Gaji, listrik, sewa, dan biaya lain. Tidak mengulang ongkos dalam biaya per sak.')}{field('purchaseBudget', 'Batas belanja stok non subsidi (Rp)', 'Usulan anggaran, bukan penarikan yang sudah dicatat.')}{field('targetMargin', 'Target margin non subsidi per sak (Rp)', 'Selisih harga jual dan biaya pengadaan per sak.')}</div></section>
          </fieldset>
          <div className="simulation-save-row"><span>{dirty ? 'Ada perubahan belum disimpan.' : revision ? 'Rencana tersimpan.' : 'Simpan agar rencana dapat dibuka lagi.'}</span><button className="primary" disabled={!!busy || !loaded || !valid}><Save size={17}/>{busy === 'save' ? 'Menyimpan…' : 'Simpan simulasi'}</button></div>
        </div>
      </section>
    </form>
    {!valid && <div className="error" role="alert">Ada angka di luar batas atau format yang belum benar. Perbaiki isian untuk menghitung hasil.</div>}
    {recordsLoading && <p className="simulation-help" role="status">Menunggu kas dan stok terbaru…</p>}
    {resultsReady && <>
      {result.shortage && <div className="error" role="alert">Stok subsidi tidak mencukupi. Kurangi rencana penjualan atau catat pengadaan yang benar sebelum memakai proyeksi laba dan kas akhir.</div>}
      {!result.shortage && result.profit === null && <div className="simulation-callout">Lengkapi harga beli dan jual untuk produk yang akan dijual, serta isian anggaran. Kolom kosong tidak dihitung sebagai Rp 0. Target margin di bawah masih dapat dipakai untuk membandingkan rencana.</div>}
      {result.purchaseBudgetExceeded && <div className="error" role="alert">Biaya pengadaan non subsidi {money(result.nonCost)} melebihi batas belanja {money(inputs.purchaseBudget)}.</div>}
      {result.liquid !== null && result.upfrontCash !== null && result.upfrontCash > result.liquid && <div className="error" role="alert">Kebutuhan belanja dan biaya tambahan melebihi bank + kas awal.</div>}
      {result.bank !== null && result.bank < 0 && <div className="error" role="alert">Penarikan melebihi dana masuk yang diisi. Periksa dana dan rekening koran.</div>}
      <section aria-label="Ringkasan simulasi" className="simulation-results"><div className="card cash"><span>Kebutuhan penjualan</span><strong>{number(result.subSacks === null || result.nonSacks === null ? null : result.subSacks + result.nonSacks)} sak</strong><small>{number(result.subSacks)} sak subsidi · {number(result.nonSacks)} sak non subsidi</small></div><div className={'card ' + (result.profit !== null && result.profit < 0 ? 'expenditure' : '')}><span>Perkiraan laba sebelum pajak</span><strong>{money(result.profit)}</strong><small>Berdasarkan harga yang diisi dan biaya tambahan</small></div><div className="card"><span>Surplus pada target margin</span><strong>{money(result.targetProfit)}</strong><small>Target {money(inputs.targetMargin)} / sak non subsidi</small></div><div className="card"><span>Perkiraan bank + kas akhir</span><strong>{money(result.closingCash)}</strong><small>Semua penjualan dan biaya dibayar tunai dalam satu putaran</small></div></section>
      <section className="panel"><div className="panel-heading"><div><h2>Kebutuhan dan sisa stok</h2><small>Stok terbaru dikurangi rencana subsidi; non subsidi diadakan baru.</small></div></div><div className="table-wrap"><table className="simulation-table"><thead><tr><th>Jenis pupuk</th><th>Stok tercatat</th><th>Subsidi</th><th>Non subsidi baru</th><th>Sisa stok awal</th><th>Biaya aktual / sak</th></tr></thead><tbody>{result.products.map(product => <tr key={product.name}><td><strong>{product.name}</strong></td><td>{number(product.stock)} sak<small>{number(product.stock * 50)} kg</small></td><td>{number(product.subsidySacks)} sak<small>{number(product.subsidyKg)} kg</small></td><td>{number(product.nonSubsidySacks)} sak<small>{number(product.nonSubsidyKg)} kg</small></td><td className={product.remaining !== null && product.remaining < 0 ? 'simulation-negative' : ''}>{number(product.remaining)} sak</td><td>{money(product.landed)}</td></tr>)}</tbody></table></div><p className="simulation-footnote">Biaya aktual memakai rata-rata pembelian dan ongkos berjenis pupuk. {result.generalExpenses > 0 ? `Biaya umum ${money(result.generalExpenses)} dialokasikan rata per sak masuk.` : 'Ongkos tercatat sudah masuk biaya per sak.'}</p></section>
      <section className="panel"><div className="panel-heading"><h2>Proyeksi penjualan dan laba</h2></div><div className="table-wrap"><table className="simulation-table"><thead><tr><th>Komponen</th><th>Subsidi</th><th>Non subsidi</th><th>Gabungan</th></tr></thead><tbody>
        {[['Penjualan pupuk', result.subRevenue, result.nonRevenue, result.revenue], ['Biaya pupuk + ongkos', result.subCost, result.nonCost, result.cost], ['Margin setelah pengadaan', result.subMargin, result.nonMargin, result.subMargin === null || result.nonMargin === null ? null : result.subMargin + result.nonMargin], ['Komisi resmi', result.commission, 0, result.commission]].map(([title, sub, non, total]) => <tr key={String(title)}><td>{title}</td><td>{money(sub as number | null)}</td><td>{money(non as number | null)}</td><td>{money(total as number | null)}</td></tr>)}
        <tr><td>Biaya tambahan satu putaran</td><td>—</td><td>—</td><td>{money(inputs.extraCosts)}</td></tr><tr className="simulation-total"><td>Laba sebelum pajak</td><td>—</td><td>—</td><td>{money(result.profit)}</td></tr>
      </tbody></table></div></section>
      <div className="simulation-columns">
        <section className="panel"><div className="panel-heading"><h2>Target margin dan titik impas</h2></div><div className="simulation-body"><dl className="simulation-list"><div><dt>Kontribusi non subsidi untuk impas</dt><dd>{money(result.neededContribution)}</dd></div><div className="simulation-highlight"><dt>Margin rata-rata minimum per sak</dt><dd>{money(result.breakEvenMargin)}</dd></div><div><dt>Batas rata-rata biaya pengadaan per sak</dt><dd>{money(result.budgetPerSack)}</dd></div><div><dt>Bank jika batas belanja ditarik penuh</dt><dd>{money(result.bankAfterBudget)}</dd></div></dl><p className="simulation-help">Target impas menutup biaya tambahan dan kekurangan margin subsidi. Jika subsidi memberi margin positif, target tetap menyediakan seluruh biaya tambahan dari non subsidi.</p></div><div className="table-wrap"><table className="simulation-table"><thead><tr><th>Contoh margin / sak</th><th>Surplus sebelum pajak</th></tr></thead><tbody>{result.scenarios.map(scenario => <tr key={scenario.margin}><td>{money(scenario.margin)}</td><td>{money(scenario.profit)}</td></tr>)}</tbody></table></div><p className="simulation-footnote">Contoh target, bukan harga pasar atau laba yang sudah diterima.</p></section>
        <section className="panel"><div className="panel-heading"><h2>Arus kas satu putaran</h2></div><div className="simulation-body"><dl className="simulation-list"><div><dt>Bank + kas awal</dt><dd>{money(result.liquid)}</dd></div><div><dt>Belanja stok non subsidi baru</dt><dd>{money(result.nonCost)}</dd></div><div><dt>Biaya tambahan dibayar</dt><dd>{money(inputs.extraCosts)}</dd></div><div><dt>Penjualan diterima tunai</dt><dd>{money(result.revenue)}</dd></div><div><dt>Komisi resmi diterima</dt><dd>{money(result.commission)}</dd></div><div className="simulation-highlight"><dt>Bank + kas akhir</dt><dd>{money(result.closingCash)}</dd></div><div><dt>Nilai biaya stok awal tersisa</dt><dd>{money(result.remainingCost)}</dd></div><div><dt>Selisih biaya vs harga jual stok tersisa</dt><dd>{money(result.remainingPriceGap)}</dd></div></dl><p className="simulation-help">Kas akhir belum mengurangi utang distributor lama {money(result.debt)} dan belum menerima piutang lama {money(result.receivables)}. Selisih stok tersisa belum masuk laba putaran ini.</p></div></section>
      </div>
    </>}
  </div>;
}

'use client';
import {useEffect, useState} from 'react';
import {Calculator, Save, RefreshCw} from 'lucide-react';
import MoneyInput from './money-input';
import type {RecordRow} from '@/lib/report-data';
import {calculateSimulation, canonicalInputs, defaultSimulation, inputLimits, validSavedSimulation, validSimulationInput, type SimulationInput} from '@/lib/simulation';

const money = (value: number | null) => value === null ? 'Belum tersedia' : new Intl.NumberFormat('id-ID', {style: 'currency', currency: 'IDR', maximumFractionDigits: 0}).format(value);
const number = (value: number | null) => value === null ? '—' : new Intl.NumberFormat('id-ID', {maximumFractionDigits: 2}).format(value);
const date = (value: string) => new Date(value).toLocaleString('id-ID', {timeZone: 'Asia/Jakarta'}) + ' WIB';
const emptyInputs = Object.fromEntries(Object.keys(defaultSimulation).map(key => [key, null])) as SimulationInput;

export default function Simulation({rows, active, recordsLoading, recordsError, onReload}: {rows: RecordRow[]; active: boolean; recordsLoading: boolean; recordsError: string; onReload: () => Promise<void>}) {
  const [inputs, setInputs] = useState<SimulationInput>({...defaultSimulation});
  const [loaded, setLoaded] = useState(false), [busy, setBusy] = useState('');
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
      if (data.migrated) setMessage('Rencana lama dimuat. Biaya dan stok kini mengikuti transaksi Buku Pupuk.');
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
  async function reload() {
    if (dirty && !window.confirm('Muat versi tersimpan? Perubahan yang belum disimpan akan diganti.')) return;
    setBusy('load');
    await onReload();
    await loadPlan();
  }
  async function save(event: React.FormEvent) {
    event.preventDefault(); setError(''); setMessage('');
    if (!validSimulationInput(inputs)) {setError('Periksa isian. Jumlah sak maksimal dua angka desimal dan harga harus berupa rupiah bulat.'); return;}
    const snapshot = {...inputs}; setBusy('save');
    try {
      const response = await fetch('/api/simulation', {method: 'PUT', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({inputs: snapshot, updatedAt: revision})});
      const result = await response.json() as any;
      if (!response.ok) throw Error(result.error || 'Simulasi belum dapat disimpan.');
      setRevision(result.updatedAt); setSavedInputs(canonicalInputs(snapshot)); setMessage('Simulasi berhasil disimpan.');
    } catch (failure) {setError((failure as Error).message);} finally {setBusy('');}
  }
  const valid = validSimulationInput(inputs), result = calculateSimulation(rows, valid ? inputs : emptyInputs);
  const actualReady = !recordsLoading && !recordsError, resultsReady = loaded && actualReady && valid;
  function field(key: keyof SimulationInput, title: string) {
    const value = inputs[key];
    function change(raw: string) {
      setInputs(previous => ({...previous, [key]: raw === '' ? null : Number(raw)})); setMessage('');
    }
    return <label key={key}>{title}{key.endsWith('Price')
      ? <MoneyInput required={false} max={String(inputLimits[key])} value={value === null ? '' : String(value)} onChange={change}/>
      : <input type="number" inputMode="decimal" min="0" max={inputLimits[key]} step="0.01" value={value ?? ''} onChange={event => change(event.target.value)}/>}
    </label>;
  }
  const missing = result.products.flatMap(product => product.groups.filter(group => group.sacks === null || group.sacks > 0 && group.price === null)
    .map(group => `${product.name} ${group.kind === 'Subsidy' ? 'subsidi' : 'non subsidi'}`));
  const showMoney = (value: number | null) => resultsReady ? money(value) : 'Belum tersedia';
  if (!active) return null;
  return <div className="simulation-stack">
    <form className="simulation-form" onSubmit={save}>
      <section className="panel">
        <div className="panel-heading simulation-toolbar"><div><h2><Calculator size={21}/> Penjualan dari stok saat ini</h2><small>{busy === 'load' || !loaded ? 'Memuat simulasi…' : revision ? `Tersimpan ${date(revision)}${dirty ? ' · Ada perubahan belum disimpan' : ''}` : 'Belum disimpan'}</small></div>
          <div className="panel-actions"><button type="button" disabled={!!busy || recordsLoading} onClick={() => void reload()}><RefreshCw size={16}/> Muat ulang</button><button className="primary" disabled={!!busy || !loaded || !valid}><Save size={17}/>{busy === 'save' ? 'Menyimpan…' : 'Simpan simulasi'}</button></div>
        </div>
        <div className="simulation-body">
          {error && <div className="error" role="alert">{error}{!loaded && <button type="button" onClick={() => void loadPlan()}>Coba lagi</button>}</div>}
          {message && <div className="notice" role="status">{message}</div>}
          <div className="simulation-actual"><div className="simulation-actual-cash"><span>Kas dari transaksi tercatat</span><strong>{actualReady ? money(result.cash) : 'Belum tersedia'}</strong></div><div className="simulation-actual-expenditure"><span>Total pengeluaran tercatat</span><strong>{actualReady ? money(result.expenditure) : 'Belum tersedia'}</strong><small>Pembayaran pupuk {actualReady ? money(result.fertilizerPayments) : '—'} · Biaya operasional {actualReady ? money(result.expenses) : '—'}</small></div></div>
          <fieldset disabled={!!busy || !loaded || !actualReady}>
            <div className="simulation-columns">
              {result.products.map((product, index) => {
                const prefix = index === 0 ? 'urea' : 'phoska';
                return <section className="simulation-input-group" key={product.name}><h3>{product.name}</h3>
                  <div className="simulation-product-facts"><div><span>Stok tersedia</span><strong>{actualReady ? number(product.stock) : '—'} sak</strong><small>{actualReady ? number(product.stock * 50) : '—'} kg · 1 sak = 50 kg</small></div><div><span>Biaya rata-rata per sak</span><strong>{actualReady ? money(product.landed) : 'Belum tersedia'}</strong><small>Harga pembelian + biaya tercatat</small></div></div>
                  <div className="simulation-grid">{field(`${prefix}SubsidySacks`, 'Jumlah sak subsidi')}{field(`${prefix}SubsidyPrice`, 'Harga jual subsidi / sak (Rp)')}{field(`${prefix}NonSubsidySacks`, 'Jumlah sak non subsidi')}{field(`${prefix}NonSubsidyPrice`, 'Harga jual non subsidi / sak (Rp)')}</div>
                  <p className="simulation-help">Total rencana: {number(product.sacks)} sak · {number(product.kg)} kg. {product.shortage ? <span className="simulation-negative">Melebihi stok {number(product.remaining === null ? null : -product.remaining)} sak.</span> : <>Sisa setelah rencana: {number(product.remaining)} sak.</>}</p>
                </section>;
              })}
            </div>
            <p className="simulation-help">Isi 0 sak untuk jenis penjualan yang tidak direncanakan. Harga jual mengikuti isian Bapak dan ketentuan penyaluran. Simulasi tidak menambah transaksi.</p>
            <div className="simulation-save-row"><span>{dirty ? 'Ada perubahan belum disimpan.' : revision ? `Terakhir disimpan ${date(revision)}` : 'Simpan agar rencana dapat dibuka lagi.'}</span><button className="primary" disabled={!!busy || !valid}><Save size={17}/>{busy === 'save' ? 'Menyimpan…' : 'Simpan simulasi'}</button></div>
          </fieldset>
        </div>
      </section>
    </form>
    {!actualReady && <div className="simulation-callout" role="status">{recordsLoading ? 'Memuat transaksi Buku Pupuk…' : 'Perhitungan menunggu transaksi berhasil dimuat. Tekan Muat ulang untuk mencoba lagi.'}</div>}
    {loaded && actualReady && !valid && <div className="error" role="alert">Periksa isian. Jumlah sak tidak boleh negatif atau lebih dari dua angka desimal; harga harus berupa rupiah bulat.</div>}
    {resultsReady && <>
      {result.shortage && <div className="error" role="alert">Rencana penjualan melebihi stok tercatat. Kurangi jumlah sak yang direncanakan; laba dan kas akhir belum dapat dihitung.</div>}
      {missing.length > 0 && <div className="simulation-callout" role="status">Lengkapi jumlah sak dan harga jual untuk {missing.join(', ')} agar hasil dapat dihitung.</div>}
      {result.sacks === 0 && <div className="simulation-callout">Isi jumlah sak yang akan dijual untuk melihat hasil penjualan stok saat ini.</div>}
      <div className="simulation-results" aria-live="polite"><div className="card"><span>Laba / rugi rencana penjualan</span><strong className={result.profit !== null && result.profit < 0 ? 'simulation-negative' : ''}>{showMoney(result.profit)}</strong><small>Penjualan rencana dikurangi biaya pupuk yang akan dijual</small></div><div className="card expenditure"><span>Laba / rugi setelah rencana</span><strong className={result.periodProfit !== null && result.periodProfit < 0 ? 'simulation-negative' : ''}>{showMoney(result.periodProfit)}</strong><small>Gabungan penjualan tercatat dan rencana, termasuk biaya tercatat</small></div><div className="card cash"><span>Kas setelah rencana penjualan</span><strong>{showMoney(result.closingCash)}</strong><small>Kas saat ini + penerimaan rencana jika dibayar tunai</small></div><div className="card"><span>Nilai biaya stok yang tersisa</span><strong>{showMoney(result.remainingCost)}</strong><small>Persediaan belum terjual tetap menjadi aset</small></div></div>
      <section className="panel"><div className="panel-heading"><h2>Rincian rencana penjualan</h2><small>{number(result.sacks)} sak · {number(result.sacks === null ? null : result.sacks * 50)} kg</small></div><div className="table-wrap"><table className="simulation-table"><thead><tr><th>Pupuk / penjualan</th><th>Jumlah sak</th><th>Harga jual / sak</th><th>Penjualan</th><th>Biaya pupuk</th><th>Laba / rugi</th></tr></thead><tbody>{result.products.flatMap(product => product.groups.map(group => <tr key={product.name + group.kind}><td><strong>{product.name}</strong><small>{group.kind === 'Subsidy' ? 'Subsidi' : 'Non subsidi'}</small></td><td>{number(group.sacks)}</td><td>{money(group.price)}</td><td>{money(group.revenue)}</td><td>{money(group.cost)}</td><td className={group.margin !== null && group.margin < 0 ? 'simulation-negative' : ''}>{money(product.shortage ? null : group.margin)}</td></tr>))}<tr className="simulation-total"><td>Total rencana</td><td>{number(result.sacks)}</td><td>—</td><td>{money(result.revenue)}</td><td>{money(result.cost)}</td><td>{money(result.profit)}</td></tr></tbody></table></div><p className="simulation-footnote">Biaya rata-rata dihitung dari seluruh pembelian dan biaya yang tercatat. Biaya umum dibagi menurut jumlah sak pupuk masuk. Gaji atau biaya yang belum dicatat belum termasuk dalam hasil ini.</p></section>
      <section className="panel"><div className="panel-heading"><h2>Perhitungan kas</h2></div><div className="simulation-body"><dl className="simulation-list"><div><dt>Kas dari transaksi saat ini</dt><dd>{money(result.cash)}</dd></div><div><dt>Penerimaan rencana penjualan tunai</dt><dd>{money(result.revenue)}</dd></div><div className="simulation-highlight"><dt>Kas setelah rencana penjualan</dt><dd>{money(result.closingCash)}</dd></div><div><dt>Sisa utang distributor tercatat</dt><dd>{money(result.debt)}</dd></div><div><dt>Kas jika utang distributor dilunasi</dt><dd>{money(result.cashAfterDebt)}</dd></div><div><dt>Piutang petani yang belum diterima</dt><dd>{money(result.receivables)}</dd></div></dl><p className="simulation-help">Pembelian dan ongkos yang sudah dibayar telah mengurangi kas tercatat. Tidak ada penarikan bank atau pembelian stok baru dalam rencana ini. Piutang lama belum ditambahkan ke kas.</p></div></section>
    </>}
  </div>;
}

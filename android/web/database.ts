import {validFinance,readFinance,canonicalFinance,type SavedFinance,type FinanceInput} from './finance-data';
import {reportData, type RecordRow} from '../../lib/report-data';
import {validMember, type Member} from '../../lib/member-data';
import {canonicalInputs, normalizeSavedSimulation, validSimulationInput, type SavedSimulation, type SimulationInput} from '../../lib/simulation';

export type Snapshot = {app: 'buku-pupuk'; version: 1; createdAt: string; recordCount: number; records: RecordRow[]; members: Member[]; simulation: SavedSimulation | null; finance?: SavedFinance | null};
export type ApiResult = {status: number; body: unknown; changed?: boolean};
type RecordForm = Partial<RecordRow> & {unitPrice?:number;receiptName?:string;receiptData?:string;saleKind?:string;memberId?:string};
type Input = RecordForm & Partial<Member> & {original?:RecordForm;inputs?:SimulationInput;updatedAt?:string|null};
const types = ['withdraw', 'purchase', 'expense', 'sale', 'pay', 'collect'];
const recordFields = ['id', 'type', 'date', 'name', 'product', 'qty', 'sacks', 'unit_price', 'amount', 'paid', 'ref', 'note', 'receipt_name', 'receipt_data', 'sale_kind', 'member_id'] as const;
const defaultField = (key: string) => ['sacks','unit_price'].includes(key) ? 0 : '';
const stamp = () => new Date().toISOString();
const fail = (message: string, status = 400): never => {throw Object.assign(new Error(message), {status});};
export const blankSnapshot = (): Snapshot => ({app:'buku-pupuk',version:1,createdAt:stamp(),recordCount:0,records:[],members:[],simulation:null,finance:null});
const cleanRecord = (r: Partial<RecordRow>) => Object.fromEntries(recordFields.map(key => [key, r[key] ?? defaultField(key)])) as RecordRow;
const identicalRecord = (a: Partial<RecordRow>, b: Partial<RecordRow>) => recordFields.every(key => (a[key] ?? defaultField(key)) === (b[key] ?? defaultField(key)));
function validDate(value: unknown) {return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value)) && new Date(value+'T00:00:00Z').toISOString().slice(0,10) === value;}
function validateRecords(rows: RecordRow[], members: Member[]) {
  const ids = new Set<string>(), memberIds = new Set(members.map(m => m.id));
  for (const r of rows) {
    if (!r || typeof r.id !== 'string' || !r.id || r.id.length > 100 || ids.has(r.id) || !types.includes(r.type) || !validDate(r.date) ||
      typeof r.name !== 'string' || !r.name.trim() || r.name.length > 200 || typeof r.product !== 'string' || r.product.length > 200 ||
      typeof r.note !== 'string' || r.note.length > 1000 || typeof r.ref !== 'string' || r.ref.length > 100 ||
      !Number.isSafeInteger(r.amount) || r.amount <= 0 || !Number.isSafeInteger(r.paid) || r.paid < 0 || r.paid > r.amount ||
      !Number.isFinite(r.qty) || r.qty < 0 || !Number.isFinite(r.sacks) || r.sacks! < 0 || !Number.isSafeInteger(r.unit_price) || r.unit_price! < 0 ||
      typeof r.receipt_name !== 'string' || r.receipt_name.length > 200 || typeof r.receipt_data !== 'string' || r.receipt_data.length > 2_000_000)
      fail('Transaksi tidak valid. Periksa tanggal, nama, jumlah, pembayaran, dan kwitansi.');
    if (['purchase','sale'].includes(r.type) ? !r.product.trim() || r.qty <= 0 : r.qty !== 0 || r.paid !== 0) fail('Jumlah pupuk atau pembayaran awal tidak valid.');
    if (r.sale_kind && !['subsidi','non_subsidi'].includes(r.sale_kind) || r.sale_kind === 'subsidi' && !memberIds.has(r.member_id || '')) fail('Jenis penjualan atau anggota tidak valid.');
    ids.add(r.id);
  }
  const map = new Map(rows.map(r => [r.id, r]));
  for (const r of rows.filter(r => r.type === 'pay' || r.type === 'collect')) {
    if (map.get(r.ref)?.type !== (r.type === 'pay' ? 'purchase' : 'sale')) fail('Tagihan pembayaran tidak ditemukan.');
  }
  const data = reportData(rows);
  if (data.stock.some(r => r.balance < -0.000001) || [...data.debts,...data.credits].some(r => r.remaining < 0)) fail('Stok tidak mencukupi atau pembayaran melebihi sisa tagihan.',409);
}
function validateMembers(members: Member[]) {
  const ids = new Set<string>(), niks = new Set<string>();
  for (const m of members) {
    if (!validMember(m) || typeof m.id !== 'string' || !m.id || m.id.length > 100 || typeof m.updated_at !== 'string' || Number.isNaN(Date.parse(m.updated_at)) || ids.has(m.id)) fail('Data anggota tidak valid atau ID berulang.');
    if (m.nik && niks.has(m.nik)) fail('NIK sudah digunakan anggota lain.',409);
    ids.add(m.id); if (m.nik) niks.add(m.nik);
  }
}
export function readSnapshot(value: unknown): Snapshot {
  const data = value as Snapshot;
  if (!data || data.app !== 'buku-pupuk' || data.version !== 1 || !Array.isArray(data.records) || data.recordCount !== data.records.length || data.records.length > 10000 ||
      data.members !== undefined && (!Array.isArray(data.members) || data.members.length > 10000)) fail('Pilih file data JSON Buku Pupuk yang lengkap dan valid.');
  const rows = data.records.map(cleanRecord), members: Member[] = data.members || [];
  validateMembers(members); validateRecords(rows,members);
  const simulation = data.simulation == null ? null : normalizeSavedSimulation(data.simulation);
  if (data.simulation != null && !simulation) fail('Pengaturan simulasi tidak dapat dibaca.');
  return {app:'buku-pupuk',version:1,createdAt:typeof data.createdAt==='string'?data.createdAt:stamp(),recordCount:rows.length,records:rows,members,simulation,finance:readFinance(data.finance)};
}
function formRecord(data: RecordForm, state: Snapshot, id: string): RecordRow {
  const result = cleanRecord({...data,id,sacks:data.sacks??0,unit_price:data.unitPrice??0,receipt_name:data.receiptName??'',receipt_data:data.receiptData??'',sale_kind:data.type==='sale'?data.saleKind:'',member_id:data.type==='sale'&&data.saleKind==='subsidi'?data.memberId:''});
  if (result.type === 'sale') {
    if (!['subsidi','non_subsidi'].includes(result.sale_kind || '')) fail('Pilih Subsidi atau Non subsidi.');
    if (result.sale_kind === 'subsidi') {
      const member = state.members.find(m => m.id === result.member_id);
      if (!member) fail('Pilih anggota yang sudah tercatat.');
      result.name = member!.name;
    }
  }
  result.name = typeof result.name === 'string' ? result.name.trim() : result.name;
  return result;
}
export function applyRequest(state: Snapshot, path: string, method: string, inputValue: unknown = {}): ApiResult {
  try {
    if(!inputValue || typeof inputValue !== 'object' || Array.isArray(inputValue)) fail('Isi permintaan tidak valid.');
    const input=inputValue as Input;
    if (method === 'GET') {
      if (path === '/api/records') return {status:200,body:[...state.records].reverse().sort((a,b)=>b.date.localeCompare(a.date))};
      if (path === '/api/members') return {status:200,body:[...state.members].sort((a,b)=>a.name.localeCompare(b.name,'id'))};
      if (path === '/api/finance') return {status:200,body:{plan:state.finance||null}};
      if (path === '/api/simulation') return {status:200,body:{plan:state.simulation,migrated:false}};
      if (path === '/api/backup') return {status:200,body:{...state,createdAt:stamp(),recordCount:state.records.length}};
    }
    if (path === '/api/records' && ['POST','PATCH'].includes(method)) {
      const id = method === 'PATCH' ? input.id || '' : crypto.randomUUID(), record = formRecord(input,state,id);
      const next = [...state.records];
      if (method === 'PATCH') {
        const index = next.findIndex(r => r.id === id), old = next[index];
        if (!old) fail('Transaksi tidak ditemukan. Muat ulang catatan.',404);
        if (old.type !== record.type) fail('Jenis transaksi tidak boleh diganti melalui pengeditan.');
        const original = input?.original;
        if (!original || !identicalRecord(old,{...original,unit_price:original.unitPrice??original.unit_price??0,receipt_name:original.receiptName??original.receipt_name??'',receipt_data:original.receiptData??original.receipt_data??''})) fail('Transaksi berubah sejak form dibuka. Tutup form dan muat ulang.',409);
        next[index] = record;
      } else next.push(record);
      validateRecords(next,state.members); state.records=next; state.recordCount=next.length;
      return {status:200,body:{ok:true},changed:true};
    }
    if (path === '/api/members' && ['POST','PATCH'].includes(method)) {
      if (!validMember(input)) fail('Isi nama. NIK harus kosong atau terdiri dari 16 digit.');
      const details=input as Member;
      const next=[...state.members], id=method==='PATCH'?details.id:crypto.randomUUID();
      const old=next.find(m=>m.id===id);
      const member:Member={id,name:details.name.trim(),nik:details.nik,farmer_group:details.farmer_group.trim(),address:details.address.trim(),updated_at:new Date(Math.max(Date.now(),old?Date.parse(old.updated_at)+1:0)).toISOString()};
      if (method === 'PATCH') {
        const index=next.findIndex(m=>m.id===id);
        if(index<0 || next[index].updated_at!==input.updated_at)fail('Anggota berubah. Muat ulang sebelum mengedit.',409);
        next[index]=member;
      } else next.push(member);
      validateMembers(next); state.members=next;return {status:200,body:{ok:true,id},changed:true};
    }
    if (path === '/api/finance' && method === 'PUT') {
      const plan=inputValue as {inputs?:FinanceInput;updatedAt?:string|null};
      if(!validFinance(plan.inputs))fail('Periksa laba, persentase (total honor maksimal 100%), tanggal, dan jumlah pengawas.');
      if(plan.updatedAt!==(state.finance?.updatedAt||null))fail('Rencana keuangan berubah. Buka ulang menu Keuangan sebelum menyimpan.',409);
      state.finance={inputs:{...plan.inputs!},updatedAt:new Date(Math.max(Date.now(),state.finance?Date.parse(state.finance.updatedAt)+1:0)).toISOString()};
      return {status:200,body:{ok:true,updatedAt:state.finance.updatedAt},changed:true};
    }
    if (path === '/api/simulation' && method === 'PUT') {
      if (!validSimulationInput(input?.inputs)) fail('Periksa jumlah sak dan harga simulasi.');
      if (input.updatedAt !== (state.simulation?.updatedAt || null)) fail('Simulasi berubah. Muat ulang versi tersimpan.',409);
      state.simulation={inputs:input.inputs!,updatedAt:new Date(Math.max(Date.now(),state.simulation?Date.parse(state.simulation.updatedAt)+1:0)).toISOString()};
      return {status:200,body:{ok:true,updatedAt:state.simulation.updatedAt},changed:true};
    }
    if (path === '/api/backup' && method === 'POST') {
      const backup = readSnapshot(input), recordMap=new Map(state.records.map(r=>[r.id,r])), memberMap=new Map(state.members.map(m=>[m.id,m]));
      for(const r of backup.records)if(recordMap.has(r.id)&&!identicalRecord(recordMap.get(r.id)!,r))fail('ID transaksi sama dengan isi berbeda. Data tidak ditimpa.',409);
      for(const m of backup.members)if(memberMap.has(m.id)&&!(['name','nik','farmer_group','address','updated_at'] as const).every(key=>memberMap.get(m.id)![key]===m[key]))fail('ID anggota sama dengan isi berbeda. Data tidak ditimpa.',409);
      if(backup.simulation&&state.simulation&&canonicalInputs(backup.simulation.inputs)!==canonicalInputs(state.simulation.inputs))fail('Simulasi cadangan berbeda. Rencana tidak ditimpa.',409);
      if(backup.finance&&state.finance&&canonicalFinance(backup.finance.inputs)!==canonicalFinance(state.finance.inputs))fail('Rencana keuangan cadangan berbeda. Data tidak ditimpa.',409);
      const records=[...state.records,...backup.records.filter(r=>!recordMap.has(r.id))],members=[...state.members,...backup.members.filter(m=>!memberMap.has(m.id))];
      validateMembers(members);validateRecords(records,members);
      const added=records.length-state.records.length,membersAdded=members.length-state.members.length,simulationAdded=backup.simulation&&!state.simulation?1:0;
      const financeAdded=backup.finance&&!state.finance?1:0;
      state.records=records;state.recordCount=records.length;state.members=members;if(financeAdded)state.finance=backup.finance;if(simulationAdded)state.simulation=backup.simulation;
      return {status:200,body:{ok:true,added,skipped:backup.records.length-added,membersAdded,simulationAdded,financeAdded},changed:true};
    }
    return {status:404,body:{error:'Operasi tidak tersedia.'}};
  } catch(error) {return {status:(error as Error & {status?:number}).status||400,body:{error:(error as Error).message||'Data belum dapat diproses.'}};}
}

import {reportData,type RecordRow} from '../lib/report-data';
export type FinanceInput={basis:'actual'|'manual';profit:number;chairPercent:number;treasurerPercent:number;supervisorPercent:number;supervisorCount:number;from:string;to:string;note:string};
export type SavedFinance={inputs:FinanceInput;updatedAt:string};
export const defaultFinance=():FinanceInput=>({basis:'actual',profit:0,chairPercent:15,treasurerPercent:10,supervisorPercent:5,supervisorCount:1,from:'',to:'',note:''});
const percent=(value:unknown)=>typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=100&&Math.abs(value*100-Math.round(value*100))<0.000001;
const date=(v:unknown)=>typeof v==='string'&&(v===''||/^\d{4}-\d{2}-\d{2}$/.test(v)&&Number.isFinite(Date.parse(v))&&new Date(v+'T00:00:00Z').toISOString().slice(0,10)===v);
export function validFinance(value:unknown):value is FinanceInput{
 const v=value as FinanceInput;return !!v&&typeof v==='object'&&['actual','manual'].includes(v.basis)&&Number.isSafeInteger(v.profit)&&v.profit>=0&&percent(v.chairPercent)&&percent(v.treasurerPercent)&&percent(v.supervisorPercent)&&Math.round(v.chairPercent*100)+Math.round(v.treasurerPercent*100)+Math.round(v.supervisorPercent*100)<=10000&&Number.isInteger(v.supervisorCount)&&v.supervisorCount>=1&&v.supervisorCount<=100&&date(v.from)&&date(v.to)&&(!v.from||!v.to||v.from<=v.to)&&typeof v.note==='string'&&v.note.length<=1000;
}
export function canonicalFinance(v:FinanceInput){return JSON.stringify([v.basis,v.profit,v.chairPercent,v.treasurerPercent,v.supervisorPercent,v.supervisorCount,v.from,v.to,v.note]);}
export function readFinance(value:unknown):SavedFinance|null{if(value==null)return null;const p=value as SavedFinance;if(!validFinance(p.inputs)||typeof p.updatedAt!=='string'||!Number.isFinite(Date.parse(p.updatedAt)))throw Error('Pengaturan Keuangan tidak valid. Data tidak diganti.');return {inputs:{...p.inputs},updatedAt:p.updatedAt};}
export function splitProfit(amount:number,input:FinanceInput){
 if(!validFinance(input)||!Number.isSafeInteger(amount))throw Error('Periksa laba, persentase, tanggal, dan jumlah pengawas.');
 const profit=Math.max(0,amount),bps=(v:number)=>Math.round(v*100),share=(v:number)=>Number(BigInt(profit)*BigInt(bps(v))/BigInt(10000));
 const chair=share(input.chairPercent),treasurer=share(input.treasurerPercent),supervisors=share(input.supervisorPercent),honor=chair+treasurer+supervisors,capital=profit-honor;
 const perSupervisor=Math.floor(supervisors/input.supervisorCount),supervisorRemainder=supervisors-perSupervisor*input.supervisorCount;
 return {profit,chair,treasurer,supervisors,honor,capital,perSupervisor,supervisorRemainder,honorPercent:(bps(input.chairPercent)+bps(input.treasurerPercent)+bps(input.supervisorPercent))/100,capitalPercent:(10000-bps(input.chairPercent)-bps(input.treasurerPercent)-bps(input.supervisorPercent))/100};
}
/** FIFO by transaction date. Purchases on a day precede sales; same-day lots ordered by ID. */
export function profitFromRecords(rows:RecordRow[],from='',to=''){
 const data=reportData(rows,from,to),lots=new Map<string,{qty:number;cost:number}[]>();let cost=0,stockCost=0,missing=0;
 const ordered=rows.filter(r=>(!to||r.date<=to)&&['purchase','sale'].includes(r.type)).sort((a,b)=>a.date.localeCompare(b.date)||(a.type===b.type? a.id.localeCompare(b.id):a.type==='purchase'?-1:1));
 for(const r of ordered){const key=r.product.trim().toLowerCase(),batch=lots.get(key)||[];lots.set(key,batch);
  if(r.type==='purchase'){batch.push({qty:r.qty,cost:r.amount});continue;}
  let qty=r.qty,saleCost=0;while(qty>0.000001&&batch.length){const lot=batch[0],used=Math.min(qty,lot.qty),portion=used/lot.qty*lot.cost;saleCost+=portion;lot.cost-=portion;lot.qty-=used;qty-=used;if(lot.qty<0.000001)batch.shift();}
  if(qty>0.000001)missing+=qty;if(!from||r.date>=from)cost+=saleCost;
 }
 for(const batch of lots.values())stockCost+=batch.reduce((n,lot)=>n+lot.cost,0);
 const cogs=Math.round(cost),profit=data.sales-cogs-data.expenses;
 return {sales:data.sales,cogs,expenses:data.expenses,profit,stockCost:Math.round(stockCost),cash:data.cash,debt:data.debtTotal,credit:data.creditTotal,missing,complete:missing<0.000001};
}

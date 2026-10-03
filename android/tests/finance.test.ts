import {test} from 'node:test';
import assert from 'node:assert/strict';
import {defaultFinance,splitProfit,validFinance,profitFromRecords} from '../web/finance-data';
import {applyRequest,blankSnapshot,readSnapshot} from '../web/database';
import type {RecordRow} from '../../lib/report-data';
const record=(id:string,type:string,values:Partial<RecordRow>):RecordRow=>({id,type,date:'2026-10-03',name:'Uji',product:'',qty:0,amount:1,paid:0,ref:'',note:'',...values});
test('requested 15/10/5 allocation leaves exactly 70% capital',()=>{const result=splitProfit(1_000_000,defaultFinance());assert.deepEqual([result.chair,result.treasurer,result.supervisors,result.honor,result.capital],[150000,100000,50000,300000,700000]);assert.equal(result.honorPercent,30);assert.equal(result.capitalPercent,70);});
test('rounding and multiple supervisors preserve every rupiah; losses never fund honor',()=>{const input={...defaultFinance(),supervisorCount:3};const r=splitProfit(100001,input);assert.equal(r.honor+r.capital,100001);assert.equal(r.perSupervisor*3+r.supervisorRemainder,r.supervisors);assert.equal(splitProfit(-1000,input).honor,0);assert.equal(splitProfit(-1000,input).capital,0);const large=splitProfit(Number.MAX_SAFE_INTEGER,{...input,chairPercent:100,treasurerPercent:0,supervisorPercent:0});assert.equal(large.chair,Number.MAX_SAFE_INTEGER);assert.equal(large.capital,0);});
test('reject percentage overflow, third decimal, impossible date and invalid supervisor count',()=>{const d=defaultFinance();for(const invalid of [{...d,chairPercent:90},{...d,chairPercent:15.001},{...d,supervisorCount:0},{...d,profit:NaN},{...d,from:'2026-02-30'},{...d,from:'2026-10-03',to:'2026-10-02'}])assert.equal(validFinance(invalid),false);assert.equal(validFinance({...d,chairPercent:15.25}),true);});
test('FIFO deducts sold stock once; bank and subsequent payments never count as profit',()=>{
 const rows=[record('p1','purchase',{date:'2026-10-01',product:'Urea',qty:100,amount:100000}),record('p2','purchase',{date:'2026-10-02',product:'Urea',qty:100,amount:200000}),record('s','sale',{product:'Urea',qty:150,amount:400000,paid:100000}),record('e','expense',{amount:20000}),record('w','withdraw',{amount:10000000}),record('pay','pay',{ref:'p1',amount:50000}),record('collect','collect',{date:'2026-10-04',ref:'s',amount:200000})];
 const p=profitFromRecords(rows);assert.equal(p.cogs,200000);assert.equal(p.profit,180000);assert.equal(p.stockCost,100000);assert.equal(p.credit,100000);assert.equal(p.debt,250000);assert.equal(p.cash,10230000);
 const later=profitFromRecords(rows,'2026-10-04','2026-10-04');assert.equal(later.profit,0);assert.equal(later.cogs,0);assert.equal(later.stockCost,100000);
 assert.equal(profitFromRecords([record('s','sale',{date:'2026-10-01',product:'Urea',qty:50,amount:100000}),record('p','purchase',{date:'2026-10-02',product:'Urea',qty:50,amount:50000})]).complete,false);
});
test('same-day purchases precede sales and products have independent cost queues',()=>{const rows=[record('s','sale',{product:'Urea',qty:25,amount:60000}),record('p','purchase',{product:'Urea',qty:50,amount:100000}),record('pp','purchase',{product:'Phoska',qty:50,amount:250000})];const p=profitFromRecords(rows);assert.equal(p.cogs,50000);assert.equal(p.profit,10000);assert.equal(p.stockCost,300000);assert.equal(p.complete,true);});
test('save finance uses conflict guard and complete backups preserve plans; legacy data still opens',()=>{
 const s=blankSnapshot(),inputs={...defaultFinance(),basis:'manual' as const,profit:1000000};
 assert.equal(applyRequest(s,'/api/finance','PUT',{inputs,updatedAt:null}).status,200);assert.ok(s.finance);assert.equal(s.recordCount,0);assert.equal(applyRequest(s,'/api/finance','PUT',{inputs,updatedAt:null}).status,409);
 const backup=readSnapshot(JSON.parse(JSON.stringify(s))),empty=blankSnapshot();assert.equal(applyRequest(empty,'/api/backup','POST',backup).status,200);assert.deepEqual(empty.finance,s.finance);
 const before=JSON.stringify(empty);backup.finance!.inputs.chairPercent=20;assert.equal(applyRequest(empty,'/api/backup','POST',backup).status,409);assert.equal(JSON.stringify(empty),before);
 const legacy=blankSnapshot();delete legacy.finance;assert.equal(readSnapshot(legacy).finance,null);assert.throws(()=>readSnapshot({...s,finance:{inputs:{...inputs,chairPercent:100},updatedAt:s.finance!.updatedAt}}));
});

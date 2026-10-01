export type RecordRow={id:string;type:string;date:string;name:string;product:string;qty:number;sacks?:number;unit_price?:number;unitPrice?:number;amount:number;paid:number;ref:string;note:string;receipt_name?:string;receipt_data?:string;sale_kind?:string;member_id?:string;receiptName?:string;receiptData?:string};
export const labels:Record<string,string>={withdraw:'Penarikan bank',purchase:'Pupuk masuk',expense:'Biaya operasional',sale:'Penjualan petani',pay:'Bayar distributor',collect:'Terima pelunasan'};
export function cashFlow(r:RecordRow){return r.type==='withdraw'||r.type==='collect'?r.amount:r.type==='sale'?r.paid:r.type==='purchase'?-r.paid:r.type==='pay'||r.type==='expense'?-r.amount:0;}
export function reportData(all:RecordRow[],from='',to=''){
 const selected=all.filter(r=>(!from||r.date>=from)&&(!to||r.date<=to)).sort((a,b)=>a.date.localeCompare(b.date)||a.id.localeCompare(b.id));
 const ending=all.filter(r=>!to||r.date<=to),before=all.filter(r=>from&&r.date<from);
 const remaining=(r:RecordRow)=>r.amount-r.paid-ending.filter(p=>p.ref===r.id&&(p.type==='pay'||p.type==='collect')).reduce((n,p)=>n+p.amount,0);
 const cash=ending.reduce((n,r)=>n+cashFlow(r),0),opening=before.reduce((n,r)=>n+cashFlow(r),0);
 const receipts=selected.reduce((n,r)=>n+Math.max(0,cashFlow(r)),0),payments=selected.reduce((n,r)=>n+Math.max(0,-cashFlow(r)),0);
 const debts=ending.filter(r=>r.type==='purchase').map(r=>({...r,remaining:remaining(r)}));
 const credits=ending.filter(r=>r.type==='sale').map(r=>({...r,remaining:remaining(r)}));
 const products=Array.from(new Set(ending.filter(r=>r.product).map(r=>r.product)));
 const stock=products.map(product=>({product,incoming:ending.filter(r=>r.product===product&&r.type==='purchase').reduce((n,r)=>n+r.qty,0),outgoing:ending.filter(r=>r.product===product&&r.type==='sale').reduce((n,r)=>n+r.qty,0)})).map(r=>{const incomingSacks=ending.filter(t=>t.product===r.product&&t.type==='purchase').reduce((n,t)=>n+(t.sacks||t.qty/50),0),outgoingSacks=ending.filter(t=>t.product===r.product&&t.type==='sale').reduce((n,t)=>n+(t.sacks||t.qty/50),0);return {...r,balance:r.incoming-r.outgoing,incomingSacks,outgoingSacks,balanceSacks:incomingSacks-outgoingSacks};});
 return {transactionTotal:selected.reduce((n,r)=>n+cashFlow(r),0),selected,ending,cash,opening,receipts,payments,debts,credits,stock,debtTotal:debts.reduce((n,r)=>n+r.remaining,0),creditTotal:credits.reduce((n,r)=>n+r.remaining,0),sales:selected.filter(r=>r.type==='sale').reduce((n,r)=>n+r.amount,0),purchases:selected.filter(r=>r.type==='purchase').reduce((n,r)=>n+r.amount,0),expenses:selected.filter(r=>r.type==='expense').reduce((n,r)=>n+r.amount,0)};
}

export type Member={id:string;name:string;nik:string;farmer_group:string;address:string;updated_at:string};
export function validMember(x:any){return x&&typeof x.name==='string'&&!!x.name.trim()&&x.name.length<=200&&typeof x.nik==='string'&&(!x.nik||/^\d{16}$/.test(x.nik))&&typeof x.farmer_group==='string'&&x.farmer_group.length<=200&&typeof x.address==='string'&&x.address.length<=1000;}

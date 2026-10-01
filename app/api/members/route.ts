import {ensureSchema} from '@/lib/ensure-schema';
import {validMember,type Member} from '@/lib/member-data';
const headers={'Cache-Control':'private, no-store'};
export async function GET(){try{const d=await ensureSchema();return Response.json((await d.prepare('SELECT * FROM members ORDER BY name COLLATE NOCASE,id').all()).results,{headers});}catch(e){console.error(e);return Response.json({error:'Daftar anggota belum dapat dimuat.'},{status:503,headers});}}
async function save(req:Request,edit:boolean){try{
 if(req.headers.get('origin')!==new URL(req.url).origin)return Response.json({error:'Buka menu Anggota melalui aplikasi.'},{status:403,headers});
 const x=await req.json() as Member;if(!validMember(x)||edit&&(typeof x.id!=='string'||typeof x.updated_at!=='string'))return Response.json({error:'Isi nama. NIK harus kosong atau 16 digit. Periksa panjang isian.'},{status:400,headers});
 const d=await ensureSchema(),id=edit?x.id:crypto.randomUUID(),stamp=new Date().toISOString();
 const result=edit?await d.prepare("UPDATE members SET name=?,nik=?,farmer_group=?,address=?,updated_at=? WHERE id=? AND updated_at=? AND (?='' OR NOT EXISTS(SELECT 1 FROM members WHERE nik=? AND id<>?))").bind(x.name.trim(),x.nik,x.farmer_group.trim(),x.address.trim(),stamp,id,x.updated_at,x.nik,x.nik,id).run():await d.prepare("INSERT INTO members (id,name,nik,farmer_group,address,updated_at) SELECT ?,?,?,?,?,? WHERE ?='' OR NOT EXISTS(SELECT 1 FROM members WHERE nik=?)").bind(id,x.name.trim(),x.nik,x.farmer_group.trim(),x.address.trim(),stamp,x.nik,x.nik).run();
 if(!result.meta.changes)return Response.json({error:'NIK sudah digunakan atau data anggota berubah. Muat ulang sebelum mengedit.'},{status:409,headers});
 return Response.json({ok:true,id},{headers});
 }catch(e){console.error(e);return Response.json({error:'Anggota belum dapat disimpan. Isian tetap tersedia.'},{status:503,headers});}}
export async function POST(req:Request){return save(req,false);}
export async function PATCH(req:Request){return save(req,true);}

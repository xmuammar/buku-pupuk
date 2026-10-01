import {env} from 'cloudflare:workers';
export async function ensureSchema(){
 if(!env.DB)throw Error('Penyimpanan belum tersedia');const d=env.DB;
 await d.prepare("CREATE TABLE IF NOT EXISTS members (id TEXT PRIMARY KEY,name TEXT NOT NULL,nik TEXT NOT NULL DEFAULT '',farmer_group TEXT NOT NULL DEFAULT '',address TEXT NOT NULL DEFAULT '',updated_at TEXT NOT NULL)").run();
 for(const sql of ["ALTER TABLE records ADD COLUMN sacks REAL NOT NULL DEFAULT 0","ALTER TABLE records ADD COLUMN unit_price INTEGER NOT NULL DEFAULT 0","ALTER TABLE records ADD COLUMN receipt_name TEXT NOT NULL DEFAULT ''","ALTER TABLE records ADD COLUMN receipt_data TEXT NOT NULL DEFAULT ''","ALTER TABLE records ADD COLUMN sale_kind TEXT NOT NULL DEFAULT ''","ALTER TABLE records ADD COLUMN member_id TEXT NOT NULL DEFAULT ''"]){try{await d.prepare(sql).run();}catch(e){if(!String(e).includes('duplicate column'))throw e;}}
 return d;
}

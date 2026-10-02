import {env} from 'cloudflare:workers';
import {canonicalInputs, validSavedSimulation, validSimulationInput, type SavedSimulation} from '@/lib/simulation';

const headers = {'Cache-Control': 'private, no-store'};
type StoredPlan = {inputs: string; updated_at: string};
export async function GET() {
  try {
    if (!env.DB) throw Error('DB missing');
    const row = await env.DB.prepare("SELECT inputs,updated_at FROM simulation_settings WHERE id='utama'").first<StoredPlan>();
    const plan: SavedSimulation | null = row ? {inputs: JSON.parse(row.inputs), updatedAt: row.updated_at} : null;
    if (plan && !validSavedSimulation(plan)) throw Error('Invalid saved plan');
    return Response.json({plan}, {headers});
  } catch (error) {
    console.error(error);
    return Response.json({error: 'Simulasi tersimpan belum dapat dimuat. Coba lagi.'}, {status: 503, headers});
  }
}
export async function PUT(req: Request) {
  try {
    if (req.headers.get('origin') !== new URL(req.url).origin) return Response.json({error: 'Buka simulasi melalui aplikasi.'}, {status: 403, headers});
    const body = await req.text();
    if (body.length > 10_000) return Response.json({error: 'Isian simulasi terlalu besar.'}, {status: 413, headers});
    let data: any;
    try {data = JSON.parse(body);} catch {return Response.json({error: 'Isian simulasi tidak dapat dibaca.'}, {status: 400, headers});}
    if (!validSimulationInput(data?.inputs) || data.updatedAt !== null && (typeof data.updatedAt !== 'string' || Number.isNaN(Date.parse(data.updatedAt)))) {
      return Response.json({error: 'Periksa isian simulasi. Angka tidak boleh negatif atau melebihi batas.'}, {status: 400, headers});
    }
    if (!env.DB) throw Error('DB missing');
    const stamp = new Date(Math.max(Date.now(), data.updatedAt === null ? 0 : Date.parse(data.updatedAt) + 1)).toISOString(), inputs = canonicalInputs(data.inputs);
    // Compare the loaded revision atomically, including first save, so another device's plan cannot be overwritten silently.
    const result = data.updatedAt === null
      ? await env.DB.prepare("INSERT INTO simulation_settings (id,inputs,updated_at) VALUES ('utama',?,?) ON CONFLICT(id) DO NOTHING").bind(inputs, stamp).run()
      : await env.DB.prepare("UPDATE simulation_settings SET inputs=?,updated_at=? WHERE id='utama' AND updated_at=?").bind(inputs, stamp, data.updatedAt).run();
    if (!result.meta.changes) return Response.json({error: 'Simulasi telah berubah di perangkat lain. Muat versi tersimpan sebelum menyimpan lagi.'}, {status: 409, headers});
    return Response.json({ok: true, updatedAt: stamp}, {headers});
  } catch (error) {
    console.error(error);
    return Response.json({error: 'Simulasi belum dapat disimpan. Isian tetap tersedia.'}, {status: 503, headers});
  }
}

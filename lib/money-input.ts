export function formatMoneyInput(value:string){return value.replace(/\B(?=(\d{3})+(?!\d))/g,'.');}
export function parseMoneyInput(value:string):string|null{
 const cleaned=value.trim().replace(/^Rp\s*/i,'').replace(/\s/g,'').replace(/,0{1,2}$/,'');
 if(!/^[\d.]*$/.test(cleaned))return null;
 const raw=cleaned.replace(/\./g,'').replace(/^0+(?=\d)/,'');return raw.length<=15?raw:null;
}
export function cursorAfterDigits(value:string,count:number){if(count===0)return 0;let seen=0;for(let i=0;i<value.length;i++){if(/\d/.test(value[i]))seen++;if(seen===count)return i+1;}return value.length;}

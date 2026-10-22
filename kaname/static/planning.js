'use strict';
let inventory=null, planningBusy=false, inventoryEdit='', planningRequest=0;
const modeNames={manual:'Manual',read_only:'Read Only',managed:'Managed',import:'Import'};
function planningControls(){
  $('inventory-save').disabled=planningBusy||!inventory||!can('network.devices',true);
  $('inventory-list').querySelectorAll('button').forEach(x=>x.disabled=planningBusy||!can('network.devices',true));
  $('inventory-refresh').disabled=planningBusy;
}
function resetPlanning(){planningRequest++;inventory=null;planningBusy=false;inventoryEdit='';$('inventory-list').replaceChildren();$('inventory-count').textContent='';$('inventory-form').reset();$('inventory-query').value='';$('inventory-mode-filter').value='';$('inventory-editor').open=false;inventoryMode();planningControls();}
async function openPlanning(id){if(id==='network-devices')run(()=>loadInventory());}
async function loadInventory(){
  if(!can('network.devices'))return;
  const request=++planningRequest;inventory=null;planningControls();
  const value=await api('/api/network/devices');if(request!==planningRequest)return;
  inventory=value;renderInventory();planningControls();
}
function actionButton(label,callback){const button=document.createElement('button');button.type='button';button.textContent=label;button.disabled=planningBusy;button.addEventListener('click',()=>run(callback));return button;}
function renderInventory(){
  const parent=$('inventory-list');parent.replaceChildren();const q=$('inventory-query').value.trim().toLocaleLowerCase('tr'),mode=$('inventory-mode-filter').value;
  const items=(inventory?.items||[]).filter(x=>(!mode||x.management_mode===mode)&&[x.name,x.vendor,x.model,x.ip,x.location].join(' ').toLocaleLowerCase('tr').includes(q));
  $('inventory-count').textContent=items.length+' / '+(inventory?.items.length||0)+' cihaz · Bağlantı etkin değil';
  for(const x of items){const row=document.createElement('article');row.className='inventory-row';const info=document.createElement('div'),title=document.createElement('strong'),detail=document.createElement('p'),status=document.createElement('small');title.textContent=x.name;detail.textContent=[x.vendor,x.model,x.ip||'IP belirtilmedi',x.location].filter(Boolean).join(' · ');status.textContent=modeNames[x.management_mode]+' · '+({direct:'Direct',cloud:'Cloud',none:'Bağlantı yok'}[x.connection_type])+' · Envanter kaydı';info.append(title,detail,status);row.append(info);
    if(can('network.devices',true)){const actions=document.createElement('div');actions.className='actions';actions.append(actionButton('Düzenle',async()=>editInventory(x)),actionButton('Sil',async()=>{if(confirm('“'+x.name+'” envanter kaydı silinsin mi?'))await planningMutation('/api/network/devices/delete',{id:x.id},inventory.revision,'inventory');}));row.append(actions);}parent.append(row);
  }if(!items.length){const p=document.createElement('p');p.textContent=inventory?.items.length?'Filtreye uygun cihaz yok.':'Henüz cihaz kaydı yok. Aşağıdan ilk cihazınızı ekleyin.';parent.append(p);}
}
function editInventory(x){inventoryEdit=x.id;$('inventory-form-title').textContent='Cihazı düzenle';for(const [id,key] of Object.entries({name:'name',type:'device_type',vendor:'vendor',model:'model',ip:'ip',location:'location',mode:'management_mode',connection:'connection_type',notes:'notes'}))$('inventory-'+id).value=x[key];inventoryMode();$('inventory-editor').open=true;$('inventory-name').focus();}
function inventoryMode(){const mode=$('inventory-mode').value,offline=['manual','import'].includes(mode);$('inventory-connection').disabled=offline;if(offline)$('inventory-connection').value='none';else if($('inventory-connection').value==='none')$('inventory-connection').value='direct';$('inventory-mode-help').textContent=offline?'Cihaz erişimi ve kimlik bilgisi gerekmez. Bu seçim envantere kaydedilir.':'Bağlantı tercihi kaydedilir. SSH / API bağlantısı ve parola kaydı bu sürümde etkin değildir.';}
function cancelInventory(){inventoryEdit='';$('inventory-form').reset();$('inventory-form-title').textContent='Yeni cihaz ekle';inventoryMode();}
async function planningMutation(path,payload,revision){if(planningBusy)return;planningBusy=true;planningControls();try{inventory=await api(path,{expected_revision:revision,...payload});renderInventory();cancelInventory();await refresh();message('Envanter kaydedildi. Cihaz bağlantısı kurulmadı.');}catch(error){await loadInventory();throw error;}finally{planningBusy=false;planningControls();}}
$('inventory-form').addEventListener('submit',event=>{event.preventDefault();if(!inventory)return;const item={id:inventoryEdit};for(const [id,key]of Object.entries({name:'name',type:'device_type',vendor:'vendor',model:'model',ip:'ip',location:'location',mode:'management_mode',connection:'connection_type',notes:'notes'}))item[key]=$('inventory-'+id).value.trim();run(()=>planningMutation('/api/network/devices/save',{item},inventory.revision,'inventory'));});
$('inventory-mode').addEventListener('change',inventoryMode);$('inventory-cancel').addEventListener('click',cancelInventory);$('inventory-query').addEventListener('input',renderInventory);$('inventory-mode-filter').addEventListener('change',renderInventory);$('inventory-refresh').addEventListener('click',()=>run(()=>loadInventory()));
inventoryMode();planningControls();

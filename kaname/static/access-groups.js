'use strict';
let accessGroupPage=null,accessGroupBusy=false,accessGroupRequest=0,accessGroupId='',accessGroupRevision=null;
let accessGroupMembers=new Map(),accessGroupPickerMembers=new Map(),accessMemberRequest=0,accessMemberBusy=false,accessMemberOffset=0,accessMemberTotal=0;
function accessGroupReadable(){return can('directory.catalog')||can('policies.rules');}
function accessGroupPermissions(){
  const write=can('policies.rules',true),read=accessGroupReadable();
  $('access-groups-section').hidden=!read;$('access-group-new').hidden=!write;
  $('access-group-new').disabled=accessGroupBusy||!accessGroupPage;
  $('access-group-refresh').disabled=accessGroupBusy;
  for(const id of ['access-group-name','access-group-kind','access-group-pick','access-group-save'])$(id).disabled=!write||accessGroupBusy;
  $('access-group-save').hidden=!write;$('access-group-close').disabled=accessGroupBusy;
  $('access-group-list').querySelectorAll('button').forEach(b=>b.disabled=accessGroupBusy);
  $('access-group-selected').querySelectorAll('button').forEach(b=>b.disabled=!write||accessGroupBusy);
  $('access-group-member-previous').disabled=accessMemberBusy||accessMemberOffset===0;
  $('access-group-member-next').disabled=accessMemberBusy||accessMemberOffset+100>=accessMemberTotal;
  if(!read&&$('access-group-editor').open)closeAccessGroup();
}
function resetAccessGroups(){accessGroupRequest++;accessMemberRequest++;accessGroupBusy=false;accessMemberBusy=false;accessGroupPage=null;closeAccessGroup();$('access-group-list').replaceChildren();$('access-group-status').textContent='';$('access-group-query').value='';}
async function loadAccessGroups(){
  if(!accessGroupReadable())return;
  const request=++accessGroupRequest,generation=authGeneration;
  const page=await api('/api/access-groups');
  if(request!==accessGroupRequest||generation!==authGeneration||!accessGroupReadable())return;
  accessGroupPage=page;renderAccessGroups();accessGroupPermissions();
}
function groupButton(label,fn){const b=document.createElement('button');b.type='button';b.textContent=label;b.addEventListener('click',()=>run(fn));return b;}
function renderAccessGroups(){
  const parent=$('access-group-list');parent.replaceChildren();
  const query=$('access-group-query').value.trim().toLocaleLowerCase('tr');
  const items=(accessGroupPage?.items||[]).filter(g=>g.name.toLocaleLowerCase('tr').includes(query));
  $('access-group-status').textContent=items.length+' / '+(accessGroupPage?.items.length||0)+' AuthWire grubu';
  const table=document.createElement('table');table.className='identity-table';
  const head=document.createElement('thead'),tr=document.createElement('tr');
  for(const label of ['Grup Adı','Kullanıcı','Bilgisayar','Toplam Üye','İşlem']){const th=document.createElement('th');th.scope='col';th.textContent=label;tr.append(th);}head.append(tr);table.append(head);
  const body=document.createElement('tbody');
  for(const group of items){
    const row=document.createElement('tr'),name=document.createElement('td');
    name.append(groupButton(group.name,()=>openAccessGroup(group.id)));row.append(name);
    for(const value of [group.user_count,group.computer_count,group.member_count]){const cell=document.createElement('td');cell.textContent=String(value);row.append(cell);}
    const actions=document.createElement('td');actions.append(groupButton(can('policies.rules',true)?'Düzenle':'Üyeleri gör',()=>openAccessGroup(group.id)));
    if(can('policies.rules',true))actions.append(groupButton('Sil',()=>deleteAccessGroup(group)));
    row.append(actions);body.append(row);
  }
  if(!items.length){const row=document.createElement('tr'),cell=document.createElement('td');cell.colSpan=5;cell.textContent=accessGroupPage?.items.length?'Aramanıza uygun grup yok.':'Henüz AuthWire grubu yok.';row.append(cell);body.append(row);}
  table.append(body);parent.append(table);
}
function closeAccessGroupPicker(commit=false){
  accessMemberRequest++;accessMemberBusy=false;
  if(commit){accessGroupMembers=new Map(accessGroupPickerMembers);renderAccessGroupMembers();}
  accessGroupPickerMembers.clear();$('access-group-picker').hidden=true;$('access-group-main').inert=false;$('access-group-member-list').replaceChildren();
  if($('access-group-editor').open)$('access-group-pick').focus();
}
function closeAccessGroup(){
  closeAccessGroupPicker();if($('access-group-editor').open)$('access-group-editor').close();
  accessGroupId='';accessGroupRevision=null;accessGroupMembers.clear();$('access-group-form').reset();$('access-group-selected').replaceChildren();$('access-group-error').textContent='';
}
function renderAccessGroupMembers(){
  const parent=$('access-group-selected');parent.replaceChildren();
  for(const [guid,item]of accessGroupMembers){const chip=groupButton((item.kind==='user'?'Kullanıcı · ':'Bilgisayar · ')+(item.name||guid)+(item.available===false?' · AD kaydı yok':'')+' ×',()=>{accessGroupMembers.delete(guid);renderAccessGroupMembers();});chip.className='rule-chip';chip.setAttribute('aria-label',(item.name||guid)+' üyeliğini kaldır');parent.append(chip);}
  accessGroupPermissions();
}
async function openAccessGroup(id=''){
  if(accessGroupBusy||!accessGroupReadable()||!id&&!can('policies.rules',true))return;
  const generation=authGeneration;closeAccessGroup();
  const request=++accessGroupRequest;
  const value=id?await api('/api/access-groups?id='+encodeURIComponent(id)):await api('/api/access-groups');
  if(generation!==authGeneration||request!==accessGroupRequest||!accessGroupReadable())return;
  accessGroupId=id;accessGroupRevision=value.revision;
  $('access-group-title').textContent=id?'AuthWire Grubu':'Yeni AuthWire Grubu';$('access-group-name').value=value.group?.name||'';
  accessGroupMembers=new Map((value.members||[]).map(m=>[m.guid,m]));renderAccessGroupMembers();
  $('access-group-editor').showModal();accessGroupPermissions();$('access-group-name').focus();
}
function openAccessGroupPicker(){
  if(accessGroupBusy||!can('policies.rules',true))return;
  accessGroupPickerMembers=new Map(accessGroupMembers);accessMemberOffset=0;accessMemberTotal=0;$('access-group-member-query').value='';
  $('access-group-picker-title').textContent=$('access-group-kind').value==='user'?'Kullanıcı seçimi':'Bilgisayar seçimi';
  $('access-group-main').inert=true;$('access-group-picker').hidden=false;$('access-group-member-query').focus();run(()=>loadAccessGroupCandidates());
}
async function loadAccessGroupCandidates(){
  if($('access-group-picker').hidden||!can('policies.rules',true))return;
  const request=++accessMemberRequest,generation=authGeneration;accessMemberBusy=true;
  $('access-group-member-list').replaceChildren();$('access-group-member-status').textContent='Hesaplar yükleniyor…';accessGroupPermissions();
  try{
    const page=await api('/api/policies/targets?kind='+$('access-group-kind').value+'&offset='+accessMemberOffset+'&q='+encodeURIComponent($('access-group-member-query').value.trim()));
    if(request!==accessMemberRequest||generation!==authGeneration||$('access-group-picker').hidden)return;
    accessMemberTotal=page.total;
    for(const obj of page.items){const item={...obj,kind:$('access-group-kind').value},label=document.createElement('label'),box=document.createElement('input'),copy=document.createElement('span'),name=document.createElement('strong'),sam=document.createElement('small');
      box.type='checkbox';box.checked=accessGroupPickerMembers.has(item.guid);box.value=item.guid;name.textContent=item.name;sam.textContent=item.sam;copy.append(name,sam);
      box.addEventListener('change',()=>{if(box.checked){if(accessGroupPickerMembers.size>=500){box.checked=false;message('Bir grupta en fazla 500 üye seçebilirsiniz.','error');return;}accessGroupPickerMembers.set(item.guid,item);}else accessGroupPickerMembers.delete(item.guid);$('access-group-selection-count').textContent=accessGroupPickerMembers.size+' üye seçildi';});label.append(box,copy);$('access-group-member-list').append(label);
    }
    $('access-group-selection-count').textContent=accessGroupPickerMembers.size+' üye seçildi';
    $('access-group-member-status').textContent=!page.catalog_available?'Önce AD listesini eşitleyin.':page.total?(accessMemberOffset+1)+'–'+Math.min(accessMemberOffset+page.items.length,page.total)+' / '+page.total:'Hesap bulunamadı.';
  }catch(error){if(request===accessMemberRequest){accessMemberTotal=0;$('access-group-member-status').textContent=error.message;}}
  finally{if(request===accessMemberRequest){accessMemberBusy=false;accessGroupPermissions();}}
}
async function saveAccessGroup(event){
  event.preventDefault();if(accessGroupBusy||!can('policies.rules',true)||accessGroupRevision===null)return;
  accessGroupBusy=true;accessGroupPermissions();const generation=authGeneration;$('access-group-error').textContent='';
  try{
    await api('/api/access-groups/save',{expected_revision:accessGroupRevision,group:{id:accessGroupId,name:$('access-group-name').value.trim(),members:[...accessGroupMembers.values()].map(m=>({guid:m.guid,kind:m.kind}))}});
    if(generation!==authGeneration)return;
    closeAccessGroup();message('AuthWire grubu kaydedildi. AD üyelikleri korunuyor.');
    try{await loadAccessGroups();await refresh();if(can('policies.rules'))await loadGroups();}catch(error){message('Grup kaydedildi; listeyi yenilemek için Yenile düğmesini kullanın. '+error.message,'error');}
  }catch(error){if(generation===authGeneration){$('access-group-error').textContent=error.message+(error.code==='REVISION_CONFLICT'?' Pencereyi kapatıp güncel kaydı yeniden açın.':'');message(error.message,'error');}}
  finally{if(generation===authGeneration){accessGroupBusy=false;accessGroupPermissions();}}
}
async function deleteAccessGroup(group){
  if(accessGroupBusy||!can('policies.rules',true)||!confirm('“'+group.name+'” grubu ve yerel üyelikleri silinsin mi?'))return;
  const generation=authGeneration;accessGroupBusy=true;accessGroupPermissions();
  try{await api('/api/access-groups/delete',{expected_revision:accessGroupPage.revision,id:group.id});if(generation!==authGeneration)return;await loadAccessGroups();await refresh();message('AuthWire grubu silindi.');}
  finally{if(generation===authGeneration){accessGroupBusy=false;accessGroupPermissions();}}
}
$('access-group-new').addEventListener('click',()=>run(()=>openAccessGroup()));
$('access-group-refresh').addEventListener('click',()=>run(()=>loadAccessGroups()));
$('access-group-query').addEventListener('input',renderAccessGroups);
$('access-group-close').addEventListener('click',()=>{if(!accessGroupBusy)closeAccessGroup();});
$('access-group-form').addEventListener('submit',saveAccessGroup);
$('access-group-pick').addEventListener('click',openAccessGroupPicker);
$('access-group-picker-cancel').addEventListener('click',()=>closeAccessGroupPicker());
$('access-group-picker-done').addEventListener('click',()=>closeAccessGroupPicker(true));
$('access-group-member-search').addEventListener('click',()=>{accessMemberOffset=0;run(()=>loadAccessGroupCandidates());});
$('access-group-member-query').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();$('access-group-member-search').click();}});
$('access-group-member-previous').addEventListener('click',()=>{accessMemberOffset=Math.max(0,accessMemberOffset-100);run(()=>loadAccessGroupCandidates());});
$('access-group-member-next').addEventListener('click',()=>{accessMemberOffset+=100;run(()=>loadAccessGroupCandidates());});
$('access-group-editor').addEventListener('cancel',e=>{e.preventDefault();if(accessGroupBusy)return;if(!$('access-group-picker').hidden)closeAccessGroupPicker();else closeAccessGroup();});
$('access-group-editor').addEventListener('keydown',e=>{if(e.key!=='Tab'||$('access-group-picker').hidden)return;const elements=[...$('access-group-picker').querySelectorAll('input,button')].filter(x=>!x.disabled),first=elements[0],last=elements.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}});
accessGroupPermissions();

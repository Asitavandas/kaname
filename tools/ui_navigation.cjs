'use strict';
// Exercise the real circular group buttons before selecting an allowed page.
async function navigate(page,view){
 if(await page.locator('#nav-toggle').getAttribute('aria-expanded')!=='true')await page.locator('#nav-toggle').click();
 const item=page.locator('[data-view="'+view+'"]');
 const group=page.locator('.nav-group').filter({has:item});
 if(await group.count()){
  const heading=group.locator('.nav-heading');
  if(await heading.getAttribute('aria-expanded')!=='true')await heading.click();
 }
 await item.click();
}
module.exports={navigate};

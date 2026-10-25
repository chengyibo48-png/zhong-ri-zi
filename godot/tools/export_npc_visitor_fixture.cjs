const path=require('node:path'),{spawnSync}=require('node:child_process');
const r=spawnSync(process.execPath,[path.join(__dirname,'export_npc_schedule_fixture.cjs'),process.argv[2],'--visitors'],{stdio:'inherit'});
if(r.error)throw r.error;process.exit(r.status===null?1:r.status);

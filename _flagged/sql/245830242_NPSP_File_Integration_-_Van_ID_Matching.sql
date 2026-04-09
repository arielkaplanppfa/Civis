--Get all Van IDs
Select value as alternate_id, account as accountid, contact as contactid
into #van_ids
from npsp_sfdc.alternate_id_v 
where type ='Van';

--lock table npsp_integration.file_detail_table;

--Update the account and contact ID fields 
update npsp_integration.file_detail_table 
set 
batch_upload_household_account_matched = Case when accountid is not null then accountid else null end, 
batch_upload_contact_1_matched = Case when contactid is not null then contactid else null end,   
contact_1_first_name = null,  contact_1_last_name = null, contact_1_middle_name = null  ---- case 02330320
from #van_ids v 
where file_detail_table.alternate_id = v.alternate_id
and file_detail_table.status = 'Van ID Matching' and file_detail_table.alternate_id is not null
and vendor_name = 'EveryAction'
;

commit;

--lock table npsp_integration.file_detail_table;

update npsp_integration.file_detail_table 
set status = 'Giving Number Matching'
where status = 'Van ID Matching';

commit;
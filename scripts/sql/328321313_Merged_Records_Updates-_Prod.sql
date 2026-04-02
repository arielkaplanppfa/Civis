--------- PROD -------------- PROD -------------- PROD -------------- PROD -------------- PROD ---------------- 
----- ACCOUNT UPDATE from ACCOUNT MERGES -----------
 with tempa as 
 (
select mla.object_c, rownumber, giving_name,batch_upload_household_account_matched, fdt.status as fdt_status, mla.status_c as merge_log_status,mla.loser_id_c, mla.winner_id_c, mla.winner_account_c, mla.winner_contact_c
from npsp_integration.file_detail_table fdt
join npsp_prod_sync.merge_log_c mla on mla.loser_id_c = fdt.batch_upload_household_account_matched
  and mla.object_c = 'Account'
  and mla.status_c = 'Merged'
  and mla.winner_id_c is not null
  and fdt.batch_upload_household_account_matched is not null
  and fdt.status = 'Merge Updates'
  order by giving_name, rownumber
)
select *
into #acctmerges
from tempa; 

update npsp_integration.file_detail_table 
set batch_upload_household_account_matched = winner_id_c
----select  rownumber, giving_name,batch_upload_household_account_matched , winner_id_c
from #acctmerges
  where #acctmerges.loser_id_c = npsp_integration.file_detail_table.batch_upload_household_account_matched
    and #acctmerges.giving_name = npsp_integration.file_detail_table.giving_name;


----- CONTACT UPDATE from CONTACT MERGES -----------
 with tempc as 
 (
 select mlc.object_c,rownumber, giving_name,batch_upload_contact_1_matched, fdt.status as fdt_status, mlc.status_c as merge_log_status, mlc.loser_id_c, mlc.winner_id_c, mlc.winner_account_c, mlc.winner_contact_c
 from npsp_integration.file_detail_table fdt
join npsp_prod_sync.merge_log_c mlc on mlc.loser_id_c = fdt.batch_upload_contact_1_matched
  and mlc.object_c = 'Contact'
  and mlc.status_c = 'Merged'
  and mlc.winner_id_c is not null
  and fdt.batch_upload_household_account_matched is not null
  and fdt.status = 'Merge Updates'
 order by giving_name, rownumber
 )
select *
into #contactmerges
from tempc; 

update npsp_integration.file_detail_table 
set batch_upload_contact_1_matched = winner_id_c
----select  rownumber, giving_name,batch_upload_contact_1_matched , winner_id 
from #contactmerges
  where #contactmerges.loser_id_c= npsp_integration.file_detail_table.batch_upload_contact_1_matched
    and #contactmerges.giving_name = npsp_integration.file_detail_table.giving_name;


----- SET FDT STATUS for MULESOFT -------------------
update npsp_integration.file_detail_table
set status = 'Van ID Matching'
where status = 'Merge Updates';

------------------------------------------------------------------------------------------------------------------------------------------------------------------------\
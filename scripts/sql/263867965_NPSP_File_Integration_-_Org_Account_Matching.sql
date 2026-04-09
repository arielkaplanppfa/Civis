-- Enter your SQL here.

--Make Temp table of accountid's and cleaned names
--In case of dupes choose the one with most gifts 
create table #accts as 
with temp as(
select distinct account.id as account_id, account.name, lower(regexp_replace(account.name, '[^a-zA-Z0-9]', '')) as sf_clean_name, count(distinct opps.record_id) as num_gifts
from npsp_sfdc.account_v account
left join ppfa_golden.golden_opportunities_npsp opps on account.id = opps.npsp_accountid
where account.record_type_id = '0123t00000118hoAAA'   --org record type id 
and account.is_deleted is false
group by 1,2,3),
rank as (
select account_id, name, sf_clean_name, num_gifts, row_number() over (partition by sf_clean_name order by num_gifts desc) as gift_rank
from temp   
)
select * 
from rank
where gift_rank = 1;

--select * from #accts where sf_clean_name = 'blackrock'

update npsp_integration.file_detail_table
set account_1_id = a.account_id
from #accts a 
where a.sf_clean_name = lower(regexp_replace(account_1_name, '[^a-zA-Z0-9]', ''))
and status = 'Account Matching' 
and account_1_id is null and account_1_name is not null 
and vendor_type not ilike '%tpa%'; --> Ariel K 6/20/24 --> Suppress TPA's from this matching


--TPA Lookup matching DS 3991 --> AK 4/26/24
update npsp_integration.file_detail_table
set account_1_id = a.npsp_tpa_employer_id
from npsp_integration.tpa_employer_lookup a 
where a.npsp_tpa_employer_name = account_1_name
and status = 'Account Matching' 
and account_1_id is null and account_1_name is not null and vendor_type ilike '%tpa%';

Update npsp_integration.file_detail_table 
set status = 'Ready for MuleSoft'
where status = 'Account Matching';
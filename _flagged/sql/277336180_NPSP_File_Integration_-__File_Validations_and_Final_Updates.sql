--------- NPSP Integration File Validations ------

------- SOURCE CODE MATCHES CAMPAIGN ID ----------
with temp as 
(select 'fdt table',fdt.campaign_source, fdt.batch_upload_campaign_matched,fdt.giving_name as fdt_giving_name, fdt.giving_primary_campaign_source,
'campaign_table', cv.id, cv.source_code, cv.unique_source_code
from npsp_sfdc.campaign_v cv
join npsp_integration.file_detail_table fdt on fdt.batch_upload_campaign_matched = cv.id
and cv.source_code <> giving_primary_campaign_source)
select *
into #sourcedata
from temp;

update npsp_integration.file_detail_table
set status = 'File Validation: CampaignID not correct for Source Code'
from #sourcedata s
where giving_name = s.fdt_giving_name
and status  not like 'Loaded%SFDC';

------- ADDRESS TYPE reset Personal to Home ----------
update npsp_integration.file_detail_table
set address_type = 'Home' 
where address_type ilike 'Personal%'
and status not like 'Loaded%SFDC';

------- EMAIL TYPE reset Home to Personal ----case 02330319------
update npsp_integration.file_detail_table
set contact_1_email_type = case when contact_1_email_type  ilike 'Home%' then 'Personal' else contact_1_email_type end,
    contact_2_email_type = case when contact_2_email_type  ilike 'Home%' then 'Personal' else contact_2_email_type end
where (contact_1_email_type ilike 'Home%' or contact_2_email_type ilike 'Home%')
and status not like 'Loaded%SFDC';

------- Fix EA Tribute bad data -- extra quotes causes rejected records in NPSP bulk load---------------------
update npsp_integration.file_detail_table
set tribute_name = replace(tribute_name, '"', '')
  , tribute_notification_recipient = replace(tribute_notification_recipient, '"', '')
where  (tribute_name is not null or tribute_type is not null)
and status not like 'Loaded%SFDC';

------- CASE 02371369 Reset LA 090000 affiliation to PPGP
--- DEPRECATED 3/17/26   
    --- temp update until zip-to-affil updates deployed in EA 
    --- not be deployed b/c PPGP waiting to make merger public  -------
---update npsp_integration.file_detail_table
---set  affiliate_number = '090740'
---where affiliate_number = '090000'
---and status not like 'Loaded%SFDC';


----- CASE 02365175 -- Set Recurring Donation Period based on EA values -- SF integration defaults to Monthly----
with temp as
(
select fdt.upload_date, crc.contactsrecurringcontributionid,recurring_donation_installment_period, 
case crc.recurringcontributionfrequencyid when '1' THEN 'Yearly' WHEN '6' then 'Weekly'  when '7' then 'Quarterly' ELSE NULL END
,recurringcontributionfrequencyid,fdt.sfdc_id,fdt.giving_name as fdt_giving_name
from npsp_integration.file_detail_table fdt
join vansync.ppfa_contactsrecurringcontributions_mym crc on fdt.alternate_id = crc.vanid and fdt.giving_recurring_id = crc.contactsrecurringcontributionid
join vansync.ppfa_recurringcontributionstatuses crcs on crcs.recurringcontributionstatusid = crc.recurringcontributionstatusid
where vendor_name = 'EveryAction'
and recurringcontributionfrequencyid <>  '3' -- SF DI Period defaults to Monthly 
and recurring_donation_installment_period is not null
and fdt.status not like 'Loaded%SFDC'
)
select *
into #installperiod
from temp;

update npsp_integration.file_detail_table
set  recurring_donation_installment_period = case recurringcontributionfrequencyid when '1' THEN 'Yearly' WHEN '6' then 'Weekly'  when '7' then 'Quarterly' ELSE NULL END
from #installperiod i
where giving_name = i.fdt_giving_name
and status not like 'Loaded%SFDC';
/****
---- CASE 02385776  --- Set Deceased Year Value 
with temp as 
(
select upload_date,status, giving_name, con.id as contact_id, con.deceased, con.deceased_day, con.deceased_month, con.deceased_year, fdt.contact_1_deceased_date, fdt.contact_1_deceased_flag,
      case when con.deceased_year is null then null  --all dec contacts should have dec year but just in case
           when con.deceased_year = 'Unknown' then 'Unknown'
           when con.deceased_month is null or con.deceased_day is null then replace(con.deceased_year||'-'||nvl(con.deceased_month,'')||'-'||nvl(con.deceased_day,''),'-','') 
           else con.deceased_year||'-'||nvl(con.deceased_month,'')||'-'||nvl(con.deceased_day,'')
           end as exist_deceased_date
      from npsp_integration.file_detail_table fdt
join npsp_sfdc.contact_v con on con.id = fdt.batch_upload_contact_1_matched
where con.deceased = true and fdt.contact_1_deceased_flag = false
)
select *
into #deceased
from temp;

update npsp_integration_test.file_detail_table
set contact_1_deceased_flag = true,
    contact_1_deceased_date = to_timestamp(d.exist_deceased_date ,'YYYY-MM-DD HH24:MI:SS')
from #deceased d 
where batch_upload_contact_1_matched = d.contact_id;  
*****/

----- CASE 02330318 -- Set Event_Id on the Data Import Record - eliminate existing flow  ---
with temp as 
(
select fdt.giving_name, ev.id as event_id, fdt.event_id as fdt_event_id, fdt.status, fdt.online_event_id
from  npsp_integration.file_detail_table fdt
join npsp_sfdc.event_v ev on ev.online_event_id = fdt.online_event_id
where 1=1 
and fdt.online_event_id is not null
and fdt.status not like 'Loaded%'
)
select *
into #events
from temp;

update npsp_integration.file_detail_table
set event_id = e.event_id
from #events e 
where npsp_integration.file_detail_table.online_event_id = e.online_event_id;
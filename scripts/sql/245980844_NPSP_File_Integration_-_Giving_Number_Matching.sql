--RecurID goes to recurring donation imported and Opp ID goes to dontion imported (opportunity vendor pledge number)
/*
Notes from meeting 4/2/24 
For Moore: --> FDT.Giving_number to Opportunity.Giving_Number__c  --AK 4/3/24 DONE
do we need to include in installment period check?? If we do need it then also include Moore  --AK 4/3/24 Commented out section for now 

Actblue: return the payment to fdt.credit_payment_id for the completed opportunity on the actublue account opp.giving_number = fdt.payment_receipt_id --AK 4/3/2024 DONE

*/
--Get all the relevant pledge numbers and indicate if it matches to a Recurring or an Opportunity
with temp as(
select 
sustaining_pledge_number as pledge_number, 
online_recurring_gift_id as online_recurring_id, --coalesce(External_ID, online_recurring_gift_id)  --AK 4/26/2024 Remove External ID --> This field is ONLY used by EA and External ID is not necessary
id as matched_id,
null as payment_matched_id,
null as sg_ext_id,
null as expected_revenue,
null as probability,
null as payment_amount,
'Recurring Donation' as Type
from npsp_sfdc.recurring_donation_v 
--where sustaining_pledge_number is not null --> DS-4037 Remove this
UNION
select o.giving_number,
'xxxx' as online_recurring_id, 
o.id as matched_id,
p.id as payment_matched_id,
o.Sustaining_Gift_External_ID as sg_ext_id,
o.expected_revenue, ---(CB 6/12/24) ---> DS-4094 payment should match to expected amount
o.probability,
p.payment_amount,
'Opportunity'  --Get one time pledges
from npsp_sfdc.opp_payment_v p 
join npsp_sfdc.opportunity_v o on p.opportunity = o.id
where 
 p.paid is false    --> limits to non cash/check, thats correct?
and o.stage_name = 'Active' 
and o.recurring_donation is null
--and o.pledge is true    -->AK 2/4/2024  --> Removed per email from Julia J pending confirmation 
--vendor_pledge_number is not null and    --> AK 4/26/24 DS 3943
)
select *
into #pledge_numbers
from temp;

--(CB 6/12/24) - Update STATUS field for giving numbers with multiple payments --> excludes these from payment_id updates below 
update npsp_integration.file_detail_table
set status = 'Multiple Payment Matches for Giving Number'
where lower(vendor_name) = 'moore'
and giving_number in 
   (select pledge_number from #pledge_numbers
    join npsp_integration.file_detail_table fdt on fdt.giving_number = #pledge_numbers.pledge_number
    where type = 'Opportunity' and pledge_number is not null
    group by pledge_number
    having count(payment_matched_id) > 1); 

    
--(CB 6/12/24) - Update STATUS field when expected amount <> giving amount
update npsp_integration.file_detail_table
set status = 'Giving Amount does not equal Expected Amount'
where lower(vendor_name) = 'moore'
and status <> 'Multiple Payment Matches for Giving Number'
and giving_number in 
   (select pledge_number from #pledge_numbers
    join npsp_integration.file_detail_table fdt on fdt.giving_number = #pledge_numbers.pledge_number
    where type = 'Opportunity' and pledge_number is not null
    and #pledge_numbers.payment_amount <> giving_amount);


-- Creating an ActBLUE Matching 
with ab as 
(
select o.giving_number, 
null as online_recurring_id, 
o.id as matched_id,
p.id as payment_matched_id,
o.Sustaining_Gift_External_ID as sg_ext_id,
'Opportunity'  --Get one time pledges
from npsp_sfdc.opp_payment_v p 
join npsp_sfdc.opportunity_v o on p.opportunity = o.id
where o.account_id = '0013t00002vcBl6AAE'
)
select *
into #act_blue
from ab;



/*Need to add mapping for Actblue and User Upload Sustainers*/
--EveryAction Specific Update
update npsp_integration.file_detail_table
set 
batch_upload_giving_matched = Case when matched_id is not null then matched_id else null end
from #pledge_numbers p 
where p.online_recurring_id = giving_recurring_id   --> AK 1/17/24 - Removed incorrect field (sustiner vendor pledge number)
and status = 'Giving Number Matching'   --> Status Check
and giving_new_giving_number is null --> If value here, then gift is new, so dont match
and vendor_name = 'EveryAction'    
and batch_upload_giving_matched is null
;


--ActBlue 
/*
Return Payment ID to giving matched. 
Opportunity_Vendor_Pledge_Number__c is the SF field specifically on Opp, work that into #pledge_numbers
Match on file_detail_table.payment_receipt_id
lower(Vendor_name) like 'ActBlue' or the incoming pledge number itself starts with AB
*/
update npsp_integration.file_detail_table
set 
credit_payment_id = Case when payment_matched_id is not null then payment_matched_id else null end
from #act_blue b 
-- Fixed reciept -> receipt typo: MO
--where b.giving_number = payment_receipt_id  --DS 3960
where b.giving_number = file_detail_table.giving_number  --DS 3960
and status = 'Giving Number Matching'  
and (vendor_name = 'ActBlue'  or payment_receipt_id like 'AB%' or file_detail_table.giving_number ilike 'ab%'); --DS 3960

--Update the appropriate fields on File Details table for non-everyaction records
--Telemarketing, Moore
update npsp_integration.file_detail_table
set 
batch_upload_giving_matched = 
Case 
when lower(vendor_name) = 'moore' and matched_id like '006%' then payment_matched_id --> Return payment Id when matched to Opp DS 4065
when matched_id is not null then matched_id else null end,
giving_record_type = 
case 
when lower(vendor_name) = 'moore' and matched_id like '006%' then 'GF'
when lower(vendor_name) = 'moore' and matched_id like 'a09%' then 'PL'
when lower(vendor_type) = 'telemarketing' then 'PL' else null  end  /*,  --> Commented this out until Rob S determines if needed
recurring_donation_installment_period  = 
Case 
when lower(vendor_type) = 'telemarketing' and matched_id like '006%' then 'One Payment'   
when lower(vendor_type) = 'telemarketing' and matched_id like 'a09%' then 'Monthly'    
else null end */
from #pledge_numbers p 
where p.pledge_number = giving_number
---and p.expected_revenue = giving_amount ---> DS-4094 payment should match to expected amount-- Requirement removed commented out 7/1/24
and status = 'Giving Number Matching'   --> Status Check
and giving_new_giving_number is null    --> If value here, then gift is new, so dont match
and vendor_name <> 'EveryAction' 
and batch_upload_giving_matched is null
;

--User Upload Sustainers
update npsp_integration.file_detail_table
set 
batch_upload_giving_matched = Case when matched_id is not null then matched_id else null end,
giving_record_type = 'PL'
from #pledge_numbers p 
where p.pledge_number = coalesce(giving_recurring_id,recurring_donation_vendor_pledge_number,opportunity_vendor_pledge_number)   --> Ariel K 3/25/2024 --> Change made to recurring.sustaining_pledge_number
and giving_new_giving_number is null    --> If value here, then gift is new, so dont match
and (lower(vendor_name) ='uu-sustainer' or lower(vendor_type) = 'uu-sustainer')
and batch_upload_giving_matched is null
;

/* DS-3939 -- Error out failed matches */
update npsp_integration.file_detail_table
set status = 'Giving Number Matching Failed'
where 
giving_number is not null 
and lower(vendor_name) in ('moore', 'telemarketing', 'actblue', 'credits', 'sustainers') --> EveryAction Excluded DS 4088
and status = 'Giving Number Matching'  --> Correct status
and credit_payment_id is null --> Failed credit matching
and batch_upload_giving_matched is null --> Matching has failed
;

-- Move everything else through to the next stage
update npsp_integration.file_detail_table
set status = 'Deposit Location'  
where status = 'Giving Number Matching';
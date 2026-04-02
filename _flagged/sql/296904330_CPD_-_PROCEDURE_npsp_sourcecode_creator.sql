/*
Status: Complete
Your name: ARonis
Sprint: 12/11/2024
Link to original C4G script: https://platform.civisanalytics.com/spa/#/scripts/sql/249842760
Link to asana task: https://app.asana.com/0/1208360680922942/1208360680922962/f
*/

-- --  BE SURE TO POPULATE custom_platform_development.npsp_sourcecode_import_template BEFORE RUNNING
-- --  results to upload: select * from custom_platform_development.v_npsp_sourcecode_dataloader_upload;


call custom_platform_development.npsp_sourcecode_creator();

TRUNCATE TABLE custom_platform_development.npsp_sourcecode_dataloader_upload_formatted;
INSERT INTO custom_platform_development.npsp_sourcecode_dataloader_upload_formatted
SELECT name,
source_code__c,
unique_source_code__c,
recordtypeid,
status,
CASE WHEN isactive = 1
                    THEN 'TRUE'
                    WHEN isactive = 0
                    THEN 'FALSE'
                    END isactive,
type,
description,
startdate,
general_accounting_unit__c,
merchant_name__c,
CASE WHEN override_source_format__c = 1
                    THEN 'TRUE'
                    WHEN override_source_format__c = 0
                    THEN 'FALSE'
                    END override_source_format__c,
package_code__c,
solicitor__c,
solicitation_list__c,
numbersent,
parent_campaign_name__c,
sc_tax_status_code__c,
sc_tax_status_description__c,
sc_office_code__c,
sc_office_description__c,
sc_program_code__c,
sc_program_description__c,
sc_restriction_code__c,
sc_restriction_description__c,
sc_calendar_year_code__c,
sc_calendar_year_description__c,
sc_calendar_month_code__c,
sc_calendar_month_description__c,
sc_channel_code__c,
sc_channel_description__c,
sc_package_detail__c,
campaign_channel__c,
long_comments__c
FROM custom_platform_development.v_npsp_sourcecode_dataloader_upload 
WHERE source_code__c NOT IN (SELECT NVL(source_code,'')
                              FROM custom_platform_development.npsp_sourcecode_dataloader_upload
                              WHERE error_msg IS NOT NULL)



/*
-- -- drop procedure custom_platform_development.npsp_sourcecode_creator();
CREATE or replace PROCEDURE custom_platform_development.npsp_sourcecode_creator()
LANGUAGE plpgsql
AS $$

-- -- ds-2063
-- -- campaign.type values
-- -- Advertisement
-- -- Email
-- -- Telemarketing
-- -- Banner Ads
-- -- Seminar / Conference
-- -- Public Relations
-- -- Partners
-- -- Referral Program
-- -- Other
-- -- Capital Campaign
-- -- Coalition
-- -- Organizational


DECLARE v_error_count INT;
declare i_raise_info varchar(800);


BEGIN

-- 10/7/24 add _fivetran_deleted is false 

DROP TABLE IF EXISTS custom_platform_development.npsp_sourcecode_dataloader_upload;

CREATE TABLE custom_platform_development.npsp_sourcecode_dataloader_upload
(error_msg varchar(200)
,name varchar(20)
,source_code varchar(20)
,unique_source_code varchar(20)
,recordtypeid varchar(18)
,status varchar(200)
,active boolean
,type varchar(200)
,description varchar(500)
,start_date date
,gau_name_provided varchar(80)
,gau_name_expected varchar(80)
,general_accounting_unit varchar(18)
,merchant_name varchar(200)
,override_source_format boolean
,package_code varchar(200)
,solicitor varchar(200)
,solicitation_list varchar(200)
,numbersent INT
,production_panel varchar(5)
,parent_campaign_name varchar(300)
,sc_tax_status_code varchar(5)
,sc_tax_status_description varchar(150)
,sc_office_code varchar(5)
,sc_office_description varchar(150)
,sc_program_code varchar(5)
,sc_program_description varchar(150)
,sc_restriction_code varchar(5)
,sc_restriction_description varchar(150)
,sc_calendar_year_code varchar(5)
,sc_calendar_year_description varchar(150)
,sc_calendar_month_code varchar(5)
,sc_calendar_month_description varchar(150)
,sc_channel_code varchar(5)
,sc_channel_description varchar(150)
,sc_package_detail varchar(5)
,long_comments varchar(500)
);

insert into custom_platform_development.npsp_sourcecode_dataloader_upload
SELECT CASE WHEN LENGTH(m.NAME) <> 14 THEN 'Source Code Format'
            WHEN m.DESCRIPTION IS NULL THEN 'Missing Description'
            WHEN m.General_Accounting_Unit IS NULL THEN 'No GAU matched'
            WHEN m.Gau_Name_Expected is null 
                 THEN 'GAU validation failed'
            WHEN m.Gau_Name_Provided is not null 
                 AND m.Gau_Name_Provided <> m.Gau_Name_Expected
                 THEN 'GAU validation mismatch'
            WHEN m.sc_tax_status_description IS NULL THEN 'Incorrect Tax Entity'
            WHEN m.sc_office_description IS NULL THEN 'Incorrect Office Code'
            WHEN m.sc_program_description IS NULL THEN 'Incorrect Program Code'
            WHEN m.sc_restriction_description IS NULL THEN 'Incorrect Restriction Code'
            WHEN m.sc_calendar_year_description IS NULL THEN 'Incorrect Calendar Year Code'
            WHEN m.sc_calendar_month_description IS NULL THEN 'Incorrect Calendar Month Code'
            WHEN m.sc_channel_description IS NULL THEN 'Incorrect Channel Code'
            -- -- WHEN m.Unique_Source_Code IN (select c.unique_source_code from campaign c where c.ISDELETED = 'false') THEN 'Unique Source Code already exists'
            -- -- 11/13/19 KC updated to look at v_campaign b'c not all deleted records get isdeleted set
            WHEN m.Unique_Source_Code IN (select c.unique_source_code from npsp_sfdc.campaign_v c where c._fivetran_deleted is false) THEN 'Unique Source Code already exists'
            ELSE NULL
       END AS ERROR_MSG
      ,m.*
FROM
(
SELECT c.Source_Code AS NAME -- -- populate source_code in 3 fields on campaign
		,c.source_code as Source_Code
		,c.Source_Code AS Unique_Source_Code		
		,(select id 
		from npsp_sfdc.record_type_v
		where sobject_type = 'Campaign'
		and name = 'Standard') AS RECORDTYPEID
		,'In Progress' AS STATUS
		,1 AS ACTIVE -- -- this needs to be boolean
	 -- -- archive -- -- default value is unchecked, so no need to populate
		,'Advertisement' AS TYPE  -- -- Advertisement is the default value in SF
		,c.description AS DESCRIPTION		
		-- -- ,'01236000000Ke9yAAC' AS CAMPAIGNMEMBERRECORDTYPEID -- -- not needed in npsp
		-- -- ,c.RC_GIVING__CHANNEL AS Rc_Giving__Channel -- -- get this from component mapping
		,c.drop_date::DATE AS START_DATE
		,c.gau AS Gau_Name_Provided
		,g2.name  AS Gau_Name_Expected
		,nvl(g2.Id,g.Id) AS General_Accounting_Unit
		-- -- ,'FALSE' AS Rc_Giving__Is_Parent -- -- not needed in npsp, default value of field on campaign Parent defaults to unchecked
		,CASE SUBSTRING(c.Source_Code,1,1) WHEN '3' THEN 'PPFA National C3'
			  WHEN '4' THEN 'PPAF National C4'
			  WHEN '5' THEN 'PPAF National PAC'
			  when '6' then 'PPAF National PP Votes'
			  ELSE 'x'
		END AS Merchant_Name
		-- -- ,'Sage' AS Rc_Connect__Payment_Processor -- -- not needed in npsp
		-- -- ,'FALSE' AS Migrated_Record -- -- not needed in npsp
		,1 AS Override_Source_Format -- -- this needs to be boolean
		,c.PACKAGE_CODE AS Package_Code
		,c.SOLICITOR AS Solicitor
		,c.Solicitation_List AS Solicitation_List
		,c.number_sent::int AS NumberSent
		,c.Production_Panel -- -- to track campaign costs, need this field added to npsp after go-live
		,c.Parent_Campaign_Name as parent_campaign_name
		,SUBSTRING(c.Source_Code,1,1) AS sc_tax_status_code
		,(SELECT dr.Tax_Status_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,1,1) = dr.Tax_Status
        ) AS sc_tax_status_description		
		,SUBSTRING(c.Source_Code,2,2) AS sc_office_code
		,(SELECT dr.Office_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,2,2) = dr.office_code
        ) AS sc_office_description
		,SUBSTRING(c.Source_Code,4,1) AS sc_program_code
		,(SELECT dr.Program_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,4,1) = dr.Program_Code
        ) AS sc_program_description
		,SUBSTRING(c.Source_Code,5,1) AS sc_restriction_code
		,(SELECT dr.Restriction_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,5,1) = dr.Restriction_Code
        ) AS sc_restriction_description
		,SUBSTRING(c.Source_Code,6,2) AS sc_calendar_year_code
		,(SELECT dr.Calendar_Year_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,6,2) = dr.Calendar_Year
        ) AS sc_calendar_year_description
		,SUBSTRING(c.Source_Code,8,1) AS sc_calendar_month_code
		,(SELECT dr.Calendar_Month_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,8,1) = dr.Calendar_Month
        ) AS sc_calendar_month_description
		,SUBSTRING(c.Source_Code,9,1) AS sc_channel_code
		,(SELECT dr.Channel_Description
        FROM custom_platform_development.npsp_sourcecode_component_mapping dr
        WHERE SUBSTRING(c.Source_Code,9,1) = dr.Channel_Code
        ) AS sc_channel_description
		,SUBSTRING(c.Source_Code,10) AS sc_package_detail
		,c.long_comments
	FROM (SELECT regexp_replace(source_code, '[^[:alnum:]]', '') AS source_code,
		  production_panel,
		  description,
		  drop_date,
		  gau,
		  package_code,
		  solicitor,
		  solicitation_list,
		  REPLACE(number_sent,',','') number_sent,
		  parent_campaign_name,
		  long_comments	
		FROM custom_platform_development.npsp_sourcecode_import_template c
		WHERE source_code IS NOT NULL)  c 
	LEFT JOIN npsp_sfdc.general_accounting_unit_v g 
		ON  c.gau = g.name
		AND g.active is true
	LEFT JOIN custom_platform_development.npsp_sourcecode_gau_mapping gm -- -- gau mapping table from google doc https://docs.google.com/spreadsheets/d/1OJ7hkZs5JVCsUZZVIZv4_Be7gzJC1qIqttzuFbmNJ78/edit#gid=1554428029
		ON SUBSTRING(c.Source_Code,1,1) = gm.tax_code
		AND SUBSTRING(c.Source_Code,2,2) = gm.office_code
		AND SUBSTRING(c.Source_Code,4,1) = gm.program_code
		-- -- online channels needing online gaus
		and case when substring(c.Source_Code,9,1) in ('E', 'P', 'S', 'W', 'D' )  
				then substring(c.Source_Code,9,1) 
				else 'xx' end
				= nvl(gm.channel_code,'xx')
	LEFT JOIN npsp_sfdc.general_accounting_unit_v g2 
		ON gm.GAU = g2.name
		AND g2.active is true
) m
;

-- -- create view of only upload columns for non errors
create or replace view custom_platform_development.v_npsp_sourcecode_dataloader_upload
as
select name as Name
,source_code as Source_Code__c
,unique_source_code as Unique_Source_Code__c
,recordtypeid as RecordTypeId
,status as Status
,case when active is true then 1 else 0 end IsActive
,type as Type
,description as Description
,start_date::DATE as StartDate
,gau_name_provided  
,gau_name_expected
,general_accounting_unit as General_Accounting_Unit__c
,merchant_name as Merchant_Name__c
,case when override_source_format is true then 1 else 0 end Override_Source_Format__c
,package_code as Package_Code__c
,solicitor as Solicitor__c
,solicitation_list as Solicitation_List__c
,numbersent as NumberSent
,production_panel
,parent_campaign_name as Parent_Campaign_Name__c
,sc_tax_status_code as sc_tax_status_code__c
,sc_tax_status_description as sc_tax_status_description__c
,sc_office_code as sc_office_code__c
,sc_office_description as sc_office_description__c
,sc_program_code as sc_program_code__c 
,sc_program_description as sc_program_description__c 
,sc_restriction_code as sc_restriction_code__c
,sc_restriction_description as sc_restriction_description__c
,sc_calendar_year_code as sc_calendar_year_code__c
,sc_calendar_year_description as sc_calendar_year_description__c
,sc_calendar_month_code as sc_calendar_month_code__c
,sc_calendar_month_description as sc_calendar_month_description__c
,sc_channel_code as sc_channel_code__c
,sc_channel_description as sc_channel_description__c
,sc_package_detail as sc_package_detail__c
,sc_channel_description as Campaign_Channel__c -- -- updating additional channel field with picklist value for channel desc
,long_comments as Long_Comments__c
from custom_platform_development.npsp_sourcecode_dataloader_upload
where error_msg is null
with no schema binding;


-- -- if there are errors, raise message to select * from custom_platform_development.npsp_sourcecode_dataloader_upload which has the error message to use to fix the data
-- -- if there are no errors, raise message to select * from  custom_platform_development.v_npsp_sourcecode_dataloader_upload which has only the columns for dataloading


v_error_count = (select count(*) from custom_platform_development.npsp_sourcecode_dataloader_upload where error_msg is not null); 

IF v_error_count > 0 
	then i_raise_info = ' select * from custom_platform_development.npsp_sourcecode_dataloader_upload ';
	
	raise info 'There are errors, use this select: %', i_raise_info;
	

ELSE i_raise_info = ' select * from custom_platform_development.v_npsp_sourcecode_dataloader_upload ';
	
	raise info 'There are NO errors, use this select: %', i_raise_info;


END IF;



END;
$$;
*/
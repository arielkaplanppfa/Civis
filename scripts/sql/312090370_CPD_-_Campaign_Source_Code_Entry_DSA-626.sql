TRUNCATE campaign_services.sourcecodes_to_sf;

INSERT INTO campaign_services.sourcecodes_to_sf
SELECT 
-- distinct mailing_source_code as name,
distinct mailing_source_code  AS name, --mailing_source_code
'Status: '||A.c3_c4_status|| '; Channel: ' ||A.channel
|| '; HPC: ' ||(case when A.hpc_range in ('$10,000-24,999.99', '>$25,000') then '$10,000+' 
					when a.hpc_range in ('<$10','$10-24.99' ) then '$0-24.99' -- sustainer pulls that grab less than 10
					else a.hpc_range end)
|| '; Freq: ' ||(case when A.frequency in ('2','3','4-12','13+') then '2+' else A.frequency end)
|| '; MRC: ' ||(case when A.mrc_range in ('0-3Mos','4-6Mos','7-12Mos') then '0-12Mos' 
				when substring(a.mailing_source_code,4,1) = 'V' and substring(a.mailing_source_code,9,1) = 'T' and substring(a.mailing_source_code,13,1) in ('A','E') then '49-84Mos' 
				when substring(a.mailing_source_code,4,1) = 'A' and substring(a.mailing_source_code,9,1) = 'T' and A.mrc_range in ('49-60Mos','61-120Mos') then '49+Mos' 
				when substring(a.mailing_source_code,4,1) = 'V' and substring(a.mailing_source_code,9,1) = 'T' and A.mrc_range in ('49-60Mos','61-120Mos','>121Mos') then '49-84Mos'
				else A.mrc_range end)
as description, 
'{{start_date}}' AS start_date,
gm.GAU AS general_accounting_unit_c,
'{{long_comments}}' AS long_comments_c,
'{{solicitor}}' AS solicitor_c,
RIGHT(A.mailing_source_code,5) AS sc_package_detail_c --mailing_source_code
FROM {{table_name}} A
JOIN custom_platform_development.npsp_sourcecode_gau_mapping GM
		ON SUBSTRING(A.mailing_source_code,1,1) = GM.tax_code   --mailing_source_code
		AND SUBSTRING(A.mailing_source_code,2,2) = GM.office_code  --mailing_source_code
		AND SUBSTRING(A.mailing_source_code,4,1) = GM.program_code --mailing_source_code
		-- -- online channels needing online gaus
		and case when substring(A.mailing_source_code,9,1) in ('E', 'P', 'S', 'W', 'D' )  --mailing_source_code
				then substring(A.mailing_source_code,9,1) --mailing_source_code
				else 'xx' end
				= nvl(gm.channel_code,'xx')
JOIN npsp_sfdc.general_accounting_unit_v G
		ON GM.GAU = G.name
		AND G.active is true
;

INSERT INTO campaign_services.sourcecodes_to_sf
SELECT 
-- distinct mailing_source_code as name,
'{{wm_code}}' AS name,
'{{long_comments}}' || ' whitemail' as description, 
'{{start_date}}' AS start_date,
'' AS general_accounting_unit_c,
'{{long_comments}}' AS long_comments_c,
'{{solicitor}}' AS solicitor_c,
RIGHT('{{wm_code}}',5) AS sc_package_detail_c;

UPDATE campaign_services.sourcecodes_to_sf A
SET general_accounting_unit_c = GM.gau
FROM custom_platform_development.npsp_sourcecode_gau_mapping GM
JOIN npsp_sfdc.general_accounting_unit_v G ON GM.gau = G.name AND G.active = true
WHERE CAST(SUBSTRING(A.name, 1, 1) AS INTEGER) = GM.tax_code
  AND SUBSTRING(A.name, 2, 2) = GM.office_code
  AND SUBSTRING(A.name, 4, 1) = GM.program_code
  AND CASE
        WHEN SUBSTRING(A.name, 9, 1) IN ('E', 'P', 'S', 'W', 'D') THEN SUBSTRING(A.name, 9, 1)
        ELSE 'xx'
      END = COALESCE(GM.channel_code, 'xx')
  AND A.description ILIKE '%whitemail';

select count(*) from campaign_services.sourcecodes_to_sf;
TRUNCATE custom_platform_development.npsp_sourcecode_import_template;

INSERT INTO custom_platform_development.npsp_sourcecode_import_template
SELECT 
name AS source_code,
NULL AS production_panel,
description,
start_date AS drop_date,
general_accounting_unit_c AS gau,
sc_package_detail_c AS package_code,
solicitor_c AS solicitor,
NULL AS solicitation_list,
NULL AS number_sent,
NULL AS parent_campaign_name,
long_comments_c AS long_comments
FROM campaign_services.sourcecodes_to_sf;
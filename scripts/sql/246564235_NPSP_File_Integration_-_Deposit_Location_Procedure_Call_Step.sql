-- Procedure defined here: https://platform.civisanalytics.com/spa/#/scripts/sql/246561831

call npsp_integration.deposit_location_assignment_ea();

Update npsp_integration.file_detail_table 
set status = 'Account Matching'
where status = 'Deposit Location';
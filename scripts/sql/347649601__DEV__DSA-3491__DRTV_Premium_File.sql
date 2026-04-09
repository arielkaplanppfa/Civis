-- ============================================================================
-- Main Query
-- ============================================================================
INSERT INTO dfse_ads.ppfa_to_ec_drtv_webgifts_premium_tracker
SELECT DISTINCT
    cc.contactscontributionid AS gift_id,
    cc.datereceived AS gift_datetime,
    cc.amount AS gift_amount,
    fairmarketvalue,
    rccf.salesforcecode AS gift_source,
    shippingfirstname,
    shippinglastname,
    shippingaddress,
    shippingcity,
    shippingstateorprovince,
    REPLACE(shippingziporpostalcode, '-', '') AS shippingziporpostalcode,
    CURRENT_DATE AS insert_date,
    NULL::DATETIME
FROM vansync.ppfa_contactscontributions_mym AS cc
INNER JOIN vansync.ppfa_contactscontributionscodes_mym AS codes
    ON cc.contactscontributionid = codes.contactscontributionid
INNER JOIN vansync_projects.dfse_source_codes_parsed AS parsed
    ON codes.codeid = parsed.codeid
INNER JOIN vansync.ppfa_contactsonlineforms_mym AS cof
    ON cc.contactsonlineformid = cof.contactsonlineformid
INNER JOIN vansync.ppfa_contactscontributionspremiumgifts_mym AS ccpm
    ON cc.contactscontributionid = ccpm.contactscontributionid
LEFT JOIN vansync.ppfa_contactsrecurringcontributions_mym AS crc
    ON cc.contactsrecurringcontributionid = crc.contactsrecurringcontributionid
LEFT JOIN vansync.ppfa_recurringcontributionscustomfields AS rccf
    ON cc.contactsrecurringcontributionid = rccf.contactsrecurringcontributionid
LEFT JOIN vansync.ppfa_contactscontributionscodes_mym AS ccc
    ON cc.contactscontributionid = ccc.contactscontributionid
LEFT JOIN vansync.ppfa_codes_mym AS c
    ON ccc.codeid = c.codeid
WHERE
    1 = 1
    AND (
        -- Salesforce code Program is DRTV
        SUBSTRING(rccf.salesforcecode, 4, 2) LIKE '%3%'
        -- One specific code did not include the DRTV program
        OR rccf.salesforcecode = '3NL2U24030BWEB'
    )
    -- Ignore test cases
    AND rccf.salesforcecode NOT LIKE '%DFSETEST'
    AND contributionstatusid NOT IN (2, 4)  -- Exclude Declined (2) and Failed (4)
    -- Did not opt out of gift
    AND ispremiumgiftoptedout = 0
    AND cc.contactsrecurringcontributionid IS NOT NULL
    -- Has a valid shipping zip cod
    AND (
        LEN(shippingziporpostalcode) = 5
        OR LEN(REPLACE(shippingziporpostalcode, '-', '')) = 9
    )
    -- Skip transactions already being tracked
    AND cc.contactscontributionid NOT IN (
        SELECT DISTINCT gift_id
        FROM dfse_ads.ppfa_to_ec_drtv_webgifts_premium_tracker
    );

TRUNCATE dfse_ads.ppfa_to_ec_drtv_webgifts_premium;

INSERT INTO dfse_ads.ppfa_to_ec_drtv_webgifts_premium

SELECT
    gift_id,
    gift_datetime,
    gift_amount,
    fairmarketvalue,
    gift_source,
    shippingfirstname,
    shippinglastname,
    shippingaddress,
    shippingcity,
    shippingstateorprovince,
    shippingziporpostalcode
FROM dfse_ads.ppfa_to_ec_drtv_webgifts_premium_tracker
WHERE posted_to_ftp_date IS NULL;
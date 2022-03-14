DECLARE outbound DEFAULT 0;
DECLARE inbound DEFAULT 0;
DECLARE raw_str STRING DEFAULT '';
DECLARE complete_str STRING DEFAULT ''; 
CREATE TEMP TABLE table_1 AS (
  SELECT
    t2.rnb,
    t2.category,
    COALESCE(t1.sum_inbound, 0) AS sum_inbound
  FROM (
    SELECT
      CASE
        WHEN diff <= 90 THEN '0-90 days old'
        WHEN diff > 90 AND diff <= 180 THEN '91-180 days old'
        WHEN diff > 180 AND diff <= 270 THEN '181-270 days old'
        WHEN diff > 271 AND diff <= 365 THEN '271–365 days old'
      ELSE 'over 365 days'
    END AS category,
      SUM(CASE WHEN event_type = 'InBound' THEN OnHandQuantityDelta ELSE 0 END) AS sum_inbound
    FROM (
      SELECT
        id,
        OnHandQuantity,
        OnHandQuantityDelta,
        event_type,
        event_datetime,
        DATE_DIFF(MAX(event_datetime) OVER(), event_datetime, day) AS diff
      FROM `sql-practice-329703.Draft.warehouse`
      ORDER BY CAST(RIGHT(id,3) AS INT) DESC ) step_2
    GROUP BY 1) t1
  RIGHT JOIN (
    SELECT 1 AS rnb, '0-90 days old' AS category UNION ALL
    SELECT 2, '91-180 days old' UNION ALL
    SELECT 3, '181-270 days old' UNION ALL
    SELECT 4, '271–365 days old' UNION ALL
    SELECT 5, 'over 365 days') t2
  ON t1.category = t2.category
  ORDER BY t2.rnb DESC);
SET outbound = (
  SELECT
    SUM(CASE WHEN event_type = 'OutBound' THEN OnHANDQuantityDelta ELSE 0 END) AS outbound
  FROM `sql-practice-329703.Draft.warehouse`); 
  FOR record IN (SELECT category, sum_inbound FROM table_1) DO
IF
  outbound > record.sum_inbound THEN SET raw_str = (SELECT CONCAT(record.category,',','0')); SET outbound = outbound - record.sum_inbound; 
ELSEIF outbound < record.sum_inbound THEN
SET raw_str = (SELECT CONCAT(record.category,',',CAST((record.sum_inbound - outbound) AS STRING))); SET outbound = 0;
END IF;
SET complete_str = CONCAT(complete_str,'.',raw_str);
END FOR;
SELECT
  SUM(CASE WHEN period = '0-90 days old' THEN CAST(inventory AS INT64) ELSE 0 END) AS _0_90_days_old,
  SUM(CASE WHEN period = '91-180 days old' THEN CAST(inventory AS INT64) ELSE 0 END) AS _91_180_days_old,
  SUM(CASE WHEN period = '181-270 days old' THEN CAST(inventory AS INT64) ELSE 0 END) AS _181_270_days_old,
  SUM(CASE WHEN period = '271–365 days old' THEN CAST(inventory AS INT64) ELSE 0 END) AS _271_365_days_old
FROM (
  SELECT
    SPLIT(newstr,',')[OFFSET(0)] AS period,
    SPLIT(newstr,',')[OFFSET(1)] AS inventory
  FROM (
    SELECT newstr
    FROM UNNEST(SPLIT(RIGHT(complete_str,LENGTH(complete_str)-1),'.')) newstr)
  ORDER BY inventory DESC
  LIMIT 4)
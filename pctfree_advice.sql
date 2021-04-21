REM pctfree_advice.sql
REM (c)Go-Faster Consultancy 2008

CREATE TABLE chained_rows (
  owner_name         varchar2(30),
  table_name         varchar2(30),
  cluster_name       varchar2(30),
  partition_name     varchar2(30),
  subpartition_name  varchar2(30),
  head_rowid         urowid,
  analyze_timestamp  date
);

DROP INDEX chained_rows;
TRUNCATE TABLE chained_rows;
CREATE INDEX chained_rows ON chained_rows (owner_name,table_name) COMPRESS 2 PCTFREE 0;

BEGIN
 FOR x IN (
	   SELECT owner, table_name, num_rows
           FROM   all_tables t
           WHERE  1=1
/*-------------------------------------------------------
	   AND    NOT table_name IN(SELECT DISTINCT table_name FROM chained_rows)
	   AND    num_rows >= 1000000
	   AND    num_rows BETWEEN 100000 AND 1000000
/*--------------------------------------------------------*/
           AND    table_name like 'PS_FT_YB%'
           AND    temporary = 'N'
          ) LOOP
  DELETE FROM chained_rows WHERE owner_name = x.owner AND table_name = x.table_name;
  EXECUTE IMMEDIATE 'ANALYZE TABLE '||x.owner||'.'||x.table_name||' LIST CHAINED ROWS INTO chained_rows';
  COMMIT;
 END LOOP;
END;
/


COLUMN owner_name FORMAT a8 HEADING 'Owner'
COLUMN pct_chained FORMAT 990.9
COLUMN chained_rows HEADING 'Chained|Rows'
COLUMN num_rows HEADING 'Number|of Rows' FORMAT 9999999
COLUMN pct_chained HEADING '%Chained'
COLUMN pct_Free HEADING '%|Free' FORMAT 999
COLUMN pct_used HEADING '%|Used' FORMAT 999
COLUMN new_pct_free HEADING 'New|%Free' FORMAT 990

COLUMN blocks FORMAT 999990 HEADING 'Blocks'
COLUMN avg_space FORMAT 99990 HEADING 'Space|per|Block'
COLUMN table_name FORMAT a30 HEADING 'Table Name'
COLUMN chain_cnt FORMAT 999999 HEADING 'Chain|Count'
COLUMN avg_row_len HEADING 'Average|Row|Length' FORMAT 99999
COLUMN wastage HEADING 'Wastage|(Mb)' FORMAT 9990

spool pctfree_advice
SELECT /*+LEADING(c)*/ c.*, t.num_rows
, c.chained_rows/t.num_rows*100 pct_chained
, t.pct_free, t.pct_used
, 100-FLOOR((100-t.pct_free)*(1-c.chained_rows/t.num_rows)) new_pct_free
from (
 SELECT owner_name, table_name, COUNT(*) chained_rows
 FROM chained_rows c
 GROUP BY owner_name, table_name) c
, all_tables t
WHERE t.owner = c.owner_name
AND   t.table_name = c.table_name
AND   t.num_rows > 0
ORDER BY chained_rows desc, 1,2
/

SELECT /*+LEADING(c)*/ c.*, t.num_rows
, c.chained_rows/t.num_rows*100 pct_chained
, t.pct_free, t.pct_used
, 100-FLOOR((100-t.pct_free)*(1-c.chained_rows/t.num_rows)) new_pct_free
from (
 SELECT owner_name, table_name, partition_name, COUNT(*) chained_rows
 FROM chained_rows c
 GROUP BY owner_name, table_name, partition_name) c
, all_tab_partitions t
WHERE t.table_owner = c.owner_name
AND   t.table_name = c.table_name
AND   t.partition_name = c.partition_name
AND   t.num_rows > 0
ORDER BY 1,2,3
/


SELECT 	'ALTER TABLE '||owner_name||'.'||table_name||
	' MOVE TABLESPACE '||tablespace_name||' PCTFREE 1;'
FROM (
	SELECT c.owner_name, c.table_name
	, c.chained_rows/t.num_rows*100 pct_chained
	, t.pct_free, t.pct_used
	, 100-FLOOR((100-t.pct_free)*(1-c.chained_rows/t.num_rows)) new_pct_free
	, t.tablespace_name
	FROM (
		SELECT 	owner_name, table_name, COUNT(*) chained_rows
		FROM 	chained_rows c
		GROUP BY owner_name, table_name) c
	, all_tables t
	WHERE t.owner = c.owner_name
	AND   t.table_name = c.table_name
	AND   t.num_rows > 0
	AND   c.chained_rows >= 500
	ORDER BY c.chained_rows,1,2
	)
/


SELECT 	'ALTER TABLE '||owner_name||'.'||table_name||
	' PCTFREE '||new_pct_free||' /*'||pct_free||'*/ PCTUSED '||LEAST(pct_used,90-new_pct_free)||';'
FROM (
	SELECT c.owner_name, c.table_name
	, c.chained_rows/t.num_rows*100 pct_chained
	, t.pct_free, t.pct_used
	, 100-FLOOR((100-t.pct_free)*(1-c.chained_rows/t.num_rows)) new_pct_free
	FROM (
		SELECT 	owner_name, table_name, COUNT(*) chained_rows
		FROM 	chained_rows c
		GROUP BY owner_name, table_name) c
	, all_tables t
	WHERE t.owner = c.owner_name
	AND   t.table_name = c.table_name
	AND   t.num_rows > 0
	AND   c.chained_rows >= 500
	ORDER BY c.chained_rows, 1,2
	)
/


SELECT x.cmd
FROM	(
	SELECT	i.*
	, 	'ALTER INDEX '||index_name||' REBUILD TABLESPACE '||tablespace_name||';' cmd
	FROM	user_indexes i
	WHERE	i.tablespace_name IS NOT NULL
	AND	NOT i.index_type = 'LOB'
	UNION ALL
	SELECT	j.*
	, 	'ALTER INDEX '||index_name||' REBUILD;'
	FROM	user_indexes j
	WHERE	j.tablespace_name IS NULL
	) x
,	(
	SELECT 	owner_name, table_name, COUNT(*) chained_rows
	FROM 	chained_rows c
	GROUP BY owner_name, table_name
	) c
WHERE	c.table_name = x.table_name
AND	c.owner_name = x.table_owner
AND	c.chained_rows >= 500
ORDER BY c.chained_rows desc, x.index_name
/




SELECT	'ALTER INDEX '||index_name||' REBUILD TABLESPACE '||tablespace_name||';'
FROM	user_indexes
WHERE	status = 'UNUSABLE'
AND	tablespace_name IS NOT NULL
UNION ALL
SELECT	'ALTER INDEX '||index_name||' REBUILD;'
FROM	user_indexes
WHERE	status = 'UNUSABLE'
and 	tablespace_name IS NULL
/

spool off

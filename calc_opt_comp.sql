REM calc_opt_comp.sql
REM (c)Go-Faster Consultancy Ltd. 2014-2025
REM see https://blog.psftdba.com/2016/02/implementing-index-compression-and.html
set serveroutput on autotrace off lines 150 pages 999
ttitle off
clear screen 
clear columns 
SPOOL calc_opt_comp.lst

REM DROP TABLE sysadm.gfc_index_stats PURGE;

--create working storage table with same structure as INDEX_STATS
CREATE TABLE sysadm.gfc_index_stats 
AS SELECT * FROM index_stats
WHERE 1=2
/

ALTER TABLE sysadm.gfc_index_stats
MODIFY name NOT NULL
/

CREATE UNIQUE INDEX sysadm.gfc_index_stats
ON sysadm.gfc_index_stats (name, partition_name)
/

undefine table_name
DECLARE
 l_sql        VARCHAR2(100);
 l_owner      VARCHAR2(8) := 'SYSADM';
 l_table_name VARCHAR2(30) := '&&table_name';
BEGIN
 FOR i IN (
  SELECT i.index_name, ip.partition_name
  FROM   all_indexes i
  ,      all_ind_partitions ip
  WHERE  i.index_type like '%NORMAL'
  AND    i.table_owner = l_owner
  AND    i.partitioned = 'YES'
  AND    i.table_name = l_table_name
  AND    ip.index_owner = i.owner
  AND    ip.index_name  = i.index_name
  AND    ip.subpartition_count = 0
  AND    ip.segment_created = 'YES'
  UNION
  SELECT i.index_name, isp.subpartition_name
  FROM   all_indexes i
  ,      all_ind_subpartitions isp
  WHERE  i.index_type like '%NORMAL'
  AND    i.table_owner = l_owner
  AND    i.partitioned = 'YES'
  AND    i.table_name = l_table_name
  AND    isp.index_owner = i.owner
  AND    isp.index_name  = i.index_name
  AND    isp.segment_created = 'YES'
  UNION
  SELECT i.index_name, NULL
  FROM   all_indexes i
  WHERE  i.index_type like '%NORMAL'
  AND    i.table_owner = l_owner
  AND    i.table_name = l_table_name
  AND    i.partitioned = 'NO'
  AND    i.segment_created = 'YES'
  MINUS
  SELECT name, partition_name
  FROM   sysadm.gfc_index_stats
 ) LOOP
  IF i.partition_name IS NULL THEN
    l_sql := 'ANALYZE INDEX '||l_owner||'.'||i.index_name||' VALIDATE STRUCTURE';
  ELSE
    l_sql := 'ANALYZE INDEX '||l_owner||'.'||i.index_name||' PARTITION ('||i.partition_name||') VALIDATE STRUCTURE';
  END IF;

  dbms_output.put_line(l_sql);
  EXECUTE IMMEDIATE l_sql;

  DELETE FROM sysadm.gfc_index_stats g
  WHERE EXISTS(
	SELECT  'x'
	FROM	index_stats i
	WHERE 	i.name = g.name
	AND	(i.partition_name = g.partition_name OR (i.partition_name IS NULL AND g.partition_name IS NULL)));

  INSERT INTO sysadm.gfc_index_stats 
  SELECT i.* FROM index_stats i;
  COMMIT;
 END LOOP;
END;
/

set lines 150 
column name heading 'Index Name' format a18
column partition_name heading 'Partition Name' format a30
column height heading 'Height' format 9999

ttitle 'GFC_INDEX_STATS'
--SELECT * FROM gfc_index_stats;

column table_name heading 'Table Name' format a18
column index_name heading 'Index Name' format a18
column freq format 999
column pct_used heading '%|Used' format 9999
column rows_per_key heading 'Rows/Key' format 999.999
column blks_gets_per_access heading 'Blk Gets/Access' format 999.999
column parts heading 'Num|Parts' format 9999
column prefix_length heading 'Index|Prefix|Length' format 9999
column weighted_average_saving format 999.9 heading 'Weighted|Average|Saving %'
column opt_cmpr_count heading 'Opt Comp|Prefix|Length' format 9999
column opt_cmpr_pctsave format 999.9 heading 'Saving|%'
column blocks heading 'Blocks' format 999,999,999
column est_comp_blocks heading 'Est.|Comp|Blocks' format 999,999,999
column tot_blocks heading 'Total|Blocks' format 999,999,999
column tot_parts  heading 'Total|Parts'  format 999,999
column compress_columns    heading 'Compress Columns'        format a59 wrap on
column noncompress_columns heading 'Do Not Compress Columns' format a59 wrap on
compute sum of blocks on name 
compute sum of blocks on table_name 
compute sum of blocks on report
compute sum of est_comp_blocks on name 
compute sum of est_comp_blocks on table_name 
compute sum of est_comp_blocks on report
compute sum of parts on name 
compute sum of parts on table_name 
compute sum of parts on report

break on table_name skip 1 on report 
ttitle 'Summary Report'
set lines 120 
SPOOL calc_opt_comp.summary.lst
WITH i AS (
SELECT i.owner, i.table_name, s.name, s.opt_cmpr_count
, count(*) freq
, count(partition_name) parts
, sum(s.blocks) blocks
, sum(s.opt_cmpr_pctsave*blocks)/sum(s.blocks) weighted_average_saving
, sum((1-s.opt_cmpr_pctsave/100)*blocks) est_comp_blocks
FROM sysadm.gfc_index_stats s, all_indexes i
WHERE s.name = i.index_name
AND i.owner = 'SYSADM'
--and not owner IN('SYS','SYSTEM','AUDSYS','CTXSYS','DBSNMP','DVSYS','LBACSYS','MDSYS','OLAPSYS','ORDSYS','OJVMSYS','OUTLN','ORDDATA','WMSYS','XDB','GSMADMIN_INTERAL')
--AND s.blocks > 256
GROUP BY i.owner, i.table_name, s.name, s.opt_cmpr_count
)
SELECT i.table_name, i.name, i.opt_cmpr_count, i.freq, i.parts, i.blocks, i.weighted_average_saving, i.est_comp_blocks
,      (SELECT LISTAGG(ic.column_name,', ') WITHIN GROUP(ORDER BY column_position) 
        FROM all_ind_columns ic 
        WHERE ic.index_name = i.name AND ic.index_owner = i.owner AND ic.column_position <= i.opt_cmpr_count) compress_columns
,      (SELECT LISTAGG(ic.column_name,', ') WITHIN GROUP(ORDER BY column_position) 
        FROM all_ind_columns ic 
        WHERE ic.index_name = i.name AND ic.index_owner = i.owner AND ic.column_position > i.opt_cmpr_count) noncompress_columns
FROM i
ORDER BY i.table_name, i.name, i.opt_cmpr_count
/


break on table_name on index_name skip 1
compute sum of blocks on index_name
compute sum of est_comp_blocks on index_name 
compute count of partition_name on index_name
compute count of partition_name on table_name
set lines 150
ttitle 'Partitions with Lower Optimal Prefix Length than Majority'
SPOOL calc_opt_comp.partitions.lst
WITH s AS (
select i.table_name, i.index_name, i.prefix_length, s.opt_cmpr_count
, 	    s.partition_name
,	     s.blocks
,	     s.opt_cmpr_pctsave
from	  sysadm.gfc_index_stats s, dba_indexes i
WHERE 	s.name = i.index_name
AND 	  i.owner = 'SYSADM'
), x as (
SELECT  table_name, index_name, opt_cmpr_count
, 	    count(*) freq
, 	    count(partition_name) parts
, 	    sum(blocks) blocks
, 	    sum(opt_cmpr_pctsave*blocks)/sum(blocks) weighted_average_saving
FROM 	s
--AND 	blocks > 256
GROUP BY table_name, index_name, opt_cmpr_count
), y as (
select row_number() over (partition by table_name, index_name order by blocks desc) ranking
,      x.*
from   x
)
select s.table_name, s.index_name, s.prefix_length
, 	    y.opt_cmpr_count, y.parts, y.blocks
,	     s.partition_name
, 	    s.opt_cmpr_count, s.blocks, s.opt_cmpr_pctsave
,      ((1-s.opt_cmpr_pctsave/100)*s.blocks) est_comp_blocks
from   y
,	     s
where  y.table_name = s.table_name
and	   y.index_name = s.index_name
and	   s.opt_cmpr_count < y.opt_cmpr_count
and	   y.ranking = 1
order by table_name, index_name, partition_name
/

set lines 120
ttitle 'Detail Report'
break on table_name on name skip 1
SPOOL calc_opt_comp.detail.lst
SELECT i.table_name, s.name, s.partition_name, s.opt_cmpr_count
,      s.blocks
,      s.opt_cmpr_pctsave
,      ((1-s.opt_cmpr_pctsave/100)*s.blocks) est_comp_blocks
/*
,      (SELECT LISTAGG(ic.column_name,', ') WITHIN GROUP(ORDER BY column_position) 
        FROM all_ind_columns ic 
        WHERE ic.index_name = i.index_name AND ic.index_owner = i.owner AND ic.column_position <= s.opt_cmpr_count) compress_columns
,      (SELECT LISTAGG(ic.column_name,', ') WITHIN GROUP(ORDER BY column_position) 
        FROM all_ind_columns ic 
        WHERE ic.index_name = i.index_name AND ic.index_owner = i.owner AND ic.column_position > s.opt_cmpr_count) noncompress_columns
*/
FROM   sysadm.gfc_index_stats s, all_indexes i
WHERE  s.name = i.index_name
AND    i.owner = 'SYSADM'
ORDER BY i.table_name, s.name, s.partition_name, s.opt_cmpr_count
FETCH FIRST 50 ROWS ONLY
/

spool off
ttitle off



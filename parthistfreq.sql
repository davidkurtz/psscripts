REM parthistfreq.sql
set pages 999 lines 200 trimspool on 
column table_name format a18
column column_name format a20
column endpoint_actual_value format a20
column pct format 999.9
column seq heading '#' format 999
column column_position heading 'Col|Pos' format a3
column freq     format 9,999,999,999
column num_rows format 9,999,999,999
column est_rows format 9,999,999,999
break on table_name skip 1 on num_rows on parttype on column_position on column_name skip 1 on ledger_type
compute sum of freq on column_name
compute sum of est_rows on column_name
spool parthistfreq
with r as (
select r.recname
,      DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) table_name
,      t.ledger_type, t.ledger_template
from   psrecdefn r
  LEFT OUTER JOIN ps_led_tmplt_tbl t
  ON   r.recname = t.recname
  AND NOT t.ledger_template IN('TST','BUDGET_DLJ')
WHERE  r.rectype = 0
and    (  r.recname IN('LEDGER','LEDGER_BUDG','LEDGER_ADB','LEDGER_ADB_MTD','LEDGER_ADB_QTD','LEDGER_ADB_YTD')
       OR t.ledger_type = 'S')
), k as (
select	'PARTITION' parttype, name, column_name, column_position||'/'||count(*) over (partition by object_type, name) column_position
from 	user_part_key_columns
where 	object_type = 'TABLE'
UNION ALL
select	'SUBPARTITION', name, column_name, column_position||'/'||count(*) over (partition by object_type, name) column_position
from 	user_subpart_key_columns
where 	object_type = 'TABLE'
), x as (
select r.ledger_type, h.table_name, t.num_rows, k.parttype, h.column_name
, k.column_position
, row_number() over (partition by h.table_name, h.column_name order by h.endpoint_number) seq
, NVL(h.ENDPOINT_ACTUAL_VALUE,'<NULL>') ENDPOINT_ACTUAL_VALUE
, h.endpoint_number-NVL(lag(h.endpoint_number,1) over (partition by h.table_name, h.column_name order by h.endpoint_number),0) freq
from   user_tables t
  LEFT JOIN r ON r.table_name = t.table_name
,     user_Tab_histograms h
  LEFT OUTER JOIN k
  ON k.name = h.table_name
  AND k.column_name = h.column_name
where ( (h.column_name IN('LEDGER','FISCAL_YEAR','ACCOUNTING_PERIOD') AND (r.ledger_type IS NOT NULL OR r.recname like 'LEDGER%'))
      OR k.column_name IS NOT NULL)
and   h.table_name = t.table_name
and   (r.recname IS NOT NULL OR t.partitioned = 'YES')
)
select x.*
, 100*ratio_to_report(freq) over (partition by table_name, column_name) pct
, num_rows*ratio_to_report(freq) over (partition by table_name, column_name) est_rows
from x
order by ledger_type nulls last, table_name, parttype nulls last, column_position nulls first, column_name, seq
--fetch first 50 rows only
/
spool off

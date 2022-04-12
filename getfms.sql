REM indexrep.sql
undefine indexrep
clear screen 
set autotrace off lines 200 trimspool on verify off long 1000 head on pages 999 echo off
break on table_name on index_name skip 1
column owner format a12
column table_owner format a10 heading 'Table|Owner'
column index_owner format a10 heading 'Index|Owner'
column table_name format a18
column partition_name format a30
column subpartition_name format a30
column tablespace_name format a20
column index_name format a18
column index_type format a15 heading 'Index|Type'
column column_name format a30
column column_position heading 'Pos' format 999
column num_distinct heading 'Num|Distinct' format 999,999,999
column num_rows heading 'Num|Rows' format 9,999,999,999
column distinct_keys heading 'Distinct|Keys' format 9,999,999,999
column leaf_blocks heading 'Leaf|Blocks' format 99,999,999
column prefix_length heading 'Prefix|Length' format 99
column degree format a7
column pos format 999 heading 'Pos'
column column_expression format a40
accept table_name prompt "Table Name:" 
spool indexrep.&&table_name..lst
ttitle 'Indexes'
select table_owner, owner, index_name, index_type, uniqueness, partitioned, tablespace_name, compression, prefix_length, visibility, degree
, num_rows, leaf_blocks, distinct_keys, partitioned
from all_indexes i
where i.table_name = UPPER('&&table_name')
and owner = 'SYSADM'
order by owner, index_name
/
ttitle 'Index Columns'
select /*+LEADING(I)*/ i.table_owner, i.table_name, i.index_owner, i.index_name, i.column_position, i.column_name
, c.num_distinct
--, e.column_expression
from all_ind_columns i
left outer join all_ind_expressions e
on e.index_owner = 'SYSADM'
and e.index_name = i.index_name
and e.table_owner = 'SYSADM'
and e.table_name = UPPER('&&table_name')
and e.column_position = i.column_position
left outer join all_tab_columns c
on c.owner = 'SYSADM'
and c.table_name = UPPER('&&table_name')
and c.column_name = i.column_name
where i.table_name = UPPER('&&table_name')
and i.table_owner = 'SYSADM'
and i.index_owner = 'SYSADM'
order by table_owner, index_owner, index_name, column_position
/
ttitle 'Column Statistics'
select column_name, num_distinct, num_buckets, histogram
from all_tab_col_statistics
where table_name = UPPER('&&table_name')
and owner = 'SYSADM'
and notes is null
--and histogram = 'HYBRID'
order by 1
/
ttitle 'Table Statistics'
select s.*
, m.inserts, m.updates, m.deletes, m.truncated, m.drop_segments
, (m.inserts+m.updates+m.deletes)/NULLIF(s.num_rows,0)*100 pct_stale
from all_tab_Statistics s
, all_tab_modifications m
where m.table_owner = s.owner
and m.table_name = s.table_name
and (m.partition_name = s.partition_name OR (m.partition_name IS NULL or s.partition_name IS NULL))
and (m.subpartition_name = s.subpartition_name OR (m.subpartition_name IS NULL or s.subpartition_name IS NULL))
and m.table_name = UPPER('&&table_name')
AND m.table_owner = 'SYSADM'
/
ttitle 'Table Statistics Preferences'
select *
from all_Tab_stat_prefs p
WHERE p.table_name = UPPER('&&table_name')
AND p.owner = 'SYSADM'
order by 1,2,3
/
ttitle 'DDL'
select dbms_metadata.get_ddl('INDEX',index_name,owner)
from all_indexes i
where i.table_name = UPPER('&&table_name')
and owner = 'SYSADM'
order by owner, index_name
/
spool off
ttitle off

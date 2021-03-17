set autotrace off lines 200 trimspool on verify off
break on table_name on index_name skip 1
column owner format a12
column table_owner format a12
column index_owner format a12
column table_name format a30
column tablespace_name format a20
column index_name format a30
column index_type format a15
column column_name format a30
column column_position heading 'Pos'
column num_rows heading 'Num|Rows' format 999999999
column distinct_keys heading 'Distinct|Keys'
column leaf_blocks heading 'Leaf|Blocks'
column prefix_length heading 'Prefix|Length' format 99
column degree format a7
column pos format 999
column column_expression format a40
accept table_name prompt "Table Name:" 
select table_owner, owner, index_name, index_type, uniqueness, tablespace_name, compression, prefix_length, visibility, degree
, num_rows, leaf_blocks, distinct_keys, partitioned
from all_indexes i
where i.table_name = UPPER('&&table_name')
--and owner = 'SYSADM'
order by owner, index_name
/
select i.table_owner, i.table_name, i.index_owner, i.index_name, i.column_position, i.column_name
, e.column_expression
from all_ind_columns i
left outer join all_ind_expressions e
on e.index_owner = i.indeX_owner
and e.index_name = i.index_name
and e.table_owner = i.table_owner
and e.table_name = i.table_name
and e.column_position = i.column_position
where i.table_name = UPPER('&&table_name')
--and table_owner = 'SYSADM'
order by table_owner, index_owner, index_name
/
select dbms_metadata.get_ddl('INDEX',index_name,owner)
from all_indexes i
where i.table_name = UPPER('&&table_name')
--and owner = 'SYSADM'
order by owner, index_name
/

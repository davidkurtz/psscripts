REM depend_hier.sql
undefine object_name
set pages 999 lines 180 long 50000
break on name skip 1 on owner 
ttitle 'Dependency Hierarchy'
column my_level format a5 heading 'Level'
column owner format a12
column name format a18
column type format a7
column referenced_type format a7 heading 'Refd|Type'
column referenced_owner format a6 heading 'Refd|Owner'
column referenced_name format a18 heading 'Refd|Name'
column referenced_link_name format a10 heading 'Refd|Link'
column dependency_type heading 'Dep|Type'
column text heading 'View Text' format a80 wrap on
spool depend_hier.&&object_name..lst
select LPAD(TO_CHAR(level),level,'.') my_level
, d.type, d.owner, d.name
, d.referenced_type, d.referenced_owner, d.referenced_name, d.referenced_link_name
, d.dependency_type
, v.text
from all_dependencies d
  left outer join all_views v 
    on  v.owner = d.referenced_owner
    and v.view_name = d.referenced_name
  connect by nocycle
        d.name = prior d.referenced_name
  and   d.owner = prior d.referenced_owner
start with d.owner = 'SYSADM' and d.name = UPPER('&&object_name')
/
spool off
ttitle off
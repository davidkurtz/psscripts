REM getview.sql
undefine view_name
SET pages 999 lines 180 long 50000
column sql_text format a32767 wrap off
column text format a32767 wrap 
spool getview.&&view_name..lst
select text
from dba_views
where owner = 'SYSADM'
and view_name = UPPER('&&view_name')
/
select dbms_metadata.get_ddl('VIEW',view_name,owner)
from dba_views
where owner = 'SYSADM'
and view_name = UPPER('&&view_name')
/
spool off

REM getsql.sql
undefine sql_id
set long 50000 lines 200
column sql_text format a200
select sql_text
from dba_hist_sqltext
where sql_id = '&&sql_id'
/

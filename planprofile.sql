REM planprofile.sql
set pages 99 head on timi on trimspool on
column sql_plan_line_id heading 'SQL Plan|Line ID'
column ash_Secs heading 'ASH|Secs'
column in_parse heading 'P'
column in_hard_parse heading 'H|P'
column in_sql_execution heading 'E'
column event format a40
undefine phv
select sql_plan_line_id, event
, in_hard_parse, in_parse, in_sql_Execution
, sum(10) ash_Secs
from dba_Hist_Active_SEss_history
where sql_plan_hash_value = &&phv
and sample_time > sysdate-7
group by sql_plan_line_id, event
, in_hard_parse, in_parse, in_sql_Execution
order by ash_Secs desc
/

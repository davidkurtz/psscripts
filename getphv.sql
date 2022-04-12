REM getphv.sql
undefine phv
SET pages 99 lines 180 long 50000
column module format a12
column sql_text format a32767 
spool getphv
with x as (
select sql_id, plan_hash_Value, module --, action
, avg(optimizer_cost) avg_opt_cost
, sum(executions_delta) num_execs
, sum(elapsed_Time_Delta)/1e6 elapsed_time
, sum(elapsed_Time_Delta)/1e6/NULLIF(sum(executions_delta),0) avg_elapseD_time
from dba_hist_sqlstat s
where plan_hash_value = &&phv
group by sql_id, plan_hash_value
, module --, action
)
select x.* 
from x
order by avg_elapseD_time desc
/
spool off

REM getfms.sql
alter session set nls_date_format = 'hh24:mi:ss dd/mm/yyyy';
clear screen
clear breaks
SET pages 999 lines 180 long 50000 trimspool on trimout on
break on module skip 1 on action on dbid on seq on sql_text
column seq format 9 heading '#'
column min_snap_id heading 'Minimum|Snap ID' format 999999
column max_snap_id heading 'Maximum|Snap ID' format 999999
column avg_opt_cost heading 'Average|Optimizer|Cost'format 999,999
column sql_plan_hash_value heading 'SQL Plan|Hash Value'
column plan_hash_value heading 'SQL Plan|Hash Value'
column sql_plan_line_id heading 'SQL Plan|Line ID' format 9999
column module format a30
column action format a30
column event format a48
column sql_text format a200 wrap on
column num_execs heading 'Num|Execs' format 999,999
column maX(sample_time) format a30
column ash_secs heading 'ASH|Secs' format 999,999
column plan_secs heading 'Plan|Secs' format 999,999
column elapsed_time heading 'Elapsed|Secs' format 999,999.999
column avg_elapsed_time heading 'Average|Elapsed|Secs' format 9,999.999
column avg_rows_processed heading 'Average|Rows|Processed' format 999,999
column plan_secs heading 'Plan|Secs' format 999,999
undefine fms
spool getfms
with x as (
select dbid, sql_id, plan_hash_Value
, CASE WHEN s.module LIKE 'PSAE.%' THEN REGEXP_SUBSTR(s.module, '[^.]+',1,2) 
       ELSE                             REGEXP_SUBSTR(s.module, '[^.@]+',1,1) 
  END AS module
, action
, avg(optimizer_cost) avg_opt_cost
, sum(executions_delta) num_execs
, sum(elapsed_Time_Delta)/1e6 elapsed_time
, sum(elapsed_Time_Delta)/NULLIF(sum(executions_delta),0)/1e6 avg_elapsed_time
, max(snap_id) max_snap_id
from dba_hist_sqlstat s
where force_matching_signature = TO_NUMBER(&&fms)
group by dbid, sql_id, plan_hash_value, module, action
), y as (
select row_number() over (partition by plan_hash_value, module order by elapsed_time desc) seq, x.* 
from x
)
select y.*, t.sql_text from y
  LEFT OUTER JOIN dba_Hist_sqltext t
  ON t.sql_id = y.sql_id AND t.dbid = y.dbid
where seq = 1
order by max_snap_id desc, avg_elapseD_time desc
fetch first 8 rows only 
/

column sql_profile format a30
with x as (
select sql_id, plan_hash_value, sql_profile
, round(sum(elapsed_time_delta)   over (partition by plan_hash_value, sql_profile),0)/1e6 elapsed_time
, round(sum(rows_processed_delta) over (partition by plan_hash_value, sql_profile),0) rows_processed
,       sum(executions_delta)     over (partition by plan_hash_value, sql_profile) num_execs
,       min(snap_id)              over (partition by plan_hash_value, sql_profile) min_snap_id
,       max(snap_id)              over (partition by plan_hash_value, sql_profile) max_snap_id
from dba_hist_sqlstat s
where force_matching_signature = TO_NUMBER(&&fms)
), y as (
select row_number() over (partition by plan_hash_value, sql_profile order by elapsed_time desc) seq
, sql_id, plan_hash_value, sql_profile
, elapsed_time, num_execs
, elapsed_time/NULLIF(num_execs,0) avg_elapsed_time
, rows_processed/NULLIF(num_execs,0) avg_rows_processed
, min_snap_id, max_snap_id
from x
)
select * from y
where seq = 1
/



--desc dba_hist_sqlstat

break on sql_plan_hash_value skip 1
--clear screen 
with x as (
select sql_plan_hash_value, sql_plan_line_id, event
, sum(usecs_per_Row)/1e6 ash_secs
, max(sample_time)
from dba_hist_active_Sess_history
where force_matching_signature = TO_NUMBER(&&fms)
group by sql_plan_hash_value ,sql_plan_line_id,event
)
select x.*
,(sum(ash_secs) over (partition by sql_plan_hash_value)) plan_secs
from x
order by plan_secs desc, sql_plan_hash_value,ash_Secs desc
/
spool off
clear breaks
--select * from table(dbms_xplan.display_awr('85q54j0zpvhns',null,null,'ADVANCED +ADAPTIVE'));

REM index_usage.sql
undefine object_name
set pages 99 lines 180 trimspool on pause off
break on object_name skip 1 on object_Secs
column ash_Secs heading 'ASH|Secs' format 999,999
column options format a24
column object_Secs heading 'Object|ASH Secs' format 999,999
column object_name format a18
column module format a32
column num_fms     heading 'Num|FMS'     format 999,999
column num_sqlids  heading 'Num|SQL_IDs' format 999,999
column num_plans   heading 'Num|Plans'   format 999,999
column num_actions heading 'Num|Actions' format 999,999
spool index_usage.&&object_name..lst
with o as (
select  DISTINCT object_owner, object_type, object_name
from    dba_hist_sql_plan
where   object_name like UPPER('&&object_name')
and     object_owner = 'SYSADM'
and     object_type like 'INDEX'
), p as (
select  DISTINCT o.object_owner, o.object_type, o.object_name, p.plan_hash_value, p.options, p.id
from    o, dba_hist_sql_plan p
where   o.object_name = p.object_name
and     o.object_owner = p.objecT_owner
and     o.object_type = p.object_type
and     p.plan_hash_value > 0
), h as (
select  /*+LEADING(i x h)*/ h.sql_plan_hash_value, h.sql_id, h.force_matching_signature, h.sql_plan_line_id
,       CASE WHEN h.module like 'PSAE.%' THEN regexp_substr(h.module,'[^@\.]+',1,2)
             ELSE regexp_substr(h.module,'[^@]+',1,1) END module
,       h.action
,       usecs_per_row/1e6 ash_secs
from    dba_hist_Active_Sess_history h
,       dba_hist_snapshot x
,       dba_Hist_database_instance i
where   x.dbid = h.dbid
and     x.instance_number = h.instance_number
and     x.snap_id = h.snap_id
and     i.dbid = x.dbid
and     i.instance_number = x.instance_number
and     i.startup_time = x.startup_time
--and     i.db_name = 'QENGL010'
--and     x.begin_interval_time >= SYSDATE-7
and     not h.module IN('DBMS_SCHEDULER','SQL*Plus')
), x as (
select 	p.object_name, p.options, h.module, sum(ash_secs) ash_Secs
,       count(distinct h.sql_id) num_sqlids
,       count(distinct p.plan_hash_value) num_plans
,       count(distinct h.force_matching_signature) num_fms
,       count(distinct h.action) num_actions
from    h, p
where   h.sql_plan_hash_value = p.plan_hash_value
and     h.sql_plan_line_id = p.id
group by p.object_name, p.options, h.module
)
select  o.object_name, x.module, x.options, NVL(x.ash_secs,0) ash_secs
,       sum(x.ash_secs) over (partition by o.object_name) objecT_secs
,       x.num_fms, x.num_sqlids, x.num_plans, x.num_actions
from    o
  left outer join x on x.object_name = o.object_name
order by object_secs desc nulls last, object_name, ash_secs desc nulls last
/
spool off

REM qry_cartesianplans.sql
REM https://blog.psftdba.com/2024/11/psquery-cartesian.html
Clear screen
Alter session set nls_date_format = 'HH24:MI:SS dd.mm.yy';
Set pages 999 lines 197 trimspool on
Compute sum of ash_Secs on report
Break on report 
Column prcsinstance heading 'Process|Instance' format 99999999
Column oprid format a9
column private_query_flag heading 'Private|Query' format a7
column qryname format a30
column name format a30
column max_procs heading 'Max|Prc' format 999
Column plan_seq heading '#' format 9
Column dbid format 9999999999
Column force_matching_signature format 99999999999999999999 heading 'Force Matching|Signature'
Column module format a12
Column action format a32
Column event format a45
column eff_para heading 'Eff.|Para' format 99.9
Column sql_ids heading 'SQL|IDs' format 999
Column plan_execs heading 'Plan|Execs' format 99999
Column plan_ash_secs heading 'Plan|ASH|Secs' format 999999
Column plan_awr_secs heading 'Plan|AWR|Secs' format 999999
Column sql_plan_hash_value heading 'SQL Plan|Hash Value' format 9999999999
Column elap_secs heading 'Elapsed|Seconds' format 999999
Column ash_secs heading 'ASH|Secs' format 999999
Column options format a9
ttitle 'PS/Query Cartesian Execution Plans'
spool qry_cartesianplans

WITH r as ( /*processes of interest*/
Select /*+MATERIALIZE*/ r.oprid, r.prcsinstance, r.prcsname, r.begindttm, r.enddttm
,      DECODE(c.private_query_flag,'Y','Private','N','Public') private_query_flag, c.qryname
From   psprcsrqst r
       LEFT OUTER JOIN ps_query_run_cntrl c ON c.oprid = r.oprid AND c.run_cntl_id = r.runcntlid
WHERE prcsname = 'PSQUERY'
--AND r.begindttm >= trunc(SYSDATE)-0+8/24
--AND r.begindttm <= trunc(SYSDATE)-0+19/24
), p as ( /*known Cartesian plans with SQL text*/
select /*+MATERIALIZE*/ p.plan_hash_value, MAX(p.options) options
from   dbA_hist_sql_plan p
,      dba_hist_sqltext t
Where  t.sql_id = p.sql_id
And    (p.id = 0 OR p.options = 'CARTESIAN')
GROUP BY p.plan_hash_Value
), x AS ( /*ASH for processes*/
SELECT /*+materialize leading(r x)*/  r.prcsinstance, r.oprid, r.private_query_flag, r.qryname
,      h.event, x.dbid, h.sample_id, h.sample_time, h.instance_number
,      CASE WHEN h.module IS NULL       THEN REGEXP_SUBSTR(h.program, '[^@]+',1,1)
            WHEN h.module LIKE 'PSAE.%' THEN REGEXP_SUBSTR(h.module, '[^.]+',1,2) 
            ELSE                             REGEXP_SUBSTR(h.module, '[^.@]+',1,1) 
       END AS module
,      h.action
,      NULLIF(h.top_level_sql_id, h.sql_id) top_level_sql_id
,      h.sql_id, h.sql_plan_hash_value, h.force_matching_signature, h.sql_exec_id
,      h.session_id, h.session_serial#, h.qc_instance_id, h.qc_Session_id, h.qc_Session_serial#
,      f.name, p.options
,      NVL(usecs_per_row,1e7) usecs_per_row
,      CASE WHEN p.plan_hash_value IS NOT NULL THEN NVL(usecs_per_row,1e7) ELSE 0 END usecs_per_row2
FROM   dba_hist_snapshot x
,      dba_hist_active_sess_history h
       LEFT OUTER JOIN p ON p.plan_hash_value = h.sql_plan_hash_value
       LEFT OUTER JOIN dba_sql_profiles f ON h.force_matching_signature = f.signature
,      r
,      sysadm.psprcsque q
WHERE  h.SNAP_id = X.SNAP_id
AND    h.dbid = x.dbid
AND    h.instance_number = x.instance_number
AND    x.end_interval_time >= r.begindttm
AND    x.begin_interval_time <= NVL(r.enddttm,SYSDATE)
AND    h.sample_time BETWEEN r.begindttm AND NVL(r.enddttm,SYSDATE)
And    q.prcsinstance = r.prcsinstance
And    (  (h.module = r.prcsname And h.action like 'PI='||r.prcsinstance||':Processing')
       OR  h.module like 'PSAE.'||r.prcsname||'.'||q.sessionidnum
       )
), y as( /*profile time by statement/process*/
SELECT prcsinstance, oprid, private_query_flag, qryname
,      sql_plan_hash_value, sql_id, force_matching_signature, name
,      dbid, module, action, top_level_sql_id
,      count(distinct qc_session_id||qc_session_serial#||sql_id||sql_exec_id) execs
,      sum(usecs_per_row)/1e6 ash_Secs
,      sum(usecs_per_Row2)/1e6 awr_secs
,      avg(usecs_per_row)/1e6*count(distinct sample_time) elapsed_secs
,      count(distinct instance_number||session_id||session_serial#) num_procs
,      max(options) options
FROM   x 
GROUP BY prcsinstance, oprid, private_query_flag, qryname, sql_id, sql_plan_hash_value, dbid, module, action, top_level_sql_id, force_matching_signature, qc_instance_id, qc_session_id, qc_session_serial#, name
), z as ( /*find top statement per plan and sum across all executions*/
select row_number() over (partition by force_matching_signature, sql_plan_hash_value order by awr_secs desc) plan_seq
,      prcsinstance, oprid, name, private_query_flag, NVL(qryname,action) qryname, options
,      sql_id, sql_plan_hash_Value, force_matching_signature
,      count(distinct sql_id) over (partition by force_matching_signature, sql_plan_hash_value) sql_ids
,      sum(execs) over (partition by force_matching_signature, sql_plan_hash_value) plan_execs
,      sum(ash_Secs) over (partition by force_matching_signature, sql_plan_hash_value) plan_ash_secs
,      sum(awr_Secs) over (partition by force_matching_signature, sql_plan_hash_value) plan_awr_secs
,      sum(elapsed_Secs) over (partition by force_matching_signature, sql_plan_hash_value) elap_secs
,      sum(num_procs) over (partition by force_matching_signature, sql_plan_hash_value) max_procs
from   y
)
Select z.*, z.plan_ash_secs/z.elap_secs eff_para
from   z
where  plan_seq = 1
and    sql_id is not null
and    plan_ash_secs >= 300
ORDER BY plan_ash_secs DESC
FETCH FIRST 50 ROWS ONLY
/
spool off
ttitle off
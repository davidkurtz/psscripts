REM resource_plan_report.sql
clear screen
spool resource_plan_report.lst
--------------------------------------------------------------------------------
--report section
--------------------------------------------------------------------------------
set trimspool on pages 999 lines 222 termout on
column plan_id heading 'Plan|ID' format 99999999
column plan format a25
column consumer_group_id heading 'Consumer|Group ID' format 99999999
column group_or_subplan heading 'Group or|Subplan' format a20
column consumer_group heading 'Consumer|Group' format a24
column NUM_PLAN_DIRECTIVES heading 'Num|Plan|Dirs' format 999
column mgmt_method heading 'Management|Method' format a11
column comments format a60
column status format a10
column cpu_method heading 'CPU|Method' format a11
column cpu_p1 heading 'CPU|P1' format 999
column cpu_p2 heading 'CPU|P2' format 999
column cpu_p3 heading 'CPU|P3' format 999
column cpu_p4 heading 'CPU|P4' format 999
column cpu_p5 heading 'CPU|P5' format 999
column cpu_p6 heading 'CPU|P6' format 999
column cpu_p7 heading 'CPU|P7' format 999
column cpu_p8 heading 'CPU|P8' format 999
column mgmt_p1 heading 'Mgmt|P1' format 999
column mgmt_p2 heading 'Mgmt|P2' format 999
column mgmt_p3 heading 'Mgmt|P3' format 999
column mgmt_p4 heading 'Mgmt|P4' format 999
column mgmt_p5 heading 'Mgmt|P5' format 999
column mgmt_p6 heading 'Mgmt|P6' format 999
column mgmt_p7 heading 'Mgmt|P7' format 999
column mgmt_p8 heading 'Mgmt|P8' format 999
column ACTIVE_SESS_POOL_P1 heading 'Active|Sess Pool|P1' format a10
column ACTIVE_SESS_POOL_MTH format a25
column QUEUEING_P1 heading 'Queuing|P1' format a10
column QUEUEING_MTH heading 'Queuing|Method' format a12
column PARALLEL_DEGREE_LIMIT_MTH format a30
column PARALLEL_DEGREE_LIMIT_P1 heading 'Parallel|Degree|Limit P1' format 999
column PARALLEL_SERVER_LIMIT heading 'Parallel|Server|Limit' format 999.99
column PARALLEL_TARGET_PERCENTAGE heading 'Parallel|Target%' format 999.99
column PARALLEL_STMT_CRITICAL heading 'Parallel|Stmt|Critical' format a10
column PQ_TIMEOUT_ACTION heading 'PQ|Timeout|Action' format a12
column parallel_queue_timeout heading 'Parallel|Queue|Timeout' format 99999
column SWITCH_GROUP heading 'Switch|Group' format a11
column SWITCH_FOR_CALL heading 'Switch|for|Call' format a10
column SWITCH_ELAPSED_TIME heading 'Switch|Elapsed|Time' format 999,999
column SWITCH_IO_LOGICAL heading 'Switch|I/O|Logical' format 999,999,999
column SWITCH_IO_REQS heading 'Switch|I/O|Reqs' format 999,999,999
column SWITCH_ESTIMATE heading 'Switch|Estimate' format a8
column SWITCH_IO_MEGABYTES heading 'Switch|I/O|MB' format 999,999,999
column SWITCH_TIME heading 'Switch|Time' format 999,999
column SWITCH_TIME_IN_CALL heading 'Swtich|Time|in Call' format 999,999
column MAX_UTILIZATION_LIMIT heading 'Max|Util|Limit' format 999.99
column MAX_IDLE_BLOCKER_TIME heading 'Max Idle|Blocker|Time' format 999,999,999
column MAX_IDLE_TIME heading 'Max|Idle|Time' format 999,999,999
column MAX_EST_EXEC_TIME heading 'Max Est.|Exec Time' format 999,999,999
column UNDO_POOL heading 'Undo|Pool' format a10
column UTILIZATION_LIMIT heading 'Util|Limit' format 999.99
column SESSION_PGA_LIMIT heading 'Session|PGA|Limit' format 999.99
column window_group_name format a25
column window_name format a20
column owner format a8
column resource_plan format a25
column schedule_owner heading 'Schedule|Owner' format a8
column schedule_name format a20
column repeat_interval format a40
column number_of_windows heading 'Number|of|Windows' format 999
column next_start_date format a45
column attribute format a22
column value format a40
column grantee format a20
column granted_Group format a30
column comments format a40
column additional_info format a40
column category format a20
column user_name format a12
column client_id format a20
column global_uid format a20
column operation format a10
SHOW PARAMETER RESOURCE
SELECT * FROM dba_rsrc_plans /*WHERE plan LIKE 'PSFT_PLAN%'*/ ORDER BY plan;
SELECT * FROM DBA_RSRC_PLAN_DIRECTIVES /*WHERE plan like 'PSFT_PLAN%'*/ order by plan, cpu_p1 desc nulls last, cpu_p2 desc nulls last, cpu_p3 desc nulls last, cpu_p4 desc nulls last, cpu_p5 desc nulls last, cpu_p6 desc nulls last, cpu_p7 desc nulls last, cpu_p8 desc nulls last;
select * from DBA_RSRC_CONSUMER_GROUPS /*where consumer_group_id > 1e5*/ order by 1;
select * from DBA_RSRC_CONSUMER_GROUP_PRIVS ORDER BY 1; 
select * from DBA_RSRC_GROUP_MAPPINGS order by 1,2,3;
select * from DBA_RSRC_MAPPING_PRIORITY order by priority;
select * from dbA_rsrc_manager_system_privs;
--------------------------------------------------------------------------------
select * from dba_scheduler_window_groups;
select * from DBA_SCHEDULER_WINGROUP_MEMBERS order by 1;
select * from dba_scheduler_windows;
select * from dba_scheduler_window_log order by 1,2;
--------------------------------------------------------------------------------
spool off
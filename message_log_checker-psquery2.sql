REM message_log_checker-psquery2.sql
REM match ASH data PSQUERY for resource plan terminated queries to SQL Quarantine directives
ttitle off
clear breaks
set serveroutput on trimspool on lines 174 pages 999 wrap on long 50000
column oprid format a8
column dbname format a7
column prcsinstance heading 'P.I.' format 99999999
column process_instance heading 'P.I.' format 99999999
column prcstype format a18
column prcsname heading 'Process|Name' format a7
column runcntlid format a30
column runstatus heading 'Run|Stat' format a2
column ash_secs heading 'ASH|Secs' format 99999
column ash_cpu_secs heading 'ASH|CPU|Secs' format 99999
column exec_secs heading 'Exec|Secs' format 99999
column cpu_time heading 'CPU|Time' format a5
column private_query_flag heading 'Public/|Private|Query' format a7
column qryname format a30
column message_seq heading 'Msg|Seq' format 99
column message_set_nbr heading 'Msg|Set' format 99
column message_nbr heading 'Msg|Nbr' format 999
column begindttm format a28
column dttm_stamp_Sec heading 'Message Log|Date/Time Stamp' format a28
column created heading 'Quarantine Created' format a28
column last_executed heading 'Quarantine Last Executed' format a28
column sql_plan_hash_value heading 'SQL Plan|Hash Value' format 9999999999
column sql_full_plan_hash_value heading 'Full Plan|Hash Value' format 9999999999
column plan_hash_value heading 'Plan|Hash Value' format 9999999999
column errno heading 'Oracle|Err. #' format a9 
column name heading 'Quarantine Name' format a36
column msg format a148
column signature format 99999999999999999999
column consumer_group_name heading 'Consumer Group Name' format a25
ttitle 'PS/Queries terminated by Resource Manager/quarantined Execution Plan'
REM break on prcsinstance skip 1 on dbname on prcstype on prcsname on oprid on runcntlid on runstatus on begindttm on exec_secs on private_query_flag on qryname
clear screen
spool message_log_checker-psquery2.lst
--drop table dakurt0.t purge;
--create table dakurt0.t as 
WITH FUNCTION msg(p_process_instance NUMBER, p_message_seq NUMBER) RETURN CLOB IS 
  l_message CLOB;
  l_message_set_nbr INTEGER;
  l_message_nbr INTEGER;
  l_message_len INTEGER := 0;
BEGIN
  --dbms_output.put_line(p_process_instance||':'||p_message_seq);

  SELECT c.message_set_nbr, c.message_nbr, LTRIM(c.message_text)
  INTO   l_message_set_nbr, l_message_nbr, l_message
  FROM   psmsgcatdefn c, ps_message_log l
  WHERE  l.process_instance = p_process_instance
  AND    l.message_seq = p_message_seq
  AND    c.message_set_nbr = l.message_set_nbr
  AND    c.message_nbr = l.message_nbr;

  IF l_message_set_nbr = 65 AND l_message_nbr = 30 THEN
    l_message:='%1%2%3%4%5%6%7%8%9'; --eliminate the spaces from the generic message
  END IF;
  
  FOR i IN (
    WITH n AS (SELECT level n FROM DUAL CONNECT BY LEVEL<=9
    ), p AS (
      SELECT * 
      FROM ps_message_logparm p
      WHERE p.process_instance = p_process_instance
      AND p.message_seq= p_message_seq
    )
    SELECT NVL(p.parm_seq,n.n) n, p.message_seq, p.message_parm
    FROM   n
      FULL OUTER JOIN p
      ON p.parm_seq = n.n
    ORDER BY p.parm_seq NULLS FIRST,n.n
  ) LOOP
    --dbms_output.put_line('seq='||i.message_seq||':parm='||i.n||':len='||l_message_len||'+'||LENGTH(i.message_parm)||':'||i.message_parm);
    IF l_message_len+LENGTH(i.message_parm) >= 5e4 THEN --limit message length
      NULL;
    ELSIF i.n > 9 THEN
      l_message := l_message||i.message_parm;
    ELSE
      l_message := replace(l_message,'%'||i.n,i.message_parm);
    END IF;
    l_message_len := LENGTH(l_message);
    --dbms_output.put_line(i.message_seq||':'||i.n||':'||l_message);
  END LOOP;
RETURN l_message;
END;
r as ( --failed PSQUERY process request records
SELECT /*+MATERIALIZE*/ d.dbid, r.prcsinstance, r.prcstype, r.prcsname, r.dbname, r.oprid, r.runcntlid, r.runstatus, r.begindttm, r.enddttm, q.sessionidnum
,      ROUND((CAST(NVL(r.enddttm,SYSDATE) AS DATE)-CAST(r.begindttm AS DATE))*86400,0) exec_Secs
FROM   v$database d
  INNER JOIN dba_hist_wr_control c ON c.dbid = d.dbid
  INNER JOIN psprcsrqst r ON r.prcsname = 'PSQUERY' AND r.prcstype = 'Application Engine' AND r.enddttm IS NOT NULL AND r.begindttm >= trunc(SYSDATE)-retention
  INNER JOIN psprcsque q ON q.prcsinstance = r.prcsinstance
WHERE  NOT r.runstatus IN('7','9')
), h as ( --ASH data for process requests
select /*+LEADING(r x)*/ r.prcsinstance, r.dbid, h.sql_id, h.sql_plan_hash_value, h.sql_full_plan_hash_value, NVL(c.consumer_group_name, h.consumer_group_id) consumer_group_name
,      sum(usecs_per_row)/1e6 ash_secs
,      sum(CASE WHEN event IS NULL THEN usecs_per_row End)/1e6 ash_cpu_secs
from   r
       INNER JOIN dba_hist_snapshot x
         ON x.dbid = r.dbid AND x.end_interval_time > r.begindttm AND x.begin_interval_time < r.enddttm
       INNER JOIN dba_hist_Active_Sess_history h
         ON x.dbid = h.dbid AND x.instance_number = h.instance_number AND x.snap_id = h.snap_id AND h.sample_time BETWEEN r.begindttm AND r.enddttm
         AND (  (h.module = r.prcsname AND h.action like 'PI='||r.prcsinstance||':%' AND r.prcsinstance = TO_NUMBER(REGEXP_SUBSTR(h.action,'[[:digit:]]+',4,1)))
             OR (h.module = 'PSAE.'||r.prcsname||'.'||r.sessionidnum and regexp_substr(h.module,'[^.]+',1,2) = r.prcsname and regexp_substr(h.module,'[^.]+',1,3) = r.sessionidnum))
       LEFT OUTER JOIN dba_hist_rsrc_consumer_group c ON c.dbid = h.dbid AND c.instance_number = h.instance_number AND c.snap_id = h.snap_id AND c.consumer_group_id = h.consumer_group_id
group by r.prcsinstance, r.dbid, h.sql_id, h.sql_plan_hash_value, h.sql_full_plan_hash_value, NVL(c.consumer_group_name, h.consumer_group_id) 
), x as ( --look for error message log 
SELECT /*+MATERIALIZE*/ r.dbid, r.prcsinstance, r.dbname
--     r.prcstype, r.prcsname
,      r.oprid, r.runcntlid
,      DECODE(c.private_query_flag,'Y','Private','N','Public') private_query_flag, c.qryname
--     r.begindttm, 
,      r.runstatus, r.exec_secs
,      l.dttm_stamp_sec, l.message_Seq, l.message_set_nbr, l.message_nbr
,      msg(l.process_instance, l.message_seq) msg
FROM r
       INNER JOIN ps_message_log l ON r.prcsinstance = l.process_instance 
--       AND l.message_Seq=1 AND l.message_set_nbr = 65 AND l.message_nbr = 30 --contains SQL text
         AND l.message_Seq=2 AND l.message_set_nbr = 50 AND l.message_nbr = 380 --contains SQL error message only
       INNER JOIN psmsgcatdefn m ON m.message_set_nbr = l.message_set_nbr AND m.message_nbr = l.message_nbr
       LEFT OUTER JOIN ps_query_run_cntrl c ON c.oprid = r.oprid AND c.run_cntl_id = r.runcntlid
), y as (
SELECT /*+MATERIALIZE LEADING(x)*/ x.prcsinstance, x.dbname, x.oprid, x.runcntlid, x.private_query_flag, x.qryname, x.runstatus
, regexp_substr(msg,'ORA-[0-9]{5}',1,1) errno
, x.exec_secs, h.ash_Secs, h.ash_cpu_secs, x.dttm_stamp_sec --, x.message_seq, x.message_set_nbr, x.message_nbr
, h.sql_id, h.sql_plan_hash_value, h.sql_full_plan_hash_value, h.consumer_group_name
, t.sql_text, CASE WHEN t.sql_id IS NULL THEN NULL ELSE dbms_sqltune.sqltext_to_signature(t.sql_text) END as signature
, msg --regexp_replace(substr(msg,regexp_instr(msg,'Failed SQL stmt:[ ]+',1,1,1)),'[ ]{2,}',' ') msg
, row_number() over (partition by x.prcsinstance order by h.ash_secs desc NULLS LAST) seq
FROM x
  LEFT OUTER JOIN h ON h.prcsinstance = x.prcsinstance 
  LEFT OUTER JOIN dba_hist_sqltext t ON t.dbid = h.dbid AND t.sql_id = h.sql_id
WHERE msg like 'Error%ORA-%'
AND (msg like '%ORA-56955%' or msg like '%ORA-00040%')
--AND msg like '%Failed SQL stmt:%'
)
SELECT prcsinstance, dbname, oprid, runcntlid, private_query_flag, qryname, runstatus, errno
, exec_secs, ash_Secs, ash_cpu_secs, dttm_stamp_sec --, message_seq, message_set_nbr, message_nbr
, sql_id, sql_plan_hash_value, sql_full_plan_hash_value, consumer_group_name
, y.signature, q.name, q.cpu_time, q.created, q.last_executed
--, y.msg
FROM y
  LEFT OUTER JOIN dba_sql_quarantine q ON q.signature = y.signature AND q.plan_hash_Value = y.sql_full_plan_hash_value
WHERE (y.seq = 1 OR q.signature IS NOT NULL)
ORDER BY dttm_stamp_sec DESC --, message_Seq, message_set_nbr, message_nbr
--FETCH FIRST 10 ROWS ONLY
/
spool off
ttitle off

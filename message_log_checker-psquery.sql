REM message_log_checker-psquery.sql
set serveroutput on trimspool on lines 148 pages 999 wrap on long 50000
column oprid format a8
column dbname format a7
column prcsinstance heading 'P.I.' format 99999999
column process_instance heading 'P.I.' format 99999999
column prcstype format a18
column prcsname heading 'Process|Name' format a7
column runcntlid format a30
column runstatus heading 'Run|Stat' format a2
column exec_secs heading 'Exec|Secs' format 99999
column private_query_flag heading 'Public/|Private|Query' format a7
column qryname format a30
column message_seq heading 'Msg|Seq' format 99
column message_set_nbr heading 'Msg|Set' format 99
column message_nbr heading 'Msg|Nbr' format 999
column begindttm format a28
column dttm_stamp_Sec format a28
column msg format a148
tittle off
break on prcsinstance skip 1 on dbname on prcstype on prcsname on oprid on runcntlid on runstatus on begindttm on exec_secs on private_query_flag on qryname
clear screen
spool message_log_checker-psquery.lst


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
x as (
SELECT r.prcsinstance, r.dbname
--     r.prcstype, r.prcsname
,      r.oprid, r.runcntlid
,      DECODE(c.private_query_flag,'Y','Private','N','Public') private_query_flag, c.qryname
--     r.begindttm, 
,      r.runstatus
,      (CAST(NVL(enddttm,SYSDATE) AS DATE)-CAST(begindttm AS DATE))*86400 exec_Secs
,      l.dttm_stamp_sec, l.message_Seq, l.message_set_nbr, l.message_nbr
,      msg(l.process_instance, l.message_seq) msg
FROM   v$database d
  INNER JOIN dba_hist_wr_control c ON c.dbid = d.dbid
  INNER JOIN psprcsrqst r ON r.prcsname = 'PSQUERY' AND r.prcstype = 'Application Engine' AND r.enddttm IS NOT NULL AND r.begindttm >= trunc(SYSDATE)-retention
  INNER JOIN ps_message_log l ON r.prcsinstance = l.process_instance
    AND ((l.message_Seq=1 AND l.message_set_nbr = 65 AND l.message_nbr = 30) --contains SQL text
      OR (l.message_Seq=2 AND l.message_set_nbr = 50 AND l.message_nbr = 380)) --contains SQL error message only
  INNER JOIN psmsgcatdefn m ON m.message_set_nbr = l.message_set_nbr AND m.message_nbr = l.message_nbr
  LEFT OUTER JOIN ps_query_run_cntrl c ON c.oprid = r.oprid AND c.run_cntl_id = r.runcntlid
WHERE NOT r.runstatus IN('7','9')
--and prcsinstance = 13519513
)
SELECT *
FROM x
WHERE msg like '%ORA-%'
AND (msg like '%ORA-56955%' or msg like '%ORA-00040%')
--AND msg like '%Failed SQL stmt:%'
ORDER BY dttm_stamp_sec DESC --, message_Seq, message_set_nbr, message_nbr
--FETCH FIRST 1 ROWS ONLY
/
spool off

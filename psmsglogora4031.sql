REM psmsglogora4031.sql
REM https://blog.psftdba.com/2023/04/querying-peoplesoft-message-log-with-sql.html

set pages 99 lines 170 serveroutput on long 50000 trimspool on
column prcstype heading 'Process|Type' format a20
column prcsname heading 'Process|Name' format a15
column oprid heading 'Operator|ID' format a10
column runcntlid heading 'Run Control' format a22
column process_instance heading 'Process|Instance' format 999999999
column message_seq heading 'Msg|Seq' format 999
column message_set_nbr heading 'Msg|Set#' format 9999
column message_nbr heading 'Msg#' format 9999
column message_severity heading 'Msg|Sev' format 9999
column dttm_stamp_sec format a28
column jobid format a15
column program_name format a15
column message_text format a150
spool psmsglogora4031.lst
WITH FUNCTION psmsgtext(p_process_instance INTEGER, p_message_seq INTEGER) RETURN CLOB IS
  l_message_log ps_message_log%ROWTYPE;
--l_message_text psmsgcatdefn.message_text%TYPE;
  l_message_text CLOB;
BEGIN
  SELECT *
  INTO   l_message_log
  FROM   ps_message_log 
  WHERE  process_instance = p_process_instance
  AND    message_seq = p_message_seq;

  SELECT message_text
  INTO   l_message_text
  FROM   psmsgcatdefn
  WHERE  message_set_nbr = l_message_log.message_set_nbr
  AND    message_nbr     = l_message_log.message_nbr;

  --dbms_output.put_line(l_message_text);
  FOR i IN (
    SELECT *
    FROM   ps_message_logparm
    WHERE  process_instance = p_process_instance
    AND    message_seq = p_message_seq
    ORDER BY parm_seq
  ) LOOP
    --dbms_output.put_line(i.message_parm);
    l_message_text := REPLACE(l_message_text,'%'||i.parm_seq,i.message_parm);
  END LOOP;

  --and tidy up the unused replacements at the end
  RETURN REGEXP_REPLACE(l_message_text,'%[1-9]','');
END;
x as (
select r.prcstype, r.prcsname, r.oprid, r.runcntlid
, l.*, psmsgtext(l.process_instance, l.message_seq) message_text
from ps_message_log l
LEFT OUTER JOIN psprcsrqst r ON r.prcsinstance = l.process_instance
WHERE 1=1
AND (l.process_instance, l.message_seq) IN(
  SELECT p.process_instance, p.message_seq
  FROM   ps_message_logparm p
  WHERE  p.message_parm like '%ORA-04031%')
and (l.message_set_nbr,l.message_nbr) IN((50,380),(65,30))
and l.dttm_stamp_Sec > sysdate-7
--and l.process_instance = 10263077 --10263772
)
select *
from x
ORDER BY dttm_stamp_sec
--fetch first 10 rows only
/
spool off
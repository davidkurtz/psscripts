set serveroutput on
WITH FUNCTION msg(p_process_instance NUMBER, p_message_seq NUMBER) RETURN VARCHAR2 IS 
  l_message VARCHAR2(4000);
BEGIN
  SELECT message_text
  INTO   l_message
  FROM   psmsgcatdefn c, ps_message_log l
  WHERE  l.process_instance = p_process_instance
  AND    l.message_seq = p_message_seq
  AND    c.message_set_nbr = l.message_set_nbr
  AND    c.message_nbr = l.message_nbr;
  FOR i IN (
    WITH n AS (SELECT level n FROM DUAL CONNECT BY LEVEL<=9)
    SELECT n.n, p.message_seq, p.message_parm
    FROM   n, ps_message_logparm p
    WHERE  p.process_instance(+) = p_process_instance
    AND    p.message_seq(+)= p_message_seq
    AND    p.parm_seq = n.n
    ORDER BY parm_seq DESC
  ) LOOP
    l_message := replace(l_message,'%'||i.n,i.message_parm);
--  dbms_output.put_line(i.message_seq||':'||i.message_parm||':'||i.n||':'||l_message);
  END LOOP;
RETURN l_message;
END;
x as (
SELECT 
    l.process_instance,
    a.oprid,
    a.runcntlid,
    l.dttm_stamp_sec,
    msg(l.process_instance, l.message_seq) msg
FROM
    psprcsrqst      a,
    ps_message_log  l,
    psmsgcatdefn    m
WHERE a.prcsinstance = l.process_instance
AND m.message_set_nbr = l.message_set_nbr
AND m.message_nbr = l.message_nbr
AND a.prcsname IN ( 'NVSRUN', 'RPTBOOK' )
)
SELECT * FROM x
WHERE dttm_stamp_Sec >= sysdate - 3
AND (msg LIKE '%Error%'
OR   msg LIKE '%invalid for document templates%'
OR   msg LIKE '%PROCESSING%%but no longer running%')
ORDER BY dttm_stamp_Sec
/

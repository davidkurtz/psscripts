REM set_prcs_sess_parm_trg.sql
REM 6.4.2018 added KEYWORD to permit other ALTER SESSION commands
REM https://blog.psftdba.com/2018/03/setting-oracle-session-parameters-for.html
REM https://blog.psftdba.com/2024/09/cursor-sharing-3.html
set echo on
spool set_prcs_sess_parm_trg

rollback;
alter session set current_schema=SYSADM;

REM DROP TABLE sysadm.PS_PRCS_SESS_PARM;
CREATE TABLE sysadm.PS_PRCS_SESS_PARM (PRCSTYPE VARCHAR2(30) NOT NULL,
   PRCSNAME VARCHAR2(12) NOT NULL,
   OPRID VARCHAR2(30) NOT NULL,
   RUNCNTLID VARCHAR2(30) NOT NULL,
   KEYWORD VARCHAR2(8) NOT NULL, /*keyword is uset to specify first word after ALTER SESSION command - SET, ENABLE, FORCE etc*/
   PARAM_NAME VARCHAR2(50) NOT NULL,
   PARMVALUE VARCHAR2(128) NOT NULL) TABLESPACE PTTBL 
/
CREATE UNIQUE  iNDEX sysadm.PS_PRCS_SESS_PARM ON sysadm.PS_PRCS_SESS_PARM (PRCSTYPE,
   PRCSNAME,
   OPRID,
   RUNCNTLID,
   PARAM_NAME) TABLESPACE PSINDEX
/
ALTER INDEX sysadm.PS_PRCS_SESS_PARM NOPARALLEL LOGGING
/

set serveroutput on

rollback;
CREATE OR REPLACE TRIGGER sysadm.set_prcs_sess_parm
BEFORE UPDATE OF runstatus ON sysadm.psprcsrqst
FOR EACH ROW
WHEN (new.runstatus = 7 
  AND old.runstatus != 7 
  AND new.prcstype != 'PSJob')
DECLARE
  l_cmd VARCHAR2(100 CHAR);
  l_delim VARCHAR2(1 CHAR) := '';
  l_op VARCHAR2(1 CHAR) := '=';
BEGIN
  dbms_output.put_line('Row:'||:new.prcstype||'.'||:new.prcsname||':'||:new.oprid||'.'||:new.runcntlid);

  FOR i IN (
    WITH x as (
      SELECT p.*
      ,      row_number() over (partition by param_name 
                               order by NULLIF(prcstype, ' ') nulls last,
                                        NULLIF(prcsname, ' ') nulls last,
                                        NULLIF(oprid, ' ') nulls last,
                                        NULLIF(runcntlid,' ') nulls last
                              ) priority
      FROM   sysadm.PS_PRCS_SESS_PARM p
      WHERE  (p.prcstype  = :new.prcstype  OR p.prcstype  = ' ')
      AND    (p.prcsname  = :new.prcsname  OR p.prcsname  = ' ')
      AND    (p.oprid     = :new.oprid     OR p.oprid     = ' ')
      AND    (p.runcntlid = :new.runcntlid OR p.runcntlid = ' ')
    ) 
    SELECT * FROM x
    WHERE priority = 1 
  ) LOOP

    IF UPPER(i.keyword) = 'SET' THEN
      l_op := '=';
      IF SUBSTR(i.param_name,1,1) = '_' THEN 
        l_delim := '"';
      ELSE
        l_delim := '';
      END IF;   
    ELSE 
      l_op := ' ';
      l_delim := '';
    END IF;

    IF NULLIF(i.parmvalue,' ') IS NOT NULL THEN
      dbms_output.put_line('Rule:'||NVL(NULLIF(i.prcstype,' '),'*')
                             ||'.'||NVL(NULLIF(i.prcsname,' '),'*')
                             ||':'||NVL(NULLIF(i.oprid,' '),'*')
                             ||'.'||NVL(NULLIF(i.runcntlid,' '),'*')
                             ||':'||i.keyword||':'||i.param_name||l_op||i.parmvalue);

      l_cmd := 'ALTER SESSION '||i.keyword||' '||l_delim||i.param_name||l_delim||l_op||i.parmvalue;
      dbms_output.put_line('PI='||:new.prcsinstance||':'||:new.prcstype||'.'||:new.prcsname||':'
                                ||:new.oprid||'.'||:new.runcntlid||':'||l_cmd);
      EXECUTE IMMEDIATE l_cmd;
    END IF;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line(sqlerrm);
END;
/
show errors

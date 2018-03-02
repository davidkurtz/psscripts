REM set_prcs_sess_parm.sql
REM see http://blog.psftdba.com/2018/03/setting-oracle-session-parameters-for.html
spool set_prcs_sess_parm
rollback;
alter session set current_schema=SYSADM;
DROP TABLE sysadm.PS_PRCS_SESS_PARM 
/
CREATE TABLE sysadm.PS_PRCS_SESS_PARM (PRCSTYPE VARCHAR2(30) NOT NULL,
   PRCSNAME VARCHAR2(12) NOT NULL,
   OPRID VARCHAR2(30) NOT NULL,
   RUNCNTLID VARCHAR2(30) NOT NULL,
   PARAM_NAME VARCHAR2(50) NOT NULL,
   PARMVALUE VARCHAR2(128) NOT NULL) TABLESPACE PTTBL STORAGE (INITIAL
 40000 NEXT 100000 MAXEXTENTS UNLIMITED PCTINCREASE 0) PCTFREE 10
 PCTUSED 80
/
CREATE UNIQUE  iNDEX sysadm.PS_PRCS_SESS_PARM ON sysadm.PS_PRCS_SESS_PARM (PRCSTYPE,
   PRCSNAME,
   OPRID,
   RUNCNTLID,
   PARAM_NAME) TABLESPACE PSINDEX STORAGE (INITIAL 40000 NEXT 100000
 MAXEXTENTS UNLIMITED PCTINCREASE 0) PCTFREE 10 PARALLEL NOLOGGING
/
ALTER INDEX sysadm.PS_PRCS_SESS_PARM NOPARALLEL LOGGING
/

rollback;
delete from sysadm.PS_PRCS_SESS_PARM;
REM this metadata is only a suggestion, your mileage will vary
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, param_name, parmvalue)
VALUES ('nVision-ReportBook','RPTBOOK',' ',' ', 'parallel_degree_policy','auto');
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, param_name, parmvalue)
VALUES ('nVision-ReportBook','RPTBOOK',' ',' ', 'parallel_degree_limit','4');
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, param_name, parmvalue)
VALUES ('nVision-ReportBook','RPTBOOK',' ',' ', 'parallel_degree_level','150');
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, param_name, parmvalue)
VALUES ('nVision-ReportBook','RPTBOOK',' ',' ', 'parallel_min_time_threshold','1');
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, param_name, parmvalue)
VALUES ('nVision-ReportBook','RPTBOOK',' ',' ', '_optimizer_skip_scan_enabled','FALSE');
commit;

column prcstype   format a20
column oprid      format a10
column param_name format a30
column runcntlid  format a15
column parmvalue  format a20
select * from sysadm.PS_PRCS_SESS_PARM;

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
  l_delim VARCHAR2(1 CHAR);
BEGIN
  FOR i IN (
    WITH x as (
      SELECT p.*
      ,      row_number() over (partition by param_name 
                               order by NULLIF(prcstype, ' ') nulls last,
                                        NULLIF(prcsname, ' ') nulls last,
                                        NULLIF(oprid, ' ') nulls last,
                                        NULLIF(runcntlid,' ') nulls last
                              ) priority
      FROM   PS_PRCS_SESS_PARM p
      WHERE  (p.prcstype  = :new.prcstype  OR p.prcstype  = ' ')
      AND    (p.prcsname  = :new.prcsname  OR p.prcsname  = ' ')
      AND    (p.oprid     = :new.oprid     OR p.oprid     = ' ')
      AND    (p.runcntlid = :new.runcntlid OR p.runcntlid = ' ')
    ) 
    SELECT * FROM x
    WHERE priority = 1 
  ) LOOP
    IF SUBSTR(i.param_name,1,1) = '_' THEN 
      l_delim := '"';
    ELSE
      l_delim := '';
    END IF;

    IF NULLIF(i.parmvalue,' ') IS NOT NULL THEN
      dbms_output.put_line('Rule:'||NVL(NULLIF(i.prcstype,' '),'*')
                             ||'.'||NVL(NULLIF(i.prcsname,' '),'*')
                             ||':'||NVL(NULLIF(i.oprid,' '),'*')
                             ||'.'||NVL(NULLIF(i.runcntlid,' '),'*')
                             ||':'||i.param_name||'='||i.parmvalue);

      l_cmd := 'ALTER SESSION SET '||l_delim||i.param_name||l_delim||'='||i.parmvalue;
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

--column text format a129 word_wrapped on 
--select line, text from user_source
--where name = 'SET_PRCS_SESS_PARM';

--drop TRIGGER sysadm.set_prcs_sess_parm;
/*
set serveroutput on 
rollback;
update psprcsrqst
set runstatus = 7
where runstatus != 7
and prcsname = 'RPTBOOK'
and runcntlid = 'NVS_RPTBOOK_2'
and oprid = 'NVISION'
and rownum = 1;
rollback;
update psprcsrqst
set runstatus = 7
where runstatus != 7
and prcsname = 'RPTBOOK'
and runcntlid = 'NVS_RPTBOOK_1'
and oprid = 'NVISION'
and rownum = 1;
rollback;
*/
spool off


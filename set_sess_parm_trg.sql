REM set_sess_parm_trg.sql
REM 26.2.2025 created onlogon to SYSADM trigger to detect program name
REM https://blog.psftdba.com/2025/03/resourcemanagericquerytimelimit.html
set echo on
spool set_sess_parm_trg

rollback;
alter session set current_schema=SYSADM;

REM DROP TABLE sysadm.PS_SESS_PARM;
CREATE TABLE sysadm.PS_SESS_PARM 
  (PROGRAM_NAME VARCHAR2(30) NOT NULL,
   KEYWORD VARCHAR2(8) NOT NULL, /*keyword is uset to specify first word after ALTER SESSION command - SET, ENABLE, FORCE etc*/
   PARAM_NAME VARCHAR2(50) NOT NULL,
   PARMVALUE VARCHAR2(128) NOT NULL) TABLESPACE PTTBL
/
CREATE UNIQUE  iNDEX sysadm.PS_SESS_PARM ON sysadm.PS_SESS_PARM (UPPER(PROGRAM_NAME), PARAM_NAME) TABLESPACE PSINDEX 
/
ALTER INDEX sysadm.PS_SESS_PARM NOPARALLEL LOGGING
/

set serveroutput on

rollback;

create or replace TRIGGER SYSADM.set_sess_parm 
AFTER LOGON ON sysadm.SCHEMA
DECLARE
  l_program_name VARCHAR2(64) := UPPER(REGEXP_SUBSTR(sys_context('USERENV', 'CLIENT_PROGRAM_NAME'),'[^@.]+',1,1)) /*trim from either @ or .*/;

  l_cmd VARCHAR2(100 CHAR);
  l_delim VARCHAR2(1 CHAR) := '';
  l_op VARCHAR2(1 CHAR) := '=';
BEGIN
  --dbms_output.put_line('Program:'||l_program_name);
  FOR i IN (
    SELECT *
    FROM   sysadm.PS_SESS_PARM p
    WHERE  REGEXP_LIKE(l_program_name,p.program_name,'i')
    OR     l_program_name LIKE UPPER(p.program_name)
    OR     UPPER(p.program_name) = l_program_name
  ) LOOP
    --dbms_output.put_line('program='||l_program_name||':'||i.param_name);
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

    l_cmd := 'ALTER SESSION '||i.keyword||' '||l_delim||i.param_name||l_delim||l_op||i.parmvalue;
    dbms_output.put_line('program='||l_program_name||':'||l_cmd);
    EXECUTE IMMEDIATE l_cmd;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line(sqlerrm);
END;
/
show errors


----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--Settings for PSQuery -- added 26.02.2025 - note SQL checks that parameter is valid
----------------------------------------------------------------------------------------------------
truncate table sysadm.PS_SESS_PARM;
----------------------------------------------------------------------------------------------------
INSERT INTO sysadm.PS_SESS_PARM (program_name, keyword, param_name, parmvalue)
with n as ( --returns a row if on Exadata
SELECT  COUNT(DISTINCT cell_name) num_exadata_cells
FROM    v$cell_state
HAVING  COUNT(DISTINCT cell_name)>0
), x (param_name, keyword, parmvalue) as ( --returns rows if parameters available
  select  name, 'SET', 'FALSE' 
  from    v$parameter
  where   name IN('optimizer_capture_sql_quarantine','optimizer_use_sql_quarantine')
), y (program_name) as (
  select  'PS(APP|QRY)SRV' from dual
)
select  y.program_name, x.keyword, x.param_name, x.parmvalue
from    x,y
/
----------------------------------------------------------------------------------------------------
INSERT INTO sysadm.PS_SESS_PARM (program_name, keyword, param_name, parmvalue)
with n as ( --returns a row if on Exadata
SELECT  COUNT(DISTINCT cell_name) num_exadata_cells
FROM    v$cell_state
HAVING  COUNT(DISTINCT cell_name)>0
), x (param_name, keyword, parmvalue) as ( --returns rows if parameters available
  select  name, 'SET', 'TRUE' 
  from    v$parameter
  where   name IN('optimizer_capture_sql_quarantine','optimizer_use_sql_quarantine')
), y (program_name) as (
  select  'Toad'          from dual union all
  select  'sqlplus'       from dual union all
  select  'SQL Developer' from dual
)
select  y.program_name, x.keyword, x.param_name, x.parmvalue
from    x,y
/
----------------------------------------------------------------------------------------------------
COMMIT
/
----------------------------------------------------------------------------------------------------
select * from sysadm.PS_SESS_PARM
ORDER BY 1
/
----------------------------------------------------------------------------------------------------
show parameters quarantine
----------------------------------------------------------------------------------------------------
spool off



REM ps_query_run_cntrl_hist_trigger.sql
REM 21.4.2025 - trigger and history tables to capture
REM see also application Designer project QRYRUN_HST.ZIP - 
set echo on serveroutput on timi on
clear screen
spool ps_query_run_cntrl_hist_trigger
rollback;

----------------------------------------------------------------------------------------------------
-- create psquery history logging tables - recommend also load PeopleSoft Application Designer project
----------------------------------------------------------------------------------------------------
CREATE TABLE PS_QRYRUN_CTL_HST (PRCSINSTANCE INTEGER  DEFAULT 0 NOT NULL,
   OPRID VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   RUN_CNTL_ID VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   DESCR VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   QRYTYPE SMALLINT  DEFAULT 1 NOT NULL,
   PRIVATE_QUERY_FLAG VARCHAR2(1)  DEFAULT 'N' NOT NULL,
   QRYNAME VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   URL VARCHAR2(254)  DEFAULT ' ' NOT NULL,
   ASIAN_FONT_SETTING VARCHAR2(3)  DEFAULT ' ' NOT NULL,
   PTFP_FEED_ID VARCHAR2(30)  DEFAULT ' ' NOT NULL) TABLESPACE PTTBL
/
CREATE UNIQUE  iNDEX PS_QRYRUN_CTL_HST ON PS_QRYRUN_CTL_HST (PRCSINSTANCE) TABLESPACE PSINDEX PARALLEL NOLOGGING
/
ALTER INDEX PS_QRYRUN_CTL_HST NOPARALLEL LOGGING
/
CREATE TABLE PS_QRYRUN_PARM_HST (PRCSINSTANCE INTEGER  DEFAULT 0 NOT NULL,
   OPRID VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   RUN_CNTL_ID VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   BNDNUM SMALLINT  DEFAULT 0 NOT NULL,
   FIELDNAME VARCHAR2(18)  DEFAULT ' ' NOT NULL,
   BNDNAME VARCHAR2(30)  DEFAULT ' ' NOT NULL,
   BNDVALUE CLOB) TABLESPACE PSIMAGE2 STORAGE (INITIAL 40000 NEXT
 100000 MAXEXTENTS UNLIMITED PCTINCREASE 0) PCTFREE 10 PCTUSED 80
/
CREATE UNIQUE  iNDEX PS_QRYRUN_PARM_HST ON PS_QRYRUN_PARM_HST
 (PRCSINSTANCE,
   BNDNUM) TABLESPACE PSINDEX PARALLEL NOLOGGING
/
ALTER INDEX PS_QRYRUN_PARM_HST NOPARALLEL LOGGING
/

----------------------------------------------------------------------------------------------------
-- trigger to copy PSQUERY run control and bind variables to history table
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER sysadm.query_run_cntrl_hist_ins
BEFORE UPDATE OF runstatus ON sysadm.psprcsrqst
FOR EACH ROW
WHEN (new.runstatus ='7' AND old.runstatus != '7' AND new.prcsname = 'PSQUERY' AND new.prcstype = 'Application Engine')
BEGIN
  INSERT INTO PS_QRYRUN_CTL_HST
  (PRCSINSTANCE, OPRID, RUN_CNTL_ID, DESCR ,QRYTYPE, PRIVATE_QUERY_FLAG, QRYNAME, URL, ASIAN_FONT_SETTING, PTFP_FEED_ID)
  SELECT :new.prcsinstance, OPRID, RUN_CNTL_ID, DESCR ,QRYTYPE, PRIVATE_QUERY_FLAG, QRYNAME, URL, ASIAN_FONT_SETTING, PTFP_FEED_ID 
  FROM ps_query_run_cntrl WHERE oprid = :new.oprid AND run_cntl_id = :new.runcntlid;
  
  INSERT INTO PS_QRYRUN_PARM_HST
  (PRCSINSTANCE, OPRID, RUN_CNTL_ID, BNDNUM, FIELDNAME, BNDNAME, BNDVALUE) 
  SELECT :new.prcsinstance prcsinstance, OPRID, RUN_CNTL_ID, BNDNUM, FIELDNAME, BNDNAME, BNDVALUE
  FROM ps_query_run_parm WHERE oprid = :new.oprid AND run_cntl_id = :new.runcntlid;

  EXCEPTION WHEN OTHERS THEN NULL; --exception deliberately coded to suppress all exceptions
END;
/

----------------------------------------------------------------------------------------------------
-- trigger to purge PSQUERY run control and bind variable history table when process request purged
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER sysadm.query_run_cntrl_hist_del
BEFORE DELETE ON sysadm.psprcsrqst
FOR EACH ROW
WHEN (old.prcsname = 'PSQUERY' AND old.prcstype = 'Application Engine')
BEGIN
  DELETE FROM PS_QRYRUN_CTL_HST WHERE prcsinstance = :old.prcsinstance;
  DELETE FROM PS_QRYRUN_PARM_HST WHERE prcsinstance = :old.prcsinstance;

  EXCEPTION WHEN OTHERS THEN NULL; --exception deliberately coded to suppress all exceptions
END;
/
show errors

/*----------------------------------------------------------------------------------------------------
--SQL Test scripts
----------------------------------------------------------------------------------------------------
rollback;
----------------------------------------------------------------------------------------------------
--Mark a completed PSQUERY request for which there are bind variables as running,and then look for rows in history tables
----------------------------------------------------------------------------------------------------
UPDATE psprcsrqst r
SET runstatus = '7'
WHERE runstatus = '9'
AND prcsname = 'PSQUERY'
AND EXISTS(SELECT 'x' FROM ps_querY_run_parm p WHERE r.oprid = p.oprid AND r.runcntlid = p.run_cntl_id)
And rownum = 1
/


----------------------------------------------------------------------------------------------------
-- verify history rows deleted when process request deleted.
----------------------------------------------------------------------------------------------------
select * from psprcsrqst where prcsinstance = 12390288
/
delete from psprcsrqst where prcsinstance = 12390288
/
----------------------------------------------------------------------------------------------------
--query history records
----------------------------------------------------------------------------------------------------
column oprid format a8
column run_cntl_id format a12
column url format a50
column bndnum format 999
column bndname format a20
column bndvalue format a30
select * from ps_qryrun_ctl_hst order by prcsinstance
/
select * from ps_qryrun_parm_hst order by prcsinstance, bndnum
/
----------------------------------------------------------------------------------------------------
--remember to roll these updates back and not to commit them
----------------------------------------------------------------------------------------------------
rollback;

*/
spool off


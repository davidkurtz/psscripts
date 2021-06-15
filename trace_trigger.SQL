spool trace_trigger
rem (c)Go-Faster Consultancy Ltd. 2008

rem 1.5.2008 - moved logic to disable trace from unset_trace trigger into main trigger because cursors in AE not shut until after status is changed away from processing
rem 26.3.2009 - max_dump_file_size cannot be specified in Mb, only system blocks
rem 17.4.2009 - added processing status to action

ROLLBACK;
----------------------------------------------------------------
REM explicit grants by sys required on following privileges
----------------------------------------------------------------
GRANT ALTER SESSION TO sysadm;
GRANT EXECUTE ON sys.dbms_monitor TO sysadm;
GRANT EXECUTE ON sys.dbms_application_info TO SYSADM;
----------------------------------------------------------------

CREATE OR REPLACE TRIGGER sysadm.gfc_set_trace
BEFORE UPDATE OF runstatus ON sysadm.psprcsrqst
FOR EACH ROW
WHEN (new.runstatus = '7' AND old.runstatus != '7' AND new.prcstype != 'PSJob')
DECLARE
  l_waits BOOLEAN := TRUE;
  l_binds BOOLEAN := FALSE;
BEGIN
  --set module and action whether we are tracing or not
  sys.dbms_application_info.set_module(
	module_name => :new.prcsname,
	action_name => SUBSTR('PI='||:new.prcsinstance||':Processing',1,32)
  );

  IF ( :new.runcntlid LIKE 'TRACE%' 
  ----------------------------------------------------------------
  --code conditions for enabling trace here instead of when clause
  ----------------------------------------------------------------
  --  OR (    SUBSTR(:new.prcsname,1,3) = 'TL_'
  --      AND :new.rqstdttm <= TO_DATE('20080509','YYYYMMDD'))
  ----------------------------------------------------------------
     ) THEN

    --explicitly set tracefile identifier whether we are tracing or not
    EXECUTE IMMEDIATE 'ALTER SESSION SET TRACEFILE_IDENTIFIER = '''||
--    TRANSLATE(:new.prcstype     ,' -','__')||'_'||
      TRANSLATE(:new.prcsname     ,' -','__')||'_'||
      :new.prcsinstance||'_'||
       TRANSLATE(:new.servernamerun,' -','__')||
       '''';
   
    EXECUTE IMMEDIATE 'ALTER SESSION SET TIMED_STATISTICS = TRUE';
    EXECUTE IMMEDIATE 'ALTER SESSION SET MAX_DUMP_FILE_SIZE = 2097152'; --1Gb
    EXECUTE IMMEDIATE 'ALTER SESSION SET STATISTICS_LEVEL=ALL';

    ----------------------------------------------------------------
    --logic to determine whether you want to trace binds also
    ----------------------------------------------------------------
    IF :new.runcntlid LIKE 'TRACE%BIND%' THEN
      l_binds := TRUE;
    END IF;
    ----------------------------------------------------------------

    sys.dbms_monitor.session_trace_enable(waits=>TRUE,binds=>l_binds);
    ----------------------------------------------------------------
    --Alternative for Oracle 9i and earlier
    --EXECUTE IMMEDIATE 'ALTER SESSION SET EVENTS ''10046 TRACE NAME CONTEXT FOREVER, LEVEL 12''';
    ----------------------------------------------------------------

  ELSIF :new.prcstype = 'Application Engine' THEN 
    --explicitly disable trace if application server process
    sys.dbms_monitor.session_trace_disable;

    --reset max dump file size AFTER disabling trace
    EXECUTE IMMEDIATE 'ALTER SESSION SET MAX_DUMP_FILE_SIZE = 10240';

    --explicitly set tracefile identifier whether we are tracing or not
    --5.11.2013 removed because it writes to trace file leaving lots of small trace files 
    --EXECUTE IMMEDIATE 'ALTER SESSION SET TRACEFILE_IDENTIFIER = ''''';
   
  END IF;
EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Exception in trigger GFC_SET_TRACE ignored'); --exception deliberately coded to suppress all exceptions
END;
/

show errors

DROP TRIGGER sysadm.unset_trace;

rem test that the trigger fires by updating something
UPDATE sysadm.psprcsrqst new
SET    runstatus = 7
WHERE  runstatus != 7
AND    new.prcstype != 'PSJob'
AND    new.prcstype = 'Application Engine' 
AND	   new.runcntlid LIKE 'TRACE%'
AND    rownum = 1
--AND 1=2
;

ROLLBACK;
--drop trigger gfc_set_trace;
spool off




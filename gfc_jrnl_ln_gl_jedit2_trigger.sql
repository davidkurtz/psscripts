REM gfc_jrnl_ln_gl_jedit2_trigger.sql
REM https://blog.psftdba.com/2024/09/cursor-sharing-3.html
set pages 99 lines 200 long 5000
column table_owner format a11
column base_object_type format a16
columm table_name format 18
column trigger_name format a30
column triggering_event format a20
column column_name format a20
column referencing_names format a35
column when_clause format a60
column description format a30
column trigger_body format a100
clear screen
spool gfc_jrnl_ln_gl_jedit2_trigger.lst
set echo on serveroutput on 

DROP TRIGGER gfc_jrnl_ln_fspccurr_gl_jedit2;

CREATE OR REPLACE TRIGGER gfc_jrnl_ln_gl_jedit2
FOR UPDATE OF process_instance ON ps_jrnl_ln
WHEN (new.process_instance != 0 and old.process_instance = 0)
COMPOUND TRIGGER
  l_process_instance INTEGER;
  l_runcntlid VARCHAR2(30);
  l_module VARCHAR2(64);
  l_action VARCHAR2(64);
  l_prcsname VARCHAR2(12);
  l_cursor_sharing CONSTANT VARCHAR2(64) := 'ALTER SESSION SET cursor_sharing=FORCE';

  AFTER EACH ROW IS 
  BEGIN
    l_process_instance := :new.process_instance;
    --dbms_output.put_line('process_instance='||l_process_instance);
  END AFTER EACH ROW;
  
  AFTER STATEMENT IS 
  BEGIN
    IF l_process_instance != 0 THEN
      dbms_application_info.read_module(l_module,l_action);
      --dbms_output.put_line('module='||l_module||',action='||l_action);
      IF l_module like 'PSAE.GL_JEDIT2.%' THEN --check this session is instrumented as being GL_JEDIT
        --check process instance being set is a running FSPCCURR process
        SELECT prcsname, runcntlid
        INTO l_prcsname, l_runcntlid
        FROM psprcsrqst
        WHERE prcsinstance = l_process_instance
        AND prcsname IN('FSPCCURR','GLPOCONS')
        AND runstatus = '7';
        
        l_module := regexp_substr(l_module,'PSAE\.GL_JEDIT2\.[0-9]+',1,1)||':'||l_prcsname||':PI='||l_process_instance||':'||l_runcntlid;
        dbms_application_info.set_module(l_module,l_action);
        --dbms_output.put_line('set module='||l_module||',action='||l_action);
        EXECUTE IMMEDIATE l_cursor_sharing;
        --dbms_output.put_line('set cursor_sharing');
      END IF;
    END IF;
  EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
      --dbms_output.put_line('Cannot find running '||l_prcsname||' process instance '||l_process_instance);
      NULL; --cannot find running fspccurr/glpocons with this process instance number
    WHEN OTHERS THEN
      --dbms_output.put_line('Other Error:'||sqlerrm);
      NULL;
  END AFTER STATEMENT;

END gfc_jrnl_ln_gl_jedit2;
/
show errors 

--DROP TRIGGER gfc_jrnl_ln_gl_jedit2;
ALTER TRIGGER gfc_jrnl_ln_gl_jedit2 ENABLE;
select * from user_triggers where table_name = 'PS_JRNL_LN' and trigger_name = 'GFC_JRNL_LN_GL_JEDIT2';

spool off

/*
UPDATE PS_JRNL_LN SET PROCESS_INSTANCE=0 
WHERE PROCESS_INSTANCE IN (11481032, 9011481032) 
AND BUSINESS_UNIT IN ( SELECT DISTINCT BUSINESS_UNIT FROM PS_JRNL_HEADER WHERE PROCESS_INSTANCE=11481032 AND JRNL_HDR_STATUS IN ('P','V','E'))

UPDATE PS_JRNL_LN SET JRNL_LINE_STATUS='0', PROCESS_INSTANCE=:1 
WHERE BUSINESS_UNIT=:2 AND JOURNAL_ID=:3 AND JOURNAL_DATE=TO_DATE(:4,'YYYY-MM-DD') AND UNPOST_SEQ=0
*/
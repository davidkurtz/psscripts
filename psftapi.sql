REM psftapi.sql
REM (c)David Kurtz 2009-16
REM 26.11.2013 - comment out trigger prcsrqststrng_action from script
REM 17.3.2016 no longer dropping legacy trigger name

set echo on serveroutput on buffer 1000000000 
---------------------------------------------------------------------------------------------------------
--This package contains provides an API to insert a message into the message log.  It is owned by the 
--PeopleSoft user sysadm, so that it does not require any grants on the PeopleSoft objects.  It is only 
--necessary to grant execute privilege on the package to other schemas (such as obishare) for it to be 
--usable.
---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE sysadm.psftapi AS 

---------------------------------------------------------------------------------------
--Write process instance number into a global PL/SQL variable to be used later
--This package is used by a trigger on PSPRCSRQST which will save the process instance
--in the global variable using this procedure.
---------------------------------------------------------------------------------------
PROCEDURE set_prcsinstance
(p_prcsinstance INTEGER
,p_prcsname     VARCHAR2 DEFAULT NULL
);

---------------------------------------------------------------------------------------
--Read process name, instance number into global PL/SQL variables to be used later
---------------------------------------------------------------------------------------
FUNCTION get_prcsinstance RETURN INTEGER;
FUNCTION get_prcsname     RETURN VARCHAR2;

---------------------------------------------------------------------------------------
--Writes a message to the PeopleSoft message log using delivered generic message (65,30)
---------------------------------------------------------------------------------------
PROCEDURE message_log
(p_message  VARCHAR2
,p_severity INTEGER DEFAULT 42
,p_verbose  BOOLEAN DEFAULT FALSE
);

---------------------------------------------------------------------------------------
--Set ACTION to status description
---------------------------------------------------------------------------------------
PROCEDURE set_action
(p_prcsinstance INTEGER
,p_runstatus    VARCHAR2
,p_prcsname     VARCHAR2 DEFAULT NULL
);

---------------------------------------------------------------------------------------
--get session_longops index
---------------------------------------------------------------------------------------
PROCEDURE get_session_longops
(p_rindex    OUT BINARY_INTEGER
,p_slno      OUT BINARY_INTEGER
,p_sofar     OUT NUMBER
,p_totalwork OUT NUMBER
);

---------------------------------------------------------------------------------------
--set session_longops index
---------------------------------------------------------------------------------------
PROCEDURE set_session_longops
(p_rindex    IN BINARY_INTEGER
,p_slno      IN BINARY_INTEGER
,p_sofar     IN NUMBER
,p_totalwork IN NUMBER
);

END psftapi;
/

show errors

---------------------------------------------------------------------------------------
--Package Body
---------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY sysadm.psftapi AS 

--variables that are global to package only stored between calls within session
g_prcsinstance INTEGER;          --peoplesoft process instance number
g_prcsname     VARCHAR(12 CHAR); --peoplesoft process name

--session long ops variables
g_rindex       BINARY_INTEGER;
g_slno         BINARY_INTEGER;
g_sofar        NUMBER;
g_totalwork    NUMBER;

---------------------------------------------------------------------------------------
PROCEDURE set_prcsinstance
(p_prcsinstance INTEGER
,p_prcsname     VARCHAR2 DEFAULT NULL
) IS
 l_module VARCHAR2(48 CHAR);
 l_action VARCHAR2(32 CHAR);
BEGIN
-- sys.dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
-- sys.dbms_application_info.set_module(module_name=>'psftapi.set_prcsinstance', action_name=>'Begin');
-- dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);

 g_prcsinstance := p_prcsinstance;
 g_prcsname     := p_prcsname;

END;

---------------------------------------------------------------------------------------
--Read process instance number into global PL/SQL variables to be used later
---------------------------------------------------------------------------------------
FUNCTION get_prcsinstance 
RETURN INTEGER IS
BEGIN
 RETURN g_prcsinstance;
END;

---------------------------------------------------------------------------------------
--Read process name into global PL/SQL variables to be used later
---------------------------------------------------------------------------------------

FUNCTION get_prcsname
RETURN VARCHAR2 IS
BEGIN
 RETURN g_prcsname;
END;

---------------------------------------------------------------------------------------
--Writes a message to the PeopleSoft message log using delivered generic message (65,30)
---------------------------------------------------------------------------------------
PROCEDURE message_log
(p_message  VARCHAR2
,p_severity INTEGER
,p_verbose  BOOLEAN DEFAULT FALSE
) IS 
 l_module VARCHAR2(48 CHAR);
 l_action VARCHAR2(32 CHAR);
 l_max_message_seq INTEGER; --maximum already inserted message
 l_str_start INTEGER := 1; --position from which to start breaking up message string
 l_msg_piece VARCHAR2(254 CHAR); --piece of message
 l_last_space INTEGER; --position of last space in string
 l_msg_pieces INTEGER := 0; --count number of message string pieces
 PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
--sys.dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
--sys.dbms_application_info.set_module(module_name=>'psftapi.message_log', action_name=>'Begin');

 IF p_verbose THEN
  dbms_output.put_line(p_message);
 END IF;
 IF g_prcsinstance > 0 AND p_message IS NOT NULL THEN

  BEGIN 
   --lock the first message for this process instance --this is what PeopleSoft does!
   SELECT message_seq
   INTO   l_max_message_seq
   FROM   ps_message_log 
   WHERE  process_instance = g_prcsinstance
   AND    message_seq = 1
   FOR UPDATE OF process_instance;

   --get the maximum used seq - serialised by previous statement
   SELECT MAX(message_seq)
   INTO   l_max_message_seq
   FROM   ps_message_log
   WHERE  process_instance = g_prcsinstance;
  EXCEPTION
   WHEN no_data_found THEN
    l_max_message_seq := 0;
  END;

  INSERT INTO ps_message_log
  (process_instance, message_seq, jobid, program_name
  ,message_set_nbr, message_nbr, message_severity, dttm_stamp_sec)
  VALUES
  (g_prcsinstance
  ,l_max_message_seq+1
  ,' '   --jobid
  ,' '   --program_name
  ,65,30 --always use PSFT delivered generic message that can take 9 paramters 
  ,NVL(p_severity,0) --message_severity
  ,SYSDATE);

  LOOP
   l_msg_piece := SUBSTR(p_message,l_str_start,254);
   l_msg_pieces := l_msg_pieces + 1;
   IF l_msg_piece IS NULL OR l_msg_pieces > 9 THEN
    EXIT; --stop processing message text
   END IF;

   l_last_space := INSTR(l_msg_piece,' ',-1);
   IF LENGTH(l_msg_piece)=254 AND l_last_space<254 AND l_last_space > 0 THEN
    l_msg_piece := SUBSTR(l_msg_piece,1,l_last_space);
   END IF;

   --insert it if not null
   INSERT INTO ps_message_logparm
   (process_instance, message_seq, parm_seq, message_parm)
   VALUES
   (g_prcsinstance
   ,l_max_message_seq+1
   ,l_msg_pieces
   ,l_msg_piece
   );

   l_str_start := l_str_start + LENGTH(l_msg_piece);
  END LOOP;
 END IF;

 COMMIT;
--dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);
END message_log;

---------------------------------------------------------------------------------------
--Set ACTION to status description
---------------------------------------------------------------------------------------
PROCEDURE set_action
(p_prcsinstance INTEGER
,p_runstatus VARCHAR2
,p_prcsname  VARCHAR2 DEFAULT NULL
) IS
  l_runstatus VARCHAR2(10 CHAR);
BEGIN
 BEGIN
  SELECT x.xlatshortname
  INTO   l_runstatus
  FROM   psxlatitem x
  WHERE  x.fieldname = 'RUNSTATUS'
  AND    x.fieldvalue = p_runstatus
  AND    x.eff_status = 'A'
  AND    x.effdt = (
   SELECT MAX(x1.effdt)
   FROM   psxlatitem x1
   WHERE  x1.fieldname = x.fieldname
   AND    x1.fieldvalue = x.fieldvalue
   AND    x1.effdt <= SYSDATE);
 EXCEPTION  
  WHEN no_data_found THEN l_runstatus := 'Status:'||p_runstatus;
 END;

 IF p_prcsname IS NULL THEN
  sys.dbms_application_info.set_action(
   action_name => SUBSTR('PI='||p_prcsinstance||':'||l_runstatus,1,32)
  );
 ELSE
  sys.dbms_application_info.set_module(
   module_name => p_prcsname,
   action_name => SUBSTR('PI='||p_prcsinstance||':'||l_runstatus,1,32)
  );
 END IF;
END set_action;

---------------------------------------------------------------------------------------
--get session_longops index
---------------------------------------------------------------------------------------
PROCEDURE get_session_longops
(p_rindex    OUT BINARY_INTEGER
,p_slno      OUT BINARY_INTEGER
,p_sofar     OUT NUMBER
,p_totalwork OUT NUMBER
) IS
BEGIN
 p_rindex    := g_rindex;
 p_slno      := g_slno;
 p_sofar     := g_sofar;
 p_totalwork := g_totalwork;
END;

---------------------------------------------------------------------------------------
--set session_longops index
---------------------------------------------------------------------------------------
PROCEDURE set_session_longops
(p_rindex    IN BINARY_INTEGER
,p_slno      IN BINARY_INTEGER
,p_sofar     IN NUMBER
,p_totalwork IN NUMBER
) IS
BEGIN
 g_rindex    := p_rindex;
 g_slno      := p_slno;
 g_sofar     := p_sofar;
 g_totalwork := p_totalwork;
END;

---------------------------------------------------------------------------------------
END psftapi;
/

show errors
pause

---------------------------------------------------------------------------------------
--Trigger psftapi_store_prcsinstance saves the current process instance to a global variable in 
--the psftapi procedure
---------------------------------------------------------------------------------------
--17.3.2016 no longer dropping legacy trigger name
--This trigger replaces gfc_mod_act which has been withdrawn
--DROP TRIGGER sysadm.gfc_mod_act;
---------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER sysadm.psftapi_store_prcsinstance
BEFORE UPDATE OF runstatus ON sysadm.psprcsrqst
FOR EACH ROW
WHEN ((new.runstatus IN('3','7','8','9','10') OR old.runstatus IN('7','8')) AND new.prcstype != 'PSJob')
BEGIN
 IF :new.runstatus = '7' THEN
  psftapi.set_prcsinstance(p_prcsinstance => :new.prcsinstance
                          ,p_prcsname     => :new.prcsname);
  psftapi.set_action(p_prcsinstance=>:new.prcsinstance
                    ,p_runstatus=>:new.runstatus
                    ,p_prcsname=>:new.prcsname);
 ELSIF psftapi.get_prcsinstance() = :new.prcsinstance THEN
  psftapi.set_action(p_prcsinstance=>:new.prcsinstance
                    ,p_runstatus=>:new.runstatus);
 END IF;
EXCEPTION WHEN OTHERS THEN NULL; --exception deliberately coded to suppress all exceptions
END;
/
show errors
pause

---------------------------------------------------------------------------------------
--Trigger to set action from psprcsrqststrng
---------------------------------------------------------------------------------------
--17.3.2016 no longer dropping legacy trigger name
--DROP TRIGGER sysadm.prcsrqststrng_action;

--CREATE OR REPLACE TRIGGER sysadm.gfc_prcsrqststrng_action
--BEFORE INSERT OR UPDATE OF prcsrqststring ON sysadm.psprcsrqststrng
--FOR EACH ROW
--BEGIN
-- IF psftapi.get_prcsinstance() = :new.prcsinstance THEN
--  sys.dbms_application_info.set_action(
--	action_name => SUBSTR('PI='||:new.prcsinstance||':'||:new.prcsrqststring,1,32)
--  );
-- END IF;
--EXCEPTION WHEN OTHERS THEN NULL; --exception deliberately coded to suppress all exceptions
--END;
--/
--show errors
pause

---------------------------------------------------------------------------------------
--Trigger to set current EMPLID during payroll calculation
--Will only build on HCM database.  Will error elsewhere, in which ignore error
---------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER sysadm.gfc_payroll_calc_action
BEFORE INSERT OR UPDATE OF gp_calc_ts ON sysadm.ps_gp_pye_seg_Stat
FOR EACH ROW
WHEN (new.gp_calc_ts IS NOT NULL)
DECLARE
 l_prcsinstance  INTEGER := psftapi.get_prcsinstance(); --set in trigger psftapi_store_prcsinstance

 --payroll run control values
 l_cal_run_id    VARCHAR2(18);
 l_strm_num      INTEGER;
 l_group_list_id VARCHAR2(10);

 --session long ops variables
 l_rindex       BINARY_INTEGER;
 l_slno         BINARY_INTEGER;
 l_sofar        NUMBER;
 l_totalwork    NUMBER;
BEGIN
 IF l_prcsinstance > 0 THEN
  psftapi.get_session_longops(l_rindex, l_slno, l_sofar, l_totalwork);

  IF l_rindex IS NULL THEN
   l_rindex := dbms_application_info.set_session_longops_nohint;
  END IF;

  IF l_totalwork IS NULL THEN --run this first time only if don't know amount of work
   BEGIN
    --get run control parameters
    SELECT r.cal_run_id, r.strm_num, r.group_list_id
    INTO   l_cal_run_id, l_strm_num, l_group_list_id
    FROM   psprcsrqst p
    ,      ps_gp_runctl r
    WHERE  p.prcsinstance = l_prcsinstance
    AND    r.oprid = p.oprid
    AND    r.run_cntl_id = p.runcntlid
    AND    (r.run_calc_ind = 'Y' OR r.run_recalc_all_ind = 'Y')
    ;

    --count the number of segments
    IF l_strm_num > 0 THEN -- streamed payroll
     SELECT COUNT(*)
     INTO   l_totalwork
     FROM   ps_gp_pye_seg_stat g
     ,      ps_gp_strm s
     WHERE  s.strm_num = l_strm_num
     AND    g.cal_run_id = l_cal_run_id
     AND    g.emplid BETWEEN s.emplid_from AND s.emplid_to
     ;
    ELSIF l_group_list_id > ' ' THEN --group list
     SELECT COUNT(*)
     INTO   l_totalwork
     FROM   ps_gp_pye_seg_stat g
     ,      ps_gp_grp_list_dtl l
     WHERE  g.cal_run_id = l_cal_run_id
     AND    l.group_list_id = l_group_list_id
     AND    l.emplid = g.emplid
     ;
    ELSE -- non streamed payoll
     SELECT COUNT(*)
     INTO   l_totalwork
     FROM   ps_gp_pye_seg_stat g
     ,      ps_gp_strm s
     WHERE  s.strm_num = l_strm_num
     AND    g.cal_run_id = l_cal_run_id
     AND    g.emplid BETWEEN s.emplid_from AND s.emplid_to
     ;
    END IF;

   EXCEPTION 
    WHEN no_data_found THEN 
     l_totalwork := 0;
   END;
  END IF;

  IF l_sofar IS NULL THEN 
   l_sofar := 0;
  ELSE
   l_sofar := l_sofar+1;
  END IF;

  sys.dbms_application_info.set_session_longops(l_rindex, l_slno
  ,op_name     => 'GPPDPRUN'
  ,target      => l_prcsinstance
  ,context     => l_prcsinstance
  ,sofar       => l_sofar
  ,totalwork   => l_totalwork
  ,target_desc => 'PS_GP_PYE_SEG_STAT'
  ,units       => 'Payroll Segments'
  );

  sys.dbms_application_info.set_action(
   action_name => SUBSTR('PI='||l_prcsinstance||':EMPLID='||:new.emplid,1,32)
  );

  psftapi.set_session_longops(l_rindex, l_slno, l_sofar, l_totalwork); --set session long ops
  
 END IF;
EXCEPTION WHEN OTHERS THEN NULL; --exception deliberately coded to suppress all exceptions
END;
/
show errors
pause

---------------------------------------------------------------------------------------------
--The following is a simple test to check that the process instance number is being captured
---------------------------------------------------------------------------------------------
select trigger_name, status
from user_triggers
where table_name = 'PSPRCSRQST'
/

UPDATE  sysadm.psprcsrqst new
SET     runstatus = 7
WHERE   runstatus != 7
AND     new.prcstype != 'PSJob'
AND     rownum <= 1
/

set echo on serveroutput on buffer 1000000000 
begin
 dbms_output.put_line('PI='||sysadm.psftapi.get_prcsinstance);
end;
/

rollback
/

pause

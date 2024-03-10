REM psft_resource_plan_simple.sql
set trimspool on pages 999 lines 180 termout on serveroutput on
clear screen 
spool psft_resource_plan_simple.lst
--------------------------------------------------------------------------------
set echo on

exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();
--exec DBMS_RESOURCE_MANAGER.DELETE_PLAN('PSFT_PLAN_OTHERS');
exec DBMS_RESOURCE_MANAGER.DELETE_PLAN_CASCADE('PSFT_PLAN');

exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('HIGH_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('PSFT_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('PSFT_HIGHPQ_GROUP');
--exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('SUML_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('NVISION_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('BATCH_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('PSQUERY_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('PSQUERY_ONLINE_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('PSQUERY_BATCH_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('NVSRUN_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('LOW_GROUP');
exec DBMS_RESOURCE_MANAGER.DELETE_CONSUMER_GROUP('LOW_LIMITED_GROUP');

begin
  for i in (
    SELECT DISTINCT m.*
    FROM   DBA_RSRC_PLAN_DIRECTIVES d, DBA_RSRC_GROUP_MAPPINGS m
    WHERE d.plan like 'PSFT_PLAN%'
    and   d.type = 'CONSUMER_GROUP'
    and   m.consumer_group = d.group_or_subplan
  ) loop
    dbms_output.put_line('Deleting mapping attribute='||i.attribute||', value='||i.value);
    DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => i.attribute, value => i.value, consumer_group => NULL);
  END LOOP;
end;
/
--------------------------------------------------------------------------------
--Create a plan to manage these consumer groups
--------------------------------------------------------------------------------
BEGIN 
  DBMS_RESOURCE_MANAGER.CREATE_PLAN('PSFT_PLAN', 'Plan for nVision Reporting with 20 vCPUs');
END;
/

  /* Create consumer groups.
   * By default, users start in OTHER_GROUPS, which is automatically
   * created for every database.
   * NB: This will error if the groups exist in another plan - this error can be ignore
   */
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('PSFT_GROUP', 'General PeopleSoft group');
--exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('PSFT_HIGHPQ_GROUP', 'PeopleSoft High Query Parallelism group');
--exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('HIGH_GROUP', 'High Priority Group.');
--exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('SUML_GROUP', 'Summary Ledger Processing.');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('NVISION_GROUP', 'nVision Reports.');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('BATCH_GROUP', 'General Batch Processing.');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('PSQUERY_ONLINE_GROUP', 'PeopleSoft PS/Query group');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('PSQUERY_BATCH_GROUP', 'PeopleSoft PS/Query group');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('NVSRUN_GROUP', 'Single nVision Report group');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('LOW_GROUP', 'Low Priority Group.');
exec DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP('LOW_LIMITED_GROUP', 'Low Priority Limited Group.');
--------------------------------------------------------------------------------
--create directives within plan for 20vCPUs
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'SYS_GROUP', 'Directive for sys activity'
    ,mgmt_p1 => 100);
 
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'PSFT_GROUP', 'General PeopleSoft group'
--  ,parallel_degree_limit_p1=>n
--  ,mgmt_p2 => 79
    ,mgmt_p2 => 100
	);
--DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
--  'PSFT_PLAN', 'PSFT_HIGHPQ_GROUP', 'PeopleSoft High Query Parallelism group'
--  ,parallel_degree_limit_p1=>n
--  ,mgmt_p2 => 20);

--DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
--  'PSFT_PLAN', 'HIGH_GROUP', 'High priority group'
--  ,parallel_degree_limit_p1=>n
--  ,mgmt_p2 => 1);

--DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
--  'PSFT_PLAN', 'SUML_GROUP', 'Summary Ledger Processing.'
--  ,mgmt_p3 => 100
--  ,parallel_degree_limit_p1=>n
--);
    
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'BATCH_GROUP', 'nVision Reports.'
    ,mgmt_p4 => 100
--  ,parallel_degree_limit_p1=>n
	);

  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'NVISION_GROUP', 'nVision Reports.'
    ,mgmt_p5 => 100
--  ,parallel_degree_limit_p1=>n
	);

  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'PSQUERY_ONLINE_GROUP'
    ,mgmt_p6 => 90
--  ,parallel_degree_limit_p1=>2
	);
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'PSQUERY_BATCH_GROUP'
    ,mgmt_p6 => 1
    ,switch_group => 'CANCEL_SQL'
    ,switch_time => 14400
    ,switch_estimate => TRUE 
    ,switch_for_call => TRUE
--  ,parallel_degree_limit_p1=>1
--  ,parallel_queue_timeout=>900
--  ,pq_timeout_action=>'RUN'
	);
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE( /*added 2.11.2023*/
    'PSFT_PLAN', 'NVSRUN_GROUP'
    ,mgmt_p6 => 9
--  ,parallel_degree_limit_p1=>n
	);

  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'LOW_GROUP'
    ,mgmt_p8 => 1);
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'LOW_LIMITED_GROUP'
    ,mgmt_p8 => 1
    ,switch_group => 'CANCEL_SQL'
    ,switch_time => 7200
    ,switch_elapsed_time => 7200
    ,switch_estimate => TRUE 
    ,switch_for_call => TRUE
--  ,parallel_degree_limit_p1=>4
	);
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    'PSFT_PLAN', 'OTHER_GROUPS'
    ,mgmt_p8 => 1
--  ,parallel_degree_limit_p1=>4
	);
END;
/
--------------------------------------------------------------------------------
--create automatic mapping rules - users - by default, anything connected to SYSADM goes into the PSFT_GROUP
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.ORACLE_USER, value => 'PS'    , consumer_group => 'PSFT_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.ORACLE_USER, value => 'SYSADM', consumer_group => 'PSFT_GROUP');
END;
/
--------------------------------------------------------------------------------
--create automatic mapping rules - programs that go into a group other than the PSFT_GROUP
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSQRYSRV%'     , consumer_group => 'PSQUERY_ONLINE_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSNVSSRV%'     , consumer_group => 'NVSRUN_GROUP');

  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'psae%'         , consumer_group => 'BATCH_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSAESRV%'      , consumer_group => 'BATCH_GROUP');  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSDSTSRV%'     , consumer_group => 'BATCH_GROUP');DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSMSTPRC%'     , consumer_group => 'BATCH_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSPRCSRV%'     , consumer_group => 'BATCH_GROUP');
--DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSRUNRMT%'     , consumer_group => 'PSFT_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSRUN@%'       , consumer_group => 'BATCH_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'PSSQR%'        , consumer_group => 'BATCH_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'pssqr%'        , consumer_group => 'BATCH_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'sqr%'          , consumer_group => 'BATCH_GROUP');

  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'SQL Developer%', consumer_group => 'LOW_LIMITED_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'sqlplus%'      , consumer_group => 'LOW_LIMITED_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM    , value => 'Toad%'         , consumer_group => 'LOW_LIMITED_GROUP');
END;
/

--------------------------------------------------------------------------------
--create automatic mapping rules - by module/action
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME       , value => 'PSAE.PSQUERY.%', consumer_group => 'PSQUERY_BATCH_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME       , value => 'PSQRYSRV%'     , consumer_group => 'PSQUERY_ONLINE_GROUP');
--DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME       , value => 'psqrysrv%'     , consumer_group => 'PSQUERY_ONLINE_GROUP');
  
  --PIA component that runs queries on-line
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME_ACTION, value => 'QUERY_MANAGER.QUERY_VIEWER', consumer_group => 'PSQUERY_ONLINE_GROUP');
END;
/
--------------------------------------------------------------------------------
BEGIN
--DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'GLPOCONS'        , consumer_group => 'PSFT_HIGHPQ_GROUP');
--DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'PSAE.GL_JEDIT2.%', consumer_group => 'PSFT_HIGHPQ_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'RPTBOOK'         , consumer_group => 'NVISION_GROUP');
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'NVSRUN'          , consumer_group => 'NVISION_GROUP');
--DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'PSAE.GL_SUML.%'  , consumer_group => 'SUML_GROUP');
END;
/
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute      => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'SQL Developer', consumer_group => 'LOW_LIMITED_GROUP');
END;
/
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (attribute      => DBMS_RESOURCE_MANAGER.MODULE_NAME, value => 'KTSJ'    , consumer_group => 'SYS_GROUP');
--dbms_resource_manager.set_consumer_group_mapping (attribute      => 'ORACLE_FUNCTION'                , value => 'INMEMORY', consumer_group => 'SUML_GROUP');
END;
/
--------------------------------------------------------------------------------
--see Bug 34286049 - stress:fa:huge increase in the number of aq$_plsql_ntfn jobs in 19.15 leading to performance issues (Doc ID 34286049.8)
--------------------------------------------------------------------------------
--BEGIN
--  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (
--    attribute      => DBMS_RESOURCE_MANAGER.MODULE_NAME_ACTION,
--    value          => 'DBMS_SCHEDULER.AQ$_PLSQL_NTFN%',
--    consumer_group => 'LOW_GROUP');
--END;
--/
--------------------------------------------------------------------------------
--added 21.10.2023 - long running purge of AQ tables consumes CPU - might not be able to reassign this process
--see Bug 34774667 - [AQ] Global-buffer-overflow in pga at kwqalockqtwithinfo with ORA-00700 During PURGE_QUEUE_TABLE. (Doc ID 34774667.8)
--------------------------------------------------------------------------------
--BEGIN  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping (
--    attribute      => DBMS_RESOURCE_MANAGER.CLIENT_PROGRAM,
--    value          => 'oracle@%(SVCB)',
--    consumer_group => 'LOW_GROUP');
--END;
--/
--------------------------------------------------------------------------------
-- reprioritise mapping attributes
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping_pri (
    explicit              => 1,
    module_name_action    => 2,
    module_name           => 3,
    client_program        => 4,
    oracle_user           => 5,
--this resource plan does not use the following attributes
    service_name          => 6,
    client_os_user        => 7,
    client_machine        => 8,
    service_module        => 9,
    service_module_action => 10);
END;
/

/--------------------------------------------------------------------------------
exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
--------------------------------------------------------------------------------
-- Explicitly grant RSRC system priv to SYSADM not via role for trigger
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SYSTEM_PRIVILEGE (
    grantee_name => 'SYSADM',
    privilege_name => 'ADMINISTER_RESOURCE_MANAGER',
    admin_option => FALSE);
END;
/
--------------------------------------------------------------------------------
-- Allow PeopleSoft owner id to run in these consumer groups
--------------------------------------------------------------------------------
BEGIN
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'SYS_GROUP'           , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'PSFT_GROUP'          , FALSE);
--DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'PSFT_HIGHPQ_GROUP'   , FALSE);
--DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'SUML_GROUP'          , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'NVISION_GROUP'       , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'BATCH_GROUP'         , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'PSQUERY_BATCH_GROUP' , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'PSQUERY_ONLINE_GROUP', FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'NVSRUN_GROUP'        , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'LOW_GROUP'           , FALSE);
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP('SYSADM', 'LOW_LIMITED_GROUP'   , FALSE);
END;
/
--------------------------------------------------------------------------------
spool off
REM onlineinsthwmreset.sql
REM David Kurtz 14.3.2018
REM see http://blog.psftdba.com/2018/03/resetting-high-water-marks-on-on-line.html

set echo on serveroutput on
spool onlineinsthwmreset
rollback;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--package to reset hwm on online temporary table instances
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE xx_onlineinsthwmreset AS
PROCEDURE main
(p_drop_storage BOOLEAN  DEFAULT FALSE /*if true deallocate space from object*/
,p_min_extents  INTEGER  DEFAULT 2     /*minimum number of extents for table to be truncated*/
,p_recname_like VARCHAR2 DEFAULT ''    /*pattern match record name*/
,p_testmode     BOOLEAN  DEFAULT FALSE /*if true do not apply truncate, just print debug code*/
);
END xx_onlineinsthwmreset;
/
	
--------------------------------------------------------------------------------
--package to reset hwm on online temporary table instances
--------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY xx_onlineinsthwmreset AS
--------------------------------------------------------------------------------------------------------------
--Constants that should not be changed
--------------------------------------------------------------------------------------------------------------
k_module           CONSTANT VARCHAR2(64 CHAR) := $$PLSQL_UNIT; --name of package for instrumentation
k_dfps             CONSTANT VARCHAR2(20 CHAR) := 'YYYYMMDDHH24MISS'; --date format picture string
k_dfpsh            CONSTANT VARCHAR2(30 CHAR) := 'HH24:MI:SS DD.MM.YYYY'; --date format picture string for humans
-------------------------------------------------------------------------------------------------------
--package global variables
-------------------------------------------------------------------------------------------------------
l_debug_level    INTEGER := 8;  -- variable to hold debug level of package
l_debug_indent   INTEGER := 0; -- indent level of procedure
-------------------------------------------------------------------------------------------------------
-- to optionally print debug text during package run time
-------------------------------------------------------------------------------------------------------
PROCEDURE debug_msg(p_msg VARCHAR2 DEFAULT ''
                   ,p_debug_level INTEGER DEFAULT 5) IS
BEGIN
  IF p_debug_level <= l_debug_level AND p_msg IS NOT NULL THEN
    sys.dbms_output.put_line(TO_CHAR(SYSDATE,k_dfpsh)||':'||LPAD('.',l_debug_indent,'.')||'('||p_debug_level||')'||p_msg);
  END IF;
END debug_msg;

-------------------------------------------------------------------------------------------------------
-- truncate table in autonomous transaction so that the implicit commit of the truncate does not affect
-- any other row level locks held
-- Parameters
-- * p_table_name – name of table to be truncated
-- * p_drop_storage – if true add DROP STORAGE clause to truncate to remove physical segment but leave 
--                    table Default:false 
-- * p_testmode – for testing.  if true print SQL only but do not issue truncate.  Default false.
-------------------------------------------------------------------------------------------------------
PROCEDURE truncate_table 
(p_table_name   user_tables.table_name%TYPE
,p_drop_storage BOOLEAN DEFAULT FALSE
,p_testmode     BOOLEAN DEFAULT FALSE /*if true do not apply truncate, just print debug code*/
) AS
  l_sql VARCHAR2(100);
  PRAGMA AUTONOMOUS_TRANSACTION; 
BEGIN
  l_sql := 'TRUNCATE TABLE '||p_table_name;

  IF p_drop_storage THEN
    l_sql := l_sql ||' DROP STORAGE';
  END IF;

  IF p_testmode THEN 
    debug_msg('Test mode: '||l_sql);
  ELSE
  debug_msg(l_sql);
    EXECUTE IMMEDIATE l_sql;
  END IF;

END truncate_table;

-------------------------------------------------------------------------------------------------------
-- main procedure to identify tables to be truncated
-- Parameters
-- * p_drop_storage – if true add DROP STORAGE clause to truncate to remove physical segment but leave 
--                    table Default:false 
-- * p_min_extents – table must have at least this number of extents to be considered for truncate.
--                   default: 2
-- * p_recname_like – pattern match PeopleSoft record name to this.  Default null, so match all.
-- * p_testmode – for testing.  if true print SQL only but do not issue truncate.  Default false.
-------------------------------------------------------------------------------------------------------
PROCEDURE main 
(p_drop_storage BOOLEAN  DEFAULT FALSE /*if true deallocate space from object*/
,p_min_extents  INTEGER  DEFAULT 2     /*minimum number of extents for table to be truncated*/
,p_recname_like VARCHAR2 DEFAULT ''    /*pattern match record name*/
,p_testmode     BOOLEAN  DEFAULT FALSE /*if true do not apply truncate, just print debug code*/
) AS
  l_dummy VARCHAR2(1);
--l_recname_like VARCHAR2(100);
BEGIN

--IF p_recname_like IS NULL THEN
--  l_recname_like := '%';
--ELSE
--  l_recname_like := p_recname_like;
--END IF;

  FOR i IN (
    select /*+LEADING(o)*/ t.table_name, i.curtempinstance
    ,      s.blocks, s.extents
    from   PSOPTIONS o
    ,      ps_aeonlineinst i
    ,      psrecdefn r
    ,      user_tables t
    ,      user_segments  s
    where  i.curtempinstance <= o.TEMPINSTANCEONLINE 
    and    (r.recname LIKE p_recname_like OR p_recname_like IS NULL)
    and	 r.rectype = 7 /*temporary tables only*/
    and    t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
                          ||LTRIM(TO_CHAR(i.curtempinstance,'99'))
    and    t.temporary = 'N' /*exclude GTTs*/
    and    s.segment_type = 'TABLE'
    and    s.segment_name = t.table_name
    and    s.extents >= p_min_extents
  ) LOOP
    debug_msg(i.table_name||':'||i.extents||' extents :'||i.blocks||' blocks');

    /*take out lock on instance record*/
    select 'x' 
    into   l_dummy 
    from   ps_aeonlineinst 
    where  curtempinstance = i.curtempinstance
    for update;

    /*truncate table in autonomous transaction*/
    truncate_table(i.table_name, p_drop_storage, p_testmode);

    COMMIT;

  END LOOP;
END main;
	
END xx_onlineinsthwmreset;
/

show errors
spool off



/*--------------------------------------------------------------------------------
--Usage Notes
--------------------------------------------------------------------------------
REM Test mode, Truncate tables, dropping storage where at least 2 extents, just records beginning JP
EXECUTE xx_onlineinsthwmreset.main(FALSE,2,'JP%',TRUE);

REM Normally do not specify any parameters, but here you can see all the tables that will be processed.
REM EXECUTE xx_onlineinsthwmreset.main(p_testmode=>TRUE);

REM This will truncate all tables back to a single extent - this is what you usually want to do
REM EXECUTE xx_onlineinsthwmreset.main;

REM This will truncate all tables and release the storage
REM EXECUTE xx_onlineinsthwmreset.main(TRUE,0);

REM select * from ps_aeonlineinst where curtempinstance=1 for update;
REM truncate table PS_JP_BULED_TAO1 ;
REM insert into PS_JP_BULED_TAO1 select * from PS_JP_BULED_TAO11;
REM select * from user_tables where table_name = 'PS_JP_BULED_TAO1';
REM select * from user_segments where segment_name like 'PS_JP_BULED_TAO%';
/*--------------------------------------------------------------------------------*/
REM set_prcs_sess_parm.sql
REM https://blog.psftdba.com/2018/03/setting-oracle-session-parameters-for.html
REM https://blog.psftdba.com/2024/09/cursor-sharing-3.html
REM https://blog.psftdba.com/2025/03/reourcemanagericquerytimelimit.html
REM 6.4.2018 added KEYWORD to permit other ALTER SESSION commands
spool set_prcs_sess_parm
rollback;
alter session set current_schema=SYSADM;
@@set_prcs_sess_parm_trg.sql

spool set_prcs_sess_parm app
----------------------------------------------------------------------------------------------------
rollback;
----------------------------------------------------------------------------------------------------
delete from sysadm.PS_PRCS_SESS_PARM where prcstype like 'nVision%';
----------------------------------------------------------------------------------------------------
--INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
--VALUES ('Application Engine','PSQUERY',' ',' ', 'SET', '_optimizer_skip_scan_enabled','FALSE');
commit;
----------------------------------------------------------------------------------------------------
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with x (param_name, paramvalue) as (
          select '_optimizer_skip_scan_enabled', 'FALSE' from dual
--union all select 'parallel_degree_limit'       , '4'     from dual 
--union all select 'parallel_degree_policy'      , 'auto'  from dual 
--union all select 'parallel_degree_level'      , '200'   from dual --obsolete parameter
--union all select 'parallel_min_time_threshold' , '1'     from dual
--union all select 'query_rewrite_enabled'       , 'FORCE' from dual 
--union all select 'ddl_lock_timeout'            , '30'    from dual 
), y as (
select  prcstype, prcsname
from	ps_prcsdefn
where   prcsname IN('NVSRUN','RPTBOOK')
and	prcstype like 'nVision-Report%'
)
select y.prcstype, y.prcsname, ' ', ' ', 'SET', x.param_name, x.parmvalue
from x,y
/
----------------------------------------------------------------------------------------------------
--remove trace settings
----------------------------------------------------------------------------------------------------
delete from sysadm.PS_PRCS_SESS_PARM where param_name = 'events' and parmvalue = '''10046 TRACE NAME CONTEXT FOREVER, LEVEL 12''';
delete from sysadm.PS_PRCS_SESS_PARM where lower(param_name) IN('sql_trace','tracefile_identifier');
--insert into sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
--values ('nVision-ReportBook','RPTBOOK',' ',' ','SET','tracefile_identifier','RPTBOOK');
--insert into sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
--values ('nVision-ReportBook','RPTBOOK',' ',' ','SET','sql_trace','TRUE');
----------------------------------------------------------------------------------------------------
--General nVision settings
----------------------------------------------------------------------------------------------------
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with x (param_name, keyword, parmvalue) as ( 
          select '_optimizer_skip_scan_enabled' param_name,'SET' keyword, 'FALSE' parmvalue from dual
----------------------------------------------------------------------------------------------------
--union all select 'query_rewrite_enabled'                  ,'SET'        , 'FORCE'           from dual 
--union all select 'query_rewrite_integrity'                ,'SET'        , 'STALE_TOLERATED' from dual
--union all select 'inmemory_query'                         ,'SET'        , 'ENABLE'          from dual /*not strictly necessary, but just to be sure*/
----------------------------------------------------------------------------------------------------
--disabling forced parallelism preferable to disabling bloom filter on specific reportbook to avoid ORA-600 durring Bloom filter relating to 
--See Bug 34698924  Hitting ORA-600[qesblmerge:1] during stress workload with RAC and AUTO IM - https://support.oracle.com/epmos/faces/DocContentDisplay?id=34698924.8
----------------------------------------------------------------------------------------------------
--union all select 'parallel query parallel'                ,'FORCE'      , '/**/'            from dual /*disabled 28.12.2023 significant improvement- altered 4.4.2023 do not force degree of parallelism - control via resource manager plan*
--union all select 'parallel_force_local'                   ,'SET'        , 'FALSE'           from dual --set at database level 8.11.2022 on Exadata
--union all select 'parallel_degree_level'                  ,'SET'        , '200'             from dual --12.2 deprecated       
--union all select '"_optimizer_cbqt_or_expansion"'         ,'SET'        , 'OFF'             from dual --tested 30.12.2023 - not effective
--union all select 'parallel_min_time_threshold'            ,'SET'        , '1'               from dual /*disabled 28.12.2023-1.1.2024, tested 2.1.2024 not effected*/
----------------------------------------------------------------------------------------------------
--not setting globally  --union all select '_optimizer_proc_rate_source'     ,'SET', 'MANUAL'      from dual
--moved to resource plan--union all select 'parallel_degree_limit' param_name,'SET', '6'           from dual 
--19c default is manual --union all select 'parallel_degree_policy'          ,'SET', 'auto'        from dual 
----------------------------------------------------------------------------------------------------
--), p as (select TO_CHAR(CEIL(TO_NUMBER(value)/2),'999') half_cpu_count from v$parameter where name = 'cpu_count'
----------------------------------------------------------------------------------------------------
), y as (
select  prcstype, prcsname
from	ps_prcsdefn
where   prcsname IN('NVSRUN','RPTBOOK')
and     prcstype like 'nVision-Report%'
)
select y.prcstype, y.prcsname, ' ', ' ', x.keyword, x.param_name, x.parmvalue
from x,y
/

commit;

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--Settings for SQL Quarantine in PSQuery on Exadata -- added 26.02.2025 - note SQL checks that parameter is valid
REM <add blog for SQL Quarantine control>
----------------------------------------------------------------------------------------------------
delete from sysadm.PS_PRCS_SESS_PARM where prcsname = 'PSQUERY' AND param_name IN('optimizer_capture_sql_quarantine','optimizer_use_sql_quarantine')
/
----------------------------------------------------------------------------------------------------
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with n as ( --returns a row if on Exadata
SELECT  COUNT(DISTINCT cell_name) num_exadata_cells
FROM    v$cell
HAVING  COUNT(DISTINCT cell_name)>0
), x (param_name, keyword, parmvalue) as ( --returns rows if parameters available
select  name, 'SET', 'TRUE' 
from    v$parameter
where   name IN('optimizer_capture_sql_quarantine','optimizer_use_sql_quarantine')
), y (prcstype, prcsname, oprid, runcntlid) as (
select  prcstype, prcsname, ' ', ' ' 
from    ps_prcsdefn
where   prcsname = 'PSQUERY'
)
select  y.prcstype, y.prcsname, y.oprid, y.runcntlid, x.keyword, x.param_name, x.parmvalue
from    x,y,n
/

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--report on metadata
----------------------------------------------------------------------------------------------------
commit;
set lines 180 pages 999 trimspool on
break on param_name skip 1 on parmvalue skip 1 on keyword skip 1
column prcstype   format a20
column prcsname   format a20
column oprid      format a12
column keyword    format a10
column param_name format a30
column runcntlid  format a24
column parmvalue  format a50
select * from sysadm.PS_PRCS_SESS_PARM
order by prcstype, prcsname, param_name, parmvalue, oprid, runcntlid;

--column text format a129 word_wrapped on 
--select line, text from user_source
--where name = 'SET_PRCS_SESS_PARM';

--drop TRIGGER sysadm.set_prcs_sess_parm;
Alter TRIGGER sysadm.set_prcs_sess_parm enable;

----------------------------------------------------------------------------------------------------
--trigger test
----------------------------------------------------------------------------------------------------
set serveroutput on 
rollback;
update sysadm.psprcsrqst
set runstatus = 7
where runstatus != 7
and prcsname = 'RPTBOOK'
--and runcntlid = 'NVS_RPTBOOK_2'
--and oprid = 'NVISION'
and rownum = 1;
update sysadm.psprcsrqst
set runstatus = 7
where runstatus != 7
and prcsname = 'NVSRUN'
--and runcntlid = 'NVS_RPTBOOK_1'
00and oprid = 'NVISION'
and rownum = 1;
rollback;

show parameters optimizer
show parameters parallel
show parameters rewrite
show parameters ddl

spool off


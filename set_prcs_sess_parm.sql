REM set_prcs_sess_parm.sql
REM 6.4.2018 added KEYWORD to permit other ALTER SESSION commands
spool set_prcs_sess_parm
rollback;
alter session set current_schema=SYSADM;
@@set_prcs_sess_parm_trg.sql


spool set_prcs_sess_parm app
rollback;
delete from sysadm.PS_PRCS_SESS_PARM where prcstype like 'nVision%';

--Tried in production, not successful
--INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
--VALUES ('Application Engine','PSQUERY',' ',' ', 'SET', '_optimizer_skip_scan_enabled','FALSE');
commit;

INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with x as (
          select '_optimizer_skip_scan_enabled' param_name,'FALSE' parmvalue from dual
union all select 'parallel_degree_limit' param_name, '4' parmvalue from dual 
union all select 'parallel_degree_policy' , 'auto' from dual 
--union all select 'parallel_degree_level', '200' from dual --obsolete parameter
union all select 'parallel_min_time_threshold', '1' from dual
union all select 'query_rewrite_enabled', 'FORCE' from dual 
union all select 'ddl_lock_timeout', '30' from dual 
), y as (
select  prcstype, prcsname
from	ps_prcsdefn
where   prcsname IN('NVSRUN','RPTBOOK')
and	prcstype like 'nVision-Report%'
)
select y.prcstype, y.prcsname, ' ', ' ', 'SET', x.param_name, x.parmvalue
from x,y
/

commit;

set line 200 trimspool on
column prcstype   format a20
column oprid      format a10
column runcntlid  format a24
column keyword    format a8
column param_name format a30
column parmvalue  format a20
select * from sysadm.PS_PRCS_SESS_PARM order by 1,2,3,4,5;

--column text format a129 word_wrapped on 
--select line, text from user_source
--where name = 'SET_PRCS_SESS_PARM';

--drop TRIGGER sysadm.set_prcs_sess_parm;
Alter TRIGGER sysadm.set_prcs_sess_parm enable;


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


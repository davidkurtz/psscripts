REM set_prcs_sess_parm.sql
REM 6.4.2018 added KEYWORD to permit other ALTER SESSION commands
spool set_prcs_sess_parm
rollback;
alter session set current_schema=SYSADM;
@@set_prcs_sess_parm_trg.sql


spool set_prcs_sess_parm app
rollback;
delete from sysadm.PS_PRCS_SESS_PARM where prcstype like 'nVision%';

--Tried in production 
--INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
--VALUES ('Application Engine','PSQUERY',' ',' ', 'SET', '_optimizer_skip_scan_enabled','FALSE');
commit;

INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with x as (
            select '_optimizer_skip_scan_enabled' param_name,'FALSE' parmvalue from dual
--union all select 'parallel_degree_limit' param_name, '4' parmvalue from dual 
--union all select 'parallel_degree_policy' , 'auto' from dual 
--union all select 'parallel_degree_level', '200' from dual 
--union all select 'parallel_min_time_threshold', '1' from dual
union all select 'query_rewrite_enabled', 'FORCE' from dual /*added test 16*/
), y as (
select  prcstype, prcsname
from	ps_prcsdefn
where   prcsname IN('NVSRUN','RPTBOOK')
and	prcstype like 'nVision-Report%'
)
select y.prcstype, y.prcsname, ' ', ' ', 'SET', x.param_name, x.parmvalue
from x,y
/

------------
--PARALLEL 4
------------
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with x as ( /*automatic parallelism parameters*/
          select 'parallel_degree_limit' param_name, '4' parmvalue from dual 
union all select 'parallel_degree_policy' , 'auto' from dual 
union all select 'parallel_degree_level', '200' from dual 
union all select 'parallel_min_time_threshold', '1' from dual 
), y as ( /*nVision reports*/
select  prcstype, prcsname
from	ps_prcsdefn
where   prcsname IN('NVSRUN','RPTBOOK')
and	prcstype like 'nVision-Report%'
), z as ( /*long running reports - over 4 hours*/
          select 'NVISION' oprid, 'NVS_RPTBOOK_1' runcntlid from dual
union all select 'NVISION', 'NVS_RPTBOOK_2' from dual /*added test 16*/
union all select 'NVISION', 'NVS_RPTBOOK_5' from dual
union all select 'NVISION', 'NVS_RPTBOOK_6' from dual
union all select 'NVISION', 'NVS_RPTBOOK_10' from dual
union all select 'NVISION', 'NVS_RPTBOOK_15' from dual
union all select 'NVISION', 'NVS_RPTBOOK_16' from dual
union all select 'NVISION', 'NVS_RPTBOOK_17' from dual
union all select 'NVISION', 'NVS_RPTBOOK_20' from dual /*ADDED TEST 16*/
union all select 'NVISION', 'NVS_RPTBOOK_22' from dual
union all select 'NVISION', 'NVS_RPTBOOK_23' from dual
union all select 'NVISION', 'NVS_RPTBOOK_24' from dual /*ADDED TEST 16*/
union all select 'NVISION', 'NVS_RPTBOOK_25' from dual /*added test 15*/
union all select 'NVISION', 'NVS_RPTBOOK_27' from dual
union all select 'NVISION', 'LTD_7501_Direct_CF_M1' from dual
union all select 'CANVISION', 'DIVISION' from dual /*added test 15*/
union all select 'INTRUNCNTL', 'NVS_RPTBK_IRP2' from dual
union all select 'INTRUNCNTL', 'NVS_RPTBK_IRP4' from dual
union all select 'INTRUNCNTL', 'NVS_RPTBK_LOBA1' from dual
union all select 'INTRUNCNTL', 'NVS_RPTBK_LOBA6' from dual
union all select 'INTRUNCNTL', 'NVS_RPTBK_MORYTD1' from dual
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_1' from dual
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_2' from dual
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_3' from dual /*added test 15*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_4' from dual /*added test 16*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_5' from dual /*added test 15*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_10' from dual /*added test 15*/
)
select y.prcstype, y.prcsname, z.oprid, z.runcntlid, 'SET', x.param_name, x.parmvalue
from x,y,z
/

------------
--PARALLEL 4 was 6
------------
INSERT INTO sysadm.PS_PRCS_SESS_PARM (prcstype, prcsname, oprid, runcntlid, keyword, param_name, parmvalue)
with x as ( /*automatic parallelism parameters*/
          select 'parallel_degree_limit' param_name, '4' parmvalue from dual 
union all select 'parallel_degree_policy' , 'auto' from dual 
union all select 'parallel_degree_level', '200' from dual 
union all select 'parallel_min_time_threshold', '1' from dual 
), y as ( /*nVision reports*/
select  prcstype, prcsname
from	ps_prcsdefn
where   prcsname IN('NVSRUN','RPTBOOK')
and	prcstype like 'nVision-Report%'
), z as ( /*long running reports - over 4 hours*/
          select 'NVISION' oprid, 'NVS_RPTBOOK_4' runcntlid from dual /*parallel 6 from test 22*/
union all select 'NVISION', 'NVS_RPTBOOK_7' from dual /*parallel 6 from test 22*/
union all select 'NVISION', 'NVS_RPTBOOK_14' from dual /*parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_6' from dual /*parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_7' from dual /*ADDED test 17, parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_GEO1' from dual /*added test 22, parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_GEO2' from dual /*added test 15, parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_GEO3' from dual /*added test 15, parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_GEO4' from dual /*added test 15, parallel 6 from test 22*/
union all select 'USRUNCNTRL', 'NVS_RPTBOOK_GEO5' from dual /*added test 15, parallel 6 from test 22*/
)
select y.prcstype, y.prcsname, z.oprid, z.runcntlid, 'SET', x.param_name, x.parmvalue
from x,y,z
/

commit;

column prcstype   format a20
column oprid      format a10
column param_name format a30
column runcntlid  format a24
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
and runcntlid = 'NVS_RPTBOOK_2'
and oprid = 'NVISION'
and rownum = 1;
rollback;
update sysadm.psprcsrqst
set runstatus = 7
where runstatus != 7
and prcsname = 'RPTBOOK'
and runcntlid = 'NVS_RPTBOOK_1'
and oprid = 'NVISION'
and rownum = 1;
rollback;

alter session set current_schema=SYSADM;
spool off


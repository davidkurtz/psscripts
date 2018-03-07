set echo off 
ttitle off 
btitle off
rem copy this file to $ORACLE_HOME/sqlplus/admin
rem and call by appending a line to $ORACLE_HOME/sqlplus/admin/glogin.sql : @@gfclogin.sql

undefine dbid
column plan_plus_Exp format a70
COLUMN value_col_plus_show_param format a30
column SQLPROMPT new_value SQLPROMPT 
set trimspool on trimout on arrays 1 maxdata 9999 echo off head off timi off feedback off pause off autotrace off verify off time off termout off lines 111
alter session set nls_date_format = 'HH24:MI:SS DD.MM.YYYY';

select ''''||user||'>''' SQLPROMPT 
from dual
;

rem only works on a PSFT DB
select SUBSTR(''''||user||'-'||dbname,1,49)||'>''' SQLPROMPT 
from ps.psdbowner
;

rem this query required select_catalog_role
select SUBSTR(''''||user||'.'||m.sid||':'||p.spid||'.'||d.name||'.'||s.osuser||'.'||s.machine,1,49)||'>''' SQLPROMPT 
from sys.v_$database d
,sys.v_$session s
,sys.v_$session ms,sys.v_$process p
,(select sid from v$mystat where rownum=1) m 
where ms.paddr = p.addr 
and (s.sid = 1 or s.program = 'ORACLE.EXE (PMON)' or s.program = 'oracle@'||s.machine||' (PMON)') 
and ms.sid = m.sid;

rem 12c variant of above
select SUBSTR(''''||user||'.'||m.sid||':'||p.spid||'.'||c.name||'.'||d.name||'.'||s.osuser||'.'||s.machine,1,49)||'>''' SQLPROMPT 
, c.con_id, ms.con_id, p.con_id
from sys.v_$database d
,sys.v_$session s
,sys.v_$session ms,sys.v_$process p
,(select sid from v$mystat where rownum=1) m 
,sys.v_$containers c
where ms.paddr = p.addr 
and (s.sid = 1 or s.program = 'ORACLE.EXE (PMON)' or s.program = 'oracle@'||s.machine||' (PMON)') 
and ms.sid = m.sid
and c.con_id = ms.con_id
and p.con_id = ms.con_id;


rem this query required select_catalog_role and only works on a PSFT DB
select SUBSTR(''''||user||'-'||dbname||'.'||m.sid||':'||p.spid||'.'||d.name||'.'||s.osuser||'.'||s.machine,1,49)||'>''' SQLPROMPT 
from sys.v_$database d
,sys.v_$session s
,sys.v_$session ms,sys.v_$process p
,(select sid from v$mystat where rownum=1) m 
,ps.psdbowner
where ms.paddr = p.addr
and (s.sid = 1 or s.program = 'ORACLE.EXE (PMON)' or s.program = 'oracle@'||s.machine||' (PMON)') 
and ms.sid = m.sid;

rem this query required select_catalog_role and only works on a PSFT DB
select SUBSTR(''''||user||'-'||dbname||'.'||m.sid||':'||p.spid||'.'||c.name||'.'||d.name||'.'||s.osuser||'.'||s.machine,1,49)||'>''' SQLPROMPT 
from sys.v_$database d
,sys.v_$session s
,sys.v_$session ms,sys.v_$process p
,(select sid from v$mystat where rownum=1) m 
,sys.v_$containers c
,ps.psdbowner
where ms.paddr = p.addr
and (s.sid = 1 or s.program = 'ORACLE.EXE (PMON)' or s.program = 'oracle@'||s.machine||' (PMON)') 
and ms.sid = m.sid
and c.con_id = ms.con_id
and p.con_id = ms.con_id;

spool off
set sqlprompt &&SQLPROMPT
del
set head on timi off feedback on verify on time off pages 50 termout on
spool temp





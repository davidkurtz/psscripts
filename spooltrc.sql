REM spooltrc.sql
REM https://blog.go-faster.co.uk/2022/09/obtaining-database-trace-files.html

clear screen
set heading on pages 99 lines 180 verify off echo off trimspool on termout on feedback off
column value format a95
column value new_value adr_home heading 'ADR Home' 
select value from v$diag_info where name = 'ADR Home';
column value new_value diag_trace heading 'Diag Trace'
select value from v$diag_info where name = 'Diag Trace';
column value new_value trace_filename heading 'Trace File'
select SUBSTR(value,2+LENGTH('&diag_trace')) value from v$diag_info where name = 'Default Trace File';

column adr_home format a60
column trace_filename format a40
column change_time format a32
column modify_time format a32
column con_id format 999
select *
from v$DIAG_TRACE_FILE
where adr_home = '&adr_home'
and trace_filename = '&trace_filename'
/

set head off pages 0 lines 5000 verify off echo off timi off termout off feedback off long 5000
spool &trace_filename
select payload
from v$diag_trace_file_contents
where adr_home = '&adr_home'
and trace_filename = '&trace_filename'
order by line_number
/
spool off
set head on pages 99 lines 180 verify on echo on termout on feedback on
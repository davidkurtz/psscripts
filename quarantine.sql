REM quarantine.sql
REM Quarantine a specific execution plan for a SQL_ID.
REM requires: GRANT ADMINISTER SQL MANAGEMENT OBJECT TO psadmin;

spool quarantine

DECLARE
  e_invalid_sql_id EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_invalid_sql_id ,-56975);
  l_sql_id   VARCHAR2(13) := '&sql_id';
  l_sql_text CLOB;
  l_sql_quarantine  VARCHAR2(100);
BEGIN
  BEGIN
    l_sql_quarantine := sys.DBMS_SQLQ.create_quarantine_by_sql_id(sql_id => l_sql_id);
  EXCEPTION WHEN e_invalid_sql_id THEN
    SELECT sql_text 
    INTO   l_sql_text
    FROM   dba_hist_sqltext
    WHERE  sql_id = l_sql_id;

    l_sql_quarantine := sys.DBMS_SQLQ.create_quarantine_by_sql_text(sql_text => l_sql_text);
  END;
  DBMS_OUTPUT.put_line('l_sql_quarantine=' || l_sql_quarantine);
END;
/

set long 5000 lines 200 trimspool on
ttitle 'Quarantined SQL'
COLUMN SQL_text format a200 wrap on
column signature format 99999999999999999999
column name format a30
column cpu_time format a19
column io_megabytes format a19
column io_requests format a19
column elapsed_time format a19
column io_logical format a19
SELECT signature, name, plan_hash_value, cpu_time, io_megabytes, io_requests, elapsed_time, io_logical
, sql_text
FROM   dba_sql_quarantine
/
ttitle off
spool off
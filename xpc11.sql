set lines 200 trimspool on
spool xpc11
select * from table(dbms_xplan.display_cursor(null,null,'ADVANCED +IOSTATS -PROJECTION'));
spool off

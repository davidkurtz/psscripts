set lines 200 trimspool on
spool xpc
select * from table(dbms_xplan.display_cursor(null,null,'ADVANCED +IOSTATS -PROJECTION +ADAPTIVE'));
spool off

spool xp
set pages 9999 lines 200 autotrace off
select * from table(dbms_xplan.display(null,null,'ADVANCED +ADAPTIVE -PROJECTION'))
/
spool off




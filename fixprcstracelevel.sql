REM fixprcstracelevel.sql
set pages 99 lines 200 serveroutput on

spool fixprcstracelevel append
ROLLBACK;
DECLARE
  l_counter INTEGER := 0;
  l_trace_expr VARCHAR2(20);
  l_req_trace_level INTEGER := 1152; /*this is the trace value set in the process scheduler config*/
  l_cur_trace_level INTEGER;
  l_new_trace_level INTEGER;
  l_parmlist ps_prcsdefn.parmlist%TYPE;
BEGIN
  for i in (
    SELECT t.*
    FROM   ps_prcsdefn t
    WHERE  UPPER(t.parmlist) LIKE '%-%TRACE%'
    AND   prcstype LIKE 'Application Engine'
--    AND parmlisttype IN('1','2','3')
  ) LOOP
    l_trace_expr := REGEXP_SUBSTR(i.parmlist,'\-trace[ ]*[0-9]+',1,1,'i');
    l_cur_trace_level := TO_NUMBER(REGEXP_SUBSTR(l_trace_expr,'[0-9]+',1,1,'i'));
    l_new_trace_level := l_req_trace_level+l_cur_trace_level-bitand(l_cur_trace_level,l_req_trace_level);
    l_parmlist := REGEXP_REPLACE(i.parmlist,l_trace_expr,'-TRACE '||l_new_trace_level,1,1,'i');

    IF l_new_trace_level = l_cur_trace_level THEN
      dbms_output.put_line(i.prcstype||':'||i.prcsname||':'||i.parmlist||'=>No Change');
    ELSE
      l_counter := l_counter + 1;
      IF l_counter = 1 THEN
        UPDATE psversion
        SET    version = version+1
        WHERE  objecttypename IN('SYS','PPC');

        UPDATE pslock
        SET    version = version+1
        WHERE  objecttypename IN('SYS','PPC');
      END IF;
      dbms_output.put_line(l_counter||':'||i.prcstype||' '||i.prcsname||':'||i.parmlist||'=>'||l_parmlist);
      UPDATE ps_prcsdefn
      SET    version = (SELECT version FROM psversion WHERE objecttypename = 'PPC')
      ,      parmlist = l_parmlist
      WHERE  prcstype = i.prcstype
      AND    prcsname = i.prcsname;
    END IF;
  END LOOP;
  COMMIT;
END;
/
spool off
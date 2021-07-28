REM ptorphaned.sql
column collist format a50
set serveroutput on timi on
spool ptorphaned app
DECLARE
  l_sql CLOB;
  l_count INTEGER;
  e_no_table EXCEPTION;
  pragma exception_init(e_no_table,-942);
BEGIN 
  FOR i IN (
select r.recname, r.parentrecname
, LISTAGG(fr.fieldname,',') within group (order by fr.fieldnum) collist
, LISTAGG('p.'||fr.fieldname||' = c.'||fr.fieldname,' AND ') within group (order by fr.fieldnum) ecollist
from psrecdefn r
inner join psrecfielddb fr
  on fr.recname = r.recname
  and BITAND(fr.useedit,3) > 0
inner join psrecfielddb fp
  on fp.recname = r.parentrecname
  and BITAND(fp.useedit,3) > 0
  and fr.fieldname = fp.fieldname
where r.rectype = 0
and r.parentrecname != ' '
and r.recname = r.sqltablename
--and r.recname like 'PSQ%'
group by r.recname, r.parentrecname
order by r.recname
  ) LOOP
--  l_sql := 'SELECT '||i.collist||' FROM '||i.recname||' MINUS SELECT '||i.collist||' FROM '||i.parentrecname;
    l_sql := 'SELECT COUNT(*) FROM '||i.recname||' c'
          ||' WHERE NOT EXISTS(SELECT 1 FROM '||i.parentrecname||' p WHERE '||i.ecollist||')';
--  dbms_output.put_line(l_sql);
    BEGIN
      EXECUTE IMMEDIATE l_sql INTO l_count;
      IF l_count > 0 THEN
        dbms_output.put_line(i.recname||'->'||i.parentrecname||':'||l_count);
        l_sql := 'DELETE FROM '||i.recname||' c WHERE NOT EXISTS(SELECT 1 FROM '||i.parentrecname||' p WHERE '||i.ecollist||')';
        dbms_output.put_line(l_sql);
        EXECUTE IMMEDIATE l_sql;
        dbms_output.put_line(TO_CHAR(SQL%ROWCOUNT)||' rows processed.');
      END IF;
    EXCEPTION WHEN e_no_table THEN NULL;
    END;
  END LOOP;
END;
/
spool off
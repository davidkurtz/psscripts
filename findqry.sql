REM findqry.sql
REM https://blog.psftdba.com/2024/02/what-psquery-is-that.html
REM (c)Go-Faster Cosultancy 2024

set echo on serveroutput on pages 999 lines 200 trimspool on
undefine sql_id
clear screen
delete from plan_table;

spool findqry.lst

select * from table(dbms_xplan.display_awr('&&sql_id',null,null,'ADVANCED +ADAPTIVE'));

INSERT INTO plan_table (object_name, object_alias) 
with p as (
SELECT DISTINCT object_owner, object_type, object_name, regexp_substr(object_alias,'[[:alpha:]]',2,1) object_alias
from dba_hist_sql_plan p
, ps.psdbowner d
where p.sql_id = '&&sql_id' --<<-- put SQL ID here--
and p.object_name IS NOT NULL
and p.object_owner = d.ownerid
and regexp_like(object_alias,'"[[:alpha:]]"')
), r as (
select r.recname, DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) sqltablename
from psrecdefn r
where r.rectype = 0
)
select r.recname, object_alias
from p, r
where p.object_type like 'TABLE%'
and p.object_name = r.sqltablename
union
select r.recname, object_alias
from p, r
, all_indexes i
where p.object_type like 'INDEX%'
and i.index_name = p.object_name
and i.owner = p.object_owner
and i.table_name = r.sqltablename
order by 2,1
/

DECLARE 
  l_sep1 VARCHAR2(20);
  l_sep2 VARCHAR2(20);
  l_counter INTEGER := 0;
  l_sql CLOB := 'SELECT r1.oprid, r1.qryname';
  l_where CLOB;
  
  TYPE t_query IS RECORD (oprid VARCHAR2(30), qryname VARCHAR2(30));
  TYPE a_query IS TABLE OF t_query INDEX BY PLS_INTEGER;
  l_query a_query;
BEGIN
  FOR i IN(
    SELECT *
    FROM plan_table
    ORDER BY object_alias
  ) LOOP
    l_counter := l_counter + 1;
    dbms_output.put_line(i.object_alias||':'||i.object_name);
    IF l_counter = 1 THEN
      l_sep1 := ' FROM ';
      l_sep2 := ' WHERE ';
    ELSE
      l_sep1 := ' ,';
      l_sep2 := ' AND ';
      l_where := l_where||' AND r1.oprid = r'||l_counter||'.oprid AND r1.qryname = r'||l_counter||'.qryname';
    END IF;
    l_sql := l_sql||l_sep1||'psqryrecord r'||l_counter;
    l_where := l_where||l_sep2||'r'||l_counter||'.corrname = '''||i.object_alias||''' AND r'||l_counter||'.recname = '''||i.object_name||'''';
  END LOOP;
  l_where := l_where||' ORDER BY 1,2';
  dbms_output.put_line(l_sql||l_where);

  EXECUTE IMMEDIATE l_sql||l_where BULK COLLECT INTO l_query;

  FOR indx IN 1 .. l_query.COUNT
  LOOP
    DBMS_OUTPUT.put_line (indx||':'||l_query(indx).oprid||'.'||l_query(indx).qryname);
  END LOOP;
END;
/
spool off



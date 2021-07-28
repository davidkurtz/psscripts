REM gfc_hwm.sql
rem (c) Go-Faster Consultancy Ltd. www.go-faster.co.uk (c)2021
set serveroutput on echo on termout on timi on
clear screen
spool gfc_hwm

-------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sysadm.gfc_hwm 
(p_recname VARCHAR2 DEFAULT '%'
,p_testmode BOOLEAN DEFAULT FALSE
) AS 
-------------------------------------------------------------------------------------------------------
  k_module          CONSTANT VARCHAR2(64) := $$PLSQL_UNIT;
  k_nls_date_format CONSTANT VARCHAR2(20) := 'hh24:mi:ss dd.mm.yy:';
  l_module v$session.module%TYPE;
  l_action v$session.action%TYPE;
  l_sql CLOB;
-------------------------------------------------------------------------------------------------------
BEGIN
  FOR i IN (
----------------------------------------------------------------------------------------------------
with x as (
select t.table_name, t.num_rows, t.avg_row_len
, COALESCE(t.blocks, s.blocks) blocks, s.extents
, t.last_analyzed, t.stattype_locked
from psrecdefn r
, user_segments s
, user_tab_statistics t
where r.rectype IN(0,7)
and t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
and s.segment_name = t.table_name
and t.partition_name IS NULL
and s.segment_type = 'TABLE'
and (r.recname like p_recname
     or regexp_like(r.recname,p_recname))
), y as (
select x.* 
, x.avg_row_len*x.num_rows/NULLIF(x.blocks,0) bpb
from x
)
select * from y
where (blocks >=128 OR extents >=4)
and NVL(bpb,0) < 1024
and NVL(num_rows,0) <= 1e6
order by blocks --desc
--fetch first 1 rows only
----------------------------------------------------------------------------------------------------
  ) LOOP
    dbms_output.put_line(i.table_name||':'||i.num_rows||' rows, '||i.blocks||' blocks, '||i.extents||' extents');
    
    --online move
    l_sql := 'ALTER TABLE '||i.table_name||' MOVE ONLINE';
    IF p_testmode THEN
      dbms_output.put_line('Test mode:'||l_sql);
    ELSE
      dbms_output.put_line(l_sql);
      EXECUTE IMMEDIATE l_sql;
    END IF;
    
    --gather stats
    IF i.stattype_locked IS NULL AND i.last_analyzed IS NOT NULL THEN
      IF p_testmode THEN
        NULL;
      ELSE
        dbms_stats.gather_Table_stats(user,i.table_name);
      END IF;
    END IF;

  END LOOP;
END gfc_hwm;
/
show errors
desc sysadm.gfc_hwm
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

set serveroutput on
exec sysadm.gfc_hwm('%CUR%WRK%T%');
exec sysadm.gfc_hwm('%TAO');
exec sysadm.gfc_hwm('%TMP');
exec sysadm.gfc_hwm;

spool off


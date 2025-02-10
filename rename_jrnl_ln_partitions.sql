rem rename_jrnl_ln_partitions.sql
rem requires https://github.com/davidkurtz/psscripts/blob/master/psftapi.sql
spool rename_jrnl_ln_partitions.lst
set serveroutput on
DECLARE
  l_high_value DATE;
  l_sql CLOB;
  l_new_partition_name VARCHAR2(30);
BEGIN
  psft_ddl_lock.set_ddl_permitted(TRUE);
  FOR i IN (
    select /*+LEADING(r upt upkc utc)*/ r.recname, upt.table_name, utp.partition_name, utp.high_value, upt.interval interval_size
    from sysadm.psrecdefn r 
      INNER JOIN user_part_tables upt ON upt.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) 
        AND upt.partitioning_type = 'RANGE' and upt.interval IS NOT NULL
      INNER JOIN user_part_key_columns upkc ON upkc.name = upt.table_name AND upkc.object_Type = 'TABLE' and upkc.column_position = 1
      INNER JOIN user_tab_columns utc ON utc.table_name = upkc.name AND utc.column_name = upkc.column_name
      INNER JOIN user_tab_partitions utp ON utp.table_name = upt.table_name AND utp.partition_name like 'SYS_P%'
    WHERE r.recname = 'JRNL_LN' AND r.rectype = 0
    AND (utc.data_type = 'DATE' OR utc.data_type like 'TIMESTAMP%')
  ) LOOP
    l_sql := 'SELECT '||i.high_value||'-'||i.interval_size||' FROM DUAL';
    EXECUTE IMMEDIATE l_sql INTO l_high_value;
    l_new_partition_name := i.recname||'_'||TO_CHAR(l_high_value,'YYYYMM');
    l_sql := 'ALTER TABLE '||i.table_name||' RENAME PARTITION '||i.partition_name||' TO '||l_new_partition_name;
    IF i.partition_name != l_new_partition_name THEN
      dbms_output.put_line(l_sql);
      EXECUTE IMMEDIATE l_sql;
    END IF;
  END LOOP;

  FOR i IN (
    select /*+LEADING(r upi upkc utc)*/ r.recname, upi.index_name, uip.partition_name, uip.high_value, upi.interval interval_size
    from sysadm.psrecdefn r 
      INNER JOIN user_part_indexes upi ON upi.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) 
        AND upi.partitioning_type = 'RANGE' and upi.interval IS NOT NULL
      INNER JOIN user_part_key_columns upkc ON upkc.name = upi.index_name AND upkc.object_Type = 'INDEX' and upkc.column_position = 1
      INNER JOIN user_tab_columns utc ON utc.table_name = upi.table_name AND utc.column_name = upkc.column_name
      INNER JOIN user_ind_partitions uip ON uip.index_name = upi.index_name 
        AND (uip.partition_name like 'SYS_P%' OR SUBSTR(uip.partition_name,1+LENGTH(r.recname),1) != SUBSTR(upi.index_name,3,1))
    WHERE r.recname = 'JRNL_LN' AND r.rectype = 0
    AND (utc.data_type = 'DATE' OR utc.data_type like 'TIMESTAMP%')
  ) LOOP
    l_sql := 'SELECT '||i.high_value||'-'||i.interval_size||' FROM DUAL';
    EXECUTE IMMEDIATE l_sql INTO l_high_value;
    l_new_partition_name := i.recname||SUBSTR(i.index_name,3,1)||TO_CHAR(l_high_value,'YYYYMM');
    l_sql := 'ALTER INDEX '||i.index_name||' RENAME PARTITION '||i.partition_name||' TO '||l_new_partition_name;
    IF i.partition_name != l_new_partition_name THEN
      dbms_output.put_line(l_sql);
      EXECUTE IMMEDIATE l_sql;
    END IF;
  END LOOP;
  psft_ddl_lock.set_ddl_permitted(FALSE);
END;
/
spool off
REM index_compression_test.sql
spool index_compression_test.lst
clear screen
set timi on
--drop table gfc_index_compression_stats purge;
create table gfc_index_compression_stats
(table_name varchar2(128)
,index_name varchar2(128)
,num_rows number
,last_analyzed date
,prefix_length number 
,blevel number 
,leaf_blocks number 
,avg_leaf_blocks_per_key number 
,avg_data_blocks_per_key number 
,clustering_factor number 
,constraint gfc_index_compression_stats_pk primary key (table_name, index_name, prefix_length)
);

DECLARE
  l_table_name VARCHAR2(128) := 'PSTREENODE';
  --l_index_name VARCHAR2(128) := 'PSAPSTREENODE';
  l_num_cols INTEGER;
  l_sql CLOB;
  
  e_invalid_compress_length EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_invalid_compress_length,-25194);
  
BEGIN
  FOR i IN (
    SELECT table_name, index_name, column_position prefix_length FROM user_ind_columns
    --WHERE index_name = l_index_name
    WHERE table_name = l_table_name
    UNION
    SELECT table_name, index_name, 0 FROM user_indexes
    --WHERE index_name = l_index_name
    WHERE table_name = l_table_name
    ORDER BY table_name, prefix_length DESC
  ) LOOP
   IF i.prefix_length > 0 THEN 
     l_sql := 'ALTER INDEX '||i.index_name||' REBUILD COMPRESS '||i.prefix_length;
   ELSE
     l_sql := 'ALTER INDEX '||i.index_name||' REBUILD NOCOMPRESS';
   END IF;

   BEGIN
     dbms_output.put_line(l_sql);
     EXECUTE IMMEDIATE l_sql;
     dbms_stats.gather_index_stats(user,i.index_name);
   
     MERGE INTO gfc_index_compression_stats u
     USING (SELECT * FROM user_indexes WHERE table_name = i.table_name And index_name = i.index_name) s
     ON (u.table_name = s.table_name AND u.index_name = s.index_name AND u.prefix_length = NVL(s.prefix_length,0))
     WHEN MATCHED THEN UPDATE
     SET u.num_rows = s.num_rows
     , u.last_analyzed = s.last_analyzed
     , u.blevel = s.blevel
     , u.leaf_blocks = s.leaf_blocks
     , u.avg_leaf_blocks_per_key = s.avg_leaf_blocks_per_key
     , u.avg_data_blocks_per_key = s.avg_data_blocks_per_key
     , u.clustering_factor = s.clustering_factor
     WHEN NOT MATCHED THEN INSERT (table_name, index_name, num_rows, last_analyzed, prefix_length, blevel, leaf_blocks, avg_leaf_blocks_per_key, avg_data_blocks_per_key, clustering_factor)
     VALUES (s.table_name, s.index_name, s.num_rows, s.last_analyzed, NVL(s.prefix_length,0), s.blevel, s.leaf_blocks, s.avg_leaf_blocks_per_key, s.avg_data_blocks_per_key, s.clustering_factor);
   EXCEPTION 
     WHEN e_invalid_compress_length THEN NULL;
   END;
  
  END LOOP; 
END;
/

column table_name format a18
column index_name format a18
select * from gfc_index_compression_stats
/

spool off

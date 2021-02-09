REM gfc_locktemprecstats_triggerjob.sql
spool gfc_locktemprecstats_triggerjob
set echo on pages 999 lines 180 timi on
GRANT EXECUTE on sys.dbms_job TO SYSADM;
GRANT CREATE JOB TO SYSADM;

CREATE OR REPLACE PROCEDURE sysadm.gfc_locktemprecstats
(p_table_name VARCHAR2) IS
  l_table_name      user_tables.table_name%TYPE;
  l_num_rows        user_tables.num_rows%TYPE;
  l_stattype_locked user_tab_statistics.stattype_locked%TYPE;
BEGIN
  SELECT DISTINCT
         t.table_name, t.num_rows, s.stattype_locked
  INTO   l_table_name, l_num_rows, l_stattype_locked
  FROM   pstemptblcntvw i
         INNER JOIN psrecdefn r
           ON r.recname = i.recname
           AND r.rectype = '7' --temp record
  ,      psoptions o
  ,      user_tables t
         LEFT OUTER JOIN user_tab_statistics s
           ON  s.table_name = t.table_name
           AND s.partition_name IS NULL
  ,      (SELECT rownum n FROM DUAL CONNECT BY level <= 100) v
  WHERE  v.n <= i.temptblinstances + o.temptblinstances
  AND    t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
                      ||DECODE(v.n*r.rectype,100,'',LTRIM(TO_NUMBER(v.n)))
  AND    (/*  t.num_rows        IS NOT NULL --not analyzed
         OR   t.last_analyzed   IS NOT NULL --not analyzed
         OR*/ s.stattype_locked IS     NULL --stats not locked
         )
  AND    t.table_name = p_table_name;
 
  IF l_stattype_locked IS NULL THEN
    dbms_output.put_line('Locking statistics on table '||l_table_name);
    dbms_stats.lock_table_stats(ownname=>user,tabname=>l_table_name);
  END IF;
  IF l_num_rows IS NOT NULL THEN
    dbms_output.put_line('Deleting statistics on table '||l_table_name);
    dbms_stats.delete_table_stats(ownname=>user,tabname=>l_table_name,force=>TRUE);
   END IF;
   
 EXCEPTION
   WHEN no_data_found THEN
     dbms_output.put_line('No action required for '||p_table_name);
 END gfc_locktemprecstats;
 /
show errors

CREATE OR REPLACE TRIGGER sysadm.gfc_locktemprecstats
  AFTER CREATE ON sysadm.SCHEMA
DECLARE
  l_cmd            VARCHAR2(1000 CHAR);
  l_job_no         NUMBER;
BEGIN
  dbms_output.put_line('Trigger fired on creation of '||dictionary_obj_type||':'||dictionary_obj_owner||'.'||dictionary_obj_name);
  IF DICTIONARY_OBJ_TYPE = 'TABLE' THEN
    l_cmd := 'gfc_locktemprecstats(p_table_name=>'''||dictionary_obj_name||''');';
    dbms_job.submit(l_job_no,l_cmd);
    dbms_output.put_line(l_cmd||' submitted as job '||l_job_no);
  END IF;
END;
/
show errors
spool off

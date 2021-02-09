REM gfc_deletetemptablestats.sql
spool gfc_deletetemptablestats
set echo on

CREATE OR REPLACE TRIGGER sysadm.gfc_deletetemptablestats
AFTER INSERT ON sysadm.ps_aetemptblmgr
FOR EACH ROW
WHEN (new.curtempinstance > 0)
DECLARE
 PRAGMA AUTONOMOUS_TRANSACTION;
 l_table_name VARCHAR2(30) := '';
 l_last_analyzed DATE := '';
 l_stattype_locked VARCHAR2(5) := '';
 table_doesnt_exist EXCEPTION;
 PRAGMA EXCEPTION_INIT(table_doesnt_exist,-20001);
BEGIN
 SELECT r.table_name, t.last_analyzed
 INTO   l_table_name, l_last_analyzed
 FROM   ( 
        SELECT r.recname
        ,      DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)||:new.curtempinstance table_name
        FROM   psrecdefn r
		WHERE  rectype = 7
        ) r
        LEFT OUTER JOIN user_tables t
          ON t.table_name = r.table_name
          AND t.temporary = 'N'
 WHERE  r.recname = :new.recname;

 SELECT s.stattype_locked
 INTO   l_stattype_locked
 FROM   user_tab_statistics s
 WHERE  s.table_name = l_table_name
 AND    s.object_type = 'TABLE';

 IF l_last_analyzed IS NOT NULL THEN --only delete statistics if they exist
  dbms_stats.delete_table_stats(ownname=>'SYSADM',tabname=>l_table_name,force=>TRUE);
 END IF;
 IF l_stattype_locked IS NULL THEN --stats need to be locked, 21,11,2009
  dbms_stats.lock_table_stats(ownname=>user,tabname=>l_table_name);
 END IF;
 
EXCEPTION
  WHEN no_data_found THEN NULL;
  WHEN table_doesnt_exist THEN NULL;
END;
/
show errors

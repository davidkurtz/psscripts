rem PSFT_DDL_LOCK: DDL Trigger to protect objects not managed by PeopleTools on PeopleSoft tables
rem (c) Go-Faster Consultancy Ltd.
rem documentation: http://blog.psftdba.com/2006/04/using-ddl-triggers-to-protect-database.html
rem 17. 8.2006 initial version
rem 11.10.2006 enhancement to cater for keys defined on sub-records, omit peoplesoft alternate and key index
rem 28.10.2006 enhance for PK, MV, MV log, Partition, cluster GTT, IOT.
rem 01.10.2007 restrict FBI test to records not defined in PeopleSoft because of reintroduction of descending key indexes
rem 12.11.2007 enhancements to support key fields on subrecords
rem 10.01.2008 remove any checks on explicit DDL on triggers
rem 06.07.2009 enhancements to support PS temp record and global temp table shadow table trigger - www.go-faster.co.uk/scripts.htm#gfc_temp_table_type.sql
rem 02.06.2011 introduce package function to disable trigger just for current session
/*-----------------------------------------------------------------------------------------------------------
rem Summary of Error Codes
rem 20000-Generate No Data Found Error.  Should be impossible.
rem 20001-DDL on Non PSU (Auditting) trigger on table - defunct, replaced with 20013 during table checks
rem 20002-DDL on Index on Global Temporary Table 
rem 20003-DDL on Partitioned Index
rem 20004-DDL on Function Based Index
rem 20005-DDL on Index not defined in PeopleSoft
rem 20006-Cannot alter PSRECDEFN because PSFT_DDL_LOCK refernces it
rem 20007-DDL on Global Temporary Table
rem 20008-DDL on Partitioned Table
rem 20009-DDL on Table that is part of Cluster
rem 20010-DDL on Index Organised Table
rem 20011-DDL on Table where an index not defined in PeopleSoft
rem 20012-DDL on Table with Function Based Index
rem 20013-DDL on Table with Non-PSU Trigger
rem 20014-DDL on Table with Primary Key Constraint
rem 20015-DDL on Table with Materialised View Log
rem 20016-DDL on Table that is a Materialised View
rem 20017-DDL on Table with shadow Global Temporary Table
rem 20018-DDL on Index of Table with shadow Global Temporary Table
-----------------------------------------------------------------------------------------------------------*/
set echo on feedback on verify on lines 100 timi on 
spool psft_ddl_lock

CREATE INDEX pszpsrecdefn_fbi 
ON psrecdefn (DECODE(sqltablename,' ','PS_'||recname,sqltablename))
TABLESPACE PSINDEX PCTFREE 0;  
CREATE INDEX pszpsrecfielddb ON psrecfielddb (recname, recname_parent, fieldname) 
TABLESPACE psindex PCTFREE 1 COMPRESS 1;

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE psft_ddl_lock AS 

---------------------------------------------------------------------------------------
--Write process instance number into a global PL/SQL variable to be used later
---------------------------------------------------------------------------------------
PROCEDURE set_ddl_permitted
(p_ddl_permitted BOOLEAN DEFAULT FALSE
);

---------------------------------------------------------------------------------------
--Read process name, instance number into global PL/SQL variables to be used later
---------------------------------------------------------------------------------------
FUNCTION get_ddl_permitted RETURN BOOLEAN;
---------------------------------------------------------------------------------------
END psft_ddl_lock;
/

show errors

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY psft_ddl_lock AS 
---------------------------------------------------------------------------
g_ddl_permitted BOOLEAN; --variables that are global to package only.
---------------------------------------------------------------------------

PROCEDURE set_ddl_permitted
(p_ddl_permitted BOOLEAN DEFAULT FALSE
) IS
BEGIN
 g_ddl_permitted := p_ddl_permitted;
END;

---------------------------------------------------------------------------

FUNCTION get_ddl_permitted 
RETURN BOOLEAN IS
BEGIN
 IF g_ddl_permitted IS NULL THEN
  RETURN FALSE;
 ELSE
  RETURN g_ddl_permitted;
 END IF;
END;

END;
/
show errors

---------------------------------------------------------------------------
---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER psft_ddl_lock 
BEFORE DROP OR ALTER OR RENAME
ON SYSADM.SCHEMA --you PeopleSoft schema is not sysadm then you need to change this.
DECLARE
 e_generate_message EXCEPTION;
 l_recname     VARCHAR2(15 CHAR); --peoplesoft record name
 l_rectype     INTEGER; --peoplesoft record type
 l_suffix      VARCHAR2(2 CHAR) := ''; --suffix of temporary table instance
 l_table_name  VARCHAR2(30 CHAR);
 l_table_owner VARCHAR2(30 CHAR);
 l_index_owner VARCHAR2(30 CHAR);
 l_temporary   VARCHAR2(1 CHAR); --Oracle GTT y/n
 l_partitioned VARCHAR2(3 CHAR); --Oracle Partitioned Table yes/no
 l_msg0        VARCHAR2(100 CHAR) := 'No Message.';
 l_msg         VARCHAR2(100 CHAR);
 l_msg2        VARCHAR2(100 CHAR) := 'Cannot '||ora_sysevent||' '||lower(ora_dict_obj_type)||' '||ora_dict_obj_owner||'.'||ora_dict_obj_name;
 l_errno       INTEGER := -20000; /* set a valid default in case of error in trigger*/
 l_testme      BOOLEAN := TRUE;

 sql_text ora_name_list_t;
 l_sql_stmt VARCHAR2(1000 CHAR) := ''; 
 n          INTEGER;
 i          INTEGER;

BEGIN
 l_msg := l_msg0;
 /*extract the originating SQL statement into a string variable*/
 n := ora_sql_txt(sql_text);
 FOR i IN 1..n LOOP
  l_sql_stmt := SUBSTR(l_sql_stmt || sql_text(i),1,1000);
 END LOOP;

 l_testme := psft_ddl_lock.get_ddl_permitted;
 IF l_testme THEN
  NULL; --perform no tests because DDL permitted

/******************************************************************************************
* IF ora_dict_obj_type = 'TRIGGER' THEN
*
*  BEGIN --If a trigger exists, and it is not a PSU trigger
*   SELECT -20001, 'Trigger '||t.trigger_name||' exists on PeopleSoft record '||r.recname||'.'
*   INTO   l_errno, l_msg
*   FROM   all_triggers t, psrecdefn r
*   WHERE  ROWNUM = 1
*   AND    t.trigger_name = ora_dict_obj_name
*   AND    t.owner = ora_dict_obj_owner
*   AND    t.table_owner = ora_dict_obj_owner
*   AND    DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) = t.table_name
*   AND    t.trigger_name != 'PSU'||r.recname
*   ;
*   RAISE e_generate_message;
*  EXCEPTION 
*   WHEN NO_DATA_FOUND THEN 
*    l_errno := -20000;
*    l_msg := l_msg0;
*  END;
*
****************************************************************************************/

 ELSIF ora_dict_obj_type = 'INDEX' THEN

  /*if referencing a index, check its on a PeopleSoft record and get the record name, table name and table owner*/
  BEGIN   /*6.7.2009 - temporary record handling*/
   SELECT r.recname, r.rectype, i.table_owner, i.table_name,       i.owner, i.temporary, i.partitioned
   INTO   l_recname, l_rectype, l_table_owner, l_table_name, l_index_owner, l_temporary, l_partitioned
   FROM   psrecdefn r, all_indexes i
   WHERE  DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) = i.table_name
   AND    i.owner = ora_dict_obj_owner
   AND    i.index_name = ora_dict_obj_name
   AND    r.rectype IN(0,7)
   ;
   l_testme := TRUE;
  EXCEPTION 
   WHEN NO_DATA_FOUND THEN 
    l_recname := '';
    l_testme := FALSE;
  END;

  IF NOT l_testme THEN
   BEGIN 
    SELECT r.recname, r.rectype, n.suffix /*6.7.2009 - temporary record handling*/
    ,      i.table_owner, i.table_name,       i.owner, i.temporary, i.partitioned
    INTO   l_recname, l_rectype, l_suffix
    ,      l_table_owner, l_table_name, l_index_owner, l_temporary, l_partitioned
    FROM   psrecdefn r, all_indexes i, pstemptblcntvw c, psoptions o
    ,      (SELECT rownum n, LTRIM(TO_CHAR(rownum)) suffix FROM psrecdefn WHERE rownum <= 99) n
    WHERE  DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)||n.suffix = i.table_name
    AND    n.n <= c.temptblinstances+o.temptblinstances
    AND    c.recname = r.recname
    AND    i.owner = ora_dict_obj_owner
    AND    i.index_name = ora_dict_obj_name
    AND    r.rectype IN(7)
    ;
    l_testme := TRUE;
   EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
     l_recname := '';
     l_testme := FALSE;
   END;
  END IF;

  IF  l_testme /*6.7.2009 - temporary record handling*/
  AND SUBSTR(ora_dict_obj_name,3,1) IN('_','0','1','2','3','4','5','6','7','8','9') 
  AND ora_dict_obj_name LIKE 'PS_'||l_recname THEN
   l_testme := FALSE;
  END IF;

  IF l_recname IS NOT NULL THEN
   l_msg := ora_dict_obj_owner||'.'||ora_dict_obj_name;
   IF l_temporary = 'Y' THEN
    l_errno := -20002;
    l_msg := l_msg||' is a global temporary index.';
    RAISE e_generate_message;
   ELSIF l_partitioned = 'YES' THEN
    l_errno := -20003;
    l_msg := l_msg||' is a partitioned index.';
    RAISE e_generate_message;
   END IF;
  END IF;

  IF l_testme THEN
   BEGIN --raise error if a function based index exists on the table
    SELECT -20004, 'Function Based Index '||ora_dict_obj_name||' on table '||l_table_name||' is managed outside PeopleTools.'
    INTO   l_errno, l_msg
    FROM   DUAL
    WHERE NOT EXISTS( /*not defined in PeopleSoft*/
     SELECT 'x' /*check for indexes on record*/
     FROM   psindexdefn x
     WHERE  x.recname = l_recname
     AND    x.indexid = SUBSTR(ora_dict_obj_name,3,1)
     AND    'PS'||x.indexid||x.recname||l_suffix = ora_dict_obj_name
     )
    AND EXISTS( /*check for function based column*/
     SELECT 'x'
     FROM   all_ind_expressions ie
     WHERE  ie.table_owner = l_table_owner
     AND    ie.table_name = l_table_name
     AND    ie.index_owner = ora_dict_obj_owner
     AND    ie.index_name = ora_dict_obj_name)
    ;
    RAISE e_generate_message;
   EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
    l_errno := -20000;
    l_msg := l_msg0;
   END; 

   BEGIN --raise and error if an index exists on the table that is not defined in PeopleTools
    SELECT -20005, 'Index '||ora_dict_obj_name||' on table '||l_table_name||' is managed outside PeopleTools.'
    INTO   l_errno, l_msg
    FROM   DUAL
    WHERE NOT EXISTS( /*not defined in PeopleSoft*/
     SELECT 'x' /*check for indexes on record*/
     FROM   psindexdefn x
     WHERE  x.recname = l_recname
     AND    x.indexid = SUBSTR(ora_dict_obj_name,3,1)
     AND    'PS'||x.indexid||x.recname||l_suffix = ora_dict_obj_name)
    ;
    RAISE e_generate_message;
   EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
    l_errno := -20000;
    l_msg := l_msg0;
   END;

   BEGIN --if a shadow GTT exists - www.go-faster.co.uk/scripts.htm#gfc_temp_table_type.sql
    SELECT -20018, 'Table '||i.table_name||' has a shadow Global Temporary Table '||t.table_name||'.'
    INTO   l_errno, l_msg
    FROM   all_tables t
    ,      all_indexes i
    WHERE  ROWNUM = 1
    AND    t.owner = i.table_owner
    AND    t.table_name = 'GT'||SUBSTR(i.table_name,3)
    AND    i.owner = ora_dict_obj_owner
    AND    i.index_name = ora_dict_obj_name    
    AND    t.temporary = 'Y'
    ;
    RAISE e_generate_message;
   EXCEPTION
    WHEN NO_DATA_FOUND THEN 
     l_errno := -20000;
     l_msg := l_msg0;
   END;
  END IF;

 ELSIF ora_dict_obj_type = 'TABLE' THEN 
  -------------------------------------------------------------------------------------------------------
  /*cannot permit any alterations to PSRECDEFN because it is referenced during the trigger, causes ORA-600 [12830]*/
  IF UPPER(ora_dict_obj_name) = 'PSRECDEFN' AND ora_sysevent IN('ALTER','DROP','RENAME') THEN
   l_errno := -20006;
   l_msg := 'Cannot alter '||ora_dict_obj_name||' because trigger references it';
   RAISE e_generate_message;
  -------------------------------------------------------------------------------------------------------
  --is droping or renaming table
  -------------------------------------------------------------------------------------------------------
  ELSIF ora_sysevent IN('DROP','RENAME') 
     OR UPPER(l_sql_stmt) LIKE '%ALTER%TABLE%RENAME%' THEN
   /*if referencing a table, check its a PeopleSoft and get the record name, */
   BEGIN --get record name and type
    SELECT r.recname, r.rectype
    INTO   l_recname, l_rectype
    FROM   psrecdefn r
    WHERE  DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename) = ora_dict_obj_name
    AND    r.rectype IN(0,7)
    ;
    l_testme := TRUE;
   EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
     l_recname := '';
     l_testme := FALSE;
   END;
  -------------------------------------------------------------------------------------------------------
   IF l_recname IS NULL THEN
    BEGIN --get instance of temporary record
     SELECT r.recname, r.rectype, n.suffix /*6.7.2009 - temporary record handling*/
     INTO   l_recname, l_rectype, l_suffix
     FROM   psrecdefn r, pstemptblcntvw c, psoptions o
     ,      (SELECT rownum n, LTRIM(TO_CHAR(rownum)) suffix FROM psrecdefn WHERE rownum <= 99) n
     WHERE  DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)||n.suffix = ora_dict_obj_name
     AND    n.n <= c.temptblinstances+o.temptblinstances
     AND    c.recname = r.recname
     AND    r.rectype = 7
     ;
     l_testme := TRUE;
    EXCEPTION 
     WHEN NO_DATA_FOUND THEN 
      l_recname := '';
      l_testme := FALSE;
    END;
    -------------------------------------------------------------------------------------------------------
    --debug code for temp table testing
    --  dbms_output.put_line('rectype:'||l_rectype);
    --  dbms_output.put_line('SQL    :'||l_sql_stmt||':');
    --  dbms_output.put_line('Testfor:'||UPPER('ALTER%TABLE%PS_'||l_recname||l_suffix
    --                                     ||'%RENAME%TO%GT_'||l_recname||l_suffix));
    -------------------------------------------------------------------------------------------------------
    IF  l_testme /*explcitly omit renames swap with shadow GT table*/
    AND l_rectype = 7
    AND (  UPPER(l_sql_stmt) LIKE UPPER('ALTER%TABLE%PS_'||l_recname||l_suffix
                                       ||'%RENAME%TO%GT_'||l_recname||l_suffix||'_')
        OR UPPER(l_sql_stmt) LIKE UPPER('ALTER%TABLE%PS_'||l_recname||l_suffix
                                       ||'%RENAME%TO%XX_'||l_recname||l_suffix||'_')
        ) THEN
     l_recname := ''; --clear record name to stop any more testing
     l_testme := FALSE;
    END IF;

   END IF;

   -------------------------------------------------------------------------------------------------------
   --table type tests: temp, partitioned, clustered, IOT
   -------------------------------------------------------------------------------------------------------
   IF l_testme THEN
    DECLARE 
     l_temporary    VARCHAR2(1 CHAR);
     l_partitioned  VARCHAR2(3 CHAR);
     l_cluster_name VARCHAR2(30 CHAR);
     l_iot_type     VARCHAR2(3 CHAR);
    BEGIN
     SELECT t.temporary, t.partitioned, t.cluster_name, t.iot_type
     INTO   l_temporary, l_partitioned, l_cluster_name, l_iot_type
     FROM   all_tables t
     WHERE  ROWNUM = 1
     AND    t.owner = ora_dict_obj_owner
     AND    t.table_name = ora_dict_obj_name
     ;
     l_msg := ora_dict_obj_owner||'.'||ora_dict_obj_name;
     IF l_temporary = 'Y' THEN
      l_errno := -20007;
      l_msg := l_msg||' is a global temporary table.';
      RAISE e_generate_message;
     ELSIF l_partitioned = 'YES' THEN
      l_errno := -20008;
      l_msg := l_msg||' is a partitioned table.';
      RAISE e_generate_message;
     ELSIF l_cluster_name IS NOT NULL THEN
      l_errno := -20009;
      l_msg := l_msg||' is a part of cluster '||l_cluster_name||'.';
      RAISE e_generate_message;
     ELSIF l_iot_type = 'IOT' THEN
      l_errno := -20010;
      l_msg := l_msg||' is an index organised table.';
      RAISE e_generate_message;
     END IF;
    EXCEPTION 
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --raise an error if an index exists on the table that is not defined in PeopleTools*/
     SELECT -20011, 'Index '||i.index_name||' on table '||ora_dict_obj_name||' is managed outside PeopleTools.'
     INTO   l_errno, l_msg
     FROM   all_indexes i
     WHERE  ROWNUM = 1
     AND    i.table_name = ora_dict_obj_name
     AND    i.table_owner = ora_dict_obj_owner
     AND    NOT (SUBSTR(i.index_name,3,1) IN('_','0','1','2','3','4','5','6','7','8','9')
                 AND   ora_dict_obj_name LIKE 'PS_'||l_recname)
     AND    NOT EXISTS(
      SELECT 'x' /*check for indexes on record*/
      FROM   psindexdefn j
      WHERE  j.recname = l_recname
      AND    j.indexid = SUBSTR(i.index_name,3,1)
      AND    'PS'||j.indexid||j.recname||l_suffix = i.index_name)
     ;
     RAISE e_generate_message;
    EXCEPTION 
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --raise error if a function based index exists on the table
     SELECT -20012, 'Function Based Index '||i.index_name||' on table '||i.table_name||' is managed outside PeopleTools.'
     INTO   l_errno, l_msg
     FROM   all_indexes i
     WHERE  ROWNUM = 1
     AND    i.owner = ora_dict_obj_owner
     AND    i.table_name = ora_dict_obj_name
     AND    NOT (SUBSTR(i.index_name,3,1) IN('_','0','1','2','3','4','5','6','7','8','9')
                 AND   ora_dict_obj_name LIKE 'PS_'||l_recname||l_suffix)
     AND NOT EXISTS( /*not defined in PeopleSoft*/
      SELECT 'x'
      FROM   psindexdefn x
      WHERE  x.recname = l_recname
      AND    x.indexid = SUBSTR(ora_dict_obj_name,3,1)
      AND    'PS'||x.indexid||x.recname||l_suffix = ora_dict_obj_name)
     AND EXISTS( /*check for expression column*/
      SELECT 'x'
      FROM   all_ind_expressions ie
      WHERE  ie.table_owner = i.table_owner
      AND    ie.table_name = ora_dict_obj_name
      AND    ie.index_owner = i.owner
      AND    ie.index_name = i.index_name)
     ;
     RAISE e_generate_message;
    EXCEPTION 
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --if a trigger exists on the table that is not called PSU then raise an error
     SELECT -20013, 'Trigger '||t.trigger_name||' exists on table '||ora_dict_obj_name||'.'
     INTO   l_errno, l_msg
     FROM   all_triggers t
     WHERE  ROWNUM = 1
     AND    t.table_name = ora_dict_obj_name
     AND    t.table_owner = ora_dict_obj_owner
     AND    t.trigger_name != 'PSU'||l_recname
     ;
     RAISE e_generate_message;
    EXCEPTION
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --raise and error if a primary key constraint exists on the table, and a unique index exists in PeopleSoft
     SELECT -20014, 'Primary key constraint '||ora_dict_obj_owner||'.'||c.constraint_name||' exists on table '||ora_dict_obj_name||'.'
     INTO   l_errno, l_msg
     FROM   all_constraints c
     WHERE  ROWNUM = 1
     AND    c.table_name = ora_dict_obj_name
     AND    c.owner = ora_dict_obj_owner
     AND    c.constraint_type = 'P' /*primary key constraint*/
     AND    c.index_name = 'PS_'||l_recname||l_suffix
     AND    EXISTS(SELECT 'x' /*a unique key field*/
      FROM  psrecfielddb r, psrecfield f
      WHERE r.recname = l_recname
      AND   f.recname = r.recname_parent
      AND   f.fieldname = r.fieldname
      AND   MOD(f.useedit,2) = 1)
     AND NOT EXISTS(SELECT 'x' /*a duplicate key field is not defined*/
      FROM  psrecfielddb r, psrecfield f
      WHERE r.recname = l_recname
      AND   f.recname = r.recname_parent
      AND   f.fieldname = r.fieldname
      AND   MOD((f.useedit/2),2) = 1)
     ;
     RAISE e_generate_message;
    EXCEPTION 
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --if a materialized view log exists
     SELECT -20015, 'A materialized view log exists on table '||ora_dict_obj_name||'.'
     INTO   l_errno, l_msg
     FROM   all_mview_logs l
     WHERE  ROWNUM = 1
     AND    l.master = ora_dict_obj_name
     AND    l.log_owner = ora_dict_obj_owner
     ;
     RAISE e_generate_message;
    EXCEPTION
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --if a materialized view exists
     SELECT -20016, 'Table '||ora_dict_obj_name||' is a materialized view.'
     INTO   l_errno, l_msg
     FROM   all_mviews m
     WHERE  ROWNUM = 1
     AND    m.mview_name = ora_dict_obj_name
     AND    m.owner = ora_dict_obj_owner
     ;
     RAISE e_generate_message;
    EXCEPTION
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
    -------------------------------------------------------------------------------------------------------
    BEGIN --if a shadow GTT exists - www.go-faster.co.uk/scripts.htm#gfc_temp_table_type.sql
     SELECT -20017, 'Table '||ora_dict_obj_name||' has a shadow Global Temporary Table '||t.table_name||'.'
     INTO   l_errno, l_msg
     FROM   all_tables t
     WHERE  ROWNUM = 1
     AND    t.owner = ora_dict_obj_owner
     AND    t.table_name = 'GT'||SUBSTR(ora_dict_obj_name,3)
     AND    t.temporary = 'Y'
     ;
     RAISE e_generate_message;
    EXCEPTION
     WHEN NO_DATA_FOUND THEN 
      l_errno := -20000;
      l_msg := l_msg0;
    END;
   END IF;
  END IF;
 END IF;

EXCEPTION
 WHEN NO_DATA_FOUND THEN /*if this occurs something odd has happened*/
  l_errno := -20000;
  l_msg := l_msg0;
 WHEN e_generate_message THEN /*reraise custom exception*/
  RAISE_APPLICATION_ERROR(l_errno,'PSFT_DDL_LOCK: '||l_msg||CHR(10)||l_msg2||CHR(10)||'SQL:'||l_sql_stmt);
END psft_ddl_lock;
/
DROP TRIGGER t_lock --remove old version of trigger
/

show errors
pause


BEGIN
  FOR i IN (SELECT table_name FROM user_tables WHERE table_name IN('PSRECDEFN','PSRECFIELDDB')) LOOP
    sys.dbms_stats.gather_table_Stats
      (ownname => 'SYSADM'
      ,tabname => i.table_name
      ,estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE
      ,method_opt => 'FOR COLUMNS SIZE AUTO'
      ,cascade => TRUE
      );
  END LOOP;
END;
/

--execute psft_ddl_lock
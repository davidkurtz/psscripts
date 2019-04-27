REM psredundantfix.sql
rollback;

/*-------------------------------------------------------------------------------------------------------
--To make indexes active again so script can be rerun
UPDATE psindexdefn
set    platform_ora = 1
,      activeflag = 1
WHERE  (recname, indexid) IN (
  SELECT objectvalue1, objectvalue2
  FROM   psprojectitem
  WHERE  objecttype = 1
  AND    projectname = 'REDUNDANT INDEXES')
AND    platform_ora = 0;
-------------------------------------------------------------------------------------------------------*/

set serveroutput on timi on
spool psredundantfix
DECLARE
  k_module      CONSTANT VARCHAR2(64) := 'PSREDUNDANT';
  k_projectname CONSTANT VARCHAR2(30) := 'REDUNDANT INDEXES';
  l_module VARCHAR2(48);
  l_action VARCHAR2(32);

-------------------------------------------------------------------------------------------------------
-- make a project for the redundant indexes
-------------------------------------------------------------------------------------------------------
PROCEDURE gfc_project IS
  l_version INTEGER;
  l_version2 INTEGER;
  l_sql VARCHAR2(32767);
  l_module VARCHAR2(48);
  l_action VARCHAR2(32);
BEGIN
  dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
  dbms_application_info.set_action(action_name=>'GFC_PROJECT');

  UPDATE  PSLOCK
  SET     version = version + 1
  WHERE   objecttypename IN ('PJM','SYS','RDM');

  UPDATE  PSVERSION
  SET     version = version + 1
  WHERE   objecttypename IN ('PJM','SYS','RDM');

  SELECT  version
  INTO    l_version
  FROM    PSLOCK
  WHERE   objecttypename IN ('PJM') FOR UPDATE OF version;

  SELECT  version
  INTO    l_version2
  FROM    psversion
  WHERE   objecttypename IN ('PJM') FOR UPDATE OF version;

  l_version := GREATEST(l_version,l_version2);
  l_version2 := l_version;

  DELETE FROM PSPROJECTDEL        WHERE PROJECTNAME = k_projectname;
--DELETE FROM psprojectitem       WHERE PROJECTNAME = k_projectname;
  DELETE FROM PSPROJDEFNLANG      WHERE PROJECTNAME = k_projectname;
  DELETE FROM PSPROJECTSEC        WHERE PROJECTNAME = k_projectname;
  DELETE FROM PSPROJECTINC        WHERE PROJECTNAME = k_projectname;
  DELETE FROM PSPROJECTDEP        WHERE PROJECTNAME = k_projectname;
--DELETE FROM PSPROJECTDEFN       WHERE PROJECTNAME = k_projectname;

  BEGIN
    INSERT INTO PSPROJECTDEFN 
    (VERSION, PROJECTNAME, TGTSERVERNAME, TGTDBNAME, TGTOPRID
    ,TGTOPRACCT, REPORTFILTER, TGTORIENTATION, COMPARETYPE, KEEPTGT
    ,COMMITLIMIT, MAINTPROJ, COMPRELEASE, COMPRELDTTM, OBJECTOWNERID
    ,LASTUPDDTTM, LASTUPDOPRID, PROJECTDESCR, RELEASELABEL, RELEASEDTTM, DESCRLONG)
    VALUES 
    (l_version,k_projectname,' ',' ',' '
    ,' ',16232832,0,1,3
    ,50,0,' ', null,' '
    ,sysdate,'PS','Redundant Indexes', ' ', NULL
    ,'Redundant Indexes identified '||TO_CHAR(SYSDATE,'dd.mm.yyyy')
    );
  EXCEPTION
    WHEN dup_val_on_index THEN
      dbms_output.put_line('Project '||k_projectname||' already exists');
      UPDATE psprojectdefn
      SET    version = l_version
      WHERE  projectname = k_projectname;
  END;

  dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);
END gfc_project;

-------------------------------------------------------------------------------------------------------
--create extended statistics
-------------------------------------------------------------------------------------------------------
PROCEDURE create_extended_stats(p_table_name VARCHAR2
                               ,p_fieldlist VARCHAR2) IS
  l_module   VARCHAR2(48);
  l_action   VARCHAR2(32);
  l_sql      VARCHAR(200);
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
  dbms_application_info.set_action(action_name=>'CREATE_EXTENDED_STATS');

  
  dbms_output.put_line('Creating Extended Statistics on '||p_table_name||' for '||p_fieldlist);

/*------------------------------------------------------------------------------------------------------------------
  l_sql := 'SELECT dbms_stats.create_extended_stats(null,'''||p_table_name||''',''('||p_fieldlist||')'') from dual';
  dbms_output.put_line(l_sql);
  EXECUTE IMMEDIATE l_sql;      
  ------------------------------------------------------------------------------------------------------------------*/
  dbms_stats.gather_table_stats(user,p_table_name
                               ,method_opt=>'FOR COLUMNS SIZE 254 ('||p_fieldlist||')'
                               ,cascade=>FALSE);

  dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);
END create_extended_stats;
-------------------------------------------------------------------------------------------------------
--invisible indexes
-------------------------------------------------------------------------------------------------------
PROCEDURE invisible_index(p_index_name VARCHAR2) IS
  l_module   VARCHAR2(48);
  l_action   VARCHAR2(32);
  l_sql      VARCHAR(200);

  PRAGMA AUTONOMOUS_TRANSACTION;

  e_resource_busy EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_resource_busy, -54);
BEGIN
  dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
  dbms_application_info.set_action(action_name=>'INVISIBLE INDEX');

  dbms_output.put_line('Making index '||p_index_name||' invisible');
  l_sql := 'ALTER INDEX '||p_index_name||' INVISIBLE';
--dbms_output.put_line(l_sql);
  BEGIN
    EXECUTE IMMEDIATE l_sql;      
  EXCEPTION 
    WHEN e_resource_busy THEN dbms_output.put_line(sqlerrm); --ignore data dictionary errors
  END;

  dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);
END invisible_index;
-------------------------------------------------------------------------------------------------------
--populate project
-------------------------------------------------------------------------------------------------------
PROCEDURE redundant_indexes IS
  l_module    VARCHAR2(48);
  l_action    VARCHAR2(32);
  l_version   INTEGER;
  l_version2  INTEGER;
  l_comment   VARCHAR2(1000);
  l_platforms INTEGER;
BEGIN
  dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
  dbms_application_info.set_action(action_name=>'REDUNDANT_INDEXES');

  SELECT  version
  INTO    l_version
  FROM    PSLOCK
  WHERE   objecttypename IN ('RDM') FOR UPDATE OF version;

  SELECT  version
  INTO    l_version2
  FROM    psversion
  WHERE   objecttypename IN ('RDM') FOR UPDATE OF version;

  l_version := GREATEST(l_version,l_version2);
  l_version2 := l_version;

  FOR i IN(
WITH uni AS (/*unique indexes*/
SELECT /*+MATERIALIZE*/ f.recname, i.indexid
,      MIN(i.uniqueflag) OVER (PARTITION BY f.recname) uniqueflag
,      CASE WHEN MAX(CASE WHEN f.recname != f.recname_parent THEN 1 ELSE 0 END) OVER (PARTITION BY f.recname)=1 
	       THEN f.fieldnum ELSE k.keyposn END keyposn
,      k.fieldname, i.recname idxrecname
,      i.activeflag, i.platform_sbs, i.platform_db2, i.platform_ora, i.platform_inf
,      i.platform_dbx, i.platform_alb, i.platform_syb, i.platform_mss, i.platform_db4
FROM   psrecfielddb f
,      psindexdefn i
,      pskeydefn k
WHERE  i.recname IN(f.recname,f.recname_parent)
AND    i.recname = k.recname
AND    k.fieldname = f.fieldname
AND    i.indexid = '_' /*unique index*/
AND    k.indexid = i.indexid
AND    bitand(f.useedit,3) > 0 /*unique or dup key*/
), as0 AS (/*leading column on alternate search indexes*/
SELECT f0.recname, k0.indexid, i0.uniqueflag, 0 keyposn, f0.fieldname, i0.recname idxrecname
,      i0.activeflag, i0.platform_sbs, i0.platform_db2, i0.platform_ora, i0.platform_inf
,      i0.platform_dbx, i0.platform_alb, i0.platform_syb, i0.platform_mss, i0.platform_db4
FROM   psrecfielddb f0
,      psindexdefn i0
,      pskeydefn k0
WHERE  bitand(f0.useedit,16) = 16 /*alternate search key*/
AND    k0.recname = f0.recname_parent
AND    k0.fieldname = f0.fieldname
AND    i0.recname = k0.recname
AND    i0.indexid = k0.indexid
AND    i0.indexid BETWEEN '0' AND '9' /*alternate search index*/
), as1 AS ( /*now add unique columns*/
SELECT as0.recname, as0.indexid, as0.uniqueflag, as0.keyposn, as0.fieldname, as0.idxrecname
,      as0.activeflag, as0.platform_sbs, as0.platform_db2, as0.platform_ora, as0.platform_inf
,      as0.platform_dbx, as0.platform_alb, as0.platform_syb, as0.platform_mss, as0.platform_db4
FROM   as0
UNION ALL
SELECT as0.recname, as0.indexid, as0.uniqueflag, uni.keyposn, uni.fieldname, as0.idxrecname
,      as0.activeflag, as0.platform_sbs, as0.platform_db2, as0.platform_ora, as0.platform_inf
,      as0.platform_dbx, as0.platform_alb, as0.platform_syb, as0.platform_mss, as0.platform_db4
FROM   as0, uni
WHERE  as0.recname = uni.recname
), as2 AS ( /*apply custom key orders*/
SELECT as1.recname, as1.indexid, as1.uniqueflag, NVL(k.keyposn,as1.keyposn) keyposn, as1.fieldname, as1.idxrecname
,      as1.activeflag, as1.platform_sbs, as1.platform_db2, as1.platform_ora, as1.platform_inf
,      as1.platform_dbx, as1.platform_alb, as1.platform_syb, as1.platform_mss, as1.platform_db4
FROM   as1
       LEFT OUTER JOIN pskeydefn k
       ON  k.recname = as1.recname
       AND k.indexid = as1.indexid
       AND k.fieldname = as1.fieldname
), usi AS (/*user indexes*/
SELECT i.recname, i.indexid, i.uniqueflag, k.keyposn, k.fieldname, i.recname idxrecname
,      i.activeflag, i.platform_sbs, i.platform_db2, i.platform_ora, i.platform_inf
,      i.platform_dbx, i.platform_alb, i.platform_syb, i.platform_mss, i.platform_db4
FROM   psindexdefn i
,      pskeydefn k
WHERE  k.recname = i.recname
AND    k.indexid = i.indexid
AND    k.indexid BETWEEN 'A' AND 'Z'
), m AS (/*merge three kinds of index here*/
SELECT uni.recname, uni.indexid, uni.uniqueflag, uni.keyposn, uni.fieldname, uni.idxrecname
,      uni.activeflag, uni.platform_sbs, uni.platform_db2, uni.platform_ora, uni.platform_inf
,      uni.platform_dbx, uni.platform_alb, uni.platform_syb, uni.platform_mss, uni.platform_db4
FROM   uni
UNION ALL
SELECT as2.recname, as2.indexid, as2.uniqueflag, as2.keyposn, as2.fieldname, as2.idxrecname
,      as2.activeflag, as2.platform_sbs, as2.platform_db2, as2.platform_ora, as2.platform_inf
,      as2.platform_dbx, as2.platform_alb, as2.platform_syb, as2.platform_mss, as2.platform_db4
FROM   as2
UNION ALL
SELECT usi.recname, usi.indexid, usi.uniqueflag, usi.keyposn, usi.fieldname, usi.idxrecname
,      usi.activeflag, usi.platform_sbs, usi.platform_db2, usi.platform_ora, usi.platform_inf
,      usi.platform_dbx, usi.platform_alb, usi.platform_syb, usi.platform_mss, usi.platform_db4
FROM   usi
), ic AS ( /*list of columns, restrict to tables*/
SELECT r.recname, m.indexid, m.uniqueflag, m.keyposn, m.fieldname, m.idxrecname
,      m.activeflag, m.platform_sbs, m.platform_db2, m.platform_ora, m.platform_inf
,      m.platform_dbx, m.platform_alb, m.platform_syb, m.platform_mss, m.platform_db4
from   m
,      psrecdefn r
where  r.rectype IN(0,7)
and    r.recname = m.recname
and    m.activeflag = 1
), i AS ( --construct column list
SELECT /*+ MATERIALIZE*/
       ic.recname, ic.indexid, ic.uniqueflag, ic.idxrecname
,      ic.activeflag, ic.platform_sbs, ic.platform_db2, ic.platform_ora, ic.platform_inf
,      ic.platform_dbx, ic.platform_alb, ic.platform_syb, ic.platform_mss, ic.platform_db4
,      count(*) num_columns
,      listagg(ic.fieldname,',') within group (order by ic.keyposn) AS fieldlist
FROM   ic
GROUP BY ic.recname, ic.indexid, ic.uniqueflag, ic.idxrecname
,      ic.activeflag, ic.platform_sbs, ic.platform_db2, ic.platform_ora, ic.platform_inf
,      ic.platform_dbx, ic.platform_alb, ic.platform_syb, ic.platform_mss, ic.platform_db4
)
SELECT r.recname
,      i.indexid    superset_indexid
,      i.fieldlist  superset_fieldlist
,      i.activeflag, i.platform_sbs, i.platform_db2, i.platform_ora, i.platform_inf
,      i.platform_dbx, i.platform_alb, i.platform_syb, i.platform_mss, i.platform_db4
,      r.idxrecname redundant_idxrecname
,      r.indexid    redundant_indexid
,      r.fieldlist  redundant_fieldlist
,      r.num_columns, r.platform_ora redundant_ora
FROM   i
,      i r
WHERE  i.recname = r.recname
AND    i.indexid != r.indexid
AND    r.uniqueflag = 0 /*non-unique redundant*/
AND    i.fieldlist LIKE r.fieldlist||',%'
AND    i.num_columns > r.num_columns
order by r.recname, r.indexid
  ) LOOP
    l_comment := TO_CHAR(sysdate)||' Redundant Index '||i.redundant_indexid||' disabled due to superset index '||i.superset_indexid;
    l_platforms := i.platform_db2+i.platform_ora+i.platform_inf+i.platform_dbx+i.platform_syb+i.platform_mss;
    IF l_platforms>0 AND l_platforms<6 THEN
      l_comment := l_comment||' (';
      IF i.platform_db2>0 THEN
        l_platforms := l_platforms-1;
        l_comment := l_comment||'DB2';
        IF l_platforms > 0 THEN
          l_comment := l_comment||',';
        END IF;
      END IF;
      IF i.platform_ora>0 THEN
        l_platforms := l_platforms-1;
        l_comment := l_comment||'ORA';
        IF l_platforms > 0 THEN
          l_comment := l_comment||',';
        END IF;
      END IF;
      IF i.platform_inf>0 THEN
        l_platforms := l_platforms-1;
        l_comment := l_comment||'INF';
        IF l_platforms > 0 THEN
          l_comment := l_comment||',';
        END IF;
      END IF;
      IF i.platform_dbx>0 THEN
        l_platforms := l_platforms-1;
        l_comment := l_comment||'DBX';
        IF l_platforms > 0 THEN
          l_comment := l_comment||',';
        END IF;
      END IF;
      IF i.platform_syb>0 THEN
        l_platforms := l_platforms-1;
        l_comment := l_comment||'SYB';
        IF l_platforms > 0 THEN
          l_comment := l_comment||',';
        END IF;
      END IF;
      IF i.platform_mss>0 THEN
        l_platforms := l_platforms-1;
        l_comment := l_comment||'MSS';
        IF l_platforms > 0 THEN
          l_comment := l_comment||',';
        END IF;
      END IF;
      l_comment := l_comment||')';
    END IF;
    l_comment := l_comment||' on '||i.superset_fieldlist;
    dbms_output.put_line(l_comment);

    UPDATE psrecdefn /*update version on record definition*/
    SET    version = l_version
    WHERE  recname = i.recname;

    UPDATE psindexdefn /*mark inactive if superset active on same platform*/
    SET    activeflag   = DECODE(i.activeflag  ,1,0,activeflag)
    ,      platform_sbs = DECODE(i.platform_sbs,1,0,platform_sbs)
    ,      platform_db2 = DECODE(i.platform_db2,1,0,platform_db2)
    ,      platform_ora = DECODE(i.platform_ora,1,0,platform_ora)
    ,      platform_inf = DECODE(i.platform_inf,1,0,platform_inf)
    ,      platform_dbx = DECODE(i.platform_dbx,1,0,platform_dbx)
    ,      platform_alb = DECODE(i.platform_alb,1,0,platform_alb)
    ,      platform_syb = DECODE(i.platform_syb,1,0,platform_syb)
    ,      platform_mss = DECODE(i.platform_mss,1,0,platform_mss)
    ,      platform_db4 = DECODE(i.platform_db4,1,0,platform_db4)
    ,      idxcomments = SUBSTR(l_comment,1,128)
           /*although unique and alternate search comments not visible via Application Designer*/
    WHERE  recname = i.redundant_idxrecname
    AND    indexid = i.redundant_indexid;

    UPDATE psindexdefn /*if all flags set 0, then set index inactive.  Override desupported platforms*/
    SET    activeflag = 0 
    ,      platform_alb = 0 /*AllBase*/
    ,      PLATFORM_SBS = 0 /*SQLBase*/
    ,      PLATFORM_DB4 = 0 /*DB2/AS400*/
    WHERE  recname = i.redundant_idxrecname
    AND    indexid = i.redundant_indexid
    AND    PLATFORM_DB2 = 0
    AND    PLATFORM_ORA = 0
    AND    PLATFORM_INF = 0
    AND    PLATFORM_DBX = 0
    AND    PLATFORM_SYB = 0
    AND    PLATFORM_MSS = 0;

    UPDATE psindexdefn /*fix active flag*/
    SET    activeflag = SIGN(platform_sbs+platform_db2+platform_ora+platform_inf+platform_dbx+platform_alb+platform_syb+platform_mss+platform_db4)
    WHERE  recname = i.redundant_idxrecname
    AND    indexid = i.redundant_indexid;

    BEGIN /*add record to project*/
      INSERT INTO psprojectitem
      (      PROJECTNAME, OBJECTTYPE, OBJECTID1, OBJECTVALUE1, 
             OBJECTID2, OBJECTVALUE2, OBJECTID3, OBJECTVALUE3, 
             OBJECTID4, OBJECTVALUE4, NODETYPE, SOURCESTATUS, 
             TARGETSTATUS, UPGRADEACTION, TAKEACTION, COPYDONE)
      VALUES(k_projectname,0,1,i.recname,
             0,' ',0,' ',
             0,' ',0,0,
             0,2,1,0);
--    dbms_output.put_line('Record '||i.recname||' added to project');
    EXCEPTION
      WHEN dup_val_on_index THEN NULL;
--      dbms_output.put_line('Record '||i.recname||' already in project');
    END;

    BEGIN /*add index to project*/
      INSERT INTO psprojectitem
      (      PROJECTNAME, OBJECTTYPE, OBJECTID1, OBJECTVALUE1, 
             OBJECTID2, OBJECTVALUE2, OBJECTID3, OBJECTVALUE3, 
             OBJECTID4, OBJECTVALUE4, NODETYPE, SOURCESTATUS, 
             TARGETSTATUS, UPGRADEACTION, TAKEACTION, COPYDONE)
      VALUES(k_projectname,1,1,i.recname,
             24,i.redundant_indexid,0,' ',
             0,' ',0,0,
             0,0,1,0);
      dbms_output.put_line('Record '||i.recname||', Redundant Index '||i.redundant_indexid||' added to project');
    EXCEPTION
      WHEN dup_val_on_index THEN
        dbms_output.put_line('Record '||i.recname||', Redundant Index '||i.redundant_indexid||' already in project');
    END;

    IF i.num_columns>1 AND i.platform_ora=1 THEN
      FOR j IN(  
        WITH n AS (SELECT rownum n FROM dual CONNECT BY LEVEL <= 99)
        SELECT t.table_name, 0 n
        FROM   psrecdefn r
        ,      user_tables t
        WHERE  r.rectype IN(0,7)
        AND    t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
        AND    r.recname = i.recname
        UNION ALL
        SELECT t.table_name, n
        FROM   psrecdefn r, n
        ,      pstemptblcntvw t
        ,      psoptions o 
        ,      user_tables t
        WHERE  r.rectype IN(7)
        AND    t.recname = r.recname
        AND    n.n <= t.temptblinstances+o.temptblinstances
        AND    t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)||LTRIM(TO_CHAR(n.n,'99'))
        AND    r.recname = i.recname
        ORDER BY n
     ) LOOP     
        create_extended_stats(j.table_name,i.redundant_fieldlist);
      END LOOP;
    END IF;

    IF i.platform_ora=1 THEN
      FOR j IN(  
        WITH n AS (SELECT rownum n FROM dual CONNECT BY LEVEL <= 99)
        SELECT i.index_name, 0 n
        FROM   psrecdefn r
        ,      user_indexes i
        WHERE  r.rectype IN(0,7)
        AND    i.index_name = 'PS'||i.redundant_indexid||i.recname
        AND    r.recname = i.recname
        UNION ALL
        SELECT i.index_name, n
        FROM   psrecdefn r, n
        ,      pstemptblcntvw t
        ,      psoptions o 
        ,      user_indexes i
        WHERE  r.rectype IN(7)
        AND    t.recname = r.recname
        AND    n.n <= t.temptblinstances+o.temptblinstances
        AND    i.index_name = 'PS'||i.redundant_indexid||i.recname||LTRIM(TO_CHAR(n.n,'99'))
        AND    r.recname = i.recname
        ORDER BY n
      ) LOOP      
        invisible_index(j.index_name);
      END LOOP;
    END IF;

  END LOOP;

  dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);
END redundant_indexes;

-------------------------------------------------------------------------------------------------------
BEGIN
  dbms_application_info.read_module(module_name=>l_module, action_name=>l_action);
  dbms_application_info.set_module(module_name=>k_module, action_name=>'REDUNDANT_INDEXES');

  gfc_project;
  redundant_indexes;  
  commit;

  dbms_application_info.set_module(module_name=>l_module, action_name=>l_action);
END;
/
spool off


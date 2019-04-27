REM locktemprecstats.sql
REM (c)David Kurtz, Go-Faster Consultancy Ltd. 2009   
REM Delete and lock statistics on working storage tables

spool locktemprecstats
ttitle 'Unlocked Temporary Tables'
SELECT 	DISTINCT r.recname, t.table_name, t.last_analyzed, s.stattype_locked
FROM   	psrecdefn r
,      	pstemptblcntvw i
, 	psoptions o
, 	user_tables t	
		LEFT OUTER JOIN user_tab_statistics s
		ON  s.table_name = t.table_name
        	AND s.partition_name IS NULL
,      (SELECT rownum row_number
    	FROM   all_objects 
	WHERE ROWNUM <= 100) v
WHERE 	r.rectype = '7'
AND 	r.recname = i.recname
AND   	v.row_number <= i.temptblinstances + o.temptblinstances
AND    	t.table_name 
       	= DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
	||DECODE(v.row_number*r.rectype,100,'',LTRIM(TO_NUMBER(v.row_number))) 
AND 	(/*  t.num_rows        IS NOT NULL --not analyzed 
       	OR   t.last_analyzed   IS NOT NULL --not analyzed
       	OR*/ s.stattype_locked IS     NULL --stats not locked
      	) 
ORDER BY 1
/
ttitle off





set serveroutput on
BEGIN
 FOR x IN (
  SELECT /*+LEADING(o i r v)*/ t.table_name, t.last_analyzed, t.num_rows
  ,      s.stattype_locked
  FROM pstemptblcntvw i
    INNER JOIN psrecdefn r
    ON r.recname = i.recname
    AND r.rectype = '7'
  , psoptions o
  , user_tables t
     LEFT OUTER JOIN user_tab_statistics s
     ON  s.table_name = t.table_name
     AND s.partition_name IS NULL
  , (SELECT rownum row_number
     FROM   psrecdefn 
     WHERE  ROWNUM <= 100) v                 
  WHERE  v.row_number <= i.temptblinstances + o.temptblinstances
  AND    t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
                      ||DECODE(v.row_number*r.rectype,100,'',LTRIM(TO_NUMBER(v.row_number))) 
/*---------------------------------------------------------------------            
--AND    r.recname IN('TL_PMTCH1_TMP' --TL_TA000600.SLCTPNCH.STATS1.S…
--                   ,'TL_PMTCH2_TMP' --TL_TA000600.CALC_DUR.STATS1.S…)
-----------------------------------------------------------------------*/
  AND   (/*  t.num_rows        IS NOT NULL --not analyzed 
        OR   t.last_analyzed   IS NOT NULL --not analyzed
        OR*/ s.stattype_locked IS     NULL --stats not locked
        ) 
) LOOP
  IF x.last_analyzed IS NOT NULL THEN --delete stats
   dbms_output.put_line('Deleting Statistics on '||user||'.'||x.table_name);
   dbms_stats.delete_table_stats(ownname=>user,tabname=>x.table_name,force=>TRUE);
  END IF;
  IF x.stattype_locked IS NULL THEN --lock stats
   dbms_output.put_line('Locking Statistics on '||user||'.'||x.table_name); 
   dbms_stats.lock_table_stats(ownname=>user,tabname=>x.table_name);
  END IF;
 END LOOP;
END;
/


spool off

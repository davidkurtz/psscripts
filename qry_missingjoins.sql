REM qry_missingjoins.sql
REM https://blog.psftdba.com/2024/11/psquery-cartesian.html
Clear screen
Set pages 999 lines 180
Column oprid format a9
Column qryname format a30
Column selnum heading 'Sel|#' format 999
Column rcdnum1 heading 'Rec1|#' format 999
Column rcdnum2 heading 'Rec2|#' format 999
Column corrname1 heading 'Cor|#1' format a3
Column corrname2 heading 'Cor|#2' format a3
Column recname1 heading 'Record 1' format a18
Column recname2 heading 'Record 2' format a18
Column num_key_fields heading '#Key|Flds' format 999
ttitle 'PS/Queries Possibly Missing Joins'
spool qry_missingjoins

WITH q1 as (
SELECT r.prcsinstance
, r.oprid runoprid, r.runcntlid
, DECODE(c.private_query_flag,'Y','Private','N','Public') private_query_flag
, DECODE(c.private_query_flag,'Y',r.oprid,' ') oprid
, c.qryname
, CAST(begindttm AS DATE) begindttm
, CAST(enddttm AS DATE) enddttm
, runstatus
, (CAST(NVL(enddttm,SYSDATE) AS DATE)-CAST(begindttm AS DATE))*86400 exec_Secs
FROM psprcsrqst r
  LEFT OUTER JOIN ps_query_run_cntrl c ON c.oprid = r.oprid AND c.run_cntl_id = r.runcntlid
WHERE prcsname = 'PSQUERY'
AND dbname IN(select DISTINCT dbname from ps.psdbowner)
--AND r.begindttm >= trunc(SYSDATE)-2+8/24
--AND r.begindttm <= trunc(SYSDATE)-2+19/24
), q as (
Select /*+MATERIALIZE*/ oprid, qryname
, SUM(exec_secs) exec_secs
, COUNT(*) num_execs
, COUNT(DECODE(runstatus,'9',1,NULL)) complete_execs
, COUNT(DISTINCT runoprid) runoprids
From q1
GROUP BY oprid, qryname
), x as (
SELECT r1.oprid, r1.qryname, r1.selnum
, r1.rcdnum rcdnum1, r1.recname recname1, r1.corrname corrname1
, r2.rcdnum rcdnum2, r2.recname recname2, r2.corrname corrname2
, (SELECT count(*) 
   FROM psqryfield qf1 --INNER JOIN psrecfielddb f1 ON f1.recname = r1.recname AND f1.fieldname = qf1.fieldname
   ,    psqryfield qf2 INNER JOIN psrecfielddb f2 ON f2.recname = r2.recname AND f2.fieldname = qf2.fieldname AND MOD(f2.useedit,2)=1
   , psqrycriteria c
   WHERE qf1.oprid = r1.oprid AND qf1.qryname = r1.qryname AND qf1.selnum = r1.selnum AND qf1.recname = r1.recname AND qf1.fldrcdnum = r1.rcdnum
   AND   qf2.oprid = r2.oprid AND qf2.qryname = r2.qryname AND qf2.selnum = r2.selnum AND qf2.recname = r2.recname AND qf2.fldrcdnum = r2.rcdnum
   AND    c.oprid = r1.oprid AND  c.qryname = r1.qryname AND  c.selnum = r1.selnum 
   AND   (  (c.lcrtselnum = r1.selnum AND c.lcrtfldnum = qf1.fldnum AND c.r1crtselnum = r2.selnum AND c.r1crtfldnum = qf2.fldnum)
         OR (c.lcrtselnum = r2.selnum AND c.lcrtfldnum = qf2.fldnum AND c.r1crtselnum = r1.selnum AND c.r1crtfldnum = qf1.fldnum))
   AND rownum = 1
  ) num_key_fields
FROM psrecdefn r
, psqryrecord r1
  INNER JOIN psqryrecord r2 ON r1.oprid = r2.oprid AND r1.qryname = r2.qryname AND r1.selnum = r2.selnum AND r1.rcdnum != r2.rcdnum --AND r1.corrname < r2.corrname
WHERE r.recname = r2.recname AND r.parentrecname = r1.recname
)
SELECT /*+LEADING(Q)*/ q.* 
, x.selnum
, x.rcdnum1, x.recname1, x.corrname1
, x.rcdnum2, x.recname2, x.corrname2
, x.num_key_fields
FROM x
  INNER JOIN q ON q.oprid = x.oprid AND q.qryname = x.qryname
WHERE num_key_fields = 0
AND exec_secs >= 600
--AND recname1 IN('JRNL_HEADER')
--AND recname2 IN('JRNL_LN','JRNL_DRILL_VW')
--AND r1.oprid = 'B******' AND r1.qryname = '***_GL_BJU'
--AND r1.oprid = ' ' AND r1.qryname = '***AM_FIN_GL_AP'
ORDER BY exec_secs desc
--fetch first 10 rows only
/
spool off
ttitle off
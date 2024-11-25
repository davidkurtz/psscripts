REM qry_longprcs.sql
Alter session set nls_date_format = 'HH24:MI:SS dd.mm.yy';
Set pages 99 lines 145
column private_query_flag heading 'Private|Query' format a7
column oprid format a9
column runstatus heading 'Run|Stat' format a4
column runcntlid format a30
Column action format a25
Column prcsinstance heading 'Process|Instance' format 99999999
Column runcntlid format a30
column exec_secs heading 'Exec|Secs' format 999999
column qryname format a30
compute sum of exec_Secs on report
Break on report
Ttitle 'Long Running PS/Query Elapsed Times'
spool qry_longprcs
WITH x as (
SELECT r.prcsinstance, r.oprid, r.runcntlid
, DECODE(c.private_query_flag,'Y','Private','N','Public') private_query_flag
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
)
Select x.*
From x
Where exec_Secs >= 300
ORDER BY exec_secs desc
Fetch first 50 rows only
/
spool off
ttitle off
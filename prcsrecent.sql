REM prcsrecent.sql
set pages 99 lines 200
column prcstype format a20
column begindttm format a30
column enddttm format a30
select r.jobinstance, r.prcsinstance, r.prcstype, r.prcsname, r.runcntlid, r.runstatus
, round((CAST(r.enddttm AS DATE)-CAST(r.begindttm AS DATE))*86400,3) secs
, r.servernamerun, r.begindttm, r.enddttm
from psprcsrqst r
  left outer join psprcsrqst j
  on j.prcsinstance = r.jobinstance
where (r.begindttm > sysdate-1
or     j.begindttm > sysdate-1)
order by begindttm desc
fetch first 50 rows only
/

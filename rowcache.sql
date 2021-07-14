REM rowcache.sql
spool rowcache
column event format a20
column p1text format a20

with x as (select event, p1text, p1
--, sum(usecs_per_Row)/1e6 ash_Secs
, sum(10) ash_Secs
from dba_hist_Active_Sess_history
where event = 'row cache lock'
group by event, p1, p1text
)
select x.*, c.parameter
from x
  left outer join v$rowcache c
  on c.cache# = x.p1
order by ash_secs desc nulls last
fetch first 10 rows only
/

spool off

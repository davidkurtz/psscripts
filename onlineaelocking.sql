REM onlineaelocking.sql
spool onlineaelocking.lst
set long 50000 
alter session set nls_date_Format = 'dd.mm.yyyy hh24:mi:ss';
--select sql_text from dba_hist_sqltext where sql_id = 'crjhvdj2ttag6';
column ash_secs format 999,999
column max_queue_length heading 'Max Queue|Length'
WITH FUNCTION tsround(p_in IN TIMESTAMP, p_len INTEGER) RETURN timestamp IS
l_date VARCHAR2(20);
l_secs NUMBER;
l_date_fmt VARCHAR2(20) := 'J';
l_secs_fmt VARCHAR2(20) := 'SSSSS.FF9';
BEGIN
l_date := TO_CHAR(p_in,l_date_fmt);
l_secs := ROUND(TO_NUMBER(TO_CHAR(p_in,l_secs_fmt)),p_len);
IF l_secs >= 86400 THEN
l_secs := l_secs - 86400;
l_date := l_date + 1;
END IF;
RETURN TO_TIMESTAMP(l_date||l_secs,l_date_fmt||l_secs_fmt);
END tsround;
x as (
select  i.db_name, tsround(h.sample_time,-1) sample_time
,       usecs_per_row
from    dba_hist_snapshot x
,       dba_hist_database_instance i
,       dba_hist_Active_Sess_history h
where   x.dbid = h.dbid
and     x.instance_Number = h.instance_number
and     x.snap_id = h.snap_id
and     i.dbid = x.dbid
and     i.instance_number = x.instance_number
and     i.startup_time = x.startup_time
and     h.sql_id = 'crjhvdj2ttag6'
and     h.event like 'enq: T%'
--and     x.end_interval_time >= TRUNC(SYSDATE)-7
--and     h.sample_time >= TRUNC(SYSDATE)-7
), y as (
select x.db_name, x.sample_time
,      count(*) num_samples
,      sum(usecs_per_row)/1e6 ash_Secs
from x
group by x.db_name, x.sample_time
)
select db_name
,      min(sample_time)+0 sample_time
,      max(num_samples) max_queue_length
,      sum(ash_Secs) ash_Secs
from   y
group by db_name, trunc(sample_time,'hh24') 
order by 1
/
spool off
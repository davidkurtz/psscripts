REM dup_sql_profiles.sql
REM https://blog.go-faster.co.uk/2021/08/detecting-clashing-sql-profiles.html
set long 400 lines 200 pages 999
break on sig_force skip 1
column profile# heading 'Prof#' format 9999
column num_profiles heading 'Num|SQL|Profs' format 9999
column sig_exact format 99999999999999999999
column sig_force format 99999999999999999999
column sql_Text format a80 wrap on
alter session set nls_timestamp_format = 'hh24:mi:ss dd/mm/yyyy';
spool dup_sql_profiles
WITH function sig(p_sql_text CLOB, p_number INTEGER) RETURN NUMBER IS
 l_sig NUMBER;
BEGIN
 IF p_number > 0 THEN 
  l_sig := dbms_sqltune.sqltext_to_signature(p_sql_text,TRUE);
 ELSIF p_number = 0 THEN 
  l_sig := dbms_sqltune.sqltext_to_signature(p_sql_text,FALSE);
 END IF;
 RETURN l_sig;
END;
x as (
select sig(sql_text, 0) sig_exact
, sig(sql_text, 1) sig_force
, p.*
from dba_sql_profiles p
), y as (
select x.*
, row_number() over (partition by sig_force order by sig_exact) profile#
, count(*) over (partition by sig_force) num_profiles
from x
)
select profile#, num_profiles, sig_force, sig_exact, name, created, status, force_matching, sql_text
from y
where num_profiles > 1
--and force_matching = 'NO'
order by sig_force, sig_exact
/
spool off

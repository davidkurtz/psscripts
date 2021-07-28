REM who_is_granted_what.sql
spool who_is_granted_what

set lines 200
column role format a30
column username format a30
column external_name format a30
column granted_role format a30
column granted_role_disp format a30
column grantee format a30
column grantee_list format a160
with x as (
select p.granted_role, CASE WHEN u.username IS NOT NULL THEN 'U:'||u.username
                            WHEN r.role IS NOT NULL THEN 'R:'||r.role
                            ELSE 'X:'||p.grantee END grantee
from dba_role_privs p
  left outer join dba_users u on u.username = p.grantee
  left outer join dba_roles r on r.role = p.grantee
)
select granted_role, listagg(grantee,', ') within group (order by grantee) grantee_list
from x
group by granted_role
order by 1,2
--fetch first 30 rows only
/




Column seq format 999 
with x as (
select grantee, type||'-'||privilege privilege, count(*) num_objects
from dbA_tab_privs
group by grantee, type, privilege
), y as (
select * 
from   x
pivot (sum(num_objects) 
       for privilege IN('TABLE-SELECT' as table_select
                       ,'TABLE-INSERT' as table_insert
                       ,'TABLE-UPDATE' as table_update
                       ,'TABLE-DELETE' as table_delete
                       ))
), z as (
select rownum seq, granted_role
,      LPAD('.',level,'.')||granted_role granted_role_disp
from dba_role_privs
connect by grantee = prior granted_role
start with grantee = 'SYSADM'
)
select z.seq, z.granted_role_disp, y.table_select, y.table_insert, y.table_update, y.table_delete
from z
  left outer join y on y.grantee = z.granted_role
order by seq
/


spool off

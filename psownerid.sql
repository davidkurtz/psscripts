REM psownerid.sql

column ownerid new_value ownerid
select distinct ownerid 
from ps.psdbowner p
  left outer join v$database d on p.dbname = d.name
order by d.name nulls last
fetch first 1 row only
/
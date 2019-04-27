REM psredundant.sql
set lines 160 pages 50 trimspool on
column recname format a15
column superset_index format a60
column redundant_index format a60
break on recname skip 1 on indexid skip 1

spool psredundant

with uni as (/*unique indexes*/
select /*+MATERIALIZE*/ f.recname, i.indexid
,      MIN(i.uniqueflag) OVER (PARTITION BY f.recname) uniqueflag
,      CASE WHEN MAX(CASE WHEN f.recname != f.recname_parent THEN 1 ELSE 0 END) OVER (PARTITION BY f.recname)=1 
	       THEN f.fieldnum ELSE k.keyposn END keyposn
,      k.fieldname
,      i.platform_ora
from   psrecfielddb f
,      psindexdefn i
,      pskeydefn k
where	  i.recname IN(f.recname,f.recname_parent)
and	  i.recname = k.recname
and	  k.fieldname = f.fieldname
and	  i.indexid = '_'
and	  k.indexid = i.indexid
and	  bitand(f.useedit,3) > 0 /*unique or dup*/
), as0 as (/*leading column on alternate search indexes*/
select f0.recname, k0.indexid, i0.uniqueflag, 0 keyposn, f0.fieldname, i0.platform_ora
from   psrecfielddb f0
,      psindexdefn i0
,      pskeydefn k0
where  bitand(f0.useedit,16) = 16 /*alternate search key*/
and    k0.recname = f0.recname_parent
and    k0.fieldname = f0.fieldname
and    i0.recname = k0.recname
and    i0.indexid = k0.indexid
and    i0.indexid BETWEEN '0' AND '9'
), as1 as ( /*now add unique columns*/
select as0.recname, as0.indexid, as0.uniqueflag, as0.keyposn, as0.fieldname, as0.platform_ora
from   as0
union all
select as0.recname, as0.indexid, as0.uniqueflag, uni.keyposn, uni.fieldname, as0.platform_ora
from	  as0, uni
where	  as0.recname = uni.recname
), as2 as (
select as1.recname, as1.indexid, as1.uniqueflag, NVL(k.keyposn,as1.keyposn), as1.fieldname, as1.platform_ora
from	  as1
	  left outer join pskeydefn k
	  on  k.recname = as1.recname
	  and k.indexid = as1.indexid
       and k.fieldname = as1.fieldname
), usi as (/*user indexes*/
select i.recname, i.indexid, i.uniqueflag, k.keyposn, k.fieldname, i.platform_ora
from 	  psindexdefn i
,	  pskeydefn k
where  k.recname = i.recname
and    k.indexid = i.indexid
and    k.indexid BETWEEN 'A' AND 'Z'
), m as (/*merge here*/
select	uni.recname, uni.indexid, uni.uniqueflag, uni.keyposn, uni.fieldname, uni.platform_ora
from 	uni
union all
select	as1.recname, as1.indexid, as1.uniqueflag, as1.keyposn, as1.fieldname, as1.platform_ora
from 	as1
union all
select	usi.recname, usi.indexid, usi.uniqueflag, usi.keyposn, usi.fieldname, usi.platform_ora
from 	usi
), ic as ( /*list of columns, restrict to tables*/
select r.recname, m.indexid, m.uniqueflag, m.keyposn, m.fieldname
from   m
,      psrecdefn r
where  r.rectype IN(0,7)
and    r.recname = m.recname
and    m.platform_ora = 1
), i AS ( --construct column list
SELECT /*+ MATERIALIZE*/
        ic.recname, ic.indexid, ic.uniqueflag
,       count(*) num_columns
,       listagg(ic.fieldname,',') within group (order by ic.keyposn) AS fieldlist
FROM    ic
GROUP BY ic.recname, ic.indexid, ic.uniqueflag
)
select  r.recname
,       i.indexid||' ('||i.fieldlist||')' superset_index
,       r.indexid||' ('||r.fieldlist||')' redundant_index
from    i
,       i r
WHERE   i.recname = r.recname
and     i.indexid != r.indexid
and	r.uniqueflag = 0 /*non-unique redundant*/
and     i.fieldlist LIKE r.fieldlist||',%'
AND     i.num_columns > r.num_columns
--AND   i.recname IN('TL_TA_BATCH','UPG_NAMES_TAO','EP_APPR_XREF','JOB')
order by r.recname, r.indexid
/

spool off

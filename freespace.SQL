set echo off
--@login
set head off feedback off echo off verify off pages 9999 termout off pause off
column SPOOL_FILENAME new_value SPOOL_FILENAME
SELECT 'freespace_'||lower(name)||'_'||TO_CHAR(sysdate,'YYYYmmdd_hh24mi') SPOOL_FILENAME 
FROM v$database;
set head on termout on autotrace off pages 40 lines 114 feedback off echo off pause off autotrace off timi off
break on report
compute sum of summb on report
compute sum of fragments on report
compute sum of filemb on report
compute sum of files on report
compute sum of segments on report
compute sum of extents on report
compute sum of extentmb on report
column tablespace_name	format a18 		heading 'Tablespace|Name'
column files     	format 9990		heading 'Files'
column summb     	format 9999990.90	heading 'Total|Free|Mb'
column maxmb     	format 99990.90		heading 'Largest|Free|Mb'
column fragments 	format 99990		heading 'Free|Exts'
column filemb    	format 9999990		heading 'File|Mb'
column pct       	format 999 		heading '%Free|of|File'
column maxfilemb    	format 999990.0		heading 'Max File|Mb'
column pctmax       	format 999 		heading '%Free|of|Max'
column segments  	format 999990		heading 'Used|Segs'
column extents   	format 9999990		heading 'Used|Exts'
column extentmb  	format 9999990.90	heading 'Used|Mb'
spool &&SPOOL_FILENAME
select	/*+ORDERED*/
	f.tablespace_name
,	f.files
,	s.summb
,	s.maxmb
,	s.fragments
,	f.filemb
,	NVL(s.summb,0)/f.filemb*100 pct
,	f.maxfilemb
,	(NVL(s.summb,0)+f.maxfilemb-f.filemb)/f.maxfilemb*100 pctmax
,	o.segments
,	o.extents
,	o.extentmb
from	(
	select	tablespace_name
	,	count(*) files
	,	sum(bytes)/1024/1024 filemb
	,	sum(greatest(bytes,maxbytes))/1024/1024 maxfilemb
	from	dba_data_files
	group by tablespace_name
	union all
	select	tablespace_name
	,	count(*) files
	,	sum(bytes)/1024/1024 filemb
	,	sum(greatest(bytes,maxbytes))/1024/1024 maxfilemb
	from	dba_temp_files
	group by tablespace_name
	) f
,	(
	select tablespace_name
	,	sum(bytes)/1024/1024 summb
	,	max(bytes)/1024/1024 maxmb
	,	count(*) fragments
	from 	dba_free_space
	group by tablespace_name
	) s
,	(
	select 	tablespace_name
	,	count(distinct owner||segment_name||segment_type||partition_name) segments
	,	sum(extents) extents
	,	sum(bytes)/1024/1024 extentmb
	from	dba_segments
--	where	owner = 'PSARCH'
	group by tablespace_name
	union all
	select	tablespace
	,	count(*) segments
	,	sum(extents) extents
	,	sum(blocks * x.bpb/1024/1024)
	from 	v$sort_usage
	,	(select	bytes/blocks bpb
		from	dba_temp_files
		where	rownum = 1) x
	group by tablespace
	) o
where	s.tablespace_name(+) = f.tablespace_name
and	o.tablespace_name(+) = f.tablespace_name
--and	(	f.tablespace_name like 'GP%'
--	or	f.tablespace_name like '%T%MP%')
--and	(	f.tablespace_name like 'PBD%'
--	or	f.tablespace_name like 'PAY%')
order by f.tablespace_name
/
spool off
set head on feedback on echo on termout on

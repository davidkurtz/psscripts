REM tr_moreinst.sql
REM (c) Go-Faster Consultancy 2009
REM https://blog.psftdba.com/2009/02/do-you-need-more-temporary-table.html
REM When an AE process cannot obtain a private instance of a temporary record it writes a message (108,544) to the 
REM message log.  This query reports on the records/processes which required additional instances.

set lines 80
ttitle 'Processes Unable to Allocate Non-Shared Temporary Record'
column recname     format a15 heading 'Record|Name'
column prcsname               heading 'Process|Name'
column process_instance       heading 'Last|Process|Instance'
column occurances             heading 'Occurences'
column last_occurance         heading 'Last|Occurence'

spool tr_moreinst
select 	p.message_parm recname, r.prcsname
, 	count(*) occurances
, 	max(l.dttm_stamp_sec) last_occurance
, 	max(p.process_instance) process_instance
from 	ps_message_log l
, 	ps_message_logparm p
	left outer join psprcsrqst r
	on r.prcsinstance = p.process_instance
where 	l.message_set_nbr = 108
and   	l.message_nbr = 544
and   	p.process_instance = l.process_instance
and   	p.message_seq = l.message_seq
and   	l.dttm_stamp_sec >= sysdate - 7
group by p.message_parm, r.prcsname
order by 1,2
/
spool off
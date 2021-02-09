REM gfc_locktemprecstats_triggerjob_test.sql

REM list source of trigger and procedure
break on type skip 1 on name
set pages 99 lines 180
column name format a20
column line format 999
column text format a80
select type, name, line, text
from user_source
where name like 'GFC_LOCKTEMPRECSTATS'
order by 1,2,3
/

--test locking and deleting stats on a couple of PeopleSoft HR temp record non-shared table instances
set serveroutput on timi on
exec gfc_locktemprecstats('PS_WRK_TLSCH1_AD42');
exec gfc_locktemprecstats('PS_WRK_TLSCH1_AD57');

--find temp tables without indexes
select /*+LEADING(o i v)*/ t.table_name
FROM pstemptblcntvw i
     INNER JOIN psrecdefn r
       ON r.recname = i.recname
       AND r.rectype = '7' --temp record
,    psoptions o
,    user_tables t
,    (SELECT rownum n FROM DUAL CONNECT BY level <= 100) v
WHERE  v.n <= i.temptblinstances + o.temptblinstances
AND    t.table_name = DECODE(r.sqltablename,' ','PS_'||r.recname,r.sqltablename)
                    ||DECODE(v.n*r.rectype,100,'',LTRIM(TO_NUMBER(v.n)))
and not exists (select 'x' from user_indexes i where i.table_name = t.table_name)
and r.recname =  'GPNZ_LIAB_W'
/
 
--extract DDL for one such table
set long 5000 pages 99 lines 180 serveroutput on
select dbms_metadata.get_ddl('TABLE','PS_GPNZ_LIAB_W6') from dual;

set serveroutput on timi on
drop TABLE "SYSADM"."PS_GPNZ_LIAB_W6" purge;
CREATE TABLE "SYSADM"."PS_GPNZ_LIAB_W6"
   (    "PROCESS_INSTANCE" NUMBER(10,0) NOT NULL ENABLE,
        "EMPLID" VARCHAR2(11 CHAR) NOT NULL ENABLE,
        "EMPL_RCD" NUMBER(*,0) NOT NULL ENABLE,
        "GP_PAYGROUP" VARCHAR2(10 CHAR) NOT NULL ENABLE,
        "PAY_ENTITY" VARCHAR2(10 CHAR) NOT NULL ENABLE,
        "BUSINESS_UNIT" VARCHAR2(5 CHAR) NOT NULL ENABLE,
        "PIN_CHART1_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART2_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART3_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART4_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART5_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART6_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART7_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "PIN_CHART8_VAL" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "GROUPING_CODE" VARCHAR2(15 CHAR) NOT NULL ENABLE,
        "ACCOUNT" VARCHAR2(10 CHAR) NOT NULL ENABLE,
        "PIN_NUM" NUMBER(*,0) NOT NULL ENABLE,
        "CALC_RSLT_VAL" NUMBER(18,6) NOT NULL ENABLE,
        "CAL_RUN_ID" VARCHAR2(18 CHAR) NOT NULL ENABLE
   ) SEGMENT CREATION DEFERRED
  PCTFREE 10 PCTUSED 80 INITRANS 1 MAXTRANS 255
 NOCOMPRESS LOGGING
  STORAGE( INITIAL 40960 NEXT 106496 MAXEXTENTS 2147483645
  PCTINCREASE 0)
  TABLESPACE "GPAPP"
  /
select * from user_scheduler_jobs;
--select * from user_jobs;

select * from user_scheduler_job_log order by log_date;


set serveroutput on 
--exec sysadm.gfc_locktemprecstats('SYSADM','PS_GPNZ_LIAB_W6');

set lines 180 pages 99  
select table_name, stattype_locked
from user_tab_statistics
where table_name like 'PS_GPNZ_LIAB_W%';
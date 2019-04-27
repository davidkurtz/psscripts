rem psft_ddl_lock_test.sql: Script to test PSFT_DDL_LOCK trigger
rem (c) Go-Faster Consultancy Ltd.

spool psft_ddl_lock_test

/*The following is a test script for the PSFT_DDL_LOCK trigger.  First you must create a record definition in PeopleSoft Application Designer for record DMK in PeopleSoft (you don't need to build it) and but make field A key.  The trigger also benefits from the Function based index PSZRECDEFN*/
ALTER SESSION SET TRACEFILE_IDENTIFIER = 'PSFT_DDL_LOCK';
--ALTER SESSION SET EVENTS '10046 TRACE NAME CONTEXT FOREVER, LEVEL 8';

execute psft_ddl_lock.set_ddl_permitted(FALSE);
DROP /*this should error*/ INDEX pszpsrecdefn;

/*RENAME test*/
ALTER /*this should error*/ TABLE PSRECDEFN RENAME TO WIBBLE;
RENAME /*this should error*/ PSRECDEFN TO WIBBLE;

/*Index Test*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
CREATE TABLE PS_DMK (DESCR VARCHAR2(30) NOT NULL);
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE UNIQUE INDEX PS_DMK ON PS_DMK(DESCR);
DROP INDEX PS_DMK;
CREATE UNIQUE INDEX PS1DMK ON PS_DMK(DESCR);
DROP INDEX PS1DMK;
CREATE UNIQUE INDEX WIBBLE ON PS_DMK(DESCR);
DROP /*this should error*/ INDEX WIBBLE;
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP INDEX WIBBLE;
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE UNIQUE INDEX PSZDMK ON PS_DMK(DESCR);
DROP /*this should error*/ INDEX PSZDMK;
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP INDEX PSZDMK;
execute psft_ddl_lock.set_ddl_permitted(FALSE);

/*FBI test*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
CREATE TABLE PS_DMK (DESCR VARCHAR2(30) NOT NULL);
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE INDEX PSZDMK ON PS_DMK(UPPER(DESCR));
DROP /*this should error*/ INDEX PSZDMK;
DROP /*this should error*/ TABLE PS_DMK;
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP INDEX PSZDMK;
execute psft_ddl_lock.set_ddl_permitted(FALSE);
DROP TABLE PS_DMK;

/*PK TEST*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
CREATE TABLE PS_DMK (DESCR VARCHAR2(30) NOT NULL);
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE UNIQUE INDEX PS_DMK ON PS_DMK(DESCR);
ALTER TABLE PS_DMK ADD CONSTRAINT PS_DMK PRIMARY KEY (DESCR) USING INDEX PS_DMK;
DROP /*this should ORA-02429*/ INDEX PS_DMK;
DROP /*this should error*/ TABLE PS_DMK;

/*MV LOG TEST*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
CREATE TABLE PS_DMK (DESCR VARCHAR2(30) NOT NULL);
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE MATERIALIZED VIEW LOG ON PS_DMK WITH ROWID;
DROP /*this should error*/ TABLE PS_DMK;

/*IOT LOG TEST*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE TABLE PS_DMK 
(DESCR VARCHAR2(30) NOT NULL
,CONSTRAINT PS_DMK PRIMARY KEY (DESCR)
) ORGANIZATION INDEX;
DROP /*this should error*/ TABLE PS_DMK;

/*GTT TEST*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE GLOBAL TEMPORARY TABLE PS_DMK 
(DESCR VARCHAR2(30) NOT NULL);
DROP /*this should error*/ TABLE DMK;

/*PARTITION TEST*/
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
execute psft_ddl_lock.set_ddl_permitted(FALSE);
CREATE TABLE PS_DMK (DESCR VARCHAR2(30) NOT NULL)
PARTITION BY RANGE(DESCR)
(PARTITION PS_DMK_1 VALUES LESS THAN ('X')
,PARTITION PS_DMK_2 VALUES LESS THAN (MAXVALUE)
);
CREATE INDEX PS_DMK ON PS_DMK(DESCR) LOCAL;
DROP /*this should error*/ INDEX PS_DMK;
DROP /*this should error*/ TABLE PS_DMK;

ALTER TABLE PS_DMK TRUNCATE PARTITION PS_DMK_1;

/*clear up afer test*/
ALTER SESSION SET SQL_TRACE = FALSE;
execute psft_ddl_lock.set_ddl_permitted(TRUE);
DROP TABLE PS_DMK;
execute psft_ddl_lock.set_ddl_permitted(FALSE);

spool off


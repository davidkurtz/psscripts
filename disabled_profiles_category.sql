REM disabled_profiles_category.sql
REM https://blog.go-faster.co.uk/2021/07/clashing-sql-profiles-exact-matching.html
spool disabled_profiles_category app
set serveroutput on
BEGIN
  FOR i IN (
    SELECT * FROM dba_sql_profiles
    WHERE category = 'DEFAULT'
    AND   status = 'DISABLED'
  ) LOOP
    dbms_output.put_line(i.name);
    dbms_sqltune.alter_sql_profile(name=>i.name, attribute_name=>'CATEGORY',value=>'DO_NOT_USE');
  END LOOP;
END;
/
spool off
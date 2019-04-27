rollback;
set serveroutput on buffer 1000000000 echo on verify on feedback on pause off

set termout off
spool stmtid_before
set lines 100 long 5000
SELECT * 
FROM   ps_sqlstmt_tbl
WHERE  pgm_name like 'GP%'
ORDER BY 1,2,3
;
spool off
set termout on

spool stmtid
DECLARE
   CURSOR stmt_cursor IS
   SELECT * 
   FROM   ps_sqlstmt_tbl;

   c_stmt stmt_cursor%ROWTYPE;
   l_stmt_text VARCHAR2(32767); /*for stmt text so can use text functions*/
   l_stmt_id   VARCHAR2(18);    /*PS stmt ID string*/
   l_len       INTEGER;         /*length of stmt text*/
   l_spcpos    INTEGER;         /*postition of first space*/
   l_compos    INTEGER;         /*postition of first comment*/
   l_compos2   INTEGER;         /*end of first comment*/
   l_idpos     INTEGER;         /*postition of statement id*/
BEGIN
   OPEN stmt_cursor;
   LOOP
      FETCH stmt_cursor INTO c_stmt;
      EXIT WHEN stmt_cursor%NOTFOUND;

      l_stmt_id := c_stmt.pgm_name||'_'||c_stmt.stmt_type
                                  ||'_'||c_stmt.stmt_name;
      l_stmt_text := c_stmt.stmt_text;
      l_spcpos := instr(l_stmt_text,' ');
      l_compos := instr(l_stmt_text,'/*');
      l_compos2 := instr(l_stmt_text,'*/');
      l_idpos := instr(l_stmt_text,l_stmt_id);

--    sys.dbms_output.put_line(l_stmt_id);
--    sys.dbms_output.put_line(substr(l_stmt_text,1,100));
--    sys.dbms_output.put_line('Space at '||l_spcpos);
--    sys.dbms_output.put_line('Comment at '||l_compos);
--    sys.dbms_output.put_line('Comment End at '||l_compos2);
--    sys.dbms_output.put_line('ID at '||l_idpos);

      IF (l_idpos = 0 AND l_spcpos > 0 AND LENGTH(l_stmt_text)<=32000) THEN 
         /*no id comment in string and its not too long so add one*/
         IF (l_compos = 0) THEN /*no comment exists*/
            l_stmt_text := SUBSTR(l_stmt_text,1,l_spcpos) ||'/*'||
                           l_stmt_id||'*/'||SUBSTR(l_stmt_text,l_spcpos);
         ELSE /*insert into existing comment*/
            l_stmt_text := SUBSTR(l_stmt_text,1,l_compos2-1)||
                           ' '||l_stmt_id||SUBSTR(l_stmt_text,l_compos2);
         END IF;

         UPDATE ps_sqlstmt_tbl
         SET    stmt_text = l_stmt_text
         WHERE  pgm_name  = c_stmt.pgm_name
         AND    stmt_type = c_stmt.stmt_type
         AND    stmt_name = c_stmt.stmt_name;

--       sys.dbms_output.put_line(substr(l_stmt_text,1,100));
      END IF;

   END LOOP;
   CLOSE stmt_cursor;
END;
/


show errors
spool off

set termout off
spool stmtid_after
set lines 100 long 5000
SELECT * 
FROM   ps_sqlstmt_tbl
WHERE  pgm_name like 'GP%'
ORDER BY 1,2,3
;
set termout on


spool off
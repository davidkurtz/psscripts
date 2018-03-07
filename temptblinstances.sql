REM temptblinstances.sql
REM (c)David Kurtz, Go-Faster Consultancy Ltd. 2009

ttitle 'Missing Instances of Temporary Tables'
SELECT r.recname
,      n.n instance
,      c.temptblinstances
      +o.temptblinstances temptblinstances
FROM   pstemptblcntvw c
,      psrecdefn r
,      (SELECT rownum-1 n FROM psrecdefn
        WHERE rownum <= 100) n
,      psoptions o
WHERE  r.recname = c.recname
AND    n.n <= c.temptblinstances+o.temptblinstances
AND NOT EXISTS(
       SELECT 'x'
       FROM   user_tables t
       WHERE  t.table_name = 
            DECODE(r.sqltablename, ' ', 'PS_'||r.recname,
                   r.sqltablename) ||DECODE(n.n,0,'',n.n)
        )
ORDER BY 1,2
/

ttitle 'Excess Instances of Temporary Tables'
SELECT r.recname
,      n.n instance
,      c.temptblinstances
      +o.temptblinstances temptblinstances
,      t.table_name
FROM   pstemptblcntvw c
,      psrecdefn r
,      (SELECT rownum-1 n FROM psrecfield
        WHERE rownum <= 100) n
,      user_tables t
,      psoptions o
WHERE  r.recname = c.recname
AND    t.table_name = 
          DECODE(r.sqltablename, ' ', 'PS_'||r.recname,
                 r.sqltablename) ||DECODE(n.n,0,'',n.n)
AND    n.n > c.temptblinstances+o.temptblinstances
ORDER BY 1,2
/

ttitle off

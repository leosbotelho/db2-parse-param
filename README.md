Whipped this up to:
 - parse db2 stored procedure params 
 - explore a tighter binding between pl and db types
 - avoid [this](https://metacpan.org/release/ROCKETDB/DBD-DB2-1.89/source/dbdimp.c#L2281) `SQLDescribeParam` when using `SQL_PARAM_OUTPUT` or any other attribute

<br>

eg:
```
parseDb2Param('Proc', '
  @Dtm  timestamp(3),
  @Num  float,

  out
  @Id   bigint
', {})
```

![image](https://user-images.githubusercontent.com/108152057/176324380-388b9e73-6e6d-4d49-9b8b-1109b982955c.png)


Ps. bytes as in str bytes; doesn't go beyond dbd::db2 default `ctype = SQL_C_CHAR`

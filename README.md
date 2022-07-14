Whipped this up to:
 - parse db2 stored procedure params 
 - explore a tighter binding between pl and db types

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


Ps. bytes as in str bytes (since that's what's used internally by dbd::db2)

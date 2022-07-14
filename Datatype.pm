package Datatype;

# Db2 11.5 for *nix

use strict;
use Exporter qw(import);

our @EXPORT = qw(
  Db2Datatype
  $Db2DatatypeColumnSize
);

use constant Db2Datatype => {'integer' => 4,'float' => 6,'graphic' => -95,'char' => 1,'varbinary' => -3,'real' => 7,'date' => 91,'timestamp' => 93,'binary' => -2,'vargraphic' => -96,'time' => 92,'numeric' => 2,'blob' => -98,'clob' => -99,'decimal' => 3,'smallint' => 5,'double' => 8,'varchar' => 12,'dbclob' => -350,'bigint' => -5,'decfloat' => -360,'xml' => -370,'boolean' => 16};


our $Db2DatatypeColumnSize = {'blob' => 2147483647,'float' => 53,'char' => 255,'time' => 8,'date' => 10,'decimal' => 31,'real' => 24,'vargraphic' => 16336,'boolean' => 1,'double' => 53,'varbinary' => 32672,'smallint' => 5,'bigint' => 19,'dbclob' => 1073741823,'varchar' => 32672,'binary' => 255,'graphic' => 127,'xml' => 0,'integer' => 10,'timestamp' => 32,'decfloat' => 34,'numeric' => 31,'clob' => 2147483647};

# p. 2107 of 'IBM Db2 V11.5: SQL Reference'
$Db2DatatypeColumnSize->{xml} = 31_457_280;

1;

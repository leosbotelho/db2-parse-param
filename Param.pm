package Param;

use strict;
use Exporter qw(import);
use Arr qw(safeExists strIn);
use POSIX qw(ceil);

use Datatype;

our @EXPORT = qw(parseDb2Param);

# ref 'IBM Db2 V11.5: SQL Reference'
#  pp. 28, 118, 977, 2072, 2105
#
# stackoverflow:1701055/what-is-the-maximum-length-in-chars-needed-to-represent-any-double-value
#  (to better understand p. 118)

my $Db2ParamRe = qr/
  \s* (?<out>out \s+)?

  \@(?<name>\$?[a-z_][a-z_0-9]*) \s+

  (?<dt>.+?) \s* (
    \(
      \s* (?<dt_a>[0-9]+) \s* (?<dt_a_u>k|m|g)? \s* (?<dt_a_str_u>octets|codeunits16|codeunits32)? \s*
      (, \s* (?<dt_b>[0-9]+) )? \s*
    \)
      \s* (?<dt_bit>for \s* bit \s* data)? \s*
  )?
/xi;

# p. 28
#
my @Db2StrDatatype = qw(char varchar clob);
my @Db2GraphicDatatype = qw(graphic vargraphic dbclob);
my @Db2BinaryDatatype = qw(binary varbinary blob);

sub parseDb2Param {
  my ($name, $s, $arg) = @_;

  my $ParamName = [];
  my $ParamIn = {};
  my $ParamOut = {};
  {
    my $pos = 1;
    while ($s =~ /\G$Db2ParamRe(,|$)/gc) {
      my $paramName = $+{name};
      my %a = ();
      if (safeExists $arg, 'param', $paramName) {
        $a{default} = $arg->{param}{$paramName};
      }

      my $dtName = $+{dt};

      $dtName = 'integer' if $dtName eq 'int';

      my $has_dt_a = exists $+{dt_a};
      my $has_dt_b = exists $+{dt_b};

      my $dt_a = $+{dt_a} // 0;
      my $dt_b = $+{dt_b} // 0;

      my $str_u = lc ($+{dt_a_str_u} // '');

      my $isStrDt = strIn $dtName, @Db2StrDatatype;
      my $isGraphicDt = strIn $dtName, @Db2GraphicDatatype;
      my $isBinaryDt = strIn $dtName, @Db2BinaryDatatype;

      my $dt_a_u = lc ($+{dt_a_u} // '');

      my $die = sub { die "$_[0] at $name \@$paramName\n" };

      # assert
      {
        $die->('unknown datatype') if !exists Db2Datatype->{$dtName};

        $die->('unkown datatype column size') if !exists $Db2DatatypeColumnSize->{$dtName};

        $die->('invalid datatype param') if $has_dt_a and (strIn $dtName, qw(
          smallint integer bigint
          real
          date time
          xml
          boolean
        ));

        $die->('invalid scale') if $has_dt_b and !(strIn $dtName, qw(
          decimal numeric
        ));

        # for bit data
        $die->(q(invalid 'for bit data')) if exists $+{dt_bit} and
          !(strIn $dtName, qw(char varchar));

        # k, m, g
        $die->('invalid datatype param unit') if exists $+{dt_a_u} and
          !(strIn $dtName, qw(blob clob dbclob));

        # str unit
        {
          $die->('invalid str code units')
            if $isStrDt and $str_u eq 'codeunits16';

          $die->('invalid str code units')
            if $isGraphicDt and $str_u eq 'octets';

          $die->('invalid str code units')
            if !($isStrDt or $isGraphicDt) and $str_u;
        }

        if ($dtName eq 'decimal') {
          $die->('forbidden decimal precision')
            if ($has_dt_a and !($dt_a >= 1 and $dt_a <= 31));

          $die->('forbidden decimal scale')
            if ($has_dt_b and !($dt_b >= 0 and $dt_b <= $dt_a));
        }

        $die->('forbidden float precision')
          if $dtName eq 'float'
            and ($has_dt_a and !($dt_a >= 1 and $dt_a <= 53));

        $die->('forbidden double precision')
          if $dtName eq 'double'
            and ($has_dt_a and !($dt_a >= 25 and $dt_a <= 53));

        $die->('forbidden decfloat precision')
          if $dtName eq 'decfloat'
            and ($has_dt_a and !($dt_a == 34 or $dt_a == 16));

        $die->('forbidden timestamp scale')
          if $dtName eq 'timestamp'
            and ($has_dt_a and !($dt_a >= 0 and $dt_a <= 12));
      }

      my $columnSize = $Db2DatatypeColumnSize->{$dtName};

      my %datatype = (
        name => $dtName,
        code => Db2Datatype->{$dtName},
        scale => 0
      );
      '
        Scale if the global variable data type is
        DECIMAL or distinct type based on
        DECIMAL; the number of digits of
        fractional seconds if the global variable
        data type is TIMESTAMP or distinct type
        based on TIMESTAMP; 0 otherwise.

        p. 2072
      ';

      if (strIn $dtName, qw(smallint integer bigint)) {
        $datatype{prec} = $columnSize;
        $datatype{bytes} = $columnSize + 1;

      } elsif (strIn $dtName, qw(decimal numeric)) {
        my $p = $has_dt_a ? $dt_a : 5;

        $datatype{prec} = $p;
        $datatype{scale} = $has_dt_b ? $dt_b : 0;
        $datatype{bytes} = $p + 2;

      } elsif (strIn $dtName, qw(float real double)) {
        my $p = $has_dt_a         ? $dt_a :
                $dtName eq 'real' ? 24    :
                                    53    ;
        $datatype{prec} = $p;
        $datatype{bytes} = 24;

      } elsif ($dtName eq 'decfloat') {
        $datatype{prec} = $has_dt_a ? $dt_a : 34;
        $datatype{bytes} = 42;

      } elsif ($isStrDt or $isGraphicDt or $isBinaryDt) {
        my $p;
        if ($has_dt_a) {
          $p = $dt_a;
        } elsif (strIn $dtName, qw(char graphic binary)) {
          $p = 1;
        } elsif (strIn $dtName, qw(clob dbclob blob)) {
          $p = 1024 * 1024;
        } else {
          $die->('missing length');
        }

        $p *= 1024 ** (
          $dt_a_u eq 'k' ? 1 :
          $dt_a_u eq 'm' ? 2 :
          $dt_a_u eq 'g' ? 3 :
                           0
        );

        $die->('forbidden length') if $p > $columnSize;

        my $bytes = $p;
        $bytes *= 2 if $isGraphicDt;

        $p = ceil ($p / 2)
          if $str_u eq 'codeunits32' and $isGraphicDt;

        $p = ceil ($p / 4)
          if $str_u eq 'codeunits32' and $isStrDt;

        $datatype{prec} = $p;
        $datatype{bytes} = $bytes;

      } elsif ($dtName eq 'time') {
        $datatype{bytes} =
         $datatype{prec} = 8;

      } elsif ($dtName eq 'date') {
        $datatype{bytes} =
         $datatype{prec} = 10;

      } elsif ($dtName eq 'timestamp') {
        my $scale = $has_dt_a ? $dt_a : 6;
        my $bytes = $columnSize - (12 - $scale) - ($scale == 0);

        $datatype{bytes} =
         $datatype{prec} = $bytes;

        $datatype{scale} = $scale;

      } elsif ($dtName eq 'boolean') {
        $datatype{bytes} =
         $datatype{prec} = 1;
      }

      # $datatype{bytes} += 1;
      #  the driver already does this

      ${$+{out} ? $ParamOut : $ParamIn}{$paramName} = {
        pos => $pos,
        datatype => \%datatype,
        %a
      };

      push @$ParamName, $paramName;
      $pos++;
    }
  }

  return {
    name => $ParamName,
    in => $ParamIn,
    out => $ParamOut
  };
}

1;

require "util" ;

$Inc = $Inc ; # keep -w happy
$Perl = $Perl ;

$script = <<'EOF' ;

use Filter::exec qw'tr [A-E][I-M] [a-e][i-m]' ;
use Filter::exec qw'tr [N-Z] [n-z]' ;


$A = 2 ;
PRINT "A = $A\N" ;

PRINT "HELLO JOE\N" ;
PRINT <<EOM ;
MARY HAD 
A
LITTLE
LAMB
EOM
PRINT "A (AGAIN) = $A\N" ;
EOF

$filename = 'sh.test' ;
writeFile($filename, $script) ;

$expected_output = <<'EOM' ;
a = 2
Hello joe
mary Had 
a
little
lamb
a (aGain) = 2
EOM

$a = `$Perl $Inc $filename 2>&1` ;
 
print "1..2\n" ;
ok(1, ($? >> 8) == 0) ;
ok(2, $a eq $expected_output) ;


unlink $filename ;

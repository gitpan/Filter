
require "util" ;
use Cwd ;
$here = getcwd ;

$Inc = $Inc ; # keep -w happy
$Perl = $Perl ;


$filename = "call.tst" ;
$module   = "MyTest" ;
$module2  = "MyTest2" ;
$module3  = "MyTest3" ;
$module4  = "MyTest4" ;
$module5  = "MyTest5" ;
$nested   = "nested" ;
$block   = "block" ;

print "1..20\n" ;

# Test error cases
##################

# no filter function in module 
###############################

writeFile("${module}.pm", <<EOM) ;
package ${module} ;

use Filter::Util::Call ;
 
sub import { filter_add(bless []) }

1 ;
EOM
 
$a = `$Perl -I. $Inc -e "use ${module} ;"  2>&1` ;
ok(1, ($? >>8) != 0) ;
ok(2, $a =~ /^Can't locate object method "filter" via package "MyTest"/) ;
 
# no reference parameter in filter_add
######################################

writeFile("${module}.pm", <<EOM) ;
package ${module} ;
 
use Filter::Util::Call ;
 
sub import { filter_add() }
 
1 ;
EOM
 
$a = `$Perl -I. $Inc -e "use ${module} ;"  2>&1` ;
ok(3, ($? >>8) != 0) ;
#ok(4, $a =~ /^usage: filter_add\(ref\) at ${module}.pm/) ;
ok(4, $a =~ /^Not enough arguments for Filter::Util::Call::filter_add/) ;
 



# non-error cases
#################


# a simple filter
#################

writeFile("${module}.pm", <<EOM, <<'EOM') ;
package ${module} ;
 
EOM
use Filter::Util::Call ;
sub import { filter_add(bless []) }

sub filter 
{ 
    my ($self) = @_ ;
    my ($status) ;

    if (($status = filter_read()) > 0) {
	s/ABC/DEF/g
    }
    $status ;
}

1 ;
EOM
 
writeFile($filename, <<EOM, <<'EOM') ;

use $module ;
EOM

use Cwd ;
$here = getcwd ;
print "I am $here\n" ;
print "some letters ABC\n" ;
$y = "ABCDEF" ;
print <<EOF ;
Alphabetti Spagetti ($y)
EOF

EOM

$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(5, ($? >>8) == 0) ;
ok(6, $a eq <<EOM) ;
I am $here
some letters DEF
Alphabetti Spagetti (DEFDEF)
EOM


# nested filters
################


writeFile("${module2}.pm", <<EOM, <<'EOM') ;
package ${module2} ;
use Filter::Util::Call ;
 
EOM
sub import { filter_add(bless []) }
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
 
    if (($status = filter_read()) > 0) {
        s/XYZ/PQR/g
    }
    $status ;
}
 
1 ;
EOM
 
writeFile("${module3}.pm", <<EOM, <<'EOM') ;
package ${module3} ;
use Filter::Util::Call ;
 
EOM
sub import { filter_add(bless []) }
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
 
    if (($status = filter_read()) > 0) {
        s/Fred/Joe/g
    }
    $status ;
}
 
1 ;
EOM
 
writeFile("${module4}.pm", <<EOM) ;
package ${module4} ;
 
use $module5 ;

print "I'm feeling used!\n" ;
print "Fred Joe ABC DEF PQR XYZ\n" ;
print "See you Today\n" ;
1;
EOM

writeFile("${module5}.pm", <<EOM, <<'EOM') ;
package ${module5} ;
use Filter::Util::Call ;
 
EOM
sub import { filter_add(bless []) }
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
 
    if (($status = filter_read()) > 0) {
        s/Today/Tomorrow/g
    }
    $status ;
}
 
1 ;
EOM

writeFile($filename, <<EOM, <<'EOM') ;
 
# two filters for this file
use $module ;
use $module2 ;
require "$nested" ;
use $module4 ;
EOM
 
print "some letters ABCXYZ\n" ;
$y = "ABCDEFXYZ" ;
print <<EOF ;
Fred likes Alphabetti Spagetti ($y)
EOF
 
EOM
 
writeFile($nested, <<EOM, <<'EOM') ;
use $module3 ;
EOM
 
print "This is another file XYZ\n" ;
print <<EOF ;
Where is Fred?
EOF
 
EOM

$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(7, ($? >>8) == 0) ;
ok(8, $a eq <<EOM) ;
I'm feeling used!
Fred Joe ABC DEF PQR XYZ
See you Tomorrow
This is another file XYZ
Where is Joe?
some letters DEFPQR
Fred likes Alphabetti Spagetti (DEFDEFPQR)
EOM



# using the module context 
##########################


writeFile("${module2}.pm", <<EOM, <<'EOM') ;
package ${module2} ;
use Filter::Util::Call ;
 
EOM
sub import 
{ 
    my ($type) = shift ;
    my (@strings) = @_ ;

  
    filter_add (bless [@strings]) 
}
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
    my ($pattern) ;
 
    if (($status = filter_read()) > 0) {
	foreach $pattern (@$self)
          { s/$pattern/PQR/g }
    }

    $status ;
}
 
1 ;
EOM
 
 
writeFile($filename, <<EOM, <<'EOM') ;
 
use $module2 qw( XYZ KLM) ;
use $module2 qw( ABC NMO) ;
EOM
 
print "some letters ABCXYZ KLM NMO\n" ;
$y = "ABCDEFXYZKLMNMO" ;
print <<EOF ;
Alphabetti Spagetti ($y)
EOF
 
EOM
 
$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(9, ($? >>8) == 0) ;
ok(10, $a eq <<EOM) ;
some letters PQRPQR PQR PQR
Alphabetti Spagetti (PQRDEFPQRPQRPQR)
EOM

# multi line test
#################


writeFile("${module2}.pm", <<EOM, <<'EOM') ;
package ${module2} ;
use Filter::Util::Call ;
 
EOM
sub import
{ 
    my ($type) = shift ;
    my (@strings) = @_ ;

  
    filter_add(bless []) 
}
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
 
    # read first line
    if (($status = filter_read()) > 0) {
	chop ;
	# and now the second line (it will append)
        $status = filter_read() ;
    }

    $status ;
}
 
1 ;
EOM
 
 
writeFile($filename, <<EOM, <<'EOM') ;
 
use $module2  ;
EOM
print "don't cut me 
in half\n" ;
print  
<<EOF ;
appen
ded
EO
F
 
EOM
 
$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(11, ($? >>8) == 0) ;
ok(12, $a eq <<EOM) ;
don't cut me in half
appended
EOM

# Block test
#############

writeFile("${block}.pm", <<EOM, <<'EOM') ;
package ${block} ;
use Filter::Util::Call ;
 
EOM
sub import
{ 
    my ($type) = shift ;
    my (@strings) = @_ ;

  
    filter_add (bless [@strings] )
}
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
    my ($pattern) ;
 
    filter_read(20)  ;
}
 
1 ;
EOM

$string = <<'EOM' ;
print "hello mum\n" ;
$x = 'me ' x 3 ;
print "Who wants it?\n$x\n" ;
EOM


writeFile($filename, <<EOM, $string ) ;
use $block ;
EOM
 
$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(13, ($? >>8) == 0) ;
ok(14, $a eq <<EOM) ;
hello mum
Who wants it?
me me me 
EOM

# use in the filter
####################

writeFile("${block}.pm", <<EOM, <<'EOM') ;
package ${block} ;
use Filter::Util::Call ;
 
EOM
use Cwd ;

sub import
{ 
    my ($type) = shift ;
    my (@strings) = @_ ;

  
    filter_add(bless [@strings] )
}
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
    my ($here) = getcwd ;
 
    if (($status = filter_read()) > 0) {
        s/DIR/$here/g
    }
    $status ;
}
 
1 ;
EOM

writeFile($filename, <<EOM, <<'EOM') ;
use $block ;
EOM
print "We are in DIR\n" ;
EOM
 
$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(15, ($? >>8) == 0) ;
ok(16, $a eq <<EOM) ;
We are in $here
EOM


# filter_del
#############
 
writeFile("${block}.pm", <<EOM, <<'EOM') ;
package ${block} ;
use Filter::Util::Call ;
 
EOM
 
sub import
{
    my ($type) = shift ;
    my ($count) = @_ ;
 
 
    filter_add(bless \$count )
}
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
 
    s/HERE/THERE/g
        if ($status = filter_read()) > 0 ;

    -- $$self ;
    filter_del() if $$self <= 0 ;

    $status ;
}
 
1 ;
EOM
 
writeFile($filename, <<EOM, <<'EOM') ;
use $block (3) ;
EOM
print "
HERE I am
I am HERE
HERE today gone tomorrow\n" ;
EOM
 
$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(17, ($? >>8) == 0) ;
ok(18, $a eq <<EOM) ;

THERE I am
I am THERE
HERE today gone tomorrow
EOM


# filter_read_exact
####################
 
writeFile("${block}.pm", <<EOM, <<'EOM') ;
package ${block} ;
use Filter::Util::Call ;
 
EOM
 
sub import
{
    my ($type) = shift ;
 
    filter_add(bless [] )
}
 
sub filter
{
    my ($self) = @_ ;
    my ($status) ;
 
    if (($status = filter_read_exact(6)) > 0) {
        s/HERE/THERE/g
    }
 
    $status ;
}
 
1 ;
EOM
 
writeFile($filename, <<EOM, <<'EOM') ;
use $block ;
EOM
print "
HERE I am
I am HERE
HERE today gone tomorrow\n" ;
EOM
 
$a = `$Perl -I. $Inc $filename  2>&1` ;
ok(19, ($? >>8) == 0) ;
ok(20, $a eq <<EOM) ;

THERE I am
I am HERE
HERE today gone tomorrow
EOM


unlink $filename ;
unlink "${module}.pm" ;
unlink "${module2}.pm" ;
unlink "${module3}.pm" ;
unlink "${module4}.pm" ;
unlink "${module5}.pm" ;
unlink $nested ;
unlink "${block}.pm" ;
exit ;

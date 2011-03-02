#!/site/perl/perl-5.10.1-1/bin/perl -w
use strict;
use warnings;

use lib '../../../../lib';

use Test::More plan = 1;
use Data::Dumper;


use Next::OpenSIPS::AbridgeData qw( abridge_recursive abridge_item );

my $foo = [];
push @$foo, $foo;

print Dumper  abridge_recursive( $foo );

is_deeply( abridge_recursive( $foo ), [ 'base' ], );

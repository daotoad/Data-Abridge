#!/site/perl/perl-5.10.1-1/bin/perl -w
use strict;
use warnings;

use Test::More tests => 2;

my @EXPORTABLE = qw(  abridge_item abridge_recursive abridge_items abridge_items_recursive );

use_ok( 'Next::OpenSIPS::AbridgeData', @EXPORTABLE );

can_ok( __PACKAGE__, @EXPORTABLE );



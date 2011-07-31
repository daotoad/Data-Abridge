#!/site/perl/perl-5.10.1-1/bin/perl -w
use strict;
use warnings;

use Test::More;
#use Data::Dumper;

plan tests => (count_object_tests() + count_base_data_type_tests()) + 3;

use Data::Abridge qw( abridge_recursive abridge_item abridge_items );
use constant { ARG => 1, EXPECT => 2, TYPE => 0, REFEXPECT => 3, OBJECT => 4, OBJEXPECT => 4 };

# Dummy sub to reference
sub foo { 'foo' }

my @objects;
{   diag( 'Base data types' );

    no warnings 'once';

    my @TYPE_TESTS;
    BEGIN {
        my $dummy = 57;
        @TYPE_TESTS = (
            [ NONREF => 'Nonref',   'Nonref',                  {SCALAR=>'Nonref'}, ],
            [ ARRAY  => [],         [],                        {SCALAR => []},        ],
            [ HASH   => {},         {},                        {SCALAR => {}},        ],
            [ SCALAR => \$dummy,    {SCALAR=>$dummy},          {SCALAR => \$dummy},   ],
            [ GLOB   => \*Foo,      {GLOB=>'\\*main::Foo'},     {SCALAR => \*Foo},     ],
            [ CODE   => \&foo,      {CODE =>'\\&main::foo'},    {SCALAR => \&foo},     ],
        );
    }

    sub count_base_data_type_tests {  2 * @TYPE_TESTS };
    sub count_object_tests {  0 + grep ref $_->[ARG], @TYPE_TESTS };

    for my $t ( @TYPE_TESTS ) {
        is_deeply( abridge_item($t->[ARG]), $t->[EXPECT], "$t->[TYPE] correct" );
        #print Dumper abridge_item($t->[ARG]);

        is_deeply( abridge_item(\$t->[ARG]), $t->[REFEXPECT], "REF $t->[TYPE] correct" );
        #print Dumper abridge_item(\$t->[ARG]);

        push @objects, [ @$t, bless $t->[ARG], 'SomeClass' ] if ref $t->[ARG];
    }
}

diag( 'Blessed types' );
for my $o (@objects) {
    is_deeply( abridge_item($o->[OBJECT]), { 'SomeClass'=> $o->[EXPECT] }, "BLESSED $o->[TYPE] correct" );
    #print Dumper abridge_item(\$o->[OBJECT]);
}

{
    my $sup = qr/foo/;
    my $abr = abridge_items($sup);

    is_deeply( $abr, [{ 'Regexp', "(?-xism:foo)" }] );
}

{
    my $string = StringyObect->new('A String');
    my $abr = abridge_items($string);

    is_deeply( $abr, [ 'A String' ] );
}

{
    my $code = \&abridge_item;
    bless $code, 'CodeObj';
    my $abr = abridge_items($code);

    is_deeply( $abr, [ { CodeObj => { CODE => '\&Data::Abridge::abridge_item'  } } ] );
}

BEGIN {
    package StringyObect;
    use overload '""' => 'as_string';

    sub new { shift; my $self = shift; bless \$self; }
    sub as_string { my $self = shift;  "$$self"; }
}

#!/site/perl/perl-5.10.1-1/bin/perl -w
use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;


use Data::Abridge qw( abridge_recursive abridge_item );

my $foo = ['Foo'];
is_deeply( abridge_recursive( ['Foo'] ), [ 'Foo' ], );
push @$foo,  $foo;
is_deeply( abridge_recursive( $foo ), [ Foo => {SEEN=>[]} ], );

my $bar = { Bar => 12 };
is_deeply( abridge_recursive( $bar ), { Bar => 12 }, );
$bar->{ barian }  = $bar;
is_deeply( abridge_recursive( $bar ), { Bar => 12, barian => {SEEN=>[]} }, );

$bar->{foo} = $foo;


push @$foo, $bar;
is_deeply( abridge_recursive( $foo ), 
    [ 'Foo', {SEEN=>[]}, {Bar=>12, barian=>{SEEN=>[2]}, foo => {SEEN=>[]}} ], 
);
is_deeply( abridge_recursive( $bar ), 
    {Bar=>12, barian=>{SEEN=>[]}, foo => [ Foo => {SEEN=>['foo']}, {SEEN=>[]}, ] }
);



my @node = map { bless( {next_node => undef}, 'MyNode') } 0..1 ;
$node[0]->{next_node} = $node[1];
$node[1]->{next_node} = $node[0];
is_deeply( abridge_recursive( \@node ), 
[ { MyNode => {
      next_node => {
        MyNode => {
          next_node => {
            SEEN => [0]
          },
        },
      },
    },
  },
  { SEEN => [ 0, MyNode => 'next_node' ] }
]
); 
print Dumper abridge_recursive( \@node );

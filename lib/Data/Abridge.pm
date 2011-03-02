package Next::OpenSIPS::AbridgeData;

use strict;
use warnings;

use Exporter qw( import );
use Scalar::Util qw( blessed reftype );

use Carp;

our @EXPORT_OK = qw(
    abridge_item      abridge_items
    abridge_recursive abridge_items_recursive
);


# Munge a thing for nice serialization

# Object     -> { PACKAGE => 'Package::Name',  OBJECT => <unblessed copy> };
# Code Ref   -> '\&subname'
#            -> '\&__ANON__'
# Scalar Ref -> { SCALAR => $scalar }
# Glob Ref   -> '\*main:glob'

my %SLOB_DISPATCH = (
    SCALAR  => \&_process_scalar,
    REF     => \&_process_ref,
    HASH    => \&_passthrough,
    ARRAY   => \&_passthrough,
    GLOB    => \&_process_glob,
    CODE    => \&_process_code,
    BLESSED => \&_process_object,
);

my %COPY_DISPATCH = (
    SCALAR  => \&_process_scalar,
    REF     => \&_process_ref,
    HASH    => \&_process_hash,
    ARRAY   => \&_process_array,
    GLOB    => \&_process_glob,
    CODE    => \&_process_code,
);

my %RECURSE_DISPATCH = (
    REF     => \&_recurse_ref,
    HASH    => \&_recurse_hash,
    ARRAY   => \&_recurse_array,
    BLESSED => \&_recurse_object,
);

sub _passthrough    { return $_ }
sub _process_ref    { return { SCALAR => $$_ } }
sub _process_glob   { return { GLOB => '\\'.*$_ } }
sub _process_scalar { return { SCALAR => $$_} }
sub _process_hash   { return {%$_} }
sub _process_array  { return [@$_] }

sub _process_object {
    my $obj = $_;

    my $class = blessed $obj;
    return unless defined $class;

    if( overload::Method($obj, '""') ) {
        # overloads String ?
        return "$obj";
    }
    else {
        # Shallow Copy
        my $type = reftype $obj;

        my $value = exists $COPY_DISPATCH{$type}
                  ? $COPY_DISPATCH{$type}->()
                  : _unsupported_type( $obj );

        return { $class => $value };
    }
}

sub _process_code {
    require B;
    my $cv = B::svref_2object($_);
    $cv->isa('B::CV') or return;

    # bail out if GV is undefined
    $cv->GV->isa('B::SPECIAL') and return;

    my $subname =  join "::", $cv->GV->STASH->NAME, $cv->GV->NAME;
    return {CODE => "\\&$subname"};
}

sub _unsupported_type {
    my $item = shift;
    my $type = reftype $item;

    return "Unsupported type: '$type' for $item";
}

sub abridge_items {
    return map abridge_item($_), @_;
}

sub abridge_item {
    my $item = shift;

    my $type = reftype $item;

    return $item unless $type;

    $type = 'BLESSED' if blessed $item;

    return "Unsupported type: '$type' for $item"
        unless exists $SLOB_DISPATCH{$type};

    return  $SLOB_DISPATCH{$type}->() for $item;
}


sub _recurse_ref {
    my $processed_ref = shift;

    my $val = $processed_ref->{SCALAR};

    $processed_ref->{SCALAR} = abridge_recursive($val);

    return $processed_ref;
}

sub _recurse_array {
    my $processed_array = shift;

    my @result = abridge_items_recursive( @$processed_array );

    return \@result;
}

sub _recurse_hash {
    my $processed_hash = shift;

    my %new_hash;
    @new_hash{ keys %$processed_hash }
        = abridge_items_recursive( values %$processed_hash );

    return $processed_hash;
}

sub _recurse_object {
    my $processed_object = shift;

    my ( $key, $value ) = each %$processed_object;
    my $type = reftype $value // '';

    $value = $RECURSE_DISPATCH{$type}->( $value )
        if exists $RECURSE_DISPATCH{$type};

    $processed_object->{$key} = $value;

    return $processed_object;
}


sub abridge_recursive {
    my $item = shift;

    my $type = reftype $item // '';
    $type = 'BLESSED' if blessed $item;

    my $repl = abridge_item($item);

    $repl = $RECURSE_DISPATCH{$type}->($repl)
        if exists $RECURSE_DISPATCH{$type};

    return $repl;
}

sub abridge_items_recursive { 
    return map abridge_recursive($_), @_; 
}

1;

__END__

=head1 NAME

Next::OpenSIPS::AbridgeData

=head1 SYNOPSIS

Webster's 1913 edition defines abridge as follows:

  A*bridge" (#), v. t.
  1. To make shorter; to shorten in duration; to lessen; to diminish; to
  curtail; as, to abridge labor; to abridge power or rights. The bridegroom
  . . . abridged his visit." Smollett.

  She retired herself to Sebaste, and abridged her train from state to
  necessity. Fuller.

  2. To shorten or contract by using fewer words, yet retaining the sense;
  to epitomize; to condense; as, to abridge a history or dictionary.

  3. To deprive; to cut off; -- followed by of, and formerly by from; as,
  to abridge one of his rights.

This module exists to simplify the process of serializing data to formats, such as
JSON, which do not support the full richness of perl datatypes.

An abridged data structure will feature only scalars, hashes and arrays.


=head1 EXPORTED SYMBOLS

Nothing is exported by default.

The three subroutines in the public API are available for export by request.


=head1 SUBROUTINES

=head2 abridge_item

Abridges the top level of an item.  Deep structures are B<not> modified below
the top structure.  For complete conversion, use C<abridge_recursive>.

Scalars that aren't references, array references and hash references are
unchanged:

    Input         Output
    ------------------------------------------
    'A string'    'A string'
    57            57
    {a=>1, b=>2}  {a=>1, b=>2}
    [1,2,3]       [1,2,3]

Code references are converted to a hash ref that indicates the fully
qualified name of the subroutine pointed to.  Anonymous subroutines are
marked as C<__ANON__>.

    Input         Output
    ------------------------------------------
    \&foo         {CODE => '\&main::foo'}
    sub {0}       {CODE => '\&main::__ANON__'}

Typeglob references are converted to a hash ref that contains the name
of the glob.

    Input         Output
    ------------------------------------------
    \*main::foo   {GLOB => '\*main::foo'}

Scalar references are converted to a hash ref that contains the scalar.

    Input         Output
    ------------------------------------------
    \$foo         {SCALAR => $foo}

Objects are converted to a hash ref that contains the name of the
class and an unblessed copy of the object's underlying data type.

    Input                 Output
    ------------------------------------------
    bless {a=>'b'}, 'Foo' { Foo => {a=>'b'} }
    bless [1,2,3], 'Foo'  { Foo => [1,2,3]  }

=head2 abridge_items

Operates as abridge item, but applied to a list.

Takes a list of arguments, applies C<abridge_item> to each, and then returns
a list of the results.

=head2 abridge_recursive

Operates on a single data structure as per C<abridge_item>, but in a top-down recursive mode.

The data structure returned will consist of only abridged data.

=head2 abridge_items_recursive

Operates as C<abridge_recursive>, but applied to a list.

Takes a list of arguments, applies C<abridge_recursive> to each, and then returns
a list of the results.



=cut

package Graph::QL::Schema;
# ABSTRACT: GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';
use decorators ':accessors', ':constructor';

use Ref::Util ();

use Graph::QL::Util::Errors 'throw';

our $VERSION = '0.01';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    types             => sub { +[] },
    query_type        => sub { die 'You must supply a `query_type`' },
    mutation_type     => sub {},
    subscription_type => sub {},
    directives        => sub { +[] },
);

sub BUILDARGS : strict(
    types?             => types,
    query_type         => query_type,
    mutation_type?     => mutation_type,
    subscription_type? => subscription_type,
    directives?        => directives,
);

sub BUILD ($self, $params) {

    throw('The `query_type` value must be an instance of `Graph::QL::Schema::Type::Object`, not '.$self->{query_type})
        unless Ref::Util::is_blessed_ref( $self->{query_type} )
            && $self->{query_type}->isa('Graph::QL::Schema::Type::Object');

    if ( exists $params->{mutation_type} ) {
        throw('The `mutation_type` value must be an instance of `Graph::QL::Schema::Type::Object`, not '.$self->{mutation_type})
            unless Ref::Util::is_blessed_ref( $self->{mutation_type} )
                && $self->{mutation_type}->isa('Graph::QL::Schema::Type::Object');
    }

    if ( exists $params->{subscription_type} ) {
        throw('The `subscription_type` value must be an instance of `Graph::QL::Schema::Type::Object`, not '.$self->{subscription_type})
            unless Ref::Util::is_blessed_ref( $self->{subscription_type} )
                && $self->{subscription_type}->isa('Graph::QL::Schema::Type::Object');
    }

    if ( $self->{types}->@* ) {
        foreach ( $self->{types}->@* ) {
            throw('The values in `types` value must be an instance of `Graph::QL::Schema::Type`, not '.$_)
                unless Ref::Util::is_blessed_ref( $_ )
                    && $_->isa('Graph::QL::Schema::Type');
        }
    }

    if ( $self->{directives}->@* ) {
        foreach ( $self->{directives}->@* ) {
            throw('The values in `directives` value must be an instance of `Graph::QL::Schema::Directive`, not '.$_)
                unless Ref::Util::is_blessed_ref( $_ )
                    && $_->isa('Graph::QL::Schema::Directive');
        }
    }

}

sub types : ro;

sub query_type : ro;

sub mutation_type     : ro;
sub has_mutation_type : predicate;

sub subscription_type     : ro;
sub has_subscription_type : predicate;

sub directives : ro;

## ...

sub to_type_language ($self) {
    # TODO:
    # handle the `directives`
    return "\n".# print the types first ...
        (join "\n\n" => map $_->to_type_language, $self->{types}->@*)
        ."\n\n". # followed by the base `schema` object
        'schema {'."\n    ".
            'query : '.$self->query_type->name."\n".
            ($self->has_mutation_type     ? (    '    mutation : '.$self->mutation_type->name."\n")     : '').
            ($self->has_subscription_type ? ('    subscription : '.$self->subscription_type->name."\n") : '').
        '}'."\n";
}

1;

__END__

=pod

=cut
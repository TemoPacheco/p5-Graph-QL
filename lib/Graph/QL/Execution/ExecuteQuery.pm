package Graph::QL::Execution::ExecuteQuery;
# ABSTRACT: GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';
use decorators ':accessors', ':constructor';

use Graph::QL::Util::Errors     'throw';
use Graph::QL::Util::Assertions ':all';

use Graph::QL::Execution::QueryValidator;

use constant DEBUG => $ENV{GRAPHQL_EXECUTOR_DEBUG} // 0;

our $VERSION = '0.01';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    name      => sub {}, # optional name of operation to run
    schema    => sub {}, # Graph::QL::Schema
    query     => sub {}, # Graph::QL::Operation::Query
    resolvers => sub { +{} }, # a mapping of TypeName to Resolver instance
    # internals ...
    _data     => sub { +{} },
    _errors   => sub { +[] },
);

sub BUILDARGS : strict(
    schema     => schema,
    query      => query,
    resolvers? => resolvers,
);

sub BUILD ($self, $params) {

    throw('The `schema` must be of an instance of `Graph::QL::Schema`, not `%s`', $self->{schema})
        unless assert_isa( $self->{schema}, 'Graph::QL::Schema' );

    throw('The `query` must be of an instance that does the `Graph::QL::Operation` role, not `%s`', $self->{query})
        unless assert_isa( $self->{query}, 'Graph::QL::Operation::Query' );

    # TODO:
    # - handle `initial-value`
    # - handle `variables`
    # - handle `context-value`

    if ( exists $params->{resolvers} ) {
        throw('The `resolvers` must be a HASH ref, not `%s`', $self->{resolvers})
            unless assert_non_empty( $self->{resolvers} );

        foreach ( values $self->{resolvers}->%* ) {
             throw('The values in `resolvers` must all be of type(Graph::QL::Execution::FieldResolver), not `%s`', $_ )
                unless assert_isa( $_, 'Graph::QL::Execution::FieldResolver' );
        }
    }
}

sub schema : ro;
sub query  : ro;

sub has_errors ($self) { !! scalar $self->{_errors}->@* }
sub get_errors ($self) {           $self->{_errors}->@* }

sub has_data ($self) { !! scalar keys $self->{_data}->%* }
sub get_data ($self) {                $self->{_data}->%* }

## ...

sub validate ($self) {
    # this will validate that the query supplied
    # can be executed by the schema supplied
    my $v = Graph::QL::Execution::QueryValidator->new(
        schema => $self->{schema},
        query  => $self->{query},
    );

    # validate the schema ...
    $v->validate( $self->{name} );

    # if the validation succeeds,
    # there are no errors ...
    return 1 unless $v->has_errors;
    # if the validation fails, then
    # we absorb the errors and ...
    $self->_absorb_validation_errors( 'The `operation` did not pass validation.' => $v );
    # and return false
    return 0;
}

sub execute ($self) {

    throw('You cannot execute a query that has errors')
        if $self->has_errors;


}

## ...

sub _add_error ($self, $msg, @args) {
    $msg = sprintf $msg => @args if @args;
    push $self->{_errors}->@* => $msg;
    return;
}

sub _add_data_key ($self, $key, $value) {
    $self->{_data}->{ $key } = $value;
    return;
}

sub _absorb_validation_errors ($self, $msgs, $e) {
    push $self->{_errors}->@* => $msgs, map "[VALIDATION] $_", $e->get_errors;
    return;
}

1;

__END__

=pod

=head1 DESCRIPTION

This object contains the data that must be available at all points
during query execution.

Namely, schema of the type system that is currently executing, and
the fragments defined in the query document.

=cut
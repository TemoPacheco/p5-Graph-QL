package Graph::QL::AST::Node::FieldDefinition;
# ABSTRACT: AST Node for GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';
use decorators ':accessors', ':constructor';

use Graph::QL::Util::Errors     'throw';
use Graph::QL::Util::Assertions ':all';

our $VERSION = '0.01';

use parent 'Graph::QL::AST::Node';
use slots (
    name       => sub { die 'You must supply a `name`'},
    arguments  => sub { +[] },
    type       => sub { die 'You must supply a `type`'},
    directives => sub { +[] },
);

sub BUILDARGS : strict(
    name         => name,
    arguments?   => arguments,
    type         => type,
    directives?  => directives,
    location?    => super(location),
);

sub BUILD ($self, $params) {

    throw('The `name` must be of type(Graph::QL::AST::Node::Name), not `%s`', $self->{name})
        unless assert_isa( $self->{name}, 'Graph::QL::AST::Node::Name');
    
    throw('The `arguments` value must be an ARRAY ref')
        unless assert_arrayref( $self->{arguments} );
    
    foreach ( $self->{arguments}->@* ) {
        throw('The values in `arguments` must all be of type(Graph::QL::AST::Node::InputValueDefinition), not `%s`', $_ )
            unless assert_isa( $_, 'Graph::QL::AST::Node::InputValueDefinition');
    }
    
    throw('The `type` must be of type(Graph::QL::AST::Node::Role::Type), not `%s`', $self->{type})
        unless assert_does( $self->{type}, 'Graph::QL::AST::Node::Role::Type');
    
    throw('The `directives` value must be an ARRAY ref')
        unless assert_arrayref( $self->{directives} );
    
    foreach ( $self->{directives}->@* ) {
        throw('The values in `directives` must all be of type(Graph::QL::AST::Node::Directive), not `%s`', $_ )
            unless assert_isa( $_, 'Graph::QL::AST::Node::Directive');
    }
    
}

sub name       : ro;
sub arguments  : ro;
sub type       : ro;
sub directives : ro;

1;

__END__

=pod

=cut

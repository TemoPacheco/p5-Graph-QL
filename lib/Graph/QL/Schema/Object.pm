package Graph::QL::Schema::Object;
# ABSTRACT: GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';
use decorators ':accessors', ':constructor';

use Graph::QL::Util::Errors     'throw';
use Graph::QL::Util::Assertions 'assert_isa', 'assert_arrayref';

use Graph::QL::Schema::Field;
use Graph::QL::Schema::Type::Named;

use Graph::QL::AST::Node::ObjectTypeDefinition;
use Graph::QL::AST::Node::Name;

our $VERSION = '0.01';

use parent 'UNIVERSAL::Object::Immutable';
use slots (
    _ast        => sub {},
    _name       => sub {},
    _fields     => sub {},
    _interfaces => sub {},
    _directives => sub {},
);

sub BUILDARGS : strict(
    ast?         => _ast,
    name?        => _name,
    fields?      => _fields,
    interfaces?  => _interfaces,
    directives?  => _directives,
);

sub BUILD ($self, $params) {

    if ( exists $params->{_ast} ) {

        throw('The `ast` must be an instance of `Graph::QL::AST::Node::ObjectTypeDefinition`, not `%s`', $self->{_ast})
            unless assert_isa( $self->{_ast}, 'Graph::QL::AST::Node::ObjectTypeDefinition' );

        $self->{_name}   = $self->{_ast}->name->value;
        $self->{_fields} = [ map Graph::QL::Schema::Field->new( ast => $_ ), $self->{_ast}->fields->@* ];
        if ( $self->{_ast}->interfaces->@* ) {
            $self->{_interfaces} = [
                map Graph::QL::Schema::Type::Named->new( ast => $_ ), $self->{_ast}->interfaces->@*
            ];
        }
        if ( $self->{_ast}->directives->@* ) {
            $self->{_directives} = [
                map Graph::QL::Directive->new( ast => $_ ), $self->{_ast}->directives->@*
            ];
        }
    }
    else {

        throw('You must pass a defined value to `name`')
            unless defined $self->{_name};

        throw('The `fields` value must be an ARRAY ref')
            unless assert_arrayref( $self->{_fields} );

        foreach ( $self->{_fields}->@* ) {
            throw('The values in `fields` must all be of type(Graph::QL::Schema::Field), not `%s`', $_ )
                unless assert_isa( $_, 'Graph::QL::Schema::Field');
        }

        if ( exists $params->{_interfaces} ) {
            throw('The `interfaces` value must be an ARRAY ref')
                unless assert_arrayref( $self->{_interfaces} );

            foreach ( $self->{_interfaces}->@* ) {
                throw('The values in `interfaces` must all be of type(Graph::QL::Schema::Type::Named), not `%s`', $_ )
                    unless assert_isa( $_, 'Graph::QL::Schema::Type::Named');
            }
        }

        if ( exists $params->{_directives} ) {
            throw('The `directives` value must be an ARRAY ref')
                unless assert_arrayref( $self->{_directives} );

            foreach ( $self->{_directives}->@* ) {
                throw('The values in `directives` must all be of type(Graph::QL::Directive), not `%s`', $_ )
                    unless assert_isa( $_, 'Graph::QL::Directive');
            }
        }

        $self->{_ast} = Graph::QL::AST::Node::ObjectTypeDefinition->new(
            name       => Graph::QL::AST::Node::Name->new( value => $self->{_name} ),
            fields     => [ map $_->ast, $self->{_fields}->@* ],
            (exists $params->{_interfaces}
                ? (interfaces => [ map $_->ast, $self->{_interfaces}->@* ])
                : ()),
            (exists $params->{_directives}
                ? (directives => [ map $_->ast, $self->{_directives}->@* ])
                : ()),
        );
    }

    # TODO:
    # An object type must be a super‐set of all interfaces it implements:
    #     The object type must include a field of the same name for every field defined in an interface.
    #         The object field must be of a type which is equal to or a sub‐type of the interface field (covariant).
    #             An object field type is a valid sub‐type if it is equal to (the same type as) the interface field type.
    #             An object field type is a valid sub‐type if it is an Object type and the interface field type is either an Interface type or a Union type and the object field type is a possible type of the interface field type.
    #             An object field type is a valid sub‐type if it is a List type and the interface field type is also a List type and the list‐item type of the object field type is a valid sub‐type of the list‐item type of the interface field type.
    #             An object field type is a valid sub‐type if it is a Non‐Null variant of a valid sub‐type of the interface field type.
    #     The object field must include an argument of the same name for every argument defined in the interface field.
    #         The object field argument must accept the same type (invariant) as the interface field argument.
    #     The object field may include additional arguments not defined in the interface field, but any additional argument must not be required, e.g. must not be of a non‐nullable type.
}

sub ast  : ro(_);
sub name : ro(_);

## ...

sub all_fields : ro(_fields);

sub lookup_field ($self, $name) {
    # coerce query fields into strings ...
    $name = $name->name if assert_isa( $name, 'Graph::QL::Operation::Selection::Field' );

    my ($field) = grep $_->name eq $name, $self->all_fields->@*;

    unless ( $field ) {
        require Graph::QL::Introspection;
        ($field) = grep $_->name eq $name, Graph::QL::Introspection::get_introspection_fields_for_query();
    }

    return $field;
}

## ...

sub has_interfaces : predicate(_);
sub interfaces     : ro(_);

sub has_directives : predicate(_);
sub directives     : ro(_);

## ...

sub to_type_language ($self) {
    my $directives = '';
    if ( $self->has_directives ) {
        $directives = ' '.(join ' ' => map $_->to_type_language, $self->directives->@*);
    }

    my $interfaces = '';
    if ( $self->has_interfaces ) {
        $interfaces = ' implements '.(join ' & ' => map $_->name, $self->interfaces->@*);
    }

    return 'type '.$self->name.$directives.$interfaces.' {'."\n    ".
        (join "\n    " => map $_->to_type_language, $self->all_fields->@*)."\n".
    '}';
}

1;

__END__

=pod

=cut

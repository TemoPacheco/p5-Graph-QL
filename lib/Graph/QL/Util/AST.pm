package Graph::QL::Util::AST;
# ABSTRACT: GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Ref::Util ();

use Graph::QL::Util::Errors 'throw';

use Graph::QL::Util::AST::Literals;
use Graph::QL::Core::ScalarType;

our $VERSION = '0.01';

## ----------------------------------------------
## AST Converters (to/from)
## ----------------------------------------------

# If you do not have the type, but have a literal
# value, so want to have the system guess for you
# on what is the right Value node.
sub guess_literal_to_ast_node ($literal) {

    # NOTE:
    # this needs help, lots of help. Perhaps
    # we can rely on the Parser to do the right
    # thing here, we shall see.

    # not defined is obvious, it is null ...
    if ( not defined $literal ) {
        require Graph::QL::AST::Node::NullValue;
        return Graph::QL::AST::Node::NullValue->new;
    }
    # float values have floating point values
    elsif ( Graph::QL::Util::AST::Literals::validate_float( $literal ) ) {
        require Graph::QL::AST::Node::FloatValue;
        return Graph::QL::AST::Node::FloatValue->new( value => $literal );
    }
    # this is a very simplistic view of numbers,
    # and ignores scientific notation, etc.
    elsif ( Graph::QL::Util::AST::Literals::validate_int( $literal ) ) {
        require Graph::QL::AST::Node::IntValue;
        return Graph::QL::AST::Node::IntValue->new( value => $literal );
    }
    # we have to check for Perl booleans here, ... 
    elsif ( Graph::QL::Util::AST::Literals::validate_perl_boolean( $literal ) ) {
        require Graph::QL::AST::Node::BooleanValue;
        return Graph::QL::AST::Node::BooleanValue->new( value => $literal );
    }
    # and also check for JSON booleans as well 
    elsif ( Graph::QL::Util::AST::Literals::validate_json_boolean( $literal ) ) {
        #use Data::Dumper;
        #warn Dumper $literal;        
        require Graph::QL::AST::Node::BooleanValue;
        return Graph::QL::AST::Node::BooleanValue->new( value => $literal );
    }
    elsif ( Graph::QL::Util::AST::Literals::validate_list( $literal ) ) {
        require Graph::QL::AST::Node::ListValue;
        return Graph::QL::AST::Node::ListValue->new( values => [ map guess_literal_to_ast_node( $_ ), $literal->@* ] );
    }
    elsif ( Graph::QL::Util::AST::Literals::validate_object( $literal ) ) {
        require Graph::QL::AST::Node::ObjectValue;
        require Graph::QL::AST::Node::ObjectField;
        require Graph::QL::AST::Node::Name;
        return Graph::QL::AST::Node::ObjectValue->new( 
            fields => [
                map {
                    Graph::QL::AST::Node::ObjectField->new(
                        name  => Graph::QL::AST::Node::Name->new( value => $_ ),
                        value => guess_literal_to_ast_node( $literal->{ $_ } ) 
                    )
                } sort keys $literal->%*
            ]
        );
    }
    # fuck it, it is probably a string ¯\_(ツ)_/¯
    else {
        #use Data::Dumper;
        #warn Dumper [ "WTF", $literal ];
        require Graph::QL::AST::Node::StringValue;
        return Graph::QL::AST::Node::StringValue->new( value => $literal );
    }
}

# If you know the type, then we can wrap
# it up accordingly and get you on your
# way without trouble ...
# TODO: Add item type checks for List elements and field type checks for objects
sub literal_to_ast_node ($literal, $type) {

    if ( not defined $literal ) {
        require Graph::QL::AST::Node::NullValue;
        return Graph::QL::AST::Node::NullValue->new;
    }
    elsif ( $type->name eq Graph::QL::Core::ScalarType->BOOLEAN ) {
        require Graph::QL::AST::Node::BooleanValue;
        return Graph::QL::AST::Node::BooleanValue->new( value => $literal );
    }
    elsif ( $type->name eq Graph::QL::Core::ScalarType->FLOAT ) {
        require Graph::QL::AST::Node::FloatValue;
        return Graph::QL::AST::Node::FloatValue->new( value => $literal );
    }
    elsif ( $type->name eq Graph::QL::Core::ScalarType->INT ) {
        require Graph::QL::AST::Node::IntValue;
        return Graph::QL::AST::Node::IntValue->new( value => $literal );
    }
    elsif ( $type->name eq Graph::QL::Core::ScalarType->STRING ) {
        require Graph::QL::AST::Node::StringValue;
        return Graph::QL::AST::Node::StringValue->new( value => $literal );
    }
    elsif ( (ref $type eq 'Graph::QL::Schema::Type::List') and (ref $literal eq 'ARRAY') ) {
        require Graph::QL::AST::Node::ListValue;
        return Graph::QL::AST::Node::ListValue->new( values => [ map guess_literal_to_ast_node( $_ ), $literal->@* ] );
    }
    # If it is a Named Type and if it is neither scalar nor List, then it must be an Object
    elsif ( (ref $type eq 'Graph::QL::Schema::Type::Named') and (ref $literal eq 'HASH' )) {
        require Graph::QL::AST::Node::ObjectValue;
        require Graph::QL::AST::Node::ObjectField;
        require Graph::QL::AST::Node::Name;
        return Graph::QL::AST::Node::ObjectValue->new( 
            fields => [
                map {
                    Graph::QL::AST::Node::ObjectField->new(
                        name  => Graph::QL::AST::Node::Name->new( value => $_ ),
                        value => guess_literal_to_ast_node( $literal->{ $_ } )
                    )
                } sort keys $literal->%*
            ]
        );
    }
    else {
        throw('Do not recognize the expected type(%s), unable to convert to ast-node', $type->name);
    }
}

# This is basically just because NullValue does
# not have a `value` method of its own to call
# so we do this, oh well :/
sub ast_node_to_literal ($ast_node) {
    # TODO:
    # type check $ast_node does (Graph::QL::AST::Node::Role::Value)

    return undef if $ast_node->isa('Graph::QL::AST::Node::NullValue');
    return $ast_node->value;
}

# simple util for the type-language pretty printer
sub ast_node_to_type_language ($ast_node) {

    if ( $ast_node->isa('Graph::QL::AST::Node::NullValue') ) {
        return 'null';
    }
    elsif ( $ast_node->isa('Graph::QL::AST::Node::BooleanValue') ) {
        return $ast_node->value ? 'true' : 'false';
    }
    elsif ( $ast_node->isa('Graph::QL::AST::Node::FloatValue')
            || $ast_node->isa('Graph::QL::AST::Node::IntValue')
            || $ast_node->isa('Graph::QL::AST::Node::Name')) {
        return $ast_node->value;
    }
    elsif ( $ast_node->isa('Graph::QL::AST::Node::StringValue') ) {
        return '"'.$ast_node->value.'"';
    }
    elsif ( $ast_node->isa('Graph::QL::AST::Node::ListValue') ) {
        return '['.(join ', ' => map ast_node_to_type_language( $_ ), $ast_node->values->@* ).']';
    }
    elsif ( $ast_node->isa('Graph::QL::AST::Node::ObjectValue') ) {      
        return '{'.
            (join ', ' => map { 
                ast_node_to_type_language( $_->name )
                .": ".
                ast_node_to_type_language( $_->value ) 
            } $ast_node->fields->@*)
        .'}';
    }
    else {
        throw('Do not recognize the expected ast-node(%s), unable to convert to type-language', $ast_node);
    }
    # TODO: Handle ListValue and ObjectValue
}

# When a type is referred to, we might need to convert
# that type-name to the schema and AST types, so here ...
sub ast_type_to_schema_type ($ast) {
    if ( $ast->isa('Graph::QL::AST::Node::NamedType') ) {
        require Graph::QL::Schema::Type::Named;
        return Graph::QL::Schema::Type::Named->new( ast => $ast );
    }
    elsif ( $ast->isa('Graph::QL::AST::Node::NonNullType') ) {
        require Graph::QL::Schema::Type::NonNull;
        return Graph::QL::Schema::Type::NonNull->new( ast => $ast );
    }
    elsif ( $ast->isa('Graph::QL::AST::Node::ListType') ) {
        require Graph::QL::Schema::Type::List;
        return Graph::QL::Schema::Type::List->new( ast => $ast );
    }
    else {
        throw('Do not recognize the ast type(%s), unable to convert to schema type', $ast);
    }
}

sub ast_def_to_operation_def ($ast_def) {
    if ( $ast_def->isa('Graph::QL::AST::Node::FragmentDefinition') ) {
        require Graph::QL::Operation::Fragment;
        return Graph::QL::Operation::Fragment->new( ast => $ast_def )
    }
    elsif ( $ast_def->isa('Graph::QL::AST::Node::OperationDefinition') ) {
        my $op = $ast_def->operation;
        if ( $op eq Graph::QL::Core::OperationKind->QUERY ) {
            require Graph::QL::Operation::Query;
            return Graph::QL::Operation::Query->new( ast => $ast_def );
        }
        elsif ( $op eq Graph::QL::Core::OperationKind->MUTATION ) {
            require Graph::QL::Operation::Mutation;
            return Graph::QL::Operation::Mutation->new( ast => $ast_def );
        }
        elsif ( $op eq Graph::QL::Core::OperationKind->SUBSCRIPTION ) {
            require Graph::QL::Operation::Subscription;
            return Graph::QL::Operation::Subscription->new( ast => $ast_def );
        }
        else {
            throw('This should be impossible, got ast operation of kind', $op);
        }
    }
    else {
        throw('Do not recognize the ast type def(%s), unable to convert to an operation def', $ast_def);
    }
}

sub ast_type_def_to_schema_type_def ($ast_type_def) {
    if ( $ast_type_def->isa('Graph::QL::AST::Node::EnumTypeDefinition') ) {
        require Graph::QL::Schema::Enum;
        return Graph::QL::Schema::Enum->new( ast => $ast_type_def )
    }
    elsif ( $ast_type_def->isa('Graph::QL::AST::Node::UnionTypeDefinition') ) {
        require Graph::QL::Schema::Union;
        return Graph::QL::Schema::Union->new( ast => $ast_type_def )
    }
    elsif ( $ast_type_def->isa('Graph::QL::AST::Node::InputObjectTypeDefinition') ) {
        require Graph::QL::Schema::InputObject;
        return Graph::QL::Schema::InputObject->new( ast => $ast_type_def )
    }
    elsif ( $ast_type_def->isa('Graph::QL::AST::Node::InterfaceTypeDefinition') ) {
        require Graph::QL::Schema::Interface;
        return Graph::QL::Schema::Interface->new( ast => $ast_type_def )
    }
    elsif ( $ast_type_def->isa('Graph::QL::AST::Node::ObjectTypeDefinition') ) {
        require Graph::QL::Schema::Object;
        return Graph::QL::Schema::Object->new( ast => $ast_type_def )
    }
    elsif ( $ast_type_def->isa('Graph::QL::AST::Node::ScalarTypeDefinition') ) {
        require Graph::QL::Schema::Scalar;
        return Graph::QL::Schema::Scalar->new( ast => $ast_type_def )
    }
    else {
        # NOTE:
        # Not going to support these yet
        # (most cause I am not sure enough what they are)
            # Graph::QL::AST::Node::TypeExtensionDefinition

        throw('Do not recognize the ast type def(%s), unable to convert to schema type def', $ast_type_def);
    }
}

sub ast_value_to_schema_type ($ast_value) {
    if ( $ast_value->isa('Graph::QL::AST::Node::NullValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => 'Null' );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::BooleanValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Core::ScalarType->BOOLEAN );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::FloatValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Core::ScalarType->FLOAT );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::IntValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Core::ScalarType->INT );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::StringValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Core::ScalarType->STRING );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::ListValue') ) {
        return Graph::QL::Schema::Type::List->new( of_type => ast_value_to_schema_type($ast_value->value->[0]) );
    }
    # Not sure how to infer type from ObjectValue
    #elsif ( $ast_value->isa('Graph::QL::AST::Node::ObjectValue') ) {
    #    return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Core::ScalarType->STRING );
    #}
    else {
        throw('Do not recognize the ast-value(%s), unable to convert to schema type', $ast_value);
    }
}

## ----------------------------------------------
## General utils for AST data structures
## ----------------------------------------------

sub null_out_source_locations ( $ast ) {
    state $NULL_LOCATION = {
        start => { line => 0, column => 0 },
        end   => { line => 0, column => 0 },
    };

    $ast->{loc}         = $NULL_LOCATION if $ast->{loc};
    $ast->{name}->{loc} = $NULL_LOCATION if $ast->{name};

    foreach my $k ( keys $ast->%* ) {
        my $v = $ast->{ $k };

        if ( Ref::Util::is_arrayref( $v ) ) {
            null_out_source_locations( $_ ) foreach $v->@*;
        }
        elsif ( Ref::Util::is_ref( $v ) ) {
            null_out_source_locations( $v );
        }
    }
}

sub prune_source_locations ( $ast ) {
    delete $ast->{loc}         if $ast->{loc};
    delete $ast->{name}->{loc} if $ast->{name};

    foreach my $k ( keys $ast->%* ) {
        my $v = $ast->{ $k };

        if ( Ref::Util::is_plain_arrayref( $v ) ) {
            prune_source_locations( $_ ) foreach $v->@*;
        }
        elsif ( Ref::Util::is_plain_ref( $v ) ) {
            prune_source_locations( $v );
        }
    }
}

1;

__END__

=pod

=cut




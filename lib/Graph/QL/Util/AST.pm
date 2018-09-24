package Graph::QL::Util::AST;
# ABSTRACT: GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Ref::Util ();

use Graph::QL::Util::Errors 'throw';
use Graph::QL::Util::Types;

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
    elsif ( $literal =~ /^\d+\.\d+$/ ) {
        require Graph::QL::AST::Node::FloatValue;
        return Graph::QL::AST::Node::FloatValue->new( value => $literal );
    }
    # this is a very simplistic view of numbers,
    # and ignores scientific notation, etc.
    elsif ( $literal =~ /^\d+$/ ) {
        require Graph::QL::AST::Node::IntValue;
        return Graph::QL::AST::Node::IntValue->new( value => $literal );
    }
    # this is a bad way to handle Booleans, should
    # likely also check for JSON::PP::Booleans and
    # other such esoteria ...
    elsif ( $literal eq '' || $literal =~ /^1$/ || $literal =~ /^0$/  ) {
        require Graph::QL::AST::Node::BooleanValue;
        return Graph::QL::AST::Node::BooleanValue->new( value => $literal );
    }
    # fuck it, it is probably a string ¯\_(ツ)_/¯
    else {
        require Graph::QL::AST::Node::StringValue;
        return Graph::QL::AST::Node::StringValue->new( value => $literal );
    }
}

# If you know the type, then we can wrap
# it up accordingly and get you on your
# way without trouble ...
sub literal_to_ast_node ($literal, $type) {

    if ( not defined $literal ) {
        require Graph::QL::AST::Node::NullValue;
        return Graph::QL::AST::Node::NullValue->new;
    }
    elsif ( $type->name eq Graph::QL::Util::Types->BOOLEAN ) {
        require Graph::QL::AST::Node::BooleanValue;
        return Graph::QL::AST::Node::BooleanValue->new( value => $literal );
    }
    elsif ( $type->name eq Graph::QL::Util::Types->FLOAT ) {
        require Graph::QL::AST::Node::FloatValue;
        return Graph::QL::AST::Node::FloatValue->new( value => $literal );
    }
    elsif ( $type->name eq Graph::QL::Util::Types->INT ) {
        require Graph::QL::AST::Node::IntValue;
        return Graph::QL::AST::Node::IntValue->new( value => $literal );
    }
    elsif ( $type->name eq Graph::QL::Util::Types->STRING ) {
        require Graph::QL::AST::Node::StringValue;
        return Graph::QL::AST::Node::StringValue->new( value => $literal );
    }
    # TODO:
    # we are going to want to handle some other types:
    # - INPUT_OBJECT
    # - LIST
    # - Enum Value
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
    elsif ( $ast_node->isa('Graph::QL::AST::Node::FloatValue') || $ast_node->isa('Graph::QL::AST::Node::IntValue') ) {
        return $ast_node->value;
    }
    elsif ( $ast_node->isa('Graph::QL::AST::Node::StringValue') ) {
        return '"'.$ast_node->value.'"';
    }
    else {
        throw('Do not recognize the expected ast-node(%s), unable to convert to type-language', $ast_node);
    }
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
            # Graph::QL::AST::Node::OperationDefinition
            # Graph::QL::AST::Node::TypeExtensionDefinition
            # Graph::QL::AST::Node::FragmentDefinition

        throw('Do not recognize the ast type def(%s), unable to convert to schema type def', $ast_type_def);
    }
}

sub ast_value_to_schema_type ($ast_value) {
    if ( $ast_value->isa('Graph::QL::AST::Node::NullValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Util::Types->NULL );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::BooleanValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Util::Types->BOOLEAN );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::FloatValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Util::Types->FLOAT );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::IntValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Util::Types->INT );
    }
    elsif ( $ast_value->isa('Graph::QL::AST::Node::StringValue') ) {
        return Graph::QL::Schema::Type::Named->new( name => Graph::QL::Util::Types->STRING );
    }
    else {
        throw('Do not recognize the ast-value(%s), unable to convert to schema type', $ast_value);
    }
}

## ----------------------------------------------
## General utils for AST data structures
## ----------------------------------------------

use constant NULL_LOCATION => +{
    start => { line => 0, column => 0 },
    end   => { line => 0, column => 0 },
};

sub null_out_source_locations ( $ast, @paths ) {

    $ast->{loc}         = NULL_LOCATION if $ast->{loc};
    $ast->{name}->{loc} = NULL_LOCATION if $ast->{name};

    foreach my $path ( @paths ) {
        my ($start, @rest) = split /\./ => $path;

        #warn "PATH: $path";
        #warn "START: $start";
        #warn "REST: ". (join ', ' => @rest);

        #use Data::Dumper;
        #use Carp;
        #Carp::confess(Dumper [ $ast, \@paths ]) unless defined $start;

        if ( Ref::Util::is_arrayref( $ast->{ $start } ) ) {
            foreach my $sub_ast ( $ast->{ $start }->@* ) {
                null_out_source_locations( $sub_ast, @rest ? (join '.' => @rest) : () );
            }
        }
        else {
            null_out_source_locations( $ast->{ $start }, @rest ? (join '.' => @rest) : () );
        }
    }
}

1;

__END__

=pod

=cut




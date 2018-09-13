#!/usr/bin/env perl

use v5.24;
use warnings;
use experimental 'signatures';

use Test::More;
use Test::Differences;
use Data::Dumper;

BEGIN {
    use_ok('Graph::QL::Schema');

    use_ok('Graph::QL::Schema::Type::Interface');
    use_ok('Graph::QL::Schema::Type::Object');
    use_ok('Graph::QL::Schema::Type::Scalar');

    use_ok('Graph::QL::Schema::Field');
    use_ok('Graph::QL::Schema::InputValue');
}

subtest '... testing my schema' => sub {

    # http://facebook.github.io/graphql/June2018/#example-ab5e5
    my $expected_type_language = q[
scalar Int

scalar String

interface NamedEntity {
    name : String
}

interface ValuedEntity {
    value : Int
}

type Person implements NamedEntity {
    name : String
    age : Int
}

type Business implements NamedEntity & ValuedEntity {
    name : String
    value : Int
    employeeCount : Int
}

type Query {
    findByName(name : String) : NamedEntity
    findByValue(value : Int) : ValuedEntity
}

schema {
    query : Query
}
];

    my $Int    = Graph::QL::Schema::Type::Scalar->new( name => 'Int' );
    my $String = Graph::QL::Schema::Type::Scalar->new( name => 'String' );

    my $NamedEntity = Graph::QL::Schema::Type::Interface->new(
        name   => 'NamedEntity',
        fields => [
            Graph::QL::Schema::Field->new( name => 'name', type => $String ),
        ]
    );

    my $ValuedEntity = Graph::QL::Schema::Type::Interface->new(
        name   => 'ValuedEntity',
        fields => [
            Graph::QL::Schema::Field->new( name => 'value', type => $Int ),
        ]
    );

    my $Person = Graph::QL::Schema::Type::Object->new(
        name       => 'Person',
        interfaces => [ $NamedEntity ],
        fields     => [
            Graph::QL::Schema::Field->new( name => 'name', type => $String ),
            Graph::QL::Schema::Field->new( name => 'age',  type => $Int    ),
        ]
    );

    my $Business = Graph::QL::Schema::Type::Object->new(
        name       => 'Business',
        interfaces => [ $NamedEntity, $ValuedEntity ],
        fields     => [
            Graph::QL::Schema::Field->new( name => 'name',          type => $String ),
            Graph::QL::Schema::Field->new( name => 'value',         type => $Int    ),
            Graph::QL::Schema::Field->new( name => 'employeeCount', type => $Int    ),
        ]
    );

    my $Query = Graph::QL::Schema::Type::Object->new(
        name   => 'Query',
        fields => [
            Graph::QL::Schema::Field->new(
                name => 'findByName',
                args => [ Graph::QL::Schema::InputValue->new( name => 'name', type => $String ) ],
                type => $NamedEntity,
            ),
            Graph::QL::Schema::Field->new(
                name => 'findByValue',
                args => [ Graph::QL::Schema::InputValue->new( name => 'value', type => $Int ) ],
                type => $ValuedEntity,
            ),
        ]
    );

    my $schema = Graph::QL::Schema->new(
        query_type => $Query,
        types => [
            $Int,
            $String,
            $NamedEntity,
            $ValuedEntity,
            $Person,
            $Business,
            $Query,
        ]
    );

    #warn $schema->to_type_language;

    eq_or_diff($schema->to_type_language, $expected_type_language, '... got the pretty printed schema as expected');
};

done_testing;
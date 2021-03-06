#!/usr/bin/env perl

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

use Test::More;
use Test::Differences;
use Test::Fatal;

use Data::Dumper;
use Time::Piece;

BEGIN {
    use_ok('Graph::QL::Schema');
    use_ok('Graph::QL::Operation');
    use_ok('Graph::QL::Execution::ExecuteQuery');

    use_ok('Graph::QL::Resolver::SchemaResolver');
    use_ok('Graph::QL::Resolver::TypeResolver');
    use_ok('Graph::QL::Resolver::FieldResolver');
}

my $schema = Graph::QL::Schema->new_from_source(q[
    scalar Int
    scalar String

    type Date {
        day   : String
        month : String
        year  : Int
    }

    type BirthEvent {
        date  : Date
        place : String
    }

    type DeathEvent {
        date  : Date
        place : String
    }

    type Person {
        name        : String
        nationality : String
        gender      : String
        birth       : BirthEvent
        death       : DeathEvent
    }

    type Query {
        findPerson( name : String ) : [Person]
        getAllPeople : [Person]
    }

    schema {
        query : Query
    }
]);

my $operation = Graph::QL::Operation->new_from_source(q[
    query TestQuery {
        findPerson( name : "Will" ) {
            name
            birth {
                date {
                    day
                    month
                    year
                }
            }
            death {
                date {
                    year
                }
            }
        }
        getAllPeople {
            name
            gender
            death {
                date {
                    year
                }
            }
        }
    }
]);

my $e = Graph::QL::Execution::ExecuteQuery->new(
    schema    => $schema,
    operation => $operation,
    context   => {
        people => [
            {
                displayname => 'Willem De Kooning',
                gender      => 'Male',
                culture     => 'Dutch',
                datebegin   => 'April 24, 1904',
                birthplace  => 'Rotterdam, Netherlands',
                dateend     => 'March 19, 1997',
                deathplace  => 'East Hampton, New York, U.S.',
            },
            {
                displayname => 'Jackson Pollock',
                gender      => 'Male',
                culture     => 'United States',
                datebegin   => 'January 28, 1912',
                birthplace  => 'Cody, Wyoming, U.S.',
                dateend     => 'August 11, 1956',
                deathplace  => 'Springs, New York, U.S.',
            }
        ]
    },
    resolvers => Graph::QL::Resolver::SchemaResolver->new(
        types => [
            Graph::QL::Resolver::TypeResolver->new(
                name   => 'Query',
                fields => [
                    Graph::QL::Resolver::FieldResolver->new( name => 'getAllPeople', code => sub ($, $, $context, $) { $context->{people} } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'findPerson',   code => sub ($, $args, $context, $) {
                        my $name = $args->{name};
                        return [ grep { $_->{displayname} =~ /$name/ } $context->{people}->@* ]
                    }),
                ]
            ),
            Graph::QL::Resolver::TypeResolver->new(
                name   => 'Person',
                fields => [
                    Graph::QL::Resolver::FieldResolver->new( name => 'name',        code => sub ($data, $, $, $) { $data->{displayname} } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'nationality', code => sub ($data, $, $, $) { $data->{culture}     } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'gender',      code => sub ($data, $, $, $) { $data->{gender}      } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'birth',       code => sub ($data, $, $, $) { $data } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'death',       code => sub ($data, $, $, $) { $data } ),
                ]
            ),
            Graph::QL::Resolver::TypeResolver->new(
                name   => 'BirthEvent',
                fields => [
                    Graph::QL::Resolver::FieldResolver->new( name => 'date',  code => sub ($data, $, $, $) { Time::Piece->strptime( $data->{datebegin}, '%B %d, %Y' ) } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'place', code => sub ($data, $, $, $) { $data->{birthplace} } ),
                ]
            ),
            Graph::QL::Resolver::TypeResolver->new(
                name   => 'DeathEvent',
                fields => [
                    Graph::QL::Resolver::FieldResolver->new( name => 'date',  code => sub ($data, $, $, $) { Time::Piece->strptime( $data->{dateend}, '%B %d, %Y' ) } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'place', code => sub ($data, $, $, $) { $data->{deathplace} } ),
                ]
            ),
            Graph::QL::Resolver::TypeResolver->new(
                name   => 'Date',
                fields => [
                    Graph::QL::Resolver::FieldResolver->new( name => 'day',   code => sub ($data, $, $, $) { $data->mday      } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'month', code => sub ($data, $, $, $) { $data->fullmonth } ),
                    Graph::QL::Resolver::FieldResolver->new( name => 'year',  code => sub ($data, $, $, $) { $data->year      } ),
                ]
            )
        ]
    )
);
isa_ok($e, 'Graph::QL::Execution::ExecuteQuery');

ok($e->validate, '... the schema and query validated correctly');
ok(!$e->has_errors, '... no errors have been be found');

my $result = $e->execute;

eq_or_diff(
    $result,
    {
        findPerson => [
            {
                name  => 'Willem De Kooning',
                birth => {
                    date => {
                        day   => 24,
                        month => 'April',
                        year  => 1904,
                    }
                },
                death => {
                    date => {
                        year => 1997
                    }
                },
            }
        ],
        getAllPeople => [
            {
                name   => 'Willem De Kooning',
                gender => 'Male',
                death  => {
                    date => {
                        year => 1997
                    }
                }
            },
            {
                name   => 'Jackson Pollock',
                gender => 'Male',
                death  => {
                    date => {
                        year => 1956
                    }
                }
            }
        ]
    },
    '... got the expected results of the query'
);

done_testing;

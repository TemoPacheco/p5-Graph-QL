package Graph::QL::Introspection::Resolvers::__EnumValue;
# ABSTRACT: GraphQL in Perl
use v5.24;
use warnings;
use experimental 'signatures', 'postderef';

our $VERSION = '0.01';

sub name ($value, $, $, $) { $value->name }

1;

__END__

=pod

=cut

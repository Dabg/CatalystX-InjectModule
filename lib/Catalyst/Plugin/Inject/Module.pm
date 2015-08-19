use utf8;
package Catalyst::Plugin::Inject::Module;

use Moose;
use namespace::autoclean;

has name => (
               isa      => "Str",
               is       => "rw",
);

has version => (
               isa      => "Int",
               is       => "rw",
);

has deps => (
               is       => "rw",
               isa      => "ArrayRef",
               default  => sub { [] },
           );

has path => (
               isa      => "Str",
               is       => "rw",
);


=head1 NAME

Catalyst::Plugin::Inject::Module

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=cut

1; # End of Catalyst::Plugin::Inject

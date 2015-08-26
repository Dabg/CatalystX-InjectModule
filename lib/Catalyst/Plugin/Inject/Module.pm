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
               default  => 0,
           );

has deps => (
               is       => "rw",
               isa      => "ArrayRef",
               default  => sub { [] },
           );

has path => (
               isa      => "Str",
               is       => "ro",
               trigger => sub {
                   my $self = shift;
                   $self->_build_paths;
               },
           );

has lib_path => (
               isa      => "Str",
               is       => "rw",
           );

has template_path => (
               isa      => "Str",
               is       => "rw",
           );

has static_path => (
               isa      => "Str",
               is       => "rw",
           );


sub _build_paths {
    my $self = shift;

    my $path = $self->path;

    # -- lib --
    my $lib_path = "$path/lib";
    $self->lib_path($lib_path)
        if ( -d $lib_path );

    # -- templates --
    my $template_path = "$path/root/src";
    $self->template_path($template_path)
        if ( -d $template_path );

    # -- static --
    my $static_path = "$path/root/static";
    $self->static_path($static_path)
        if ( -d $static_path );

}

=head1 NAME

Catalyst::Plugin::Inject::Module

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=cut

1; # End of Catalyst::Plugin::Inject

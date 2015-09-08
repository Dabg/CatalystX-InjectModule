use utf8;
package Catalyst::Plugin::Inject::MI;

use Moose;
use Dependency::Resolver;

has resolver => (
              is       => 'rw',
              isa      => 'Dependency::Resolver',
          );


sub get_module {
    my($self, $mod, $op , $ver) = @_;

    my $modules = $self->resolver->get_modules($mod, $op, $ver);
    return $modules->[-1];
}

sub resolv {
    my $self      = shift;
    my $module    = shift;
    my $operation = shift || '>=';
    my $version   = shift || 0;

    my $module   = $self->get_module($module, $operation, $version );
    my $resolved = $self->resolver->dep_resolv($module);
    return $resolved;
}

sub load {
    my $self           = shift;
    my $conf           = shift;
    my $conf_filename  = shift;

    $conf_filename ||= 'config.yml';
    print "load_modules ...\n";

    $self->resolver(Dependency::Resolver->new(debug => $conf->{debug}));

    # search modules in 'path' directories  and in @INC
    for my $dir ( @{ $conf->{path} }, @INC ) {
        $self->load_modules_path($dir, $conf_filename, $conf->{debug});
    }
}


sub load_modules_path{
    my $self           = shift;
    my $dir            = shift;
    my $conf_filename  = shift;
    my $debug          = shift;

    print "  - search modules on $dir ...\n";

    my $id=0;
    for my $mod_path ( glob("$dir/*") ) {
        next if ! -d $mod_path;

        my $mod_name = $mod_path;
        $mod_name =~ s/\/$//gmx;
        $mod_name =~ s/^.*\///gmx;

        my $mod_conf_filename = "$mod_path/$conf_filename";

        # OK config exist
        if ( -e $mod_conf_filename ) {
            print "    - find module $mod_name : OK\n";
            my $mod_config;
            my $filename;
            my $cfg = Config::Any->load_files({files => [$mod_conf_filename], use_ext => 1 })
                or die "Error (conf: $mod_conf_filename) : $!\n";
            ($filename, $mod_config) = %{$cfg->[0]};

            my $module = { name    => $mod_config->{name},
                           version => $mod_config->{version},
                           deps    => $mod_config->{deps},
                           path    => $mod_path,
                       };

            $self->resolver->add($module);
        }
        #else {  print "No config -> NEXT\n"; }
    }
}

=head1 NAME

Catalyst::Plugin::Inject::MI Module injector

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=cut

1;

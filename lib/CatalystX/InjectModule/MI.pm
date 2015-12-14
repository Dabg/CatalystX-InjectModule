use utf8;
package CatalystX::InjectModule::MI;

# This plugin is inspired by :
# - CatalystX::InjectComponent
# - Catalyst::Plugin::AutoCRUD
# - Catalyst::Plugin::PluginLoader
# - Catalyst::Plugin::Thruk::ConfigLoader

use Class::Load ':all';
use Clone 'clone';
use File::Find;
use File::Basename;
use Dependency::Resolver;
use Devel::InnerPackage qw/list_packages/;
use Moose;
use Moose::Util qw/find_meta apply_all_roles/;
use Class::Load ':all';
use Catalyst::Utils;

has regex_conf_name => (
              is       => 'rw',
              isa      => 'Str',
              default  => sub { '^cxim_config.yml$'},
          );

has resolver => (
              is       => 'rw',
              isa      => 'Dependency::Resolver',
          );

has ctx => (
              is       => 'rw',
          );

has catalyst_plugins => (
              is       => 'rw',
              isa      => 'HashRef',
              default  => sub { {} },
          );

has modules_loaded => (
              is       => 'rw',
              isa      => 'HashRef',
              default  => sub { {} },
          );

has _views => (
              is       => 'rw',
              isa      => 'ArrayRef',
              default  => sub { [] },
          );

has _static_dirs => (
              is       => 'rw',
              isa      => 'ArrayRef',
              default  => sub { [ ] },
          );

my $debug = 0;

sub log {
    my($self, $msg) = @_;
	$self->ctx->log->debug( "MI: $msg" ) if $debug;
}

sub get_module {
    my($self, $mod, $op , $ver) = @_;

    my $modules = $self->resolver->get_modules($mod, $op, $ver);
    return $modules->[-1];
}

sub resolv {
    my $self      = shift;
    my $module    = shift;
    my $operation = shift;
    my $version   = shift;

    my $Module   = $self->get_module($module, $operation, $version );
    die "Module $module not found !" if ! defined $Module->{name};

    my $resolved = $self->resolver->dep_resolv($Module);

    $self->_add_to_modules_loaded($resolved);
    return $resolved;
}


sub load {
    my $self           = shift;
    my $conf           = shift;
    my $conf_filename  = shift;

    $debug = 1 if $conf->{debug};
    $conf_filename ||= $self->regex_conf_name;
    $self->log("load_modules ...");

    $self->resolver(Dependency::Resolver->new(debug => $debug ));

    # search modules in 'path' directories
    for my $dir ( @{ $conf->{path} } ) {
        if ( $dir eq '__INC__' ) {
            pop(@INC) if $INC[-1] eq '.'; # do not search module in '.'
            push(@{$conf->{path}}, @INC);
            next;
        }
        $self->_load_modules_path($dir, $conf_filename);
    }
    # Merge config resolved modules ----------------
    $self->_merge_resolved_configs;

}



sub modules_to_inject {
    my $self    = shift;
    my $modules_name = shift;

    my $modules = [];
    foreach my $m ( @$modules_name ) {
        my $resolved = $self->resolv($m);

        foreach my $M ( @$resolved ) {
            if ( $M->{_injected} ){
                next;
            }
            push(@$modules,$M);
        }
    }
    return $modules;
}

sub inject {
    my $self         = shift;
    my $modules_name = shift;

    my $modules = $self->modules_to_inject($modules_name);

    for my $m ( @$modules) {
        $self->_inject($m);
    }
}

sub _add_to_modules_loaded {
    my $self    = shift;
    my $modules = shift;

    foreach my $m (@$modules) {
        $self->modules_loaded->{$m->{name}} = $m;
    }
}

sub _load_modules_path{
    my $self           = shift;
    my $dir            = shift;
    my $conf_filename  = shift;

    $self->log("  - search modules in $dir ...");

    my $all_configs = $self->_search_in_path( $dir, "^$conf_filename\$" );

    CONFIG: for my $config ( @$all_configs ) {
        my $cfg = Config::Any->load_files({files => [$config], use_ext => 1 })
            or die "Error (conf: $config) : $!\n";

        my($filename, $mod_config) = %{$cfg->[0]};

        my $path = dirname($config);
        $path =~ s|^\./||;

        # next if module already added ( ex: path=share + share/modules)
        for my $m ( @{$self->resolver->modules->{$mod_config->{name}}} ) {
            if ( $path eq $m->{path}){
                next CONFIG;
            };
        }

        my $msg = "    - find module ". $mod_config->{name};
        $msg .= " v". $mod_config->{version} if defined $mod_config->{version};
        $self->log($msg);

        $mod_config->{path} = $path;

        $self->resolver->add($mod_config);
    }
}

sub _inject {
    my $self   = shift;
    my $module = shift;

    $self->log(" InjectModule " . $module->{name});

    # Inject lib and components ----------
    $self->_load_lib($module);

    # Inject catalyse plugin dependencies
    $self->_load_catalyst_plugins($module);

    # Inject templates -------------------
    $self->_load_template($module);

    # Inject static ----------------------
    $self->_load_static($module);

    # install
    $self->_install_module($module);
}


sub _merge_resolved_configs {
	my ( $self, $module ) = @_;

    $self->log("  - Merge all resolved modules config (" . $self->regex_conf_name . ')');

    my $conf = $self->ctx->config->{'CatalystX::InjectModule'};
    my $modules = $self->modules_to_inject($conf->{inject});

    for my $module (@$modules) {
        my $mod_conf = clone($module);

        # Merge all keys except these
        map { delete $mod_conf->{$_} } qw /name version deps catalyst_plugins dbix_fixtures /;

        $self->ctx->config( Catalyst::Utils::merge_hashes($self->ctx->config, $mod_conf) );
    }
}


sub _load_lib {
	my ( $self, $module ) = @_;

    my $libpath = $module->{path} . '/lib';
    return if ( ! -d $libpath);

    $self->log("  - Add lib $libpath");
    unshift( @INC, $libpath );

	# Search and load components
	my $all_libs = $self->_search_in_path( $module->{path}, '.pm$' );

	foreach my $file (@$all_libs) {

        next if grep {/TraitFor/} $file;

		$self->_load_component( $module, $file )
			if ( grep {/Model|View|Controller/} $file );

        push(@{$self->_views}, $file)
            			if ( grep {/\/View\/\w*\.pm/} $file );
	}
}

sub _install_module {
    my $self   = shift;
    my $module = shift;

    my $module_name = $module->{name};
    $module_name =~ s|::|/|;

    if ( $self->_is_installed($module) ) {
        $self->log("  - $module_name already installed");
        return;
    }

    my $module_path = $module->{path};
    my $module_file = $module_path . '/lib/' . $module_name . '.pm';

    if ( -f $module_file ) {
        load_class($module_name);
        my $mod = $module_name->new;
        if ( $mod->can('install') ) {
            $self->log("  - Install $module_name $module_file...");
            $mod->install($module, $self);
        }
    }
}

sub _is_installed {
    my $self   = shift;
    my $module = shift;

    my $conf = $self->ctx->config->{'CatalystX::InjectModule'};
    my $states_path = $conf->{states_path};


    #use Data::Dumper;print Dumper($conf);
    return 0;
}

sub _load_catalyst_plugins {
	my ( $self, $module ) = @_;

	my $plugins = $module->{catalyst_plugins};
	foreach my $p (@$plugins) {

		# If plugin is not already loaded
		if ( !$self->catalyst_plugins->{$p} ) {
			$self->_load_catalyst_plugin($p);
			$self->catalyst_plugins->{$p} = 1;
		} else {
			$self->log(" - Catalyst plugin $p already loaded !");
		}
	}
}

sub _load_catalyst_plugin {
	my ( $self, $plugin ) = @_;

	$self->log("  - Add Catalyst plugin $plugin\n");

	my $isa = do { no strict 'refs'; \@{ $self->ctx . '::ISA' } };
	my $isa_idx = 0;
	$isa_idx++ while $isa->[$isa_idx] ne 'Catalyst'; #__PACKAGE__;


	if ( $plugin !~ s/^\+(.*)/$1/ ) { $plugin = 'Catalyst::Plugin::' . $plugin }

	Catalyst::Utils::ensure_class_loaded($plugin);
	$self->ctx->_plugins->{$plugin} = 1;

	my $meta = find_meta($plugin);

	if ( $meta && blessed $meta && $meta->isa('Moose::Meta::Role') ) {
		apply_all_roles( $self->ctx => $plugin );
	} else {
		splice @$isa, ++$isa_idx, 0, $plugin;
	}

	unshift @$isa, shift @$isa; # necessary to tell perl that @ISA changed
	mro::invalidate_all_method_caches();

	{

		# ->next::method won't work anymore, we have to do it ourselves
		my @precedence_list = $self->ctx->meta->class_precedence_list;

		1 while shift @precedence_list ne 'Catalyst'; #__PACKAGE__;

		my $old_next_method = \&maybe::next::method;

		my $next_method = sub {
			if ( ( caller(1) )[3] !~ /::setup\z/ ) {
				goto &$old_next_method;
			}

			my $code;
			while ( my $next_class = shift @precedence_list ) {
				$code = $next_class->can('setup');
				last if $code;
			}
			return unless $code;

			goto &$code;
		};

		no warnings 'redefine';
		local *next::method        = $next_method;
		local *maybe::next::method = $next_method;

		return $self->ctx->next::method(@_);
	}
}


sub _load_template {
	my ( $self, $module ) = @_;

    foreach my $dir ( 'root/src', 'root/lib') {

        my $template_dir = $module->{path} . "/$dir";

        if ( -d $template_dir ) {
            $self->log("  - Add template directory $template_dir") if $debug;
            $module->{template_dir} = $template_dir;

            # TODO: Template directory for all views (???)
            foreach my $viewfile ( @{$self->_views} ) {
                $viewfile =~ /\/View\/(\w*)\.pm/;
                push( @{ $self->ctx->view($1)->config->{INCLUDE_PATH} }, $template_dir );
            }
        }
    }
}


sub _load_static {
    my ( $self, $module ) = @_;

    my $static_dir = $module->{path} . "/root/static";


    if ( -d $static_dir ) {
        $self->log("  - Add static directory") if $debug;
        $module->{static_dir} = $static_dir;
        push(@{$self->_static_dirs}, $static_dir);
    }
}

sub _load_component {
	my ( $self, $module, $file ) = @_;

	my $libpath = $module->{path} . '/lib';
	my $comp    = $file;
	$comp =~ s|$libpath/||;
	$comp =~ s|\.pm$||;
	$comp =~ s|/|::|g;

    my $into = $self->ctx;
    my $as  = $comp;
    $as =~ s/.*(Model|View|Controller):://;
	$self->log("  - Add Component into: $into comp:$comp as:$as");

    Catalyst::Utils::inject_component( into => $into,
                                       component => $comp,
                                       as => $as );

}

sub _search_in_path {
	my $self  = shift;
    my $path  = shift;
	my $regex = shift;

	my @files;
	my $tf_finder = sub {
		return if !-f;
		return if !/$regex/;

		my $file = $File::Find::name;
		push @files, $file;
	};

    find( $tf_finder, $path  );
	return \@files;
}


=head1 NAME

CatalystX::InjectModule::MI Catalyst Module injector

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head2 resolv

=head2 get_module

=head2 load

=head2 inject

=head2 log

=head2 modules_to_inject




=head1 AUTHOR

Daniel Brosseau, C<< <dabd at catapulse.org> >>

=cut

1;

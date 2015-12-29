package Fixture;

use Moose;
with 'CatalystX::InjectModule::Fixture';

sub install {
    my ($self, $module, $mi) = @_;

    $self->install_fixtures($module, $mi);
}

1;

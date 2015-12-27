package Install;

use Moose;


sub install {
    my ($self, $module, $mi ) = @_;
    $module->{installed} = 1;
}

1;

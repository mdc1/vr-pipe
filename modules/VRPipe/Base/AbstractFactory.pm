# stolen directly from MooseX::AbstractFactory

package VRPipe::Base::AbstractFactory;
use strict;
use warnings;

use Moose ();
use Moose::Exporter;
use VRPipe::Base::AbstractFactoryRole;
use VRPipe::Base::AbstractFactoryMetaClass;

# syntactic sugar for various tricks
Moose::Exporter->setup_import_methods(
    with_caller => ['implementation_does', 'implementation_class_via'],
    also        => 'Moose',
);

sub implementation_does {
    my ($caller, @roles) = @_;
    $caller->meta->implementation_roles(\@roles);
    return;
}

sub implementation_class_via {
    my ($caller, $code) = @_;
    $caller->meta->implementation_class_maker($code);
    return;
}

sub init_meta {
    my ($self, %options) = @_;
    
    Moose->init_meta(%options, metaclass => 'VRPipe::Base::AbstractFactoryMetaClass');
    
    Moose::Util::MetaRole::apply_base_class_roles(
        for_class => $options{for_class},
        roles     => ['VRPipe::Base::AbstractFactoryRole'],
    );
    
    return $options{for_class}->meta();
}

1;

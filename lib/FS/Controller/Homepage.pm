package FS::Controller::Homepage;
use Mojo::Base 'Mojolicious::Controller';

use FS::Object::Path;
use FS::Object::Solr;

sub default {
    my $self = shift;


    $self->render();
}

1;

package FS::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

use FS::Object::Path;
use FS::Object::Search;

sub default {
    my $self = shift;

    my $resultset = FS::Object::Search
        ->new
        ->solr($self->solr)
        ->search(
            query => $self->param('query'),
            rows  => 200,
        );
    
    $self->render(
        resultset => $resultset,
    );
}

1;

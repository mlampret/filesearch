package FS::Controller::Indexer;
use Mojo::Base 'Mojolicious::Controller';

use FS::Object::Indexer;
use FS::Object::Path;
use FS::Object::Solr;

use Mojo::DOM;
use Mojo::IOLoop;

sub default {
    my $self = shift;

    my $dir_url = 'http://dl5.downloadha.com/Behnam/2015/April/SoftWare/';
    $dir_url = 'http://video.ame4u.com/mp4-iwalk/iWalkInformativeVideos/';
    $dir_url = 'http://www.epatha.com/music/70s/';
    $dir_url = 'http://newcenstein.com/mp3/Album/';
    $dir_url = 'http://www.atgrandmashouse.com/mp3/';
    $dir_url = 'http://donyayeiran.com/contents/';
    $dir_url = 'http://donyayeiran.com/contents/video/';

    my $time_broken_max  = time - 3600 * 24 * 14;
    my $time_updated_max = time - 3600 * 24 * 14;

    my $unprocessed_docs = $self->solr->docs(
        'q' => "type:dir "
             . "AND ((-time_broken:[* TO *] AND *:*) OR time_broken:[0 TO $time_broken_max]) "
             . "AND ((-time_updated:[* TO *] AND *:*) OR time_updated:[0 TO $time_updated_max]) ",
        'sort' => 'time_updated asc, time_created asc',
        'group' => 'true',
        'group.sort' => 'time_updated asc, time_created asc',
        'group.main' => 'true',
        'group.field' => 'authority',
        'rows' => '200',
    )->to_array;

    my @unprocessed_paths = map { FS::Object::Path->new->from_hash($_) } @$unprocessed_docs;

    $self->render(
        unprocessed_paths => \@unprocessed_paths,
    );
}

sub add_url {
    my $self = shift;

    $self->indexer->process($self->param('url'));

    $self->redirect_to('indexer');
    #return $self->default();
}

sub delete_url {
    my $self = shift;

    $self->solr->delete(id => $self->param('id') || '-1');

    $self->redirect_to('indexer');
}

sub do_more {
    my $self = shift;

    $self->indexer->process_unavailable_dirs();

    $self->redirect_to('indexer');
}

1;

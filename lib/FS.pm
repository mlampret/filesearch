package FS;
use Mojo::Base 'Mojolicious';

use FS::Object::Indexer;
use FS::Object::Solr;

sub startup {
    my $self = shift;

    push @{$self->commands->namespaces}, 'FS::Command';

    $self->plugin('Config', {file => 'fs.conf'});
    $self->plugin('VersionDir' => {version => '108'});

    $self->helper( solr => sub {
        FS::Object::Solr->new(core_url => 'http://localhost:8080/solr/fs');
    });

    $self->helper( indexer => sub {
        my $self = shift;

        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(7);
        $ua->inactivity_timeout(15);
        $ua->request_timeout(20);
        $ua->max_redirects(1);
        $ua->transactor->name('Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36');

        return FS::Object::Indexer->new(
            solr => $self->solr,
            ua   => $ua,
        );
    });

    my $r = $self->routes;
    $r->get('/')->to('homepage#default');
    $r->get('/search')->to('search#default');
    $r->get('/indexer')->to('indexer#default');
    $r->any('/indexer/add_url')->name('indexer_add_url')->to('indexer#add_url');
    $r->any('/indexer/delete_url')->name('indexer_delete_url')->to('indexer#delete_url');
    $r->get('/indexer/do_more')->name('indexer_do_more')->to('indexer#do_more');
}

1;

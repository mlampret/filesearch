package FS::Command::indexer;

use Encode qw(decode encode);
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(url_unescape);

use FS::Object::Path;

has description => 'indexer';
has usage       => "Usage: APPLICATION indexer [daemon|process]\n";

sub run {
    my ($self, $action, @args) = @_;

    $self->$action(@args);
}

sub daemon {
    my $self = shift;
    my @args = @_;

    my $i = 0;
    while ($i++ < 5000) {
        $self->app->indexer->process_unavailable_dirs();
        print "Processing unavailable dirs: $i\n";
        sleep int(rand(10));        
    }

    return 1;
}

sub process {
    my $self = shift;
    my @args = @_;

    $self->app->indexer->process($args[0]);

    return 1;
}

1;

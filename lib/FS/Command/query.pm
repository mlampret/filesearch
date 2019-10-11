package FS::Command::query;

use Encode qw(decode encode);
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(url_unescape);

use FS::Object::Path;

has description => 'run solr query';
has usage       => "Usage: APPLICATION query [delete] '<query>'\n";

sub run {
    my ($self, $action, @args) = @_;

    $self->$action(@args);

    print "Done\n";
}

sub delete {
    my $self = shift;
    my @args = @_;

    my %cond = ();
    for my $cond (split /\s+AND\s+/, $args[0]) {
        my ($field, $value) = split /\:/, $cond, 2;
        $cond{$field} = $value;
    }

    print $self->app->solr->delete(%cond);
    $self->app->solr->commit;
    
    return 1;
}

1;





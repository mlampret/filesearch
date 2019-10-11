package FS::Command::try;

use Encode qw(decode encode);
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(url_unescape b64_encode sha1_bytes sha1_sum);

use FS::Object::Path;

has description => 'try different things';
has usage       => "Usage: APPLICATION try [action]\n";

sub run {
    my ($self, $action, @args) = @_;

    $self->$action(@args);

    print "Done\n";
}

sub url {
    my $self = shift;

    return 1;
}

sub unescape {
    my $self = shift;
    my @args = @_;

    print $args[0]."\n";
    print url_unescape($args[0])."\n";
    print url_unescape( Mojo::URL->new($args[0])->to_string )."\n";

    my $path = FS::Object::Path->new(solr => $self->app->solr);

    $path->from_url($args[0])->id('test');
    my $dir = decode('UTF-8', $path->dir);
    $path->dir($dir);
    $path->delete;
    print $path->to_url_unescaped."\n";
    
    return 1;
}


sub compare_ids {
    my $self = shift;
    my @args = @_;

    my $p1 = FS::Object::Path->new(solr => $self->app->solr)->id($args[0])->load;
    my $p2 = FS::Object::Path->new(solr => $self->app->solr)->id($args[1])->load;

    use Data::Dumper;
    
    warn Dumper $p1;
    warn Dumper $p2;

    $p1->generate_id;
    $p2->generate_id;
    
    warn Dumper $p1;
    warn Dumper $p2;

}

1;





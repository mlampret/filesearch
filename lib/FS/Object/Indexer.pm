package FS::Object::Indexer;

use Mojo::Base -base;
use Mojo::Path;
use Mojo::URL;
use Term::ANSIColor;
use Time::HiRes qw(usleep);


use FS::Object::Bot;
use FS::Object::Path;

has solr => undef;
has ua   => undef;

sub bot {
    my $self = shift;
    return FS::Object::Bot->new(
        solr => $self->solr,
        ua   => $self->ua,
    );
}

sub process {
    my $self = shift;
    my @args = shift;

    $self->bot->process($args[0]);
}

sub process_unavailable_dirs {
    my $self = shift;

    my $process_max = 1000;

    my @paths = $self->get_unavailable_dirs();

    my $cnt = 0;
    while (scalar @paths) {
        while (my $path = shift @paths) {

            my $orig_id = $path->id;
            my $new_id  = $path->generate_id->id;

            if ($orig_id ne $new_id) {
                $path->id($orig_id)->solr($self->solr)->delete;                
                print "\n".color('black on_red')."\n";
                print "Invalid ID > DELETED: ";
                print $path->to_url_unescaped."\n";
                print "Old: $orig_id\nNew: $new_id";
                print color('reset')."\n\n";
            }

            $self->bot->process($path->to_url_escaped);
            usleep 200;
            last if ++$cnt >= $process_max;
        }
        last if ++$cnt >= $process_max;
        @paths = $self->get_unavailable_dirs();
        my $sleep =  int(1 / (1 + scalar @paths) * 200);
        warn "\nWaiting $sleep sec before searching again...\n";        
        sleep $sleep;
    }
}

sub get_unavailable_dirs {
    my $self = shift;

    my $time_broken_max  = time - 3600 * 24 * 14;
    my $time_updated_max = time - 3600 * 24 * 14;

    my $res = $self->solr->select(
        'q' => "type:dir "
             . "AND ((-time_broken:[* TO *] AND *:*) OR time_broken:[0 TO $time_broken_max]) "
             . "AND ((-time_updated:[* TO *] AND *:*) OR time_updated:[0 TO $time_updated_max]) ",
        'sort' => 'time_updated asc, time_created asc',
        'group' => 'true',
        'group.sort' => 'time_updated asc, time_created asc',
        'group.main' => 'true',
        'group.field' => 'authority',
        'rows' => '1000',
    );

    return () unless
        $res &&
        $res->{response} &&
        $res->{response}->{docs} &&
        $res->{response}->{docs}->[0];

    my @paths = ();
    for my $doc (@{ $res->{response}->{docs} }) {
        push @paths, FS::Object::Path->new->from_hash($doc);
#        warn  $paths[-1]->id . " " . $paths[-1]->to_url_unescaped."\n";
    }

    return @paths;
}

1;


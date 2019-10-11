package FS::Command::loop;

use Encode qw(encode decode is_utf8);
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(url_unescape);

use FS::Object::Path;

has description => 'Loop through all the documents and perform an action on each';
has usage       => "Usage: APPLICATION loop [action]\n";

sub run {
    my ($self, @args) = @_;

    my $count_all = 0;
    my $count_result = 0;
    my @unprocessed_paths = ();

    do {
        my $unprocessed_docs = $self->app->solr->docs(
            'q'    => '*:*',
            'start'=> $count_all,
            'rows' => 100,
            'sort' => 'time_updated desc',
        )->to_array;

        @unprocessed_paths = map { FS::Object::Path->new->from_hash($_) } @$unprocessed_docs;

        $self->app->solr->auto_commit(0);

        for my $path (@unprocessed_paths) {
            my $action = $args[0];
            $count_result += $self->$action($path);
            $count_all++;
        }

        $self->app->solr->commit;
        $self->app->solr->auto_commit(1);

        print "Loop commit: $count_all\n";

    } while scalar @unprocessed_paths > 0;

    print "Result count: $count_result\n";

}

sub print {
    my $self = shift;
    my $path = shift;

    print $path->id."\n";
    print url_unescape($path->to_url_unescaped)."\n\n";

    return 1;
}

sub unescape {
    my $self = shift;
    my $path = shift;

    unless ($path->to_url_unescaped) {
        print "NO URL: ". $path->id."\n";
        $path->solr($self->app->solr)->delete;
        return 1;
    }

    return 0 unless $path->to_url_unescaped =~ m!\%[A-Z0-9]{2}!;

    $path->dir(url_unescape $path->dir);
    $path->name(url_unescape $path->name) if $path->name;
    $path->extension(url_unescape $path->extension) if $path->extension;
    $path->solr($self->app->solr);
    $path->save;

    print $path->id." - ".$path->to_url_unescaped."\n\n";
    
    return 1;
}

sub reindex {
    my $self = shift;
    my $path = shift;

    $path->solr($self->app->solr)->save;

    print $path->id." - ".$path->to_url_unescaped."\n\n";
    
    return 1;
}

sub fix_encoding {
    my $self = shift;
    my $old = shift;

    if (length $old->id < 30) {
        print "Skip: ".$old->id."\n";
        return 0;
    }

    my $new = FS::Object::Path
        ->new
        ->solr($self->app->solr)
        ->from_url($old->to_url_escaped_old)
        ->type($old->type)
        ->generate_id()
        ->time_created($old->time_created)
        ->time_updated($old->time_updated)
        ->time_available($old->time_available);
        

    if ($old->to_url_escaped ne $old->to_url_escaped_old) {
        print "FIX: ".$old->to_url_escaped."\n";
        print " TO: ".$old->to_url_escaped_old."\n";
    }

    print "ID: ".$old->id ." >> ". $new->id."\n";

    $old->solr($self->app->solr)->delete;
    $new->save;

    return 1;
}

sub fix_times {
    my $self = shift;
    my $path = shift;

    return 0 if $path->time_created;

    $path->time_created(time);
    $path->time_updated(time);
    $path->time_available(time);

    my $type = $path->dir && ! $path->name && ! $path->extension
        ? 'dir'
        : 'file';

    $path->type($type) unless $path->type;

    $path->solr($self->app->solr);

    $path->save;

    return 1;
}

1;





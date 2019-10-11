package FS::Object::Bot;

use Mojo::Base -base;
use Mojo::Path;
use Mojo::Util qw(url_unescape url_escape);
use Mojo::URL;
use Encode qw(is_utf8);
use Term::ANSIColor;

use FS::Object::Solr;
use FS::Object::Path;

has solr => undef;
has ua   => undef;

sub process {
    my $self = shift;
    my $start_url = shift;

    # start_url: should be ESCAPED !!

    # TODO: check if it is escaped

    my $start_url_escaped   = $start_url;
    my $start_url_unescaped = url_unescape($start_url);
 
    my $path = Mojo::URL->new($start_url_escaped)->path('../')->path->canonicalize;
    $path =~ s!/../!/!;

    my $start_parent_url_escaped   = Mojo::URL->new($start_url_escaped)->path($path)->to_string;
    my $start_parent_url_unescaped = url_unescape $start_parent_url_escaped;

#    use utf8;
#    print "$start_parent_url_unescaped \n";
#    print "Is utf8: " . utf8::is_utf8( $start_parent_url_unescaped ) . "\n";

    my @valid_urls = ();
    my @invalid_urls = ();

    my $time = time;
    my $tx   = $self->ua->get($start_url_escaped);
    my $dom  = Mojo::DOM->new( $tx->res->body );
    my $authority = Mojo::URL->new($start_url_escaped)->host;    
    my $tx_code = $tx->res->code || '???';

    $self->output('bold white', "\n\n".$tx_code.' '.$start_url_escaped);

    $self->solr->auto_commit(0);

    if (!$tx->res->code) {

        my $path = FS::Object::Path->new(solr => $self->solr)
            ->from_url($start_url_escaped)
            ->generate_id
            ->load
            ->time_updated($time)
            ->save;

        my $coll = $self->solr->docs(
            'q' => qq{ authority:"$authority" AND -time_broken:* },
            'rows' => 3000,
        );

        $coll->each(sub {
            my $res = $_;
            my $this_path = FS::Object::Path->new(solr => $self->solr)->id($res->{id});
            $this_path->load->time_broken($time)->save;
            $self->output('yellow', 'ERC', $this_path);
        });        
        $self->solr->commit;
        return;
    }

    elsif (! $self->is_index_of($dom)) {
        my $path = FS::Object::Path->new(solr => $self->solr)
            ->from_url($start_url_escaped)
            ->generate_id
            ->load
            ->type('unknown')
            ->time_updated($time);

        
        if ($path->time_broken) {
            $path->save;
            $self->output('bright_black', "Already marked as broken");
            return $self;
        }

        $path->time_created($time) unless $path->time_created;
        $path->time_broken($time);
        $path->save;

        # disable siblings
        my $path_dir = $path->dir;
        my $coll = $self->solr->docs(
            'q' => qq{ authority:"$authority" AND dir:"$path_dir" AND -time_broken:* },
            'rows' => 1000,
        );

        $coll->each(sub {
            my $res = $_;
            my $this_path = FS::Object::Path->new(solr => $self->solr)->id($res->{id})->load;               
            return if $this_path->dir ne $path_dir;
            $this_path->time_broken($time)->save;
            $self->output('yellow', 'BRK', $this_path);
        });

        $self->solr->commit;
        $self->solr->auto_commit(1);

        return $self;
    }

    $dom->find('a')->each(sub {
        my $a = $_;
        my $href = $a->attr('href');
        my $url = Mojo::URL->new($start_url_escaped);

        return if $href =~ m!(ht|f)tps?://!i;
        return if $href =~ m!^mailto:!i;

        my $href_unescaped = url_unescape $href;
        #$href =~ s!/\.\.?$!/! if ($href =~ m!/\.\.$! || $href_unescaped =~ m!/\.\.$!);

        my $href_abs = '';

        if ($start_url_escaped =~ m!/$! && $href !~ m!^/!) {
            $href_abs = Mojo::URL->new($start_url_escaped . $href)->path->to_string;
        } else {
            # This convert some characters (%ee) to 2 bytes (%c3$ae).
            my $href_abs = $url->clone->path->merge($href);
        }

        $href_abs =~ s!(/[^/]+)?/\.\./$!/!g;
        $href_abs =~ s!/\./!/!g;

        #my $slash = $start_url_unescaped =~ m!/$! ? '' : '/';

        $href_unescaped =~ m!^/!
            ? $url->path( $href )
            : $url->path( $href_abs );

        my $has_query = $href_unescaped =~ m!\?! ? 1 : 0;

        my $contains_parent = 0;
        # TODO: is this working
        $contains_parent = 1 if substr(url_unescape($url->to_string), 0, length($start_parent_url_unescaped) - 1);
        eval { $contains_parent = 1 if url_unescape($url->to_string) =~ m!^$start_parent_url_unescaped! };
        $contains_parent = 1 if !$contains_parent && ($url->to_string) =~ m!^$start_parent_url_escaped!;        

        my @oct1 = split /\s+/, to_oct( $start_parent_url_unescaped );
        my @oct2 = split /\s+/, to_oct( url_unescape($url->to_string) );

        my $oct_eq = 1;
        for my $i (0..scalar(@oct1)-1) {
            $oct_eq = 0 if $oct1[$i] != $oct2[$i];
        }
        $contains_parent = 1 if $oct_eq;

#        unless ($has_query) {
#            warn $start_parent_url_unescaped."\n";
#            warn url_unescape($url->to_string)."\n";
#            warn "Contains parent: ".$contains_parent."\n\n";
#        }

        my $contains_abs_url = $url->to_string =~ m!/(ht|f)tps?://! ? 1 : 0;

#        warn "A: $href_abs\n";
#        warn "U: ".$url->to_string."\n";

        $contains_parent && $self->is_valid_url($url) && ! $has_query && ! $contains_abs_url
            ? push @valid_urls, $url
            : push @invalid_urls, $url;
    });

    $self->output('bright_black', "valid  urls: ".scalar(@valid_urls));

    $start_url .= '/' unless $start_url =~ m!/$!;
    unshift @valid_urls, Mojo::URL->new($start_url_escaped) if scalar @valid_urls;

    my @valid_ids = ();

    for my $url (@valid_urls) {
        my $type = $url->to_string =~ m!/$! ? 'dir' : 'file';
        my $path = FS::Object::Path->new(solr => $self->solr)
            ->from_url($url)
            ->generate_id
            ->load
            ->type($type);

#        warn "Created: ".($path->time_created || '<undef>')."\n";

        my $color = $path->time_created || 0 > 0 ? 'green' : 'bright_green';

        $path->time_available(undef);
        $path->time_broken(undef);
        $path->time_updated($time) if $path->time_created || 0 > 0 && $type eq 'file';
        $path->time_created($time) unless $path->time_created || 0 > 0;

#        warn "Updated: ".($path->time_updated || '<undef>')."\n";


        $self->output($color, 'OK ', $path);

        $path->save;

        push @valid_ids, $path->id;
    }

    if (scalar @valid_ids > 1) {
        my $authority = Mojo::URL->new($start_url_escaped)->host;

        my $coll = $self->solr->docs(
            'q' => qq{ authority:"$authority" AND dir:"$path" },
            'sort' => 'time_created asc',
            'rows' => 1000,
        );

        $coll->each(sub {
            my $res = $_;
            return if $res->{dir} ne Mojo::URL->new($start_url_escaped)->path->canonicalize->to_string;

            my $this_path = FS::Object::Path->new(solr => $self->solr)->id($res->{id});

            unless (grep { $this_path->id eq $_ } @valid_ids) {
                $self->output('red', 'DEL', $this_path->load);
                $this_path->delete;
            }
        });
    }

    $self->solr->commit;
    $self->solr->auto_commit(1);

    # TODO: handle files (when $start_url points to a file)
    # TODO: check one with http HEAD

    return $self;
}

sub is_index_of {
    my $self = shift;
    my $dom  = shift;

    my $result = 1;

    $result = 0 if $dom->find('link[rel=stylesheet]')->size;
    $result = 0 unless $dom->find('title')->size;
    $dom->find('title')->each(sub {
        $result = 0 unless $_->text =~ m!^Index of /! || $_->text =~ m!/[^\s]+/!i
    });

    $self->output('bright_black', "is index of: $result");

    return $result;
}

sub is_valid_url {
    my $self = shift;
    my $url  = shift;

    my $result = 1;

    $result = 0 if $url->query->to_string;

    return $result;
}


sub to_oct {
    my $oct = '';
    ($oct.= ord($_)." ") for split //, $_[0];
    return $oct;
}

sub output {
    my $self = shift;
    my $color = shift;
    my $text = shift;
    my $path = shift;

    print color($color || 'gray').$text.color('reset');
    print " ".$path->id." ".($path->to_url_escaped || '???') if $path;
    print color('reset')."\n";
}

1;


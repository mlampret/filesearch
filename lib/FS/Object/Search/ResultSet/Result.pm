package FS::Object::Search::ResultSet::Result;

use Encode qw(encode decode is_utf8);
use DateTime;
use Mojo::Base -base;
use Mojo::URL;
use Mojo::Util qw(md5_sum url_escape url_unescape);

use FS::Object::Search::ResultSet::Result::Type;

has path  => undef;
has query => undef;

sub type {
    FS::Object::Search::ResultSet::Result::Type->new->type($_);
}

sub title {
    my $self = shift;

    my @url_all = (split(/\//, $self->path->dir), $self->path->name);
    my @url = grep { $_ if $_ } @url_all;

    my @title = ();
    push @title, pop @url;

    my $words = {};
    for my $word (split /\s/, $self->query) {
        next unless $word;
        next if $word =~ m!^\.!;
        next if index(lc($title[-1]), lc($word)) + 1;
        $word =~ s![-\*\.]!!;
        $words->{$word} = 1;
    }

    for my $elt (reverse @url) {
        next unless $elt;
        for my $word (keys %$words) {
            next unless $word;
            my $word_found = index(lc($elt), lc($word)) + 1;
            if ($word_found) {
                push @title, $elt;
                delete $words->{$word} if $word_found;
                last;
            }
        }
    }
    
    for my $title (@title) {
#        $title = decode('UTF-8', $title);
        $title =~ s![_]! !isg;
        $title =~ s!(\S)\-(\S)!$1 - $2!isg;
        $title =~ s!^\(?[\s\-\d\.]+\)?!!isg if length $title > 20;
        $title = substr($title, 0, 60) . '...' if length $title > 65;
        $title = ucfirst(lc $title) if (uc $title eq $title);
    }

    my @short_title = ();
    for my $title (@title) {
        push @short_title, $title if _array_length(@short_title, $title) < 80;
    }

    my $title = join " - ", reverse @short_title;

    $title ||= $self->path->name;

    return $title;
}


sub links {
    my $self = shift;

    my @links = ();

    push @links, {
        title => $self->path->authority,
        url   => $self->path->protocol.'://'.$self->path->authority,
    };

    for my $dir (split(/\//,$self->path->dir)) {
        next unless $dir;
        my $dir_title = $dir;
        $dir_title =~ s![_]! !isg;
        $dir_title = substr($dir_title, 0, 30) . '...' if length $dir_title > 35; 
        push @links, {
            title => $dir_title,
            url   => $links[-1]->{url} . "/$dir",
        };
    }

    my $deleted = undef;
    for (1..scalar(@links)-1) {
        if (_array_length(map { $_->{title} } @links) > 80) {
            $deleted = splice(@links, 1, 1);
        }
    }
    if ($deleted) {
        splice @links, 1, 0, {
            title => '...',
            url   => $deleted->{url},
        };
    }

    map { $_->{url} = Mojo::URL->new($_->{url})->to_string } @links;

    return @links;
}

sub time_created {
    my $self = shift;

    my $dt = DateTime->from_epoch(epoch => $self->path->time_created);

    return $dt->strftime('%d %b %Y');
}

sub _array_length {
    my $length = 0;
    map { $length += length $_ } @_;
    return $length;
}

1;


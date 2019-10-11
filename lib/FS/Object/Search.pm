package FS::Object::Search;

use Encode qw(encode decode is_utf8);
use Mojo::Base -base;
use Mojo::Collection;
use Mojo::URL;
use Mojo::Util qw(md5_sum url_unescape);

use FS::Object::Solr;
use FS::Object::Search::ResultSet;
use FS::Object::Search::ResultSet::Result;
use FS::Object::Search::ResultSet::Result::Type;

has solr  => undef;

sub search {
    my $self = shift;
    my $args = { @_ };

    my @words = ();    
    my @extensions = ();
    my @fields = ();

    my $query = $args->{query};

    $query =~ s!^\s+!!;
    $query =~ s!\s+$!!;
    #$query =~ s!\w\.\w!. !;
    $query =~ s!\s+! !;
    
    my $groups = FS::Object::Search::ResultSet::Result::Type->new->groups;

    for my $group (keys %$groups) {
        my $extensions = join ' ', map { '.'.$_ } @{ $groups->{$group} };
        $query =~ s!=$group!$extensions!ig;
    }

    for my $string (split /\s+/, $query) {
        if ($string =~ m!(-)?(authority|path|name|extension):(.+)!) {
            push @fields, [ "$1$2" => $3 ];
        } elsif ($string =~ m!^\.(.+)$!) {
            push @extensions, $1;
        } else {
            push @words, $string;
        }
    }

    my @ands = ();

    push (@ands, "$_->[0]:$_->[1]") for @fields;

    for my $word (@words) {
        my $neg = $word =~ m!^\-! ? '-' : '';
        my $op  = $neg ? 'AND' : 'OR';
        $word =~ s!^\-+!!;
        push @ands, 
            ($neg ? '' : "(").
            $neg."dir:$word $op ".$neg."name:$word $op ".$neg."extension:$word".
            ($neg ? '' : ')');
    }

    push @ands, '('.join(" OR ", map { "extension:$_"} @extensions).')' if scalar @extensions;

    push @ands, "(*:* NOT time_broken:[* TO *])";

    my $q = join ' AND ', @ands;

    warn $q;

    my $res = $self->solr->select(
        'q' => $q,
        'sort'  => 'time_created desc',
        'rows'  => $args->{rows} || 200,
#        'facet' => 'true',
#        'facet.field' => ['domain', 'extension'],
#        'facet.limit' => '10',
#        'facet.mincount' => 1,
    );
    
    my @results = map {
        FS::Object::Search::ResultSet::Result->new->query($query)->path(
            FS::Object::Path->new->from_hash($_)
        )
    } @{ $res->{response}->{docs} };


    my $resultset = FS::Object::Search::ResultSet->new->query($query);
    $resultset->total($res->{response}->{numFound});
    $resultset->results( Mojo::Collection->new(@results) );

    return $resultset;
}

1;


package FS::Object::Path;

use Encode qw(encode decode is_utf8);
use Encode::Guess qw(Windows-1252);
use URI::Escape qw(uri_unescape uri_escape);
use utf8;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::Util qw(md5_sum url_escape url_unescape sha1_sum sha1_bytes b64_encode);

use FS::Object::Solr;

my @fields = qw(
    id
    time_created
    time_updated
    time_available
    time_broken
    protocol
    authority
    dir
    name
    extension
    url
    size
    type
);

has ['solr', @fields] => undef;


sub from_hash {
    my $self = shift;
    my @hash = @_;
    my $hash = ref $hash[0] ? $hash[0] : { @hash };

    for my $field (@fields) {
        $self->$field($hash->{$field}) if defined $hash->{$field};
    }

    return $self;
}

sub from_url {
    my $self = shift;
    my $url  = shift;

    my $orig_url = undef;

    if (ref $url) {
        $orig_url = $url->to_string;
    } else {
        $orig_url = $url;
        $url = Mojo::URL->new($url);
    }

    my $encoding = $self->_is_escaped_utf8($orig_url) ? 'UTF-8' : 'Guess';

    my $path = '';

    eval {
        $Encode::Guess::NoUTFAutoGuess = 1;
        $path = decode($encoding, url_unescape($url->path) );
    };
    $path = url_unescape($url->path) if $@;

    my $dir = $path;
    $dir =~ s!/[^/]*$!/!;

    my $file = substr($path, length($dir));

    my $name = $file;
    $name =~ s!\.[^\.]+$!!;

    my $extension = length($name) < length($file)
        ? substr($file, length($name) + 1)
        : undef;

    $self
        ->protocol($url->protocol)
        ->authority(url_unescape $url->authority)
        ->dir($dir)
        ->name($name)
        ->extension($extension);

    unless ($encoding eq 'UTF-8') {
        $self->url($orig_url);
        warn "NON-UTF8 url: $orig_url";
    }

    return $self;
}

sub to_url {
    my $self = shift;

    # THIS SEEMS WRONG, should be to_url_escaped !!!
    return Mojo::URL->new($self->to_url_unescaped);
}

sub to_url_escaped {
    my $self = shift;

    return $self->url if $self->url;

    return undef unless
        $self->protocol &&
        $self->authority;

    my $url = $self->protocol . '://' . $self->authority;
    
    my $rel = $self->dir || '';
    $rel .= $self->name if $self->name;
    $rel .= '.' . $self->extension if $self->extension;

    my $ends_with_slash = substr($rel, -1) eq '/';

    $url .= join '/', map { url_escape(encode('UTF-8', $_)) } split(/\//, $rel);
    
    # This seems wrong
    # $url .= '/' if $self->type && $self->type eq 'dir' && ! $self->name && ! $self->extension;

    $url .= '/' if $ends_with_slash;

    return encode('UTF-8', $url);
}

sub to_url_escaped_old {
    my $self = shift;

    return undef unless
        $self->protocol &&
        $self->authority &&
        $self->dir;

    my $url = $self->protocol . '://' . $self->authority;
    
    my $rel = $self->dir;
    $rel .= $self->name if $self->name;
    $rel .= '.' . $self->extension if $self->extension;

    $url .= join '/', map { url_escape($_) } split(/\//, $rel);
    
    $url .= '/' if $self->dir =~ m!/$! && ! $self->name && ! $self->extension;

    return $url;
}

sub to_url_unescaped {
    my $self = shift;

    return undef unless
        $self->protocol &&
        $self->authority &&
        $self->dir;

    my $url = $self->protocol . '://' . $self->authority . $self->dir;

    $url .= $self->name if $self->name;
    $url .= '.' . $self->extension if $self->extension;

    return $url;
}

sub generate_id {
    my $self = shift;

    #my $path_str = join '', map { $self->$_ || '' } qw(protocol authority dir name extension);
    #$self->id(md5_sum encode('UTF-8', $path_str));

    my $id = b64_encode(sha1_bytes $self->to_url_escaped);
    $id =~ s!\=\n?$!!;
    $id =~ tr[+/][-_];
    $self->id($id);

#    warn "GID: ".$self->to_url_escaped."\n";
#    warn "GID: ".$id."\n";

    return $self;
}

sub id_old {
    my $self = shift;

    my $path_str = join '', map { $self->$_ || '' } qw(protocol authority dir name extension);
    return md5_sum encode('UTF-8', $path_str);
}

sub load {
    my $self = shift;
    my %args = @_;

    my $res = $self->solr->select(
        'q' => 'id:"'.$self->id.'"',
    );

    return $self unless
        $res &&
        $res->{response} &&
        $res->{response}->{docs} &&
        $res->{response}->{docs}->[0];

    my $doc = {};

    if ($args{fields}) {
        for my $field (@{$args{fields}}) {
            $doc->{$field} = $res->{response}->{docs}->[0]->{$field};
        }
    } else {
        $doc = $res->{response}->{docs}->[0];
    }

    $self->from_hash( $doc );

    return $self;
}

sub save {
    my $self = shift;

    $self->generate_id unless $self->id;

    my $doc    = ();
    $doc->{$_} = ($self->$_ || undef) for @fields;

    return undef unless $self->solr->update(%$doc);
    return $self;
}

sub delete {
    my $self = shift;

    $self->generate_id unless $self->id;

    $self->solr->delete(id => $self->id);
}

# sub update_from_remote {
#    my $self = shift;
#
#    return $self;
#}
#
#sub update_from_head {
#    my $self = shift;
#
#    return $self;
#}

sub parent {
    my $self = shift;

}

sub children {
    my $self = shift;

}

sub _is_escaped_utf8 {
    my $self = shift;    
    my $orig = shift;

    $orig =~ s!/! !isg;

    my $unescaped = uri_unescape $orig;
    my $decoded = decode 'UTF-8', $unescaped;
    my $encoded = encode 'UTF-8', $decoded;
    my $escaped = uri_escape $encoded;

    my $result = $unescaped eq $encoded ? 1 : 0;
    return $result;
}

1;


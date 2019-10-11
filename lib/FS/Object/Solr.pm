package FS::Object::Solr;

use Mojo::Base -base;
use Mojo::ByteStream 'b';
use Mojo::Collection;
use Mojo::JSON 'j';
use Mojo::URL;
use Mojo::UserAgent;

has core_url => '';
has auto_commit => 1;

sub update {
    my $self = shift;
    my %args = @_;

    my $doc = {};
    $doc->{add}->{overwrite} = Mojo::JSON->true;
    $doc->{add}->{doc} = \%args;

    my $url = $self->core_url.'/update/json';
    my $res = Mojo::UserAgent->new->post($url => json => $doc)->res;
    $self->commit if $self->auto_commit;

    return $res->body;    
}

sub delete {
    my $self = shift;
    my %args = @_;

    my @cond = ();
    for my $key (keys %args) {
        push @cond, "($key:\"$args{$key}\")";
    }

    my $url = Mojo::URL->new($self->core_url.'/update');
    $url->query(
        'stream.body' => '<delete><query>id:'. join('AND', @cond) . '</query></delete>',
    );
    my $res = Mojo::UserAgent->new->get($url->to_string)->res;
    $self->commit if $self->auto_commit;

    return $res->body;
}

sub commit {
    my $self = shift;

    my $url = $self->core_url.'/update/json?commit=true';
    my $res = Mojo::UserAgent->new->post($url)->res;

    return $res->body;
}


sub select {
    my $self = shift;
    my %args = @_;

    my $time_start = time;

    my $url = Mojo::URL->new($self->core_url.'/select');
    $url->query(
        wt => 'json',
        ident => 'true',
    );
    $url->query(\%args) if (keys %args);

    my $res = Mojo::UserAgent->new->get($url->to_string)->res;

    my $res_json = j( $res->body );

    return undef unless 
        $res_json->{responseHeader} &&
        $res_json->{responseHeader}->{status} == 0;

    return $res_json;
}

sub docs {
    my $self = shift;

    my $res_json = $self->select(@_);

    return Mojo::Collection->new unless
        $res_json &&
        $res_json->{response} &&
        $res_json->{response}->{docs};

    return Mojo::Collection->new(@{ $res_json->{response}->{docs} });
}

1;


use strict;
use warnings;
use Encode qw(is_utf8 encode decode);
use URI::Escape;

use Mojo::URL;
use Mojo::Util qw(url_escape url_unescape);

{

    my $url_orig  = decode 'UTF-8', 'http://www.test.com/Musica%20Antiqua%20Ko%CC%88ln/';
    my $url_esc   = url_escape $url_orig;
    my $url_unesc = url_unescape $url_orig;
    my $url_unesc_esc = url_escape $url_unesc;
    my $url_unesc_uri_esc = uri_escape $url_unesc;
    my $url_to_str = Mojo::URL->new($url_orig)->to_string;
    my $url_unesc_to_str = Mojo::URL->new($url_unesc)->to_string;


    print_url('orig', $url_orig);
    print_url('unesc', $url_unesc);
    print_url('unesc esc', $url_unesc_esc);
    print_url('unesc uri_esc', $url_unesc_uri_esc);
    print_url('to str', $url_to_str);
    print_url('unesc to str', $url_unesc_to_str);
}


sub print_url {
    my $name = shift;
    my $url = shift;

    my $is_utf8 = is_utf8($url) || 0;
    
    print "$name is utf8: $is_utf8 - $url\n";
}
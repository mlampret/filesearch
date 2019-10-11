use strict;
use warnings;

use base qw(Encode::Encoding);
use Encode qw(is_utf8 encode decode find_encoding);
use Encode::Guess qw(Windows-1252);
use URI::Escape;

use Mojo::URL;
use Mojo::Util qw(url_escape url_unescape);

{

    $Encode::Guess::NoUTFAutoGuess = 1;

    my $orig  = 'Der_Lehrer%2C_sein_Sch%FCler_und_der_wei%DFe_Mogul_H%F6rbuch.mp3';
    my $unescaped = uri_unescape $orig;
    my $decoded = decode 'UTF-8', $unescaped;
    my $encoded = encode 'UTF-8', $decoded;
    my $escaped = uri_escape $encoded;

    my $out = $escaped;

    print_url('orig', $orig);
#    print_url('decoded', $decoded);
#    print_url('encoded', $encoded);
    print_url('escaped', $escaped);


    print "\nIN == OUT: ".($orig eq $out ? 1 : 0). "\n\n";
}


sub print_url {
    my $name = shift;
    my $url = shift;

    my $is_utf8 = is_utf8($url) || 0;
    
    print "$name\t $is_utf8 - $url\n";
}


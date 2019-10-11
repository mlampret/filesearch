package FS::Object::Search::ResultSet::Result::Type;

use Mojo::Base -base;

sub groups {

    return {
        archive      => [qw( zip gz bz2 xz tar tgz rar 7z arj hqx )],
        audio        => [qw( mp3 m4a m4b m4r wav wma flac ogg asf )],
        book         => [qw( mobi epub chm cbr prc lit)],
        font         => [qw( ttf svg odt eot )],
        image        => [qw( jpg jpeg bmp gif png webp )],
        modmusic     => [qw( mod s3m stp psf pt2 vt2 xm minigsf minipsf )],
        music        => [qw( mid midi gp3 gp4 gp5 mus )],
        pdf          => [qw( pdf ps djv djvu)],
        presentation => [qw( pps ppt odp )],
        spreadsheet  => [qw( xls xlsx csv ods )],
        text         => [qw( txt doc odt docx rtf readme 1st tex)],
        video        => [qw( mpg mp4 avi wmv mkv mpeg mov flv ts webm )],
        web          => [qw( htm html shtml css js php )],
    };
}

sub type {
    my $self = shift;
    my $result = shift;

    my $map = $self->groups;

    my $type = $result->path->type;

    for my $t (keys %$map) {
        for my $e (@{ $map->{$t} }) {
            if (lc $e eq lc($result->path->extension || '')) {
                $type = $t;
                last;
            }
        }
    }

    return $type;

}

1;


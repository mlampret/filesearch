package Mojolicious::Plugin::VersionDir;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;

my $c = undef;
my $app = undef;
my $conf = undef;

sub register {
    my ($self, $app_param, $args) = @_;

    $app = $app_param;

    $conf = $args;
    $conf->{version} ||= time;

    $app->helper(

        'version_dir' => sub {
            my $self       = shift;
            my $class_name = shift;
 
            $class_name ||= 'Mojolicious::Plugin::VersionDir';

            unless ($class_name =~ m/[A-Z]/) {
                my $namespace = ref($self->app) . '::';
                $namespace = '' if $namespace =~ m/^Mojolicious::Lite/;

                $class_name = join '' => $namespace, Mojo::ByteStream->new($class_name)->camelize;
            }

            my $e = Mojo::Loader->load_class($class_name);

            Carp::croak qq/Can't load validator '$class_name': / . $e->message if ref $e;
            Carp::croak qq/Can't find validator '$class_name'/ if $e;
            Carp::croak qq/Wrong validator '$class_name' isa/ unless $class_name->isa($class_name);

            return $class_name->new(%$conf, @_);
        }
    );

    $app->hook( before_routes => sub {
        $c = shift;
    });

    $app->routes->get('/vd/:version/*rel_path')->name('version_dir')->to(
        cb => sub {
            my $self = shift;
            $self->reply->static($self->param('rel_path'));
        }
    );

}


sub path {
    my $self = shift;
    my $version = $app->mode eq 'production' ? $conf->{version} : time;
    return '/vd/' . $version;
}

1;




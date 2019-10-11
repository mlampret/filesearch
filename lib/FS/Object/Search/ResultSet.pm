package FS::Object::Search::ResultSet;

use Mojo::Base -base;
use Mojo::Collection;

use FS::Object::Search::ResultSet::Result;

has query   => undef;

has results => undef;

has offset  => undef;
 
has total   => undef;

1;


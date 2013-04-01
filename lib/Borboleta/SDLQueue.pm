package Borboleta::SDLQueue;
use strict;
use warnings;
use SDL::Event;
use SDL::Events;

# used for API compatibility with Thread::Queue

sub new {
  return __PACKAGE__;
}

sub enqueue {
  my ($self, $data) = @_;
  my $event = SDL::Event->new();
  $event->type ( SDL_USEREVENT );
  $event->user_code( 0 );
  $event->user_data1($data);
  SDL::Events::push_event($event);
}

1;

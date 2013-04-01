package Borboleta::Mode::Level::InputMap;
use strict;
use warnings;
use SDL::Event;
use SDL::Events ':all';

sub run {
  my ($class, $data) = @_;
  my $self = bless
    { model_q => $data->{model_q},
      controller_q => $data->{controller_q},
      inputmap_cq => $data->{inputmap_cq},
      states => { right => 0,
                  left => 0,
                  up => 0,
                  down => 0
                }
    }, $class;
  async {
    $self->loop();
  };
}

sub loop {
  my $self = shift;
  my $paused = 0;
  my $transfer_out = 0;
  my $event = SDL::Event->new;
  if ($transfer_out) {
    while (my ($c_event) = $self->{inputmap_cq}->dequeue) {
      if ($c_event eq 'leave') {
        return;
      } elsif ($c_event eq 'transferin') {
        $transfer_out = 0;
        last;
      }
    }
  } else {
    while (wait_event($event)) {
      if ($event->type == SDL_QUIT ||
          ( $event->type == SDL_KEYDOWN &&
            $event->key_sym == SDLK_ESCAPE )) {
        $self->{controller_q}->enqueue('escape');
      } elsif ($event->type == SDL_KEYDOWN &&
          $event->key_sym == SDLK_RETURN) {
        $self->{controller_q}->enqueue('return');
      } elsif ($event->type == SDL_USEREVENT) {
        if ($event->user_data1 eq 'pause') {
          $paused = 1;
        }
        if ($event->user_data1 eq 'leave') {
          return;
        }
        if ($event->user_data1 eq 'transferout') {
          $transferout = 1;
          last;
        }
      } elsif (!$paused) {
        my $change = 0;
        if ($event->type == SDL_KEYDOWN) {
          if ($event->key_sym == SDLK_DOWN) {
            $change = 1;
            $self->{states}{down} = 1;
          } elsif ($event->key_sym == SDLK_UP) {
            $change = 1;
            $self->{states}{up} = 1;
          } elsif ($event->key_sym == SDLK_LEFT) {
            $change = 1;
            $self->{states}{left} = 1;
          } elsif ($event->key_sym == SDLK_RIGHT) {
            $change = 1;
            $self->{states}{right} = 1;
          }
        } elsif ($event->type == SDL_KEYUP) {
          if ($event->key_sym == SDLK_DOWN) {
            $change = 1;
            $self->{states}{down} = 0;
          } elsif ($event->key_sym == SDLK_UP) {
            $change = 1;
            $self->{states}{up} = 0;
          } elsif ($event->key_sym == SDLK_LEFT) {
            $change = 1;
            $self->{states}{left} = 0;
          } elsif ($event->key_sym == SDLK_RIGHT) {
            $change = 1;
            $self->{states}{right} = 0;
          }
        }
        if ($change) {
          $self->{model_q}->enqueue({ type => 'key_state_update',
                                      states => $elf->{states} });
        }
      }
    }
  }
}

1;

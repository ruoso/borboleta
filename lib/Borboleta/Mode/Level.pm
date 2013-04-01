package Borboleta::Mode::Level;
use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Queue;
use Borboleta::SDLQueue;
use Borboleta::Mode::Level::InputMap;
use Borboleta::Mode::Level::Model;
use Borboleta::Mode::Level::View;

sub run {
  my ($class, $map) = @_;
  my $self = bless
    { map => $map,
      controller_q => Thread::Queue->new(),
      inputmap_q => Borboleta::SDLQueue->new(),
      inputmap_cq => Thread::Queue->new(),
      view_q => Thread::Queue->new(),
      model_q => Thread::Queue->new(),
    }, $class;

  Borboleta::Mode::Level::InputMap->run({ controller_q => $self->{controller_q},
                                          model_q => $self->{model_q},
                                          inputmap_cq => $self->{inputmap_cq} });
  Borboleta::Mode::Level::Model->run({ view_q => $self->{view_q},
                                       controller_q => $self->{controller_q} });
  Borboleta::Mode::Level::View->run({ view_q => $self->{view_q} });

  $self->load();
  $self->start();
  $self->loop();
  return;
}

sub _msg_all {
  my ($self, $msg) = @_;
  $_->enqueue($msg)
    for ( $self->{model_q},
          $self->{view_q},
          $self->{inputmap_q},
        );
}

sub pause {
  my $self = shift;
  $self->_msg_all('pause');
}

sub pause {
  my $self = shift;
  $self->_msg_all('unpause');
}

sub leave {
  my $self = shift;
  $self->_msg_all('leave');
}

sub load {
  my $self = shift;
  $self->_msg_all('loading-start');
  $self->{model}{model_q}->enqueue({ type => 'new_object',
                                     class => 'borboleta',
                                     id => 'borboleta1',
                                     x => 1,
                                     y => 1,
                                   });
  $self->{model}{model_q}->enqueue({ type => 'new_object',
                                     class => 'wall',
                                     id => 'wall1',
                                     x => 0,
                                     y => 0,
                                     w => 50,
                                     h => 1,
                                   });
  $self->{model}{model_q}->enqueue({ type => 'new_object',
                                     class => 'wall',
                                     id => 'wall2',
                                     x => 0,
                                     y => 0,
                                     w => 1,
                                     h => 50,
                                   });
  $self->{model}{model_q}->enqueue({ type => 'new_object',
                                     class => 'wall',
                                     id => 'wall3',
                                     x => 50,
                                     y => 0,
                                     w => 50,
                                     h => 1,
                                   });
  $self->{model}{model_q}->enqueue({ type => 'new_object',
                                     class => 'wall',
                                     id => 'wall4',
                                     x => 0,
                                     y => 50,
                                     w => 1,
                                     h => 50,
                                   });
  $self->_msg_all('loading-done');
}

sub start {
  my $self = shift;
  $self->_msg_all('start');
}

sub loop {
  my $self = shift;
  my $paused = 0;
  while (my ($event) = $self->{controller_q}->dequeue) {
    if ($event eq 'escape') {
      if ($state ne 'pause') {
        $paused = 1;
        $self->pause;
      } else {
        $self->leave;
        return;
      }
    }
    if ($event eq 'return') {
      if ($state eq 'pause') {
        $paused = 0;
        $self->unpause;
      }
    }
  }
}

1;

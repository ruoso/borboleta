package Borboleta::Mode::Level::Model;
use strict;
use warnings;
use Data::Dumper;
use Math::Complex;
use List::Util qw(max min);
use SDL;

sub run {
  my ($class, $data) = @_;
  my $self = bless
    { view_q => $data->{view_q},
      controller_q => $data->{controller_q},
      model_q => $data->{model_q},
      objects => {},
      objects_with_bounding_box => {},
      objects_with_input => {},
      objects_with_time_lapse => {},
      objects_with_active_collision => {},
      objects_with_motion => {},
      last_tick => undef,
    }, $class;
  async {
    $self->loop();
  };
  return;
}

sub loop {
  my $self = shift;
  my $running = 0;
  my $paused = 0;
  while (1) {
    if (not defined $self->{last_tick}) {
      $self->{last_tick} = SDL::get_ticks();
    }
    my $this_tick = SDL::get_ticks();
    my $elapsed = $this_tick - $last_ticks;

    my $event = $self->{model_q}->dequeue_nb();
    if ($event) {
        if (ref $event eq 'HASH') {
          if ($event->{type} eq 'new_object') {
            $self->new_object($event);
          } elsif ($event->{type} eq 'key_state_update') {
            $self->key_state_update($event);
          } else {
            warn "unknown event: ".Dumper($event);
          }
        } elsif ($event eq 'pause') {
            $paused = 1;
        } elsif ($event eq 'unpause') {
            $paused = 0;
        } elsif ($event eq 'leave') {
            return;
        } elsif ($event eq 'start') {
            $running = 1;
        } else {
          warn "unknown event: ".Dumper($event);
        }
    }

    if ($running && !$paused) {
        $self->time_lapse($self->{last_tick}, $this_tick);
    }

    $self->{last_tick} = $this_tick;
    select(undef,undef,undef,0.01);
  }
}

sub new_object {
  my ($self, $event) = @_;
  my $class = $event->{class};
  eval "require $class;";
  if ($@) {
    warn "Failed to load $class for new_object $event->{id}";
    return;
  }
  my $obj = $class->new($event);
  if (!$obj) {
    warn "Failed to create object $class $event->{id}";
    return;
  }
  if (exists $self->{objects}{$event->{id}}) {
    warn "Trying to override object $event->{id} with new object of class $class";
    return;
  }
  $self->{objects}{$event->{id}} = $obj;
  if ($obj->can('time_lapse')) {
    $self->{objects_with_time_lapse}{$event->{id}} = $obj;
  }
  if ($obj->can('input')) {
    $self->{objects_with_input}{$event->{id}} = $obj;
  }
  if ($obj->can('active_collision')) {
    $self->{objects_with_active_collision}{$event->{id}} = $obj;
  }
  if ($obj->can('x') && $obj->can('y') && $obj->can('w') && $obj->can('h')) {
    $self->{objects_with_bounding_box}{$event->{id}} = $obj;
  }
  if ($obj->can('vx') && $obj->can('vy') && $obj->can('ax') && $obj->can('ay')) {
    $self->{objects_with_motion}{$event->{id}} = $obj;
  }
}

sub time_lapse {
  my ($self, $last_tick, $this_tick) = @_;
  my $dt = ($this_tick - $last_tick) / 1000; # to seconds

  # The first step is to find the bounding rectangles for the entire
  # movement. This is such that we only perform proper collision
  # detection within the range of object-to-object relationships that
  # actually may collide, instead of having to perform N**2 collision
  # tests
  my %bounding_proximity_rectangles;
  foreach my $object_id (keys %{$self->{objects_with_bounding_box}}) {
    my $object = $self->{objects_with_motion}{object_id};
    my @all_x = ($object->{x}, $object->{x} + $object->{w});
    my @all_y = ($object->{y}, $object->{y} + $object->{h});

    if (exists $self->{objects_with_motion}{$object_id}) {
      # We translate X,Y coordinates into the complex plane (X + Yi) in
      # order to perform the calculations.  That means that the X axis in
      # the equations below actually represent time, and the 2D plane of
      # the game is actually laid down between the y and the z axis (if we
      # were to do a projection of that graphs).

      my $s0 = $object->{x}  + $object->{y}*i;
      my $v0 = $object->{vx} + $object->{vy}*i;
      my $a  = $object->{ax} + $object->{ay}*i;
      # We are going to use the movement equation here.
      # f(x) = s0 + v0*t + (a * (t**2))/2

      # We are first going to evaluate it for $dt
      my $s = $s0 + $v0*$dt + ($a * ($dt ** 2))/2;

      push @all_x, ( $s->Re, $s->Re + $object->{w} );
      push @all_y, ( $s->Im, $s->Im + $object->{h} );

      # now we need to find the vertex of the equation using:
      # vertex_x = -b/2a
      if ($a != 0) { # linear equations have no vertex.
        my $vertex = (0 - ($v0 * $dt)) / 2*($a/2);
        # and we need to see if it would be less than $dt (inside this
        # frame time) or not. If it isn't it means that $s0 and $s are
        # sufficient to define the bounding box, otherwise we need to
        # include the vertex point when deciding that.
        if ($vertex && $vertex > 0 && $vertex < $dt) {
          # The vertex is in this frame, which means that we need to also
          # consider it when defining the bounding box.
          my $sv = $s0 + $v0*$vertex + ($a * ($vertex ** 2))/2;
          push @all_x, ( $sv->Re, $sv->Re + $object->{w} );
          push @all_y, ( $sv->Im, $sv->Im + $object->{h} );
        }
      }
    }
    $bounding_proximity_rectangles{$object_id} =
      [ [ min(@all_x),min(@all_y) ],
        [ max(@all_x),max(@all_y) ] ];
  }

  # now we can find out which objects actually may generate a
  # collision, by traversing the moving objects and testing their
  # movement-region against all other bounding proximity rectangles.
  my %overlapping_proximity;
  for my $object_id (keys %{$self->{objects_with_motion}}) {
    my $object = $self->{objects_with_motion}{$object_id};
    my $rect = $bounding_proximity_rectangles{$object_id};
    my $rmin = 0; my $rmax = 1; my $rx = 0; my $ry = 1;
    foreach my $other_object_id (keys %bounding_proximity_rectangles) {
      my $other_rect = $bounding_proximity_rectangles{$other_object_id};
      # Now we do a simple rectangle overlap check
      if (# The lower-left corner of my rectangle is closer to the
          # origin than the upper-right corner of the other rectangle.
          ( $rect->[$rmin][$rx] <= $other_rect->[$rmax][$rx] &&
            $rect->[$rmin][$ry] <= $other_rect->[$rmax][$ry]    ) &&
          # The upper-right corner of my rectangle is farther away from
          # the origin than the lower-left corner of the other rectangle.
          ( $other_rect->[$rmin][$rx] <= $rect->[$rmax][$rx] &&
            $other_rect->[$rmin][$ry] <= $rect->[$rmax][$ry]    )
         ) {
        # we canonicalize the entry in that hash.
        my ($k, $v) = $object_id > $other_object_id ?
          ($object_id => $other_object_id) :
            ($other_object_id => $object_id);
        $overlapping_proximity{$k}{$v} = 1;
      }
    }
  }

  # Now that we have a subset of the interactions that are actually
  # likely to happen, we perform a real collision detection.

  # Find first TOI (Time Of Impact), then choose the first ones (if it
  # so happens that more than one collision happen at the same time)
  # and execute that collision, re-invoking the simulation for the
  # remaining of the time.

  # The collision detection can happen in two ways: 1) moving object
  # against static object, or 2) moving object against moving object.
  # The first is an instersection of the parabola with the rectangle,
  # the second is the intersection of the two parabolas.
  my @collisions;
  foreach my $object_id (keys %overlapping_proximity) {
    my $object_is_moving = exists $self->{objects_with_motion}{$object_id} ? 1 : 0;
    foreach my $other_object_id (keys %{$overlapping_proximity{$object_id}}) {
      my $other_object_is_moving = exists $self->{objects_with_motion}{$other_object_id} ? 1 : 0;
      if ($object_is_moving && $other_object_is_moving) {
        # Both objects are moving
        if (my $toi = $self->intersection_parabola_parabola($object_id, $other_object_id, $dt)) {
          push @collisions, [ $toi, $object_id, $other_object_id ];
        }
      } elsif ($object_is_moving) {
        # first one is moving, second is static
        if (my $toi = $self->intersection_parabola_rectangle($object_id, $other_object_id, $dt)) {
          push @collisions, [ $toi, $object_id, $other_object_id ];
        }
      } elsif ($other_object_is_moving) {
        # second is moving, first is static
        if (my $toi = $self->intersection_parabola_rectangle($other_object_id, $object_id, $dt)) {
          push @collisions, [ $toi, $object_id, $other_object_id ];
        }
      } else {
        # what?
        warn "shouldn't be here."
      }
    }
  }

}

sub intersection_parabola_parabola {
  my ($self, $objid_1, $objid_2, $t) = @_;
  my $obj1 = $self->{objects_with_motion}{$objid_1};
  my $obj2 = $self->{objects_with_motion}{$objid_2};
  # We take an intersection of the parabolas, by subtracting the
  # equation of the first parabola from the equation of the second
  # parabola.
  # fa(t) = s0a + v0a * t + (aa * ( t ** 2 ))/2
  # fb(t) = s0b + v0b * t + (ab * ( t ** 2 ))/2
  # fa(t) - fb(t) = 0
  # s0a - s0b + v0a * t - v0b * t +
  #  (aa * ( t ** 2 ))/2 - (ab * ( t ** 2 ))/2 = 0
  # (s0a - s0b) + (v0a - v0b)t + ( aa/2 - ab/2  ) * t**2 = 0
  my $s0a = ($obj1->{x} + $obj1->{w}/2) + ($obj1->{y} + $obj1->{h}/2)*i;
  my $s0b = ($obj2->{x} + $obj2->{w}/2) + ($obj2->{y} + $obj2->{h}/2)*i;
  my $v0a = $obj1->{vx} + $obj1->{vy}*i;
  my $v0b = $obj2->{vx} + $obj2->{vy}*i;
  my $aa  = $obj1->{ax} + $obj1->{ay}*i;
  my $ab  = $obj2->{ax} + $obj2->{ay}*i;
  my $s0  = $s0a - $s0b;
  my $v0  = $v0a - $v0b;
  my $a   = $aa - $ab;

  # Now what we need is to find if there are any roots for that
  # equation, and that tells if there is an interesection.  But, in
  # order to properly address the bounding boxes for the collisions,
  my $bounding =
    ($obj1->{x}/2 + $obj2->{x}/2) + ($obj1->{y}/2 + $obj2->{y}/2)*i;
  # we have to make that an inequality instead. And because we can't
  # assume sign and because we also know that this is actually in the
  # complex plane, we have to use the absolute value in the
  # inequality.
  #
  # | (s0a - s0b) + (v0a - v0b)t + ( aa - ab )/2 * t**2 | <= bounding
  #
  # in order to solve the absolute of a quadratic, I'll solve it twice:
  #
  # (s0a - s0b) + (v0a - v0b)t + ( aa - ab )/2 * t**2 <= bounding
  # (s0a - s0b) + (v0a - v0b)t + ( aa - ab )/2 * t**2 >= bounding * -1
  #
  # which, in standard notation, is:
  #
  # (s0a - s0b - bounding) + (v0a - v0b)t + ( aa - ab )/2 * t**2 <= 0
  # (s0a - s0b + bounding) + (v0a - v0b)t + ( aa - ab )/2 * t**2 >= 0
  #
  # and I will find one, two, three or four points, giving me
  # different segments that will tell me when a collision would start
  # as well as when it would end, at the same time as it would respect
  # the bounding boxes.

  if ($a == 0 && $v0 == 0) {
    if ($s0 == 0) {
      # this is a resting collision
      return 0;
    } else {
      # what? that's impossible
      warn "inconsistent data, $s0 = 0";
      return;
    }
  } elsif ($a == 0 && $v0 != 0) {
    # Linear version
    # t <= (0 - (s0 - bounding))/v0
    # t >= (0 - (s0 + bounding))/v0
    my ($t1, $t2) = sort ( ((0 - ($s0 - $bounding)) / $v0),
                           ((0 - ($s0 + $bounding)) / $v0) );

    # first of all, if these events happen outside this frame, we
    # really don't care.
    if ($t1 > $t || $t2 < 0) {
      return;
    } else {
      # Now we know that these segments are alternating in state
      # regarding our original absolute-value inequality, so we only
      # need to test the middle section to know if it satisfy between t1
      # and t2 or if it is not coliding between t1 and t2.
      my $midseg = ($t1 + $t2)/2;
      if (abs($s0 + $v0 * $midseg) <= $bounding) {
        # ok, mid segment is the collision, and it collides for the
        # whole interval of [t1,t2].
        if ($t1 < 0) {
          warn 'inconsistent data, cannot start as collision';
          return;
        } else {
          return $t1;
        }
      } else {
        # we were colliding before t1, stopped colliding, and start
        # colliding after t2 again.
        if ($t1 > 0) {
          warn 'inconsistent data, cannot start as collision';
          return;
        } elsif ($t2 > $t) {
          # we only collide again after this time frame, ignore.
          return;
        } else {
          return $t2;
        }
      }
  } else {
    my $discriminant_u = $v0 ** 2 - 4 * $a * ($s0 + $bounding);
    my $discriminant_l = $v0 ** 2 - 4 * $a * ($s0 - $bounding);
    if ($discriminant_u <= 0 && $discriminant_l <= 0) {
      # no significant collision.
      return
    } else {
      # There is, maybe, a collision
      my @solutions;
      if ($discriminant_u > 0) {
        push @solutions, ( ((0 - $v0) + sqrt($discriminant_u))/(2*$a),
                           ((0 - $v0) - sqrt($discriminant_u))/(2*$a) );
      }
      if ($discriminant_l > 0) {
        push @solutions, ( ((0 - $v0) + sqrt($discriminant_l))/(2*$a),
                           ((0 - $v0) - sqrt($discriminant_l))/(2*$a) );
      }
      # again, we know that these are alternating states, so we only
      # need to test one of them, and we also don't care about events
      # outside our time frame
      @solutions = sort grep { $_ >= 0 && $_ <= $t } @solutions;
      if (@solutions) {
        if ($s0 <= $bounding) {
          warn "cannot start frame colliding.";
          return
        } else {
          return shift @solutions;
        }
      } else {
        # everything was outside the time frame.
        return;
      }
    } else {
      # no collision.
      return;
    }
  }
}

1;

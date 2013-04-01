
use Test::More tests => 8;
use Borboleta::Mode::Level::Model;
use Math::Complex;
{ package No::Op;
  sub AUTOLOAD { }
};

my %objects;
my $tester = bless
  { view_q => bless({}, No::Op),
    controller_q => bless({}, No::Op),
    model_q => bless({}, No::Op),
    objects => \%objects,
    objects_with_bounding_box => \%objects,
    objects_with_input => \%objects,
    objects_with_time_lapse => \%objects,
    objects_with_active_collision => \%objects,
    objects_with_motion => \%objects,
    last_tick => undef,
  }, 'Borboleta::Mode::Level::Model';


# This test is to exercise the collision detection of moving object
# against moving object

eval {
  %objects = ( o1 => { h => 0, w => 0, x => 0,  y => 0, vx =>  10, vy => 0, ax => 0, ay => 0 },
               o2 => { h => 0, w => 0, x => 10, y => 0, vx =>   0, vy => 0, ax => 0, ay => 0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', 1,
         'two bodies 10m apart, one of them moving at 10m/s should meet after 1 second');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 0, w => 0, x => 0,  y => 0,  vx =>  10, vy => 10, ax => 0, ay => 0 },
               o2 => { h => 0, w => 0, x => 10, y => 10, vx =>   0, vy =>  0, ax => 0, ay => 0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', 1,
         'two bodies 10m apart, one of them moving at 10m/s in both axis should meet after 1 second');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 0, w => 1, x => 0,  y => 0, vx =>  10, vy => 0, ax => 0, ay => 0 },
               o2 => { h => 0, w => 1, x => 10, y => 0, vx =>   0, vy => 0, ax => 0, ay => 0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', 0.9,
         'two bodies with centers 10m apart with 1m size, one of them moving at 10m/s should meet after 0.9 second');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 0, w => 0, x => 0,  y => 0, vx =>   5, vy => 0, ax => 0, ay => 0 },
               o2 => { h => 0, w => 0, x => 10, y => 0, vx =>  -5, vy => 0, ax => 0, ay => 0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', 1,
         'two bodies 10m apart, moving at 5m/s in oposite directions should meet after 1 second');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 0, w => 1, x => 0,  y => 0, vx =>   5, vy => 0, ax => 0, ay => 0 },
               o2 => { h => 0, w => 1, x => 10, y => 0, vx =>  -5, vy => 0, ax => 0, ay => 0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', 0.9,
         'two bodies with centers 10m apart with 1m size, moving at 5m/s in oposite directions should meet after 0.9 second');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 0, w =>  0,  x => 0,   y => 10, vx =>  0, vy => 0, ax => 0, ay => -10 },
               o2 => { h => 0, w =>  0,  x => 0,   y =>  0, vx =>  0, vy => 0, ax => 0, ay =>   0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', sqrt(2),
         'a body in free-fall from 10 m with 10m/s2 acceleation should reach the ground in sqrt(2) seconds');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 1, w =>  1,  x => -0.5,  y =>  10, vx =>  0, vy => 0, ax => 0, ay => -10 },
               o2 => { h => 1, w =>  1,  x => -0.5,  y =>  -1, vx =>  0, vy => 0, ax => 0, ay =>   0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', sqrt(2),
         'a body in free-fall from 10 m with 10m/s2 acceleation should reach the ground in sqrt(2) seconds, independent of the shape of the second object');
};
if ($@) {
  fail($@);
}

eval {
  %objects = ( o1 => { h => 1, w =>  1,  x => 10,  y =>  10, vx =>  0, vy => 0, ax => -10, ay => -10 },
               o2 => { h => 1, w =>  1,  x => -1,  y =>  -1, vx =>  0, vy => 0, ax => 0,   ay =>   0 } );
  cmp_ok($tester->intersection_parabola_parabola('o1','o2',10), '==', sqrt(2) + sqrt(2)*i,
         'body accelerating in both axis from 10m with 10m/s2 should reach the origin in sqrt(2)+sqrt(2)*i');
};
if ($@) {
  fail($@);
}

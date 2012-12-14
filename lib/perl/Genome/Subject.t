#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Subject') or die;
class Genome::SubjectTest { # class for testing
    is => 'Genome::Subject',
};

my $project = Genome::Project->create(name => '__TEST_PROJECT__');
ok($project, 'create project');

my $subject = Genome::SubjectTest->create(
    name => '__TEST_SUBJECT__',
    projects => [ $project ],
);
ok($subject, 'create subject');
is_deeply([$subject->projects], [$project], 'subject has projects');

done_testing();

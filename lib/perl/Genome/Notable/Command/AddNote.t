#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Notable::Command::AddNote') or die;
use_ok('Genome::Notable') or die;

class Genome::Notable::Test {
    is => 'Genome::Notable',
};

class Genome::Notable::Test::Command::AddNote {
    is => 'Genome::Notable::Command::AddNote',
    has => [
        notable => {
            is => 'Genome::Notable::Test',
        }
    ],
};

my $notable = Genome::Notable::Test->create();
ok($notable, 'created test notable object');

my $command = Genome::Notable::Test::Command::AddNote->create(
    notable => $notable
);
ok($command, 'made command object without header_text');

my ($header_text_error) = grep { ($_->properties)[0] eq 'header_text' } $command->__errors__;
ok($header_text_error, 'got an error about header_text');
my $rv = eval { $command->execute };
ok(!$rv, 'could not execute add note command, as expected');

$command = Genome::Notable::Test::Command::AddNote->create(
    notable => $notable,
    header_text => 'test',
    body_text => 'blah',
);
ok($command, 'created add note command object');

$rv = eval { $command->execute };
my $error = $@;
ok(($rv and !$error), 'add note command executed successfully');

my @notes = $notable->notes;
is(scalar @notes, 1, 'found one note on object, as expected');
is($notes[0]->header_text, 'test', 'note on object has expected header_text');
is($notes[0]->body_text, 'blah', 'note on object has expected body_text');

done_testing();

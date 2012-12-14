#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Disk::Command::Allocation::Create') or die;

my $cmd = Genome::Disk::Command::Allocation::Create->create(
    disk_group_name => 'info_apipe',
    allocation_path => 'allocation/create/test',
    kilobytes_requested => 100,
    owner_class_name => 'UR::Object',
    owner_id => 'test',
);
ok($cmd, 'Successfully created allocation command object') or die;

my $rv = eval { $cmd->execute };
ok($rv, 'Successfully executed command') or die;

done_testing();

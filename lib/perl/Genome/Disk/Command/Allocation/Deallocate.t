#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Disk::Command::Allocation::Deallocate') or die;
use_ok('Genome::Disk::Allocation') or die;

my $allocation = Genome::Disk::Allocation->create(
    disk_group_name => Genome::Config::get('disk_group_dev'),
    allocation_path => 'command/allocation/deallocate/test',
    kilobytes_requested => 100,
    owner_class_name => 'UR::Value',
    owner_id => 'test',
);
ok($allocation, 'Successfully created allocation') or die;

my $cmd = Genome::Disk::Command::Allocation::Deallocate->create(
    allocations => [$allocation],
);
ok($cmd, 'Successfully created deallocate command object') or die;

my $rv = $cmd->execute;
ok($rv, 'Successfully executed deallocate command');

done_testing();

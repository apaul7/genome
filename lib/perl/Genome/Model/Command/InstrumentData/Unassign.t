#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use strict;
use warnings;

use above 'Genome';
use Test::More;

use_ok('Genome::Model::Command::InstrumentData::Unassign') or die;

class Genome::Model::Tester { is => 'Genome::ModelDeprecated', };

my $pp = Genome::ProcessingProfile::Tester->create(
    name => 'Tester Test for Testing',
);
ok($pp, "created processing profile") or die;

my $model = Genome::Model->create(
    processing_profile => $pp,
    subject_name => 'human',
    subject_type => 'species_name',
);
ok($model, 'create model') or die;

my $sample = Genome::Sample->create(name => 'unassign-test');
ok($sample, 'sample');
my $library = Genome::Library->create(name => $sample->name.'-extlibs', sample_id => $sample->id);
ok($library, 'library');

my @sanger_id = map { Genome::InstrumentData::Sanger->create(id => '0'.$_.'jan00.101amaa', library => $library) } (1..4);
is(scalar(@sanger_id), 4, 'create instrument data') or die;

my $solexa_id = Genome::InstrumentData::Solexa->create(flow_cell_id => 'TEST_FLOW_CELL', library => $library);
ok($solexa_id, 'create solexa inst data') or die;

for my $data (@sanger_id, $solexa_id) {
    $model->add_instrument_data($data);
}
my @assigned_inst_data = $model->instrument_data;
is(scalar(@assigned_inst_data), 5, 'instrument data is assigned to model');

# Fails
my $unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model => $model,
    all => 1,
    instrument_data => [ $solexa_id ],
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to request multiple functions - will fail execute');
$unassign->dump_status_messages(1);
ok(!$unassign->execute, 'execute failed as expected');

# Success
$unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model => $model,
    instrument_data => [ $sanger_id[0] ],
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to unassign single instrument data');
$unassign->dump_status_messages(1);
ok($unassign->execute, 'execute single unassign');
@assigned_inst_data = $model->instrument_data;
ok(!grep($_ eq $sanger_id[0], @assigned_inst_data), 'data is no longer assigned');

$unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model => $model,
    instrument_data => [ $sanger_id[1], $sanger_id[2] ],
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to unassign multiple instrument data');
$unassign->dump_status_messages(1);
ok($unassign->execute, 'execute multiple unassign');
@assigned_inst_data = $model->instrument_data;
ok(!grep(($_ eq $sanger_id[1] || $_ eq $sanger_id[2]), @assigned_inst_data), 'data is no longer assigned');

$unassign = Genome::Model::Command::InstrumentData::Unassign->create(
    model => $model,
    all => 1,
);
isa_ok($unassign, 'Genome::Model::Command::InstrumentData::Unassign', 'create to unassign all available instrument data');
$unassign->dump_status_messages(1);
ok($unassign->execute, 'execute');
@assigned_inst_data = $model->instrument_data;
is(scalar(@assigned_inst_data), 0, 'all data unassigned');

done_testing();

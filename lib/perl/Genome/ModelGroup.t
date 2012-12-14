#!/usr/bin/env genome-perl
use strict;
use warnings;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use above "Genome";

use Data::Dumper;
use Test::More;

#It is intended that nothing actually writes to it--this should just be to prevent allocations
my $test_data_dir = File::Temp::tempdir('Genome-ModelGroup-XXXXX', DIR => "$ENV{GENOME_TEST_TEMP}", CLEANUP => 1);

# overload username to test name update
no warnings;
my $orig_username = Genome::Sys->username;
my $username = $orig_username;
*Genome::Sys::username = sub{ return $username; };
use warnings;

use_ok('Genome::ModelGroup') or die;

my ($test_model, $test_model_two) = setup_test_models();

my $model_group = Genome::ModelGroup->create(
  name => 'Testsuite_ModelGroup',
  models => [ $test_model ],
);
ok($model_group, 'create a model_group');
isa_ok($model_group, 'Genome::ModelGroup');
my @err = $model_group->__errors__;
ok(!@err, 'no errors in created group') or diag(map($_->__display_name__, @err));
is($model_group->name, 'Testsuite_ModelGroup', 'name');
ok($model_group->convergence_model, 'Auto-generated associated Convergence model'); 
is_deeply([$model_group->models], [$test_model], 'group has test model');
is($model_group->model_count, 1, 'group model count');
my $project = $model_group->project;
ok($project, 'create a project w/ model group'); 
is($project->id, $model_group->uuid, 'project id matches model group uuid');
is($project->name, $model_group->name, 'project name matches model group name');
my $user_email = Genome::Sys::User->get(username => Genome::Sys->username)->email;
is($model_group->user_name, $user_email, "Model username matches user email address");
my $creator = $project->parts(role => 'creator')->entity;
is($creator->email, $model_group->user_name, 'project creator email matches model group user name');
my @project_models = sort { $a->id <=> $b->id } map { $_->entity } $project->parts('entity_class_name like' => 'Genome::Model%');
is_deeply(\@project_models, [$model_group->models], 'project models match model group models');

# failed to create again
ok(!Genome::ModelGroup->create(name => 'Testsuite_ModelGroup'), 'failed to create model group with the same name');

# rename
ok(!$model_group->rename(), 'failed to rename w/o name');
ok(!$model_group->rename('Testsuite_ModelGroup'), 'failed to rename to same name');
ok($model_group->rename('Testsuite ModelGroup'), 'rename');
is($model_group->name, 'Testsuite ModelGroup', 'name after rename');
is($model_group->convergence_model->name, 'Testsuite ModelGroup_convergence', 'convergence model name after rename');
is($model_group->project->name, 'Testsuite ModelGroup', 'project name after rename');

# add models
ok(!$model_group->assign_models(), 'Cannot assign zero models!');
ok($model_group->assign_models($test_model_two), 'Cannot assign zero models!');
my $add_command = Genome::ModelGroup::Command::Member::Add->create(
    model_group => $model_group,
    models => [ $test_model_two, $test_model, $test_model_two, ], # give model twice and already assigned to test skipping assigned models
);
$add_command->dump_status_messages(1);
ok($add_command, 'created member add command');
ok($add_command->execute(), 'executed member add command');
my @model_bridges = $model_group->model_bridges;
is(@model_bridges, 2, 'group has 2 model bridges');
is_deeply([$model_group->models], [$test_model_two, $test_model], 'group has both models');
@project_models = sort { $a->id <=> $b->id } map { $_->entity } $project->parts('entity_class_name like' => 'Genome::Model%');
is_deeply(\@project_models, [$model_group->models], 'after add model - project models match model group models');

# remove models
ok(!$model_group->unassign_models(), 'Cannot unassign zero models!');
my $remove_command = Genome::ModelGroup::Command::Member::Remove->create(
    model_group => $model_group,
    models => [ $test_model ],
);
$remove_command->dump_status_messages(1);
ok($remove_command, 'created member remove command');
ok($remove_command->execute(), 'executed member remove command');
is_deeply([$model_group->models], [$test_model_two], 'group has test model two'); 
@project_models = sort { $a->id <=> $b->id } map { $_->entity } $project->parts('entity_class_name like' => 'Genome::Model%');
is_deeply(\@project_models, [$model_group->models], 'after remove model - project models match model group models');

# delete
my $delete_command = Genome::ModelGroup::Command::Delete->create(
    model_group => $model_group,
);
ok($delete_command, 'create model-group delete command');
ok($delete_command->execute(), 'executed model-group delete command');
is(ref($project), 'UR::DeletedRef', 'deleted project with model group');

done_testing();


###
# Create some test models with builds and all of their prerequisites
sub setup_test_models {
    my $test_profile = Genome::ProcessingProfile::ReferenceAlignment->create(
        name => 'test_profile',
        sequencing_platform => 'solexa',
        dna_type => 'cdna',
        read_aligner_name => 'bwa',
        snv_detection_strategy => 'samtools -test Genome/ModelGroup.t',
    ); 
    ok($test_profile, 'created test processing profile');
    
    my $test_sample = Genome::Sample->create(
        name => 'test_subject',
    );
    ok($test_sample, 'created test sample');
    
    my $reference_sequence_build = Genome::Model::Build::ImportedReferenceSequence->get(name => 'NCBI-human-build36');
    isa_ok($reference_sequence_build, 'Genome::Model::Build::ImportedReferenceSequence') or die;

    my $test_model = Genome::Model->create(
        name => 'test_reference_aligment_model_mock',
        subject_name => 'test_subject',
        subject_type => 'sample_name',
        processing_profile_id => $test_profile->id,
        reference_sequence_build => $reference_sequence_build,
    );
    ok($test_model, 'created test model');
     
    my $test_model_two = Genome::Model->create(
        name => 'test_reference_aligment_model_mock_two',
        subject_name => 'test_subject',
        subject_type => 'sample_name',
        processing_profile_id => $test_profile->id,
        reference_sequence_build => $reference_sequence_build,
    );
    ok($test_model_two, 'created second test model');
    
    return ($test_model, $test_model_two);
}

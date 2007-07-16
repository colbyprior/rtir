use strict;

use Test::WWW::Mechanize;
use Test::More tests => 107;

require "t/rtir-test.pl";

my $agent = default_agent();

my @ir_ids;

for(my $i = 1; $i < 5; $i++) {
	push @ir_ids, create_ir($agent, {Subject => "IR number $i for RTIR testing"});
	my $ir_obj = RT::Ticket->new(RT::SystemUser());
	my $ir_id = $ir_ids[-1];

    $ir_obj->Load($ir_id);
    is($ir_obj->Id, ($ir_id), "IR $i has the right ID");
    is($ir_obj->Subject, "IR number $i for RTIR testing", "IR $i has the right subject")
}

my @incident_ids;

push @incident_ids, create_incident_for_ir($agent, $ir_ids[0], {Subject => "Incident number 1"}, {Function => "IncidentCoord"});
my $inc_obj = RT::Ticket->new(RT::SystemUser());

$inc_obj->Load($incident_ids[0]);
is($inc_obj->Id, $incident_ids[0], "Incident has the right ID");
is($inc_obj->Subject, "Incident number 1", "Incident has the right subject");

LinkChildToIncident($agent, $ir_ids[1], $incident_ids[0]);

ticket_is_linked_to_inc($agent, $ir_ids[0], [$incident_ids[0]]);
ticket_is_linked_to_inc($agent, $ir_ids[1], [$incident_ids[0]]);

push @incident_ids, create_incident_for_ir($agent, $ir_ids[2], {Subject => 'Incident number 2'}, {Function => 'IncidentCoord'});

$inc_obj->Load($incident_ids[0]);
is($inc_obj->Id, $incident_ids[0], "Incident has the right ID");
is($inc_obj->Subject, "Incident number 1", "Incident has the right subject");

LinkChildToIncident($agent, $ir_ids[3], $incident_ids[1]);

ticket_is_linked_to_inc($agent, $ir_ids[2], [$incident_ids[1]]);
ticket_is_linked_to_inc($agent, $ir_ids[3], [$incident_ids[1]]);

resolve_rtir_ticket($agent, $ir_ids[0], 'Incident Report');

my @invests;

push @invests, create_investigation($agent, {Incident => $incident_ids[0], Subject => 'Investigation 1 for incident ' . $incident_ids[0]});
push @invests, create_investigation($agent, {Incident => $incident_ids[0], Subject => 'Investigation 2 for incident ' . $incident_ids[0]});

push @invests, create_investigation($agent, {Incident => $incident_ids[1], Subject => 'Investigation 1 for incident ' . $incident_ids[1]});
push @invests, create_investigation($agent, {Incident => $incident_ids[0], Subject => 'Investigation 2 for incident ' . $incident_ids[1]});

resolve_rtir_ticket($agent, $invests[0], 'Investigation');

bulk_abandon($agent, @incident_ids);

foreach my $id (@incident_ids) {
	ticket_state_is($agent, $id, 'abandoned', "Incident $id is abandoned");
}

foreach my $id (@ir_ids ) {
	diag("IR #$id state is " . ticket_state($agent, $id)) if($ENV{'TEST_VERBOSE'});
}
foreach my $id (@invests) {
	diag("IR #$id state is " . ticket_state($agent, $id)) if($ENV{'TEST_VERBOSE'});
}


sub bulk_abandon {
	my $agent = shift;
	my @to_abandon = @_;
	
	go_home($agent);
	$agent->follow_link_ok({text => "Incidents", n => '1'}, "Followed 'Incidents' link");
	$agent->follow_link_ok({text => "Bulk Abandon", n => '1'}, "Followed 'Bulk Abandon' link");
	
	$agent->form_number(3);
	foreach my $id (@to_abandon) {
		$agent->tick('SelectedTickets', $id);
	}
	
	$agent->click('BulkAbandon');
	
	foreach my $id (@to_abandon) {
		ok_and_content_like($agent, qr/Ticket $id: State changed from \w+ to abandoned/, "Incident $id abandoned");
	}
	
	$agent->form_number(3);
	ok($agent->value('BulkAbandon'), "Still on Bulk Abandon page");
}

sub resolve_rtir_ticket {
	my $agent = shift;
	my $id = shift;
	my $type = shift || 'Ticket';
	
	display_ticket($agent, $id);
	$agent->follow_link_ok({text => "Quick Resolve", n => "1"}, "Followed 'Quick Resolve' link");
	
	is($agent->status, 200, "Attempting to resolve $type #$id");
	
	$agent->content_like(qr/.*State changed from \w+ to resolved.*/, "Successfully resolved $type #$id")
}

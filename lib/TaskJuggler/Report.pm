package TaskJuggler::Report;

use Modern::Perl;
use Text::CSV_XS qw(csv);
use GraphViz2;

use TaskJuggler::Task;

sub main {
	my $file = shift @ARGV;

	die "need file" unless -f $file;

	my $task_data = csv( in => $file,
		sep_char => ";",
		headers => 'auto' );
	my %node_to_task;
	my @node_ids;

	my $level = -1;
	for my $data (@$task_data) {
		my $task = TaskJuggler::Task->new( data => $data );
		$node_to_task{$task->id} = $task;
		push @node_ids, $task->id;
	}


	my $format = 'svg';

	{
		my $graph_aon = activity_on_node_graph( \%node_to_task, \@node_ids );

		my $output_file = "$ENV{HOME}/public_html/tj/test_aon.$format";
		$graph_aon->run( driver => 'dot', format => $format, output_file => $output_file);
		#say $graph_aon->dot_input;#DEBUG
	}


	{
		my $graph_aoa = activity_on_arc_graph( \%node_to_task, \@node_ids );

		my $output_file = "$ENV{HOME}/public_html/tj/test_aoa.$format";
		$graph_aoa->run( driver => 'dot', format => $format, output_file => $output_file);
		#say $graph_aoa->dot_input;#DEBUG
	}

	#use DDP; p %node_to_task;
}

sub activity_on_arc_graph {
	my ($node_to_task, $node_ids) = @_;

	my $digraph_nodes = [ values %$node_to_task ];
	my $digraph_edges = {};

	my $line_digraph_nodes;
	my $line_digraph_edges;

	for my $node (@$digraph_nodes) {
		my $precursor_ids = $node->precursor_ids;
		for my $precursor_id (@$precursor_ids) {
			$line_digraph_nodes->{"$precursor_id|@{[ $node->id ]}"} = [ $precursor_id, $node->id ];
			$digraph_edges->{$precursor_id}{$node->id} = 1;
		}
	}

	for my $line_graph_node (keys %$line_digraph_nodes) {
		my ($d_a, $d_b) = @{ $line_digraph_nodes->{$line_graph_node} };
		my @connected_from_b = keys %{ $digraph_edges->{$d_b} };
		for my $from_b (@connected_from_b) {
			my $target = "$d_b|$from_b";
			$line_digraph_edges->{$line_graph_node}{$target} = 1;
		}
	}

	my $graph = GraphViz2->new(
		global => {
			directed => 1,
			label => 'AOA',
		},
		graph => {
			rankdir => 'LR',
			clusterrank => "local",
			#splines => 'line',
			splines => 'polyline',
			#ranksep => "0.82",
			#nodesep => "0.85",
			#K => 2,
			#maxiter => 2000,
		},
	);

	for my $node ( keys %$line_digraph_nodes ) {
		$graph->add_node(
			name => $node ,
			label => ''
			#label =>
				#join(
					#"|",
					#map { $node_to_task->{$_}->name }
						#@{ $line_digraph_nodes->{$node} }
				#),
		);
	}
	for my $from (keys %$line_digraph_edges) {
		for my $to (keys %{ $line_digraph_edges->{$from} }) {
			my ($d_a, $d_b) = @{ $line_digraph_nodes->{$from} };
			my $label = $node_to_task->{$d_b}->name;
			$graph->add_edge( from => $from , to => $to, label => $label );
		}
	}

	return $graph;
}

sub activity_on_node_graph {
	my ($node_to_task, $node_ids) = @_;

	my $graph = GraphViz2->new(
		global => {
			directed => 1,
			label => 'Project Activity Network',
		},
		graph => {
			rankdir => 'LR',
			clusterrank => "local",
			#splines => 'line',
			splines => 'polyline',
			#ranksep => "0.82",
			#nodesep => "0.85",
			#K => 2,
			#maxiter => 2000,
		},
	);

	my $level = -1;
	for my $id (@$node_ids) {
		my $task = $node_to_task->{$id};
		#say "@{[ $task->depth ]} @{[ $task->id ]} @{[ $task->name ]}";
		my $depth = $task->depth;
		if( $depth > $level ) {
			$level++;
			$graph->push_subgraph(
				name =>
					"cluster_" .
					$task->id,
				subgraph => {
					style => 'invis', # no frame around clusters
				},
				#graph => {
					#rankdir => $depth % 2 ? 'LR' : 'TB' ,
				#},
			);
		} else {
			while( $level > $depth ) {
				$level--;
				$graph->pop_subgraph;
			}
		}
		if( @{ $task->precursor_ids } ) {
			$graph->add_node(
				name => $task->id,
				label => $task->name,
			);
		}
	}
	while( $level > -1 ) {
		$level--;
		$graph->pop_subgraph;
	}
	for my $node_id (keys %$node_to_task) {
		my $precursor_ids = $node_to_task->{$node_id}->precursor_ids;
		for my $precursor_id (@$precursor_ids) {
			$graph->add_edge( from => $precursor_id, to => $node_id, color => 'blue' );
			for my $task ($node_to_task->{$precursor_id}, $node_to_task->{$node_id}) {
				$graph->add_node(
					name => $task->id,
					label => $task->name,
				);
			}
			#my $children_ids = $node_to_task->{$precursor_id}->children_ids;
			#for my $children_id (@$children_ids) {
				#$graph->add_edge( to => $precursor_id, from => $children_id, color => 'red', style => 'dashed' );
			#}
		}
		if( 0 ) {
			my $children_ids = $node_to_task->{$node_id}->children_ids;
			for my $children_id (@$children_ids) {
				$graph->add_edge( to => $node_id, from => $children_id, color => 'red', style => 'dashed' );
			}
		}

	}

	return $graph;
}

1;

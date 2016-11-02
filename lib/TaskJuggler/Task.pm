package TaskJuggler::Task;

use Moo;
use MooX::HandlesVia;

use constant NAME_ID_ITEM => qr/ (?<name> .*?) [ ] \( (?<id> [^)]+ ) \) /x;

=attr data

C<id>, C<has_id>

C<duration>, C<has_duration>

C<effort>, C<has_effort>

C<name>, C<has_name>

C<start>, C<has_start>

C<end>, C<has_end>


=cut

has data => (
	is => 'rw',
	trigger => 1,
	handles_via => 'Hash',
	handles => {
		map {
			my $key = $_;
			my $key_lc = lc $key;
			(
				$key_lc          => [ 'get', $key ],
				"has_${key_lc}"  => [ 'exists', $key ],
			);
		 } ( qw(Id Duration Effort Name Start End) ),
	},
);

=func data_headers

Returns an ArrayRef of the keys in the C<data> attribute.

=cut
sub data_headers {
	my ($self) = @_;
	[ keys %{ $self->data } ];
}

sub _trigger_data {
	my ($self) = @_;
	# Odd bug where the Name value is prefixed with spaces that should not
	# be there.
	$self->data->{Name} =~ s/^\s+//g;
}

=attr

C<children_ids>

C<precursor_ids>

C<resource_ids>

=cut
has [qw( children_ids precursor_ids resource_ids )] => (
	is => 'lazy',
);

sub _get_ids {
	my ($str) = @_;
	$str .= ", ";
	my @ids;
	while( $str =~ /@{[ NAME_ID_ITEM ]} , [ ]/gx ) {
		push @ids, $+{id};
	}

	\@ids;
}

sub _build_children_ids {
	my ($self) = @_;
	return _get_ids($self->data->{Children});
}

sub _build_precursor_ids {
	my ($self) = @_;
	my $precursor_str = $self->data->{Precursors} . ", ";
	my @precursor_ids;
	while( $precursor_str =~ /@{[ NAME_ID_ITEM ]} [ ] \]->\[ [ ] (?<date> \d{4}-\d{2}-\d{2} ) , [ ]/gx ) {
		push @precursor_ids, $+{id};
	}

	\@precursor_ids;
}

sub _build_resource_ids {
	my ($self) = @_;
	return _get_ids($self->data->{Resources});
}

1;

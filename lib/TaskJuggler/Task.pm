package TaskJuggler::Task;

use Moo;
use MooX::HandlesVia;

use constant NAME_ID_ITEM => qr/ (?<name> .*?) [ ] \( (?<id> [^)]+ ) \) /x;

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
		 } ( qw(Id Duration Effort Name Start End) )
		#Children     "Navigation (curie.nav), v0.002 (curie.m0_002), v0.003 (curie.m0_003), v0.004 (curie.m0_004)",
		#Precursors   "",
		#Resources    "",
	},
);

sub _trigger_data {
	my ($self) = @_;
	# Odd bug where the Name value is prefixed with spaces that should not
	# be there.
	$self->data->{Name} =~ s/^\s+//g;
}

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

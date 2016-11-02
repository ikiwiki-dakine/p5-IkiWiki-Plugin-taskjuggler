package TaskJuggler::Report;

use Modern::Perl;
use Text::CSV_XS qw(csv);

use TaskJuggler::Task;

sub main {
	my $file = shift @ARGV;
	die "need file" unless -f $file;

	my $task_data = csv( in => $file,
		sep_char => ";",
		headers => 'auto' );
	my @t = map { TaskJuggler::Task->new( data => $_ ) } @$task_data;
}

1;

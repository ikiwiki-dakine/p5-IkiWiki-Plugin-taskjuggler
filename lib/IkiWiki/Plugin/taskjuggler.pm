package IkiWiki::Plugin::taskjuggler;

use warnings;
use strict;
use IkiWiki 3.00;
use File::Temp qw (tempdir);
use File::Spec;
use File::Find;
use Encode;

sub import {
	hook(type => "getsetup", id => "tjp", call => \&getsetup);
	hook(type => "htmlize", id => "tjp", call => \&htmlize);
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => 1, # format plugin
			section => "format",
		},
}

sub htmlize(@) {
	my %params = @_;

	my $page = $params{page};
	my $content = $params{content};
	my $destdir = File::Spec->rel2abs($config{destdir});

	my $tmpdir = tempdir ('tjp.XXXXXXXXXX', TMPDIR => 1, CLEANUP => 1);

	my $page_filename = File::Spec->rel2abs(srcfile($page), $config{srcdir});
	my ($filename) = grep { -f $_ }  map { "$_.tjp" } ( $page_filename, "$page_filename/index" );

	# Bring back linking... this is major hack.
	# Figure out how to turn off [[...]] linking in ikiwiki
	$content =~ s,<span class="createlink">(?<name>[^>]*?)</span>,[[$+{name}]],sg;

	# Read in a list of all the reports
	open my $reports_fh, '-|', qw(tj3 --no-reports --list-reports .),  $filename;
	my @reports_output_all;
	chomp, push @reports_output_all, $_ while(<$reports_fh>);

	# Get metadata out of the report list output
	my @reports_output;
	while( @reports_output_all ) {
		my $current = pop @reports_output_all;
		last if( $current =~ /^Checking/ );
		my ($path, $format, $name) = split ' ', $current, 3;
		unshift @reports_output, {
			path => $path,
			format => $format,
			name => $name,
		};
	}
	my @reports = map { $_->{name} } grep { $_->{format} eq 'html' } @reports_output;

	die "No HTML reports in TaskJuggler file $page" unless @reports;

	system( qw(tj3),
		qw(--output-dir), $tmpdir,
		$filename );

	my %html = ();
	my $copy_to_page = sub {
		my $abs_filename = $File::Find::name;
		my $filename = File::Spec->abs2rel($File::Find::name, $tmpdir);
		return unless -f $abs_filename;
		return if $filename =~ /\.tj[pi]$/;
		my $dest_page = "$page/$filename";
		my $data = readfile($abs_filename, 1);
		if( $filename =~ /^(?<base>.*)\.html$/ ) {
			my $name = $+{base};
			$html{$name} = decode_utf8($data);
		} else {
			will_render( $params{page}, $dest_page );
			writefile($filename, "$destdir/$page", $data, 1);
		}
	};

	find($copy_to_page, $tmpdir);

	my $remove_css = 0;
	for my $report (@html{@reports}) {
		if( $remove_css ) {
			$report =~ s/<link [^>]*? \Qtjreport.css\E [^>]*? >//xsg;
		} else {
			my $insert = <<HTML;
			<style type="text/css">
			.tj_page table {
				border-collapse: initial !important;
				margin-bottom: 0em !important;
			}
			.tj_page th, .tj_page td {
				border: 0px !important;
			}
			</style>
HTML
			$report =~ s/(<link [^>]*? \Qtjreport.css\E [^>]*? >)/$1\n$insert/xsg;
			$remove_css = 1;
		}
	}

	my ($h1) = (values %html)[0] =~ m,(<h1 [^>]*? > [^<]*? </h1>),xs;
	for my $report (values %html) {
		$report =~ s/\Q$h1\E//g;
	}

	my $all_html = join "\n", map { exists $html{$_} ? qq|<a name="$_"></a>\n| . $html{$_} : "" } @reports;

	# prefix with header
	$all_html = $h1 . $all_html;

	for my $report_name (@reports) {
		$all_html =~ s/$report_name.html/#$report_name/sg;
	}
	return $all_html;
}

1;

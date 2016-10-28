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

	my $tmpdir = tempdir ('tjp.XXXXXXXXXX', TMPDIR => 1, CLEANUP => 0);

	my $filename = 'build.tjp';

	# Bring back linking... this is major hack.
	# Figure out how to turn off [[...]] linking in ikiwiki
	$content =~ s,<span class="createlink">(?<name>[^>]*?)</span>,[[$+{name}]],sg;

	writefile($filename, $tmpdir, $content);
	my @reports = grep { length $_ > 0 } ($content =~ /textreport.*?"([^"]*?)"/g);
	system( qw(tj3),
		qw(--output-dir), $tmpdir,
		File::Spec->catfile($tmpdir, $filename) );

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

	my $all_html = join "\n", map { qq|<a name="$_"></a>\n| . $html{$_} } @reports;
	for my $report_name (@reports) {
		$all_html =~ s/$report_name.html/#$report_name/sg;
	}
	return $all_html;
}

1;

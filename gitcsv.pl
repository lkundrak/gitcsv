# Format git history into a CSV-file
# Assigns a semi-intelligently decided branch to each commit.
# Should be rather robust when it comes to various weirdnesses.

use strict;
use warnings;

# Return list of branches in order in which we intend to process them
sub branches
{
	local $ENV{LANG} = 'C';
	open (my $refs, '-|', 'git', 'show-ref');
	open (my $head, '-|', 'git', 'symbolic-ref', '-q', 'refs/remotes/origin/HEAD');
	$_ = <$head>;
	$_ ||= 'master';
	chomp;

	# HEAD branch, and following from the oldest
	return $_, map { $_->[0] } sort { $a->[1] <=> $b->[1] } map {
		open (my $timestamp, '-|', 'git', 'log', '--pretty=%ct', $_, '-1');
		[ $_ => <$timestamp> ]
		# From the shortest
		#open (my $revlist, '-|', 'git', 'rev-list', $_);
		#[ $_ => @{[<$revlist>]} ];
	} map {
		open (my $symref, '-|', 'git', 'symbolic-ref', '-q', $_);
		<$symref> ? () : $_;
	} map { m{(refs/remotes/origin/.*)} } <$refs>;
}

# Return a handle to shortlog formatted for machine consumption
sub shortlog
{
	my $branch = shift;
	my $root = shift;

	local $ENV{LANG} = 'C';
	# shortstat is not displayed for commits that have no changes,
	# we separate the log entries with '#' to detect such cases
	open (my $log, '-|', 'git', 'log', '--date=short',
		'--shortstat', ($root ? '--first-parent' : ()),
		'--pretty=#%n%h%n%aN%n%aE%n%ad%n%at%n%cN%n%cE%n%cd%n%ct%n%s', #'-2',
		($root ? "$root.." : '').($branch || 'HEAD'));
	<$log>; # skip first '#'
	return $log;
}

# Print CSV-formatted line to specified handle
sub printrow
{
	print join ',', map { "\"$_\"" } 
		map { s/(["\\"])/\\$1/g; $_ }
		map { $_ } @_;
	print "\n";
}

my %processed;

printrow ('Commit ID', 'Author Name', 'Author Address',
	'Author Date', 'Author Time', 'Committer Mame',
	'Committer Address', 'Committer Date', 'Committer Time',
	'Subject', 'Files changed', 'Lines Added', 'Lines Deleted', 'Branch');

my $head;
BRANCH: foreach my $branch (branches) {
	my $log = shortlog ($branch, $head);

	# Assume first is head
	$head = $branch unless $head;

	while (grep { $_ } my @row = map { chomp if $_; $_ }
		map { scalar <$log> } (0..10)) {
		if (not defined $row[10] or $row[10] eq '#') {
			# Commit entry terminated too soon, no shortstat entry
			@row[10..12] = (0, 0, 0);
		} elsif ($row[10] eq '') {
			# Empty line always introduces shortstat
			@row[10..12] = <$log> =~
				/(\d+) files? changed.*\D(\d+) insertions?.*\D(\d+) deletions?/
				or die 'Malformed shortstat';
			<$log>; # Skip '#'
		} else {
			die 'Unexpected input';
		}
		# Proceed with next branch once we meet with an already processed one
		next BRANCH if exists $processed{$row[0]};
		$processed{$row[0]} = undef;
		$branch =~ /([^\/]*)$/ or die 'Weird branch name';
		printrow (@row, $1);
	}
}

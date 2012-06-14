#!/usr/bin/perl
#
# Format git history into a CSV-file
# Assigns a semi-intelligently decided branch to each commit.
# Should be rather robust when it comes to various weirdnesses.

use Cwd;
use File::Basename;

use strict;
use warnings;

# Return list of branches in order in which we intend to process them
sub branches
{
	local $ENV{LANG} = 'C';
	open (my $refs, '-|', 'git', 'show-ref');
	open (my $head, '-|', 'git', 'symbolic-ref', '-q', 'refs/remotes/origin/HEAD');
	$_ = <$head>;
	$_ ||= 'refs/remotes/origin/master';
	chomp;

	# HEAD branch, and following from the oldest
	return $_, map { $_->[0] } sort { $a->[1] <=> $b->[1] } map {
		open (my $timestamp, '-|', 'git', 'log', '--pretty=%ct', $_, '-1');
		[ $_ => <$timestamp> ]
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
		'--pretty=#%n%h%n%aN%n%aE%n%at%n%cN%n%cE%n%ct%n%s', #'-2',
		($root ? "$root.." : '').($branch || 'HEAD'));
	<$log>; # skip first '#'
	return $log;
}

# Print CSV-formatted line to specified handle
sub printrow
{
	print join ',', map { "\"$_\"" } 
		map { s/(["\\"])/_/g; $_ }
		map { s/(.{250}).*/$1.../g; $_ }
		map { $_ } @_;
	print "\n";
}

sub processrepo
{
	my $repo = shift;

	my %processed;
	my $head;

	local $ENV{GIT_DIR};
	$ENV{GIT_DIR} = "$repo/.git" unless $repo eq '.';

	BRANCH: foreach my $branch (branches) {

		my $log = shortlog ($branch, $head);

		$branch =~ /([^\/]*)$/ or die 'Weird branch name';
		my $branchname = $1;

		# Assume first is head
		$head = $branch unless $head;

		while (grep { $_ } my @row = map { chomp if $_; $_ }
			map { scalar <$log> } (0..8)) {
			if (not defined $row[8] or $row[8] eq '#') {
				# Commit entry terminated too soon, no shortstat entry
				@row[8..10] = (0, 0, 0);
			} elsif ($row[8] eq '') {
				# Empty line always introduces shortstat
				@row[8..10] = <$log> =~
					/(\d+) files? changed.*\D(\d+) insertions?.*\D(\d+) deletions?/
					or die 'Malformed shortstat';
				<$log>; # Skip '#'
			} else {
				die 'Unexpected input';
			}
			# Proceed with next branch once we meet with an already processed one
			next BRANCH if exists $processed{$row[0]};
			$processed{$row[0]} = undef;

			$repo = basename (cwd) if $repo eq '.';
			printrow ($repo, @row, $branchname);
		}
	}
}

printrow ('Repository', 'GIT Commit', 'Author', 'Author Address',
	'Author Time', 'Committer',
	'Committer Address', 'Committer Time',
	'Subject', 'Files changed', 'Lines Added', 'Lines Deleted',
	'Branch');

@ARGV = ('.') unless @ARGV;
processrepo ($_) foreach @ARGV;

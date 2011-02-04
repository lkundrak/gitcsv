import java.io.File;
import java.io.FileWriter;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.text.SimpleDateFormat;

import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.diff.Edit;
import org.eclipse.jgit.lib.AbbreviatedObjectId;
import org.eclipse.jgit.lib.Ref;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.lib.RepositoryBuilder;
import org.eclipse.jgit.patch.FileHeader;
import org.eclipse.jgit.patch.HunkHeader;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.storage.file.FileRepository;

import au.com.bytecode.opencsv.CSVWriter;

class gitcsv
{

// Counts changes in a commit, similar to what
// git show --stat would do.
// Seems pretty inefficient, maybe it would make sense
// to extend JGit instead.
public static class LineChanges
{

	public int added, deleted, files;

	LineChanges (DiffFormatter formatter, RevCommit commit)
		throws java.io.IOException
	{

		added = deleted = files = 0;

		// No changes for root commit
		if (commit.getParentCount () == 0)
			return;

		List<DiffEntry> diff = formatter.scan (commit.getParent (0), commit);
		for (DiffEntry diffentry : diff) {
			files++;

			// Renames seem to be very expensive
			// Really?
			if (!diffentry.toString ().startsWith ("DiffEntry[MODIFY "))
				continue;

			FileHeader header = formatter.toFileHeader (diffentry);
			for (HunkHeader hunk : header.getHunks ()) {
				// These are populated when parsing a patch file only,
				// remain unset when creating hunks from DiffEntry
				//deleted += hunk.getOldImage ().getLinesDeleted ();
				//added += hunk.getOldImage ().getLinesAdded ();
				for (Edit edit : hunk.toEditList ()) {
					deleted += edit.getEndA () - edit.getBeginA ();
					added += edit.getEndB () - edit.getBeginB ();
				}
			}
		}
	}

}

public static void
main (String argv[])
	throws java.io.IOException
{
	CSVWriter commits_csv = new CSVWriter (new FileWriter("commits.csv"));
	CSVWriter branches_csv = new CSVWriter (new FileWriter("branches.csv"));
	CSVWriter tags_csv = new CSVWriter (new FileWriter("tags.csv"));

	// Used to ensure that we do not fetch commit details more than once
	HashSet<String> commits_seen = new HashSet<String> ();

	// Open the repository
	RepositoryBuilder builder = new RepositoryBuilder ();
	builder.findGitDir (new File (argv[0]));
	builder.readEnvironment ();
	builder.findGitDir ();
	builder.build ();
	Repository repo = new FileRepository (builder);

	// Initialize these here so that we don't have
	// to recreate them upon each iteration
	RevWalk walk = new RevWalk (repo);
	DiffFormatter formatter = new DiffFormatter (null);
	formatter.setRepository (repo);
	SimpleDateFormat date = new SimpleDateFormat ();
	date.applyPattern ("yyyy-MM-dd");

	for (Map.Entry<String,Ref> entry : repo.getAllRefs ().entrySet ()) {
		CSVWriter ref_csv;
		String refname;
		if (entry.getKey ().startsWith ("refs/remotes/origin/")) {
			ref_csv = branches_csv;
			refname = entry.getKey ().substring ("refs/remotes/origin/".length ());
		} else if (entry.getKey ().startsWith ("refs/tags")) {
			ref_csv = tags_csv;
			refname = entry.getKey ().substring ("refs/tags/".length ());
		} else {
			// We're not interested in anything that's not tagged and not in a branch
			continue;
		}

		// Possibly dereference attotated tags
		RevCommit startcommit = walk.lookupCommit (
			entry.getValue ().getPeeledObjectId () == null
			? entry.getValue ().getObjectId ()
			: entry.getValue ().getPeeledObjectId ());

		walk.markStart (startcommit);
		for (RevCommit commit : walk) {

			// Seems like abbreviation does not work in JGit, so we abbreviate
			// the ids ourselves to 10 chars which we consider safe enough
			String commit_id = AbbreviatedObjectId.fromObjectId (commit).name ();
			commit_id = commit_id.substring (0, 10);

			ref_csv.writeNext (new String[] {
				AbbreviatedObjectId.fromObjectId (commit).name (),
				refname});

			// Skip fetching commit details if we've already seen the commit
			if (commits_seen.contains (commit_id))
				continue;
			commits_seen.add (commit_id);

			LineChanges changes = new LineChanges (formatter, commit);
			commits_csv.writeNext (new String[] {
				AbbreviatedObjectId.fromObjectId (commit).name (),
				commit.getShortMessage (),
				commit.getAuthorIdent ().getEmailAddress (),
				commit.getAuthorIdent ().getName (),
				commit.getCommitterIdent ().getEmailAddress (),
				commit.getCommitterIdent ().getName (),
				date.format (commit.getCommitTime () * 1000L).toString (),
				Integer.toString (commit.getCommitTime ()),
				Integer.toString (commit.getParentCount ()),
				Integer.toString (changes.files),
				Integer.toString (changes.added),
				Integer.toString (changes.deleted)});
		}
		walk.reset ();
		
	}

	commits_csv.close ();
	branches_csv.close ();
	tags_csv.close ();
}

}

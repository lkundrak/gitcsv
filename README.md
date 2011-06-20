gitcsv GoodData upload example
==============================

1. Prepare a CSV from your git repository ("../perl-WWW-GoodData" in this case)
<br />
<code>
$ (cd ../perl-WWW-GoodData; perl ../gitcsv/gitcsv.pl) >commits.csv
</code>

2. Log in to GoodData with [WWW::GoodData](http://search.cpan.org/dist/WWW-GoodData/) client
<br />
<code>
$ gdc --user wololo@example.net
Password: 
</code>

3. Create a project
<br />
<code>
\> mkproject Commits
</code>

4. Create a logical data model
<br />
<code>
\> chmodel --file commits.maql
</code>

5. Trigger the upload
<br />
<code>
\> upload commits.json
</code>

6. Take a note of the project URI for later use
<br />
<code>
\> project
/gdc/projects/1c3ac6a44eb8036d99e5c52124f0e24f
</code>

7. Log off
<br />
<code>
\> ^D
</code>

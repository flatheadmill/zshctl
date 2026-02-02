I'm experimenting with a programmers journal using `git notes`.

The programmer's journal is maintained using `git notes --ref=journal`. This
will keep the journal under a `git/notes/journal` reference which is apart
from the default `git/notes/commit` reference.

The following commands are a place to start when managing the journal. Note
that `git notes add` will not stomp, but `git notes remove` will delete
without prompting. It is better to use `git notes edit` and view the message
you want to delete, then delete it by deleting the note body in your editor.

```zsh
# Add a note to the current entry.
git notes --ref=journal add

# Add a note to a specific commit.
git notes --ref=journal add abc1234

# Add a quick note without popping an editor.
git notes --ref=journal add -m 'Interited file descriptors and coproc'

# Read specific notes.
git notes --ref=journal show HEAD
git notes --ref=journal show abc1234

# List all notes.
git notes --ref=journal list

# See commits with journal entries.
git log --notes=refs/notes/journal

# See commits with notes from multiple namespaces.
git log --notes=refs/notes/journal --notes=refs/notes/todo

# Push the journal.
git push origin refs/notes/journal

# Pull all notes namespaces.
git fetch origin refs/notes/*:refs/notes/*

# Push all notes on a `git push`.
git config --add remote.origin.push '+refs/notes/*:refs/notes/*'

# Pull all notes on a `git pull`.
git config --add remote.origin.fetch '+refs/notes/*:refs/notes/*'
```

Get a basic journal.

```
git notes --ref=journal list | while read ref commit; do
    echo "## $(git show -s --format=%s $commit)"
    print here $commit
    git notes --ref=journal show $commit
    print there $commit
    echo "---"
done
```

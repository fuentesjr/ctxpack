Make the following small behavior change.

StoriesController#update currently resurrects a deleted story when the owner
edits it.

Change this so editing a deleted story still updates the submitted story
attributes, but keeps the story deleted. Non-deleted stories must continue to
update normally, and the explicit undelete action must remain the way to
restore a deleted story.

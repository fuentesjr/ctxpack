A controller spec is failing on this branch:

    bundle exec rspec spec/controllers/articles_controller_spec.rb -e "assignes last article with id like parent_id"

Failure output:

    {failing_test_output}

Diagnose and fix the bug so this spec passes. Do not modify any file under
spec/.

<!-- {failing_test_output} is filled mechanically by the harness with the
     verbatim runner output captured once at grid setup, identical in both
     arms. -->

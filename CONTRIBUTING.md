# Contribute to the GPU Operator Project

Want to hack on the NVIDIA Container Toolkit Project? Awesome!
We only require you to sign your work, the below section describes this!

## Sign your work

The sign-off is a simple line at the end of the explanation for the patch. Your
signature certifies that you wrote the patch or otherwise have the right to pass
it on as an open-source patch. The rules are pretty simple: if you can certify
the below (from [developercertificate.org](http://developercertificate.org/)):

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
1 Letterman Drive
Suite D4700
San Francisco, CA, 94129

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

Then you just add a line to every git commit message:

    Signed-off-by: Joe Smith <joe.smith@email.com>

Use your real name (sorry, no pseudonyms or anonymous contributions.)

If you set your `user.name` and `user.email` git configs, you can sign your
commit automatically with `git commit -s`.

## Pull Request Guidelines

### One PR per root cause, not per file

If the same bug appears in multiple OS-specific directories
(ubuntu22.04, ubuntu24.04, rhel8, rhel9, rhel10), fix all instances
in a single PR. Title the PR around the root cause:

- Good: `fix: set -e suppresses command-substitution exit codes`
- Avoid: one PR per distro for the same one-liner change

### Open an issue before bulk fixes

If you find five or more instances of the same pattern, open one
GitHub issue first. Describe the pattern and your proposed fix.
Wait for a maintainer response before opening any PR. This avoids
flooding CI with work the team may not want.

### Do not open more than three PRs per day

Each PR triggers a CI run that uses shared compute. Submitting many
PRs in a single session blocks CI for every other contributor.
If you have many fixes, batch them or stagger them across days.

### Check for conflicts before opening

Search for open PRs that touch the same file before opening a new one:

```
is:open is:pr <filename>
```

A PR that conflicts with an already-open PR will stall on review.

### Separate cosmetic from correctness changes

Put style fixes (variable naming, deprecated test syntax) in their
own PR, separate from behavioral bug fixes. Reviewers triage
correctness issues first; cosmetic changes buried inside bug fixes
slow the queue.

### Write tests that execute the code

A test that greps for absence of old text is a linter check, not a
regression test. Tests should invoke the function being fixed (even
via a stub harness) and verify the correct behavior. A test that
passes on the unchanged code is not useful.

### Link every PR to an issue

Every PR must include a `Fixes #NNN` or `Related to #NNN` reference.
If no issue exists, open one first (see above). PRs without an issue
link are harder to triage and may be closed without review.


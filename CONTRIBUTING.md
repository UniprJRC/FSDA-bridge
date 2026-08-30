# Contributing to FSDA-bridge

Rules for the packaging phase of the project. Read `CONSTITUTION.md` first; it defines the
bridge architecture, marshalling contracts, and agreement gate that everything here builds on.

## 1. Repository layout

Packages live in `packages/<name>/` (e.g. `packages/pyfsda/`, `packages/FSDAjl/`).

`code/` is shared prototype space from the spec phase. Do not put group-specific work there.

`specs/` is the design-rationale archive. Do not edit closed specs.

## 2. Git workflow

**Branches.** Each group works on its own branch: `group1/pypi`, `group2/cran`, `group3/julia`.

**Forks.** Each group has at least one fork (typically the coordinator's, with students added as
collaborators). Students can also use their own personal forks/branches for individual submissions. Either way, PRs compare against
**your group's branch** on upstream, never against `main` or another group's branch.

**Who opens the PR.** For individual work (a single student's batch of examples, a fix, a docs update),
the student can open a PR directly from their fork/branch. For collaborative work where multiple people
contributed to the diff, the group coordinator aggregates and opens the PR, and is responsible for
its quality (see §12).

**Keeping in sync.** Keep your fork in sync with the upstream, especially before opening a PR.
After every merge your fork becomes stale; working on an outdated fork and then opening a PR
creates unnecessary merge conflicts.

**Merging to main.** The maintainers merge group branches into `main` when the
work is ready. Do not target `main` with your PRs.

## 3. Commits

One logical concern per commit. The test is: can a reviewer tell what changed and why from the
diff alone?

The unit is a concern, not a file. Several changes of the same kind (e.g. a batch of examples)
can go in one commit, because the concern is uniform and nothing is hidden. But changes of
different kinds (e.g. a feature and its documentation, or a file copy and modifications to that
copy) belong in separate commits, because mixing them hides what actually changed in the diff.

Format: `type(package): short description` for package-scoped changes, `type: short description`
for repo-level changes. No scope means the change is not specific to one package.

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`.

Examples:

- `feat(pyfsda): add workspace persistence`
- `fix(fsdabridge): guard check_engine for missing MATLAB`
- `docs: update CONTRIBUTING.md`
- `test(FSDAjl): add mahalFS agreement check`

## 4. Pull requests

**Size.** Smaller PRs get reviewed faster and with better feedback. Do not accumulate weeks of
changes into a single PR; merge periodically.

**Description.** The PR must include: a short summary of what it accomplishes as a whole, links to any previous PR or Issues it addresses, what it
should be tested against, and any workarounds or non-obvious decisions made along the way. Commit
messages say what changed at each step; the PR description says why and how to verify.

## 5. The engine is read-only

Your package wraps `engine.*`; it does not re-implement the MATLAB call. Never duplicate the
MATLAB call, never edit FSDA, never change `engine.*`'s marshalling or call semantics.

If you believe `engine.*` needs a change, raise it with the core maintainers. A change to engine.py
affects all three packages. Do not fork it, do not make a local copy with modifications.

Student groups have read-only access to engine files. Engine changes are merged exclusively by
the maintainers with the agreement of the developing team.

## 6. Dependencies

Do not add new dependencies to a package without clearing it with the maintainers first. Every
dependency carries a cost for users who must install it and for maintainers who must support it;
its benefits must be weighed accordingly.

## 7. Example code style

Examples are user-facing documentation. They showcase how to use the package, not how the
internals work. They are not tests and they are not debugging scripts. Follow the style of the
existing examples in the package: small docstring, link to the relevant [FSDA documentation](https://rosa.unipr.it/FSDA/index.html), consistent
structure.

**Use the facade if available.** If the function has a facade wrapper, use it. Otherwise fall back
to the package's exported `call` API. Do not use internal engine classes or raw engine calls.
API usage must be consistent across all examples in a package.

**Signal, not noise.** Print output that showcases results that are interesting for the user (coefficients, flagged outliers,
distances). Do not print engine lifecycle messages, array shapes, dictionary keys, or other
debugging artefacts. Again, this is user facing documentation and must be treated as such.

**Data.** Use the small, well-known FSDA benchmark datasets (wool, stars, citiesItaly, covid, wine,
swiss banknotes, etc.) loaded via the package's own API, or generate samples at runtime through
MATLAB (e.g. `rand`, `randi`, `randn`). Do not paste literal arrays inline in the script. Do
not commit third-party datasets to the repository; every example must run with nothing beyond
the bridge package and FSDA.

## 8. Licensing

All packages use the **EUPL-1.2** licence, matching FSDA. Do not change the licence without
sign-off from the core maintainers.

Maintainer and copyright fields on published packages (PyPI account, CRAN `Maintainer`, Julia
`authors`): ask before setting these. They carry long-term obligations.

## 9. Agreement gate

Every numerical example must reproduce its FSDA reference output within the project tolerance
(**1e-9**). Use small benchmark datasets with fixed seeds. An example that has not been checked
against the oracle is not done.

Any change to `engine.*` must pass the full agreement gate (`check_engine.*`) in all three
languages before it is committed.

See CONSTITUTION.md section 5 for the full definition.

## 10. CI and skipping

All tests and examples must skip gracefully when MATLAB is absent. The ecosystem's automated
checks (PyPI build, `R CMD check --as-cran`, Julia AutoMerge) run on machines with no MATLAB and
must pass.

## 11. Reports and findings

Bug reports, suggestions, measurements, and analysis go in GitHub issues, not in the repository
tree. The repo holds code, documentation, and examples; it is not a notebook.

## 12. For group coordinators

**You review before we review.** When you open a PR that aggregates your group's work, you are
presenting it as ready. Before requesting review, check that the work matches what was actually
asked for, that nothing out of scope slipped in, that commits follow §3, that examples match §7,
and that the diff is clean. Issues caught inside your fork are quick fixes; the same issues
caught in a PR review cost everyone more time.

Keep a diary of friction points encountered with the MATLAB engine during bridging work:
unhelpful error messages, missing features, edge cases, missing documentation. We are reporting
back to MathWorks on the user experience, and this feedback is valuable. A shared text document
is sufficient.

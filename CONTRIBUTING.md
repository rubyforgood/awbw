# Welcome Contributors! 👋

We ♥ contributors! By participating in this project, you agree to abide by the Ruby for Good [code of conduct](https://github.com/rubyforgood/awbw/blob/main/CODE_OF_CONDUCT.md).

If you're new here, here are some things you should know:

- A great introductory overview of the application is available at the [README](https://github.com/rubyforgood/awbw/blob/main/README.md).
- Issues tagged "Help Wanted" are self-contained and great for new contributors
- Pull Requests are reviewed within a week or so
- Ensure your build passes linting and tests and addresses the issue requirements
- This project relies entirely on volunteers, so please be patient with communication

# Communication 💬

If you have any questions about an issue, comment on the issue, open a new issue, or ask in [the RubyForGood slack](https://join.slack.com/t/rubyforgood/shared_invite/zt-2k5ezv241-Ia2Iac3amxDS8CuhOr69ZA). awbw has a `#awbw` channel in the Slack.

Many helpful members are available to answer your questions. Just ask, and someone will be there to help you!

You won't be yelled at for giving your best effort. The worst that can happen is that you'll be politely asked to change something. We appreciate any sort of contributions, and don't want a wall of rules to get in the way of that.

# Getting Started

## Local Environment 🛠️

#### Install WSL2 first if Using Windows

Follow [documentation](https://docs.microsoft.com/en-us/windows/wsl/install-win10) from Microsoft for enabling and installing Windows Subsystem For Linux 2 on your machine.

Make sure to install **Ubuntu** as your Linux distribution. (This should be default.)

As noted [here](https://learn.microsoft.com/en-us/windows/wsl/compare-versions#comparing-features), WSL2 performs poorly when Linux processes try to access Windows files. For that reason, it's recommended that you clone the project to a directory in the Linux file system so the app and tests don't run slowly.

You might also want to try VSCode with [this WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) as an IDE that can run on Windows but still access the Linux file system.

**Note:** If you run into any issues with a command not running, restart your machine.

### Non-Docker Setup

1. Install mise
   - Follow the [mise installation guide](https://mise.jdx.dev/getting-started.html#installing-mise-cli) for your operating system
   - mise will automatically install and manage the Ruby version specified in [`.ruby-version`](.ruby-version) with `mise i`
   - Verify that mise is working by running `mise --version`
2. Install MySQL
   - **macOS**: [Use Homebrew](https://formulae.brew.sh/formula/mysql@8.0)
   - **Windows**: Use WSL2 with Ubuntu - follow [the MariaDB install guide from digital ocean](https://www.digitalocean.com/community/tutorials/how-to-install-mariadb-on-ubuntu-20-04#step-1-installing-mariadb)

   - **Linux/Ubuntu**: Follow [the MariaDB install guide from digital ocean](https://www.digitalocean.com/community/tutorials/how-to-install-mariadb-on-ubuntu-20-04#step-1-installing-mariadb)
**Note:** If you receive an error when connecting to the database "Access denied for user 'root'@'locahost' you may need to
[create a root user password](https://phoenixnap.com/kb/access-denied-for-user-root-localhost)(a blank password will work).

   - Alternative (Docker): with docker installed run `mise docker-db` to start
     the DB only (after cloning the repo)

3. Clone the project and switch to its directory
4. Run `mise setup`
5. Run `mise server` and visit <http://localhost:3000/> to see the AWBW portal page.
6. Log in as a sample user with the default [credentials](#credentials).

### Docker Setup

For Docker-based development (recommended):

1. Ensure Docker is installed and running on your system
2. Use mise tasks to manage Docker containers. (`mise tasks` for a full list)
   - `mise docker-up` - start containers

3. Visit <http://localhost:3000/> to see the AWBW portal page
4. Log in as a sample user with the default [credentials](#credentials)

## Credentials

These credentials also work for [staging](https://awbw-staging-xzek4.ondigitalocean.app/):

- User
  - email: <umberto.user@example.com>
  - password: password
- Admin
  - email: <amy.admin@example.com>
  - password: password

## Codespaces and Dev Container - EXPERIMENTAL 🛠️

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/rubyforgood/awbw/tree/main?quickstart=1)

1. Create the container:
   - To run the container on a Github VM, follow the Codespace link above. You can connect to the Codespace using VSCode or the VSCode web editor.
   - Or follow instructions to [create a new Codespace.](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository)
2. Wait for the container to start. This will take a few (10-15) minutes since Ruby needs to be installed, the database needs to be created, and the `mise setup` script needs to run
3. Run `mise server`. On the Ports tab, visit the forwarded port 3000 URL marked as Application to see the AWBW portal page.
4. Login as a sample user with the default [credentials](#credentials).

## Troubleshooting 👷🏼‍♀️

Please let us know by opening up an issue! We have many new contributors come through and it is likely what you experienced will happen to them as well.

# 🤝 Code Contribution Workflow

1. **Identify an unassigned issue**. Read more [here](#issues) about how to pick a good issue.
2. **Assign it** to avoid duplicated efforts (or request assignment by adding a comment).
3. **Fork the repo** if you're not a contributor yet. Read about becoming a contributor [here](#becoming-a-repo-contributor).
4. **Create a new branch** for the issue using the format `XXX-brief-description-of-feature`, where `XXX` is the issue number.
5. **Commit fixes locally** using descriptive messages that indicate the affected parts of the app. Read debugging tips [here](#debugging).
6. If you create a new model run `bundle exec annotate` from the root of the app
7. **Create RSpec tests** to validate that your work fixes the issue (if you need help with this, please reach out!). Read guidelines [here](#writing-browsersystemfeature-testsspecs).
8. **Run the tests** and make sure all tests pass successfully; if any fail, fix the issues causing the failures. Read guidelines [here](#test-before-submitting-pull-requests).
9. **Final commit** if tests needed fixing.
10. **Squash smaller commits.** Read guidelines [here](#squashing-commits).
11. **Push** up the branch
12. **Create a pull request** and indicate the addressed issue (e.g. `Resolves #1`) in the title, which will ensure the issue gets closed automatically when the pull request gets merged. Read PR guidelines [here](#pull-requests).
13. **Code review**: At this point, someone will work with you on doing a code review. The automated tests will run linting, rspec, and brakeman tests. If the automated tests give :+1: to the PR merging, we can then do any additional (staging) testing as needed.

14. **Merge**: Finally if all looks good the core team will merge your code in; if your feature branch was in this main repository, the branch will be deleted after the PR is merged.

15. Deploys are currently done about once a week! Read the deployment process [here](#deployment-process).

## Issues

Please feel free to contribute! While we welcome all contributions to this app, pull-requests that address outstanding Issues _and_ have appropriate test coverage for them will be strongly prioritized. In particular, addressing issues that are tagged with the next milestone should be prioritized higher.

All work is organized by issues.
[Find issues here.](https://github.com/rubyforgood/awbw/issues)

If you would like to contribute, please ask for an issue to be assigned to you.
If you would like to contribute something that is not represented by an issue, please make an issue and assign yourself.
Only take multiple issues if they are related and you can solve all of them at the same time with the same pull request.

## Becoming a Repo Contributor

Users that are frequent contributors and are involved in discussion (join the slack channel! :)) may be given direct Contributor access to the Repo so they can submit Pull Requests directly instead of Forking first.

## Debugging

If starting server directly, via `rail s` or `rail console`, or built-in debugger in RubyMine, or running `bundle exec rspec path/to/spec.rb:line_no`, then you can use `binding.pry` to debug. Drop the pry where you want the execution to pause.

If you want to connect via Shopify Ruby LSP VSCode extension or rdbg, start the server with `bundle exec rdbg -O -n -c -- bin/rails server -p 3000`

## Squashing commits

Consider the balance of "polluting the git log with commit messages" vs. "providing useful detail about the history of changes in the git log". If you have several smaller commits that serve a one purpose, you are encouraged to squash them into a single commit. There's no hard and fast rule here about this (for now), just use your best judgement. Please don't squash other people's commits. Everyone who contributes here deserves credit for their work! :)

Only commit the schema.rb only if you have committed anything that would change the DB schema (i.e. a migration).

## Pull Requests

### Stay scoped

Try to keep your PRs limited to one particular issue, and don't make changes that are out of scope for that issue. If you notice something that needs attention but is out of scope, please [create a new issue](https://github.com/rubyforgood/awbw/issues/new).

### In-flight pull requests

If you are so inclined, you can open a draft PR as you continue to work on it. Sometimes we want to get a PR up there and going so that other people can review it or provide feedback, but maybe it's incomplete. This is OK, but if you do it, please tag your PR with `in-progress` label so that we know not to review / merge it.

## Tests 🧪

### Writing Browser/System/Feature Tests/Specs

Add a test for your change. If you are adding functionality or fixing a bug, you should add a test!

If you are inexperienced in writing tests or get stuck on one, please reach out for help :)

#### Guidelines

- Prefer request tests over system tests (which run much slower) unless you need to test Javascript or other interactivity
- When creating factories, in each RSpec test, hard code all values that you check with a RSpec matcher. Don't check FactoryBot default values. See [#4217](https://github.com/rubyforgood/human-essentials/issues/4217) for why.
- Keep individual tests tightly scoped, only test the endpoint that you want to test. E.g. create inventory directly using `TestInventory` rather than using an additional endpoint.
- You probably don't need to write new tests when simple re-stylings are done (ie. the page may look slightly different but the Test suite is unaffected by those changes).

#### Useful Tips

### Test before submitting pull requests

Before submitting a pull request, run all tests and lints. Fix any broken tests and lints before submitting a pull request.

#### Continuous Integration

- There are Github Actions workflows which will run all tests in parallel using Knapsack and lints whenever you push a commit to your fork.
- Once your first PR has been merged, all commits pushed to an open PR will also run these workflows.

#### Local testing

- Run all tests with `mise spec` (or `mise docker-spec` if using docker)
- You can run a single test with `mise spec {path_to_test_name}_spec.rb` or on a specific line by appending `:LineNumber`
- If you need to skip a failing test, place `pending("Reason you are skipping the test")` into the `it` block rather than skipping with `xit`. This will allow rspec to deliver the error message without causing the test suite to fail.

```ruby
  it "works!" do
    pending("Need to implement this")
    expect(my_code).to be_valid
  end
```

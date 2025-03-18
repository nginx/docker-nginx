# Contributing Guidelines

The following is a set of guidelines for contributing to the Docker NGINX image. We really appreciate that you are considering contributing!

#### Table Of Contents

- [Getting Started](#getting-started)
- [Contributing](#contributing)
- [Code Guidelines](#code-guidelines)
- [Code of Conduct](/CODE_OF_CONDUCT.md)

## Getting Started

Follow our [how to use this image guide](https://hub.docker.com/_/nginx/) to get the Docker NGINX image up and running.

## Contributing

### Report a Bug

To report a bug, open an issue on GitHub with the label `bug` using the available [bug report issue form](/.github/ISSUE_TEMPLATE/bug_report.yml). Please ensure the bug has not already been reported. **If the bug is a potential security vulnerability, please report it using our [security policy](/SECURITY.md).**

### Suggest a Feature or Enhancement

To suggest a feature or enhancement, please create an issue on GitHub with the label `enhancement` using the available [feature request issue form](/.github/ISSUE_TEMPLATE/feature_request.yml). Please ensure the feature or enhancement has not already been suggested.

### Open a Pull Request (PR)

- Fork the repo, create a branch, implement your changes, add any relevant tests, and submit a PR when your changes are **tested** and ready for review.
- Fill in the [PR template](/.github/pull_request_template.md).

**Note:** If you'd like to implement a new feature, please consider creating a [feature request issue](/.github/ISSUE_TEMPLATE/feature_request.yml) first to start a discussion about the feature.

#### F5 Contributor License Agreement (CLA)

F5 requires all contributors to agree to the terms of the F5 CLA (available [here](https://github.com/f5/f5-cla/.github/blob/main/docs/f5_cla.md)) before any of their changes can be incorporated into an F5 Open Source repository (even contributions to the F5 CLA itself!).

If you have not yet agreed to the F5 CLA terms and submit a PR to this repository, a bot will prompt you to view and agree to the F5 CLA. You will have to agree to the F5 CLA terms through a comment in the PR before any of your changes can be merged. Your agreement signature will be safely stored by F5 and no longer be required in future PRs.

## Code Guidelines

### Git Guidelines

- Keep a clean, concise and meaningful git commit history on your branch (within reason), rebasing locally and squashing before submitting a PR.
- If possible and/or relevant, use the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format when writing a commit message, so that changelogs can be automatically generated
- Follow the guidelines of writing a good commit message as described here <https://chris.beams.io/posts/git-commit/> and summarised in the next few points:
  - In the subject line, use the present tense ("Add feature" not "Added feature").
  - In the subject line, use the imperative mood ("Move cursor to..." not "Moves cursor to...").
  - Limit the subject line to 72 characters or less.
  - Reference issues and pull requests liberally after the subject line.
  - Add more detailed description in the body of the git message (`git commit -a` to give you more space and time in your text editor to write a good message instead of `git commit -am`).

### Docker Guidelines

- Update any entrypoint scripts via the the scripts contained in the `/entrypoint` directory.
- Update any Dockerfiles via the Dockerfile templates in the root directory (e.g. `Dockerfile-alpine.template`).
- Run the `./update.sh` script to apply all entrypoint/Dockerfile template changes to the relevant image entrypoints & Dockerfiles.

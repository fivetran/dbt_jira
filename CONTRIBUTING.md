# Contributing to `dbt_jira`

1. [About this document](#about-this-document)
2. [Proposing a change](#proposing-a-change)
3. [Getting the code](#getting-the-code)
4. [Running `dbt_jira` in development](#running-dbt_jira-in-development)
5. [Testing](#testing)
6. [Submitting a Pull Request](#submitting-a-pull-request)

## About this document

This document is a guide intended for folks interested in contributing to `dbt_jira`. Below, we document the process by which members of the community should create issues and submit pull requests (PRs) in this repository. 

If you're new to contributing to open-source software, we encourage you to read this document from start to finish. If you get stuck, drop us a question in the #tools-fivetran channel within [dbt Slack](https://community.getdbt.com).

## Proposing a change

All Fivetran dbt packages are Apache 2.0-licensed open source software. They are what they are today because community members like you have opened issues, provided feedback, and contributed to the knowledge loop for the entire community. Whether you are a seasoned open source contributor or a first-time committer, we welcome and encourage you to contribute code, documentation, ideas, or problem statements to this project.

### Defining the problem

If you have an idea for a new feature or if you've discovered a bug in `dbt_jira`, the first step is to open an issue. Please check the list of [open issues](https://github.com/fivetran/dbt_jira/issues) before creating a new one. If you find a relevant issue, please add a comment to the open issue instead of creating a new one. **The `dbt_jira` maintainers are always happy to point contributors in the right direction**, so please err on the side of documenting your idea in a new issue if you are unsure where a problem statement belongs.

> **Note:** All community-contributed Pull Requests _must_ be associated with an open issue. If you submit a Pull Request that does not pertain to an open issue, you will be asked to create an issue describing the problem before the Pull Request can be reviewed.

### Discussing the idea

After you open an issue, a project maintainer will follow up by commenting on your issue (usually within 1-3 days) to explore your idea further and advise on how to implement the suggested changes. In many cases, community members will chime in with their own thoughts on the problem statement. If you as the issue creator are interested in submitting a Pull Request to address the issue, you should indicate this in the issue. The project maintainers are _always_ happy to help contributors with the implementation of fixes and features, so please also indicate if there's anything you're unsure about or could use guidance around in the issue.

### Submitting a change

If an issue is appropriately well scoped and describes a beneficial change to the `dbt_jira` codebase, then anyone may submit a Pull Request to implement the functionality described in the issue. See the sections below on how to do this.

Here's a good workflow:
- Comment on the open issue, expressing your interest in contributing the required code change
- Outline your planned implementation. If you want help getting started, ask!
- Follow the steps outlined below to develop locally. Once you have opened a PR, one of the `dbt_jira` maintainers will work with you to review your code.
- Add a test! Tests are crucial for both fixes and new features alike. We want to make sure that code works as intended, and that it avoids any bugs previously encountered. 

In some cases, the right resolution to an open issue might be tangential to the `dbt_jira` codebase. The right path forward might be a documentation update or a change that can be made in user-space. In other cases, the issue might describe functionality that the maintainers are unwilling or unable to incorporate into the codebase. When it is determined that an open issue describes functionality that will not translate to a code change in the `dbt_jira` repository, the issue will be tagged with the `wontfix` label and closed.

## Getting the code

### Installing git

You will need `git` in order to download and modify the `dbt_jira` source code. On macOS, the best way to download git is to just install [Xcode](https://developer.apple.com/support/xcode/).

### External contributors

If you are not a member of the `fivetran` GitHub organization, you can contribute to `dbt_jira` by forking the `dbt_jira` repository. For a detailed overview on forking, check out the [GitHub docs on forking](https://help.github.com/en/articles/fork-a-repo). In short, you will need to:

1. fork the `dbt_jira` repository
2. clone your fork locally
3. check out a new branch for your proposed changes
4. push changes to your fork
5. open a pull request against `fivetran/dbt_jira` from your forked repository

## Running `dbt_jira` in development

### Installation

`dbt_jira` is a dbt package, which can be installed into your existing dbt project using the [local package](https://docs.getdbt.com/docs/building-a-dbt-project/package-management#local-packages) functionality. After adding it to your project's `packages.yml` file, run `dbt deps`.

## Testing

When you add new functionality to the package it is important to ensure your changes run successfully. When opening a PR (below) please be sure to document what you did to test your changes. Screenshots and detail examples are always encouraged!

## Submitting a Pull Request

A `dbt_jira` maintainer will review your PR. They may suggest code revision for style or clarity, or request that you add additional components. These are good things! We believe that, with a little bit of help, anyone can contribute high-quality code. Similarly, the maintainers may make small adjustments themselves prior to merging.

Once all tests are passing and your PR has been approved, a `dbt_jira` maintainer will merge your changes into the active development branch and will communicate when the release will be live. And that's it! Happy developing 🎉
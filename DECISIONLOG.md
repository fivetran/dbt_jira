# Decision Log
In creating this package, which is meant for a wide range of use cases, we had to take opinionated stances on a few different questions we came across during development. We've consolidated significant choices we made here, and will continue to update as the package evolves.

## Enhancing Jira Sprint Reporting with Flexible Metrics
To improve sprint reporting in the Jira dbt package, we introduced two new models, `jira__daily_issue_field_history` and `jira__sprint_enhanced`, designed to capture key sprint metrics such as velocity, time tracking, and story point completion.  
  
If further refinements or reporting is needed for the sprint report, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_jira/issues).
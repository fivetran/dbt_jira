# Decision Log
In creating this package, which is meant for a wide range of use cases, we had to take opinionated stances on a few different questions we came across during development. We've consolidated significant choices we made here, and will continue to update as the package evolves.

## Enhancing Jira Sprint Reporting with Flexible Metrics
To improve sprint reporting in the Jira dbt package, we introduced a new model, `jira__sprint_enhanced`, designed to capture key sprint metrics such as velocity, time tracking, and story point completion.  A key consideration in this update was ensuring flexibility in metric selection, allowing users to analyze sprint data in a way that best suits their reporting needs.   

Here is simplified issue data with current and historical sprint and story point information.

| issue_id |   current_sprint_id | historical_sprint_ids | story_points | story_point_estimate | sprint_name    |
|----------|-------------------|-----------------------|--------------|----------------------|----------------|
| 101      |  5                 | 4                 | 8            | 10                   |  Sprint 5       |
| 102      | 5                | null                    | 5            | 6                    |  Sprint 5     |
| 101     | 4                | null                | 3            | 5                    |  Sprint 4    |

The `int_jira__sprint_metrics` model will aggregate metrics only for the current sprint an issue is assigned to. For example, Issue 101 contributes 8 story points to Sprint 5, 10 points estimated.

The `int_jira__sprint_story_points` model will track sprint assignments of story points at the beginning and end of a sprint. Issue 101 was previously in Sprint 4, so historical reports can then factor in what the story points were for those sprints where `int_jira__sprint_metrics` could not (3 story points, 5 estimated). 

The `jira__sprint_enhanced model` aggregates both current and historical sprint metrics, allowing users to select the reporting method that best fits their needs.So metrics can be analyzed by current sprint assignments, or by including past sprints for a broader view of velocity and progress.
  
If further refinements or reporting is needed for the sprint report, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_jira/issues).
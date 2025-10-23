{{ config(enabled=var('jira_using_teams', True)) }}

select * 
from {{ var('team') }}
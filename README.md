# materialize-monitoring
a repo to incubate and share monitoring configurations and visualizations for Materialize

this repo contains configurations for the Prometheus SQL Exporter and Grafana. Basic setup instructions can be found here:
 https://materialize.com/docs/manage/monitor/grafana/ 

 After following the above instructions, the below files can be used to create a Materialize monitoring dashboard.

## sql_exporter/config.yml
 this is a configuration file for the Prometheus SQL Exporter.
 Be sure to replace the connection string with one for your environment, which can be found from the "connect" link on the bottom left of the Materialize dashboard. 

## grafana/materialize-overview-dashboard.json
 this JSON is for a Grafana dashboard intended to be a good starting point for Materialize monitoring. It includes in-line descriptions of each metric under the "i" icon on the dashboard.



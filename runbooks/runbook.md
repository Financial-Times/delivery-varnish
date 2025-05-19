<!--
    Written in the format prescribed by https://github.com/Financial-Times/runbook.md.
    Any future edits should abide by this format.
-->

# UPP - Delivery Varnish

Delivery varnish is the main entry point in the delivery cluster. It performs authentication when needed, caching, and routes traffic to the cluster's applications.

## Code

delivery-varnish

## Primary URL

<https://github.com/Financial-Times/delivery-varnish>

## Service Tier

Platinum

## Lifecycle Stage

Production

## Host Platform

AWS

## Architecture

Varnish is the entry point for Delivery clusters. Service is having few main functions - authentification/reverse proxy/cache/load-balancing for services in the Delivery clusters. This varnish instance is performing static routing primary, but for dynamic routing is referred to Path Routing Varnish service. In this service is also located DNS registration job for main URL of the cluster. After authentification this service will route the request to the needed service.

[Content Publishing Diagram](https://lucid.app/lucidchart/5f4f1a8b-2d62-4fb3-a605-b54d52ba7ddb/edit?view_items=_riE.MQN~Dcv&invitationId=inv_2d591f1a-d6df-4d98-8c33-3b74c4feaa37)

## Contains Personal Data

No

## Contains Sensitive Data

No

<!-- Placeholder - remove HTML comment markers to activate
## Can Download Personal Data
Choose Yes or No

...or delete this placeholder if not applicable to this system
-->

<!-- Placeholder - remove HTML comment markers to activate
## Can Contact Individuals
Choose Yes or No

...or delete this placeholder if not applicable to this system
-->

## Failover Architecture Type

ActiveActive

## Failover Process Type

FullyAutomated

## Failback Process Type

FullyAutomated

## Failover Details

The service is deployed in all clusters. The failover guide for the clusters is located here: <https://github.com/Financial-Times/upp-docs/tree/master/failover-guides/delivery-cluster>

## Data Recovery Process Type

FullyAutomated

## Data Recovery Details

Data for requests is stored in Splunk. Authentification secrets are encrypted and stored in Delivery clusters and in emergency LastPass note "UPP - k8s Basic Auth".

## Release Process Type

FullyAutomated

## Rollback Process Type

Manual

## Release Details

The deployment is automated.

<!-- Placeholder - remove HTML comment markers to activate
## Heroku Pipeline Name
Enter descriptive text satisfying the following:
This is the name of the Heroku pipeline for this system. If you don't have a pipeline, this is the name of the app in Heroku. A pipeline is a group of Heroku apps that share the same codebase where each app in a pipeline represents the different stages in a continuous delivery workflow, i.e. staging, production.

...or delete this placeholder if not applicable to this system
-->

## Key Management Process Type

None

## Key Management Details

There are no keys for rotation.

## Monitoring

- <https://upp-prod-delivery-us.upp.ft.com/__health>
- <https://upp-prod-delivery-eu.upp.ft.com/__health>

## First Line Troubleshooting

<https://github.com/Financial-Times/upp-docs/tree/master/guides/ops/first-line-troubleshooting>

## Second Line Troubleshooting

Please refer to the <https://github.com/Financial-Times/delivery-varnish/blob/master/README.md>

## UPP Delivery Varnish

This is the main entry point in the delivery cluster. It performs authentication when needed, caching, and routes traffic to the cluster's applications.

See [default.vcl](/default.vcl) for the Varnish routing policies.

## Kubernetes details
It uses a service of type `LoadBalancer` that will provision an ElasticLoadBalancer in AWS.

Every time this service is recreated, a new ELB will be created. 
This does `NOT` happen in normal deploy situations, but only on extreme situations like helm chart delete.

#### ELB DNS registration
Since this is the entry point in the cluster, the ELB needs to be registered at the DNS name of the cluster.

This is done by a Kubernetes job, set to run at `helm install` and `helm  update`, to make sure that the DNS 
name is updated even if the ELB is recreated. See [k8s job file](/helm/delivery-varnish/templates/elb-registrator-job.yaml) for details.
#### Config map keys used

- global-config:
    - dns_subdomain : the DNS name where the cluster should be reachable
    - k8s.app_namespace : the k8s namespace where the app lives
    - aws.region: the aws region of the cluster

#### Secret keys used

- global_secrets:
    - aws.access_key_id: AWS access key id
    - aws.secret_access_key : AWS secret access key
    - kon.dns_api.key: The API key for Konstructor used for setting up the DNS record

# Enterprise Bot DevOps Technical Assignment

This repository contains my solution for the DevOps technical assignment.

The solution includes:

* A small Node.js application running on port `8080`
* Docker containerization using a non-root user
* Helm chart for Kubernetes deployment
* Resource requests and limits
* Readiness checks
* Kubernetes Service and Ingress
* A setup script to create the local kind cluster and deploy the application
* Debugging fixes and findings from the supplied broken environment

## How to Run

### Prerequisites

The following tools should be installed:

* Docker
* kind
* kubectl
* Helm

Docker should also be running and accessible by the current user.

## Run the application locally (optional)

clone this repo Install the Node.js dependencies:

```bash
npm install
```

Start the application:

```bash
node server.js
``` 

## Deploy to Kubernetes

For the Kubernetes deployment, you do not need to run npm install manually because the dependencies are installed during the Docker image build.

Run:

```bash
chmod +x setup.sh
```

```bash
./setup.sh
```

The script will:

1. Check the required tools.
2. Create the kind cluster if it does not already exist.
3. Install ingress-nginx.
4. Build the application Docker image.
5. Load the image into kind.
6. Deploy the application using Helm.
7. Wait for the application to become ready.

The script can be run again safely. If the cluster and Helm release already exist, it will reuse/update them instead of creating duplicates.

## How to Verify

Check the application resources:

```bash
kubectl get pods -n demo
kubectl get svc -n demo
kubectl get ingress -n demo
```

The application pods should show `Running` and `1/1 Ready`.

The application can also be tested through port-forwarding:

```bash
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8081:80
```

Then, from another terminal:

```bash
curl -H "Host: demo.local" http://localhost:8081/
```

Example response:

```json
{
  "app": "enterprisebot-demo",
  "version": "1.0.0",
  "pod": "demo-..."
}
```

The Helm chart can also be checked independently:

```bash
helm lint ./chart
helm template demo ./chart
```

For example, replica count can be overridden using:

```bash
helm template demo ./chart --set replicaCount=5
```

## Resource Requests and Limits

I used the following resources for the application:

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

I chose these values because this is a small Node.js service with very little workload.

The request of `50m` CPU and `64Mi` memory gives Kubernetes a reasonable minimum for scheduling the pod, while the `200m` CPU and `128Mi` memory limits prevent the application from using unnecessary resources.

For a real workload, I would not keep these numbers based only on assumptions. I would monitor actual CPU and memory usage and adjust the requests and limits based on collected metrics and load testing.

## Debug Lab

I used `kubectl get`, `kubectl describe`, `kubectl logs`, Kubernetes events, temporary debug pods and direct connectivity tests to identify the issues.

The detailed debugging process, symptoms, causes and fixes are documented in:

```text
lab/FINDINGS.md
```
Some of the issues found included incorrect Job configuration, container security-context problems, application port mismatch, read-only filesystem issues, incorrect RBAC binding, CPU limits that violated namespace policies and an incorrect backend service address.

## What I Deliberately Skipped

I did not try to modify or rebuild the supplied `docker.io/ebinterview/eb-debug-app:1.0.1` image because the assignment specifically requires using the provided image.

The reporter workload still showed an application-side JSON parsing issue after I verified and corrected the Kubernetes-side configuration. I verified its ServiceAccount permissions, RBAC, networking and writable runtime directories. Since modifying the supplied image was outside the allowed scope, I documented my investigation and remaining findings instead of changing the image.

The risk is that the reporter functionality will remain unavailable until the application-side behavior is investigated and fixed.

I also kept the solution focused on the requirements of the assignment instead of adding additional infrastructure that was not required.

## What I Would Change for Production Readiness

For a production-ready setup, I would add:

* CI/CD to automatically build, test and deploy the application.
* Automated unit, container and Helm validation tests.
* Container image scanning and dependency scanning.
* A container registry instead of relying on locally loaded images.
* Monitoring and alerting using tools such as Prometheus and Grafana.
* Centralized application and Kubernetes logging.
* Horizontal Pod Autoscaling based on application load.
* Proper TLS and certificate management.
* Instaed of loal ingress will use Domain name wth proper A records.
* Separate configuration for different environments.
* Backup, rollback and deployment strategies suitable for the target environment.
* Resource requests and limits would also be tuned using real monitoring data and load testing rather than keeping the values used for this local assignment.

## How I Used AI

I used ChatGPT as asupport tool during this assignment, mainly to speed up documentation and to help organize my findings clearly.

I used it mainly to:

* Review Kubernetes and Helm configuration.
* Help interpret Kubernetes errors and events while debugging.
* Discuss possible causes after collecting evidence using `kubectl logs` and `kubectl describe`.
* Review shell commands and YAML structure.
* Help organize and improve the README and debugging findings.

I did not rely only on AI generated answers for the debugging exercise. I verified the suggestions against the actual cluster state using commands such as `kubectl get`, `kubectl describe`, `kubectl logs`, `kubectl auth can-i`, Helm commands

All changes included in the submission are changes that I reviewed, tested and can explain.

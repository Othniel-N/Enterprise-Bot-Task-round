# Findings — Part 4 debug lab

Fill in one entry per defect you find. Paste the *actual* output you saw —
we cross-check it against your session recording and your git diff, and the
diagnostic path matters more to us than the fix itself.

Before you start investigating, begin recording:
`script -q part4-session.log` (or `asciinema rec part4-session.cast`), and
commit that file alongside this one.

---

## Defect 1  invalid restart policy on migration job

**Symptom** The first run of the lab failed while Helm was installing the broken chart:

==> applying cluster environment (cluster-state/) namespace/debug-lab created Error from server (NotFound): error when creating "cluster-state/limits.yaml": namespaces "debug-lab" not found ==> installing the broken chart Release "debug-lab" does not exist. Installing it now. Error: 1 error occurred: * Job.batch "migrate" is invalid: spec.template.spec.restartPolicy: Required value: valid values: "OnFailure", "Never"
FAIL migrate Job has not completed

**Cause** Kubernetes jobs require the pod restart policy to be either Never or OnFailure. butin our yaml it was configured with ALWAYS so

**Fix** I configured the migration job with: restartPolicy: Never:

**How I found it** when running scenatio.sh up cmd for the first time, it directly showed invalid field and listed the accepted values.
After correcting it and running ./scenario.sh up again, Helm successfully installed the chart.

---

## Defect 2 Containers could not start because runAsNonRoot could not verify the image user

**Symptom:** After the chart installed, several workloads remained in CreateContainerConfigError.

**Cause:** The chart correctly required: runAsNonRoot: true but the supplied image declared a named user, nonroot

**Fix:** I inspected the supplied image using folowing cmds
docker create --name tmp docker.io/ebinterview/eb-debug-app:1.0.1
docker cp tmp:/etc/passwd - | tar -xO | grep nonroot
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
This showed that the image nonroot account uses 65532. and i explicitly configured these UID to all the affected workload templates.

**How I found it:** Kubectl get po and describe command i used to find this
Error: container has runAsNonRoot and image has non-numeric user (nonroot),
cannot verify user is non-root

---

## Defect 3 Application port did not match the Helm chart

**Symptom:**  After the containers could start, the pod was Running but remained unready

**Cause:**kubectl describe showed the readiness probe targeting port 8080:
Readiness:
  http-get http://:8080/healthz
Warning  Unhealthy  kubelet
Readiness probe failed:
Get "http://10.244.0.15:8080/healthz":
dial tcp 10.244.0.15:8080: connect: connection refused

**Fix:** I configured the application explicitly through its supported environment variable:

**How I found it:** I compared two independent check for evidence: kubectl logs of the pod  showed the process listening on 8081, while: kubectl describe pod -n debug-lab showed Kubernetes probing 8080.


---

## Defect 4 Worker crashed because its cache directory was on a read-only root filesystem

**Symptom:** The worker entered CrashLoopBackOff Continoiusly

**Cause:**  kubectl logs worker-95f494bf9-p8jxw -n debug-lab 2026/09/19 08:11:43 FATAL: worker could not initialise its cache: mkdir /var/cache/app: read-only file system — the process needs a writable directory at /var/cache/app (mount a volume there, or set CACHE_DIR

**Fix:** I kept the root filesystem read-only and provided only the writable location the application required 

**How I found it:** I inspected the worker after seeing CrashLoopBackOff: kubectl logs i used

---

## Defect 5 Reporter ServiceAccount was bound to the wrong RBAC subject

**Symptom:** The reporter started, but its health check remained 503.
pod list failed: kubernetes API returned HTTP 403: { "kind":"Status", "status":"Failure", "message":"pods is forbidden: User \"system:serviceaccount:debug-lab:reporter\" cannot list resource \"pods\" in API group \"\" in the namespace \"debug-lab\"", "reason":"Forbidden", "code":403 }

**Cause:** The reporter-read Role had the correct permissions, and a dedicated reporter ServiceAccount existed, but the RoleBinding granted those permissions to the default ServiceAccount instead. The reporter pod itself ran as: system:serviceaccount:debug-lab:reporter so it never received the Role's permissions.

**Fix:** I changed the RoleBinding subject from: name default to reporter

**How I found it:** Using kubectl auth and kubectl logs command

---

## Defect 6 Metrics pod violated namespace CPU guardrails

**Symptom:** The new ReplicaSet existed but had created zero pods
Error creating: pods "metrics-5dcfcd74cd-45hjs" is forbidden:
maximum cpu usage per Container is 1, but limit is 4

**Cause:** The supplied namespace guardrails permit a maximum CPU limit of 1 CPU per container.The metrics container requested a limit of 4 CPUs, so admission rejected creation of the pod.

**Fix:** I changed the metrics resources to values appropriate for this small service and consistent with the other workloads:

**How I found it:** nitially the old metrics pod showed CreateContainerConfigError, but after fixing its numeric UID, Kubernetes still did not create the replacement pod. so i checked deployment  using kubectl describe cmd and found out failed create state

---

## Defect 7 Gateway referenced the backend Service in the wrong namespace

**Symptom:** Pod was in not Ready state

**Cause:** The gateway pod itself became healthy, but the verifier reported: FAIL  gateway /status does not report backend=ok
The original gateway configuration contained: BACKEND_URL: "http://backend.default.svc:8080" but, both gateway and backend were deployed into debug-la

**Fix:** I corrected the gateway configuration to: BACKEND_URL: "http://backend.debug-lab.svc:8080" The short same-namespace name http://backend:8080 would also resolve correctly,  I tested using both the Service address

**How I found it:** Gateway pod was running but in not ready state so I tested the backend Service directly from a temporary pod in debug-lab and found out

---



If you ran out of time on any defect, say so here and describe what you would
have tried next — that section is read carefully and counts in your favour.



**
## YES I RAN OUT OF TIME ON THIS:
**

**Reporter issue**

After fixing the other issues, ./scenario.sh verify showed 7 out of 11 checks passing. The reporter was still not Ready and its /report endpoint was not working. The logs showed parse pod list: unexpected end of JSON input

I verified that the reporter ServiceAccount had the correct RBAC permission to list pods, and I was able to list pods using the same ServiceAccount.

*Since the Kubernetes permissions and configuration were working but the reporter binary still failed while parsing the Kubernetes API response, this appears to be an issue inside the supplied eb-debug-app:1.0.1 application. As the assignment does not allow modifying the provided image, I documented this as the remaining application-level issue.*
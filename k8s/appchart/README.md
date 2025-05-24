# appchart

a simple chart that ease deployment of classic apps on k8s.

##  values

See `example-values.yaml`

## use

In your HelmRelease:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: example
spec:
  chart:
    spec:
      chart: ./k8s/appchart
      version: "x.x.x"
      sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
      interval: 10m
  targetNamespace: services
  values:
---


```
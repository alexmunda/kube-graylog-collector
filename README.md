# kube-kube-graylog-collector
Graylog collector for applications deployed to Kubernetes

## Environment Variables

`GELF_HOST` (REQUIRED) - The Graylog host that is responsible for receiving log messages. Within a Kubernetes cluster, it is usually `{namespace}.{graylog service name}` or just `{graylog service name}` if the collector and the graylog service reside in the same namespace.

`GELF_PORT` (OPTIONAL) - The port that the Graylog host is listening on. Defaults to 12201.

`FLUEND_ARGS` (OPTIONAL) - Any [fluentd](https://docs.fluentd.org/deployment/command-line-option) command line args. Log rotation is highly recommended. See the sample deployment for examples.

Note: the protocol is currently hardcoded to UDP but can easily be changed to take in a TCP option if the need arises.

## Sample Deployment
```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-graylog-collector
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: kube-graylog-collector
  namespace: default
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - namespaces
  verbs:
  - get
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: kube-graylog-collector
roleRef:
  kind: ClusterRole
  name: kube-graylog-collector
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: kube-graylog-collector
  namespace: default
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: kube-graylog-collector
  namespace: default
  labels:
    name: kube-graylog-collector
spec:
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: kube-graylog-collector
    spec:
      serviceAccount: kube-graylog-collector
      serviceAccountName: kube-graylog-collector
      containers:
      - name: kube-graylog-collector
        image: alexmunda/kube-graylog-collector:0.0.1
        command:
          - "/bin/sh"
          - "-c"
          - "/run.sh $FLUENTD_ARGS"
        env:
        - name: GELF_HOST
          value: "graylog-service"
        - name: GELF_PORT
          value: "12201"
        - name: RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR
          value: "0.9"
        - name: FLUENTD_ARGS
          value: --no-supervisor --log-rotate-age 5 --log-rotate-size 104857600 -o /var/log/fluentd.log
        terminationMessagePath: /dev/termination-log
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

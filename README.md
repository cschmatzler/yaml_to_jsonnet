# yaml to Jsonnet

> :warning: Nowhere near done.

Converts Kubernetes definitions from YAML to Jsonnet.
Uses the `k8s-libsonnet` library.

## Goals

- Provide a starting point to write Jsonnet definitions from existing YAML ones.
- Be reasonably readable (after piping into `jsonnetfmt`).

## Definitely not goals

- Encompass all Kubernetes resource types.
- Guarantee that generated code is correct and can just be used without editing.
- Make things configurable.
- Care about performance.

## Example

Input:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hcloud-csi-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hcloud-csi-controller
  template:
    metadata:
      labels:
        app: hcloud-csi-controller
    spec:
      containers:
        - args:
            - --default-fstype=ext4
          image: registry.k8s.io/sig-storage/csi-attacher:v4.3.0
          name: csi-attacher
          volumeMounts:
            - mountPath: /run/csi
              name: socket-dir
        - image: registry.k8s.io/sig-storage/csi-resizer:v1.8.0
          name: csi-resizer
          volumeMounts:
            - mountPath: /run/csi
              name: socket-dir
        - args:
            - --feature-gates=Topology=true
            - --default-fstype=ext4
          image: registry.k8s.io/sig-storage/csi-provisioner:v3.5.0
          name: csi-provisioner
          volumeMounts:
            - mountPath: /run/csi
              name: socket-dir
        - command:
            - /bin/hcloud-csi-driver-controller
          env:
            - name: CSI_ENDPOINT
              value: unix:///run/csi/socket
            - name: METRICS_ENDPOINT
              value: 0.0.0.0:9189
            - name: ENABLE_METRICS
              value: "true"
            - name: KUBE_NODE_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: spec.nodeName
            - name: HCLOUD_TOKEN
              valueFrom:
                secretKeyRef:
                  key: token
                  name: hcloud
          image: hetznercloud/hcloud-csi-driver:v2.3.2
          imagePullPolicy: Always
          livenessProbe:
            failureThreshold: 5
            httpGet:
              path: /healthz
              port: healthz
            initialDelaySeconds: 10
            periodSeconds: 2
            timeoutSeconds: 3
          name: hcloud-csi-driver
          ports:
            - containerPort: 9189
              name: metrics
            - containerPort: 9808
              name: healthz
              protocol: TCP
          volumeMounts:
            - mountPath: /run/csi
              name: socket-dir
        - image: registry.k8s.io/sig-storage/livenessprobe:v2.10.0
          imagePullPolicy: Always
          name: liveness-probe
          volumeMounts:
            - mountPath: /run/csi
              name: socket-dir
      serviceAccountName: hcloud-csi
      volumes:
        - emptyDir: {}
          name: socket-dir
```

After `mix translate -i hcloud-csi.yaml | jsonnetfmt -`:
```jsonnet
local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.26/main.libsonnet',
      deployment = k.apps.v1.deployment,
      container = k.core.v1.container,
      envVar = k.core.v1.envVar,
      containerPort = k.core.v1.containerPort,
      volumeMount = k.core.v1.volumeMount;
{
  csi_attacher_container::
    container.withArgs(['--default-fstype=ext4']) +
    container.withImage('registry.k8s.io/sig-storage/csi-attacher:v4.3.0') +
    container.withName('csi-attacher') +
    container.withVolumeMounts([
      volumeMount.withMountPath('/run/csi') +
      volumeMount.withName('socket-dir'),
    ]),
  csi_resizer_container::
    container.withImage('registry.k8s.io/sig-storage/csi-resizer:v1.8.0') +
    container.withName('csi-resizer') +
    container.withVolumeMounts([
      volumeMount.withMountPath('/run/csi') +
      volumeMount.withName('socket-dir'),
    ]),
  csi_provisioner_container::
    container.withArgs(['--feature-gates=Topology=true', '--default-fstype=ext4']) +
    container.withImage('registry.k8s.io/sig-storage/csi-provisioner:v3.5.0') +
    container.withName('csi-provisioner') +
    container.withVolumeMounts([
      volumeMount.withMountPath('/run/csi') +
      volumeMount.withName('socket-dir'),
    ]),
  hcloud_csi_driver_container::
    container.withCommand(['/bin/hcloud-csi-driver-controller']) +
    container.withEnv([
      envVar.withName('CSI_ENDPOINT') +
      envVar.withValue('unix:///run/csi/socket'),
      envVar.withName('METRICS_ENDPOINT') +
      envVar.withValue('0.0.0.0:9189'),
      envVar.withName('ENABLE_METRICS') +
      envVar.withValue('true'),
      envVar.withName('KUBE_NODE_NAME') +
      envVar.valueFrom.fieldRef.withApiVersion('v1') +
      envVar.valueFrom.fieldRef.withFieldPath('spec.nodeName'),
      envVar.withName('HCLOUD_TOKEN') +
      envVar.valueFrom.secretKeyRef.withKey('token') +
      envVar.valueFrom.secretKeyRef.withName('hcloud'),
    ]) +
    container.withImage('hetznercloud/hcloud-csi-driver:v2.3.2') +
    container.withImagePullPolicy('Always') +
    container.livenessProbe.withFailureThreshold('5') +
    container.livenessProbe.httpGet.withPath('/healthz') +
    container.livenessProbe.httpGet.withPort('healthz') +
    container.livenessProbe.withInitialDelaySeconds('10') +
    container.livenessProbe.withPeriodSeconds('2') +
    container.livenessProbe.withTimeoutSeconds('3') +
    container.withName('hcloud-csi-driver') +
    container.withPorts([
      containerPort.withContainerPort('9189') +
      containerPort.withName('metrics'),
      containerPort.withContainerPort('9808') +
      containerPort.withName('healthz') +
      containerPort.withProtocol('TCP'),
    ]) +
    container.withVolumeMounts([
      volumeMount.withMountPath('/run/csi') +
      volumeMount.withName('socket-dir'),
    ]),
  liveness_probe_container::
    container.withImage('registry.k8s.io/sig-storage/livenessprobe:v2.10.0') +
    container.withImagePullPolicy('Always') +
    container.withName('liveness-probe') +
    container.withVolumeMounts([
      volumeMount.withMountPath('/run/csi') +
      volumeMount.withName('socket-dir'),
    ]),
  hcloud_csi_controller: {
    deployment: deployment.new(
                  name=$._config.hcloud_csi_controller.name,
                  replicas=$._config.hcloud_csi_controller.replicas,
                  containers=[
                    self.csi_attacher_container,
                    self.csi_resizer_container,
                    self.csi_provisioner_container,
                    self.hcloud_csi_driver_container,
                    self.liveness_probe_container,
                  ]
                ) +
                deployment.metadata.withName('hcloud-csi-controller') +
                deployment.spec.withReplicas('1') +
                deployment.spec.template.spec.withServiceAccountName('hcloud-csi') +
                deployment.spec.template.spec.withVolumes([
                  volume.withName('socket-dir'),
                ]),
  },
}
```

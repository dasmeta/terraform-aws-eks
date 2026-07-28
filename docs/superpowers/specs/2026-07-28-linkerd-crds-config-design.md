# Linkerd CRD Chart Configuration Design

## Context

The root EKS module enables Linkerd by default and exposes `linkerd.configs` for
the control-plane chart and `linkerd.configs_viz` for the Viz chart. The
separate `linkerd-crds` Helm release does not accept consumer-provided values.
As a result, consumers cannot configure chart options such as
`installGatewayAPI` through the root module.

## Goal

Allow consumers to pass explicit values to the `linkerd-crds` Helm chart while
preserving all existing behavior when the new configuration is omitted.

## Interface

Add an optional `configs_crds` attribute to the root module's existing
`linkerd` object:

```hcl
linkerd = {
  configs_crds = {
    installGatewayAPI = true
  }
}
```

The attribute has type `any` and defaults to `{}`, matching the established
`configs` and `configs_viz` interface pattern. The root module forwards the
value to the Linkerd child module, which exposes the same optional input.

## Data Flow

1. A consumer supplies `linkerd.configs_crds`.
2. The root EKS module forwards it to `modules/linkerd`.
3. The child module serializes it with `jsonencode`.
4. The serialized values are supplied only to `helm_release.this_crds`.
5. Helm merges the values into the selected `linkerd-crds` chart.

The control-plane and Viz releases remain unchanged.

## Compatibility

The change is additive and backward-compatible. Omitting `configs_crds`
produces an empty values object and retains the chart's existing defaults. The
module will not enable Gateway API CRDs globally by default.

The interface remains an opinionated grouped object: CRD chart configuration
stays under `linkerd`, alongside the existing control-plane and Viz settings.

## Documentation and Examples

Update the Linkerd module documentation and an existing Linkerd example to show
how to set:

```hcl
configs_crds = {
  installGatewayAPI = true
}
```

Document that these values target the `linkerd-crds` chart rather than the
control-plane chart.

## Testing

Add Terraform validation coverage that demonstrates:

- the new input is optional;
- an explicit `installGatewayAPI = true` value is accepted;
- the root module forwards `configs_crds` to the child module;
- the child module supplies the encoded map to the CRD Helm release.

Run repository formatting and Terraform validation checks after implementation.

## Out of Scope

- Enabling Gateway API CRDs by default.
- Installing the separate DasMeta Gateway API CRD module.
- Changing Linkerd chart versions.
- Modifying control-plane or Viz configuration behavior.
- Changing existing clusters directly.

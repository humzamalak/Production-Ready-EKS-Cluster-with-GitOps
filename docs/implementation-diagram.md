<!-- Docs Added: 2025-10-05 — High-level implementation diagram for GitOps flow. -->
# Implementation Diagram

This diagram illustrates the end-to-end flow: bootstrap -> Argo CD app-of-apps -> environment apps -> Helm chart deploys.

```mermaid
flowchart LR
  classDef action fill:#e9f5ff,stroke:#4098d7,stroke-width:1px,color:#0b3e6f
  classDef file fill:#fff7e6,stroke:#c17d00,stroke-width:1px,color:#5a3a00
  classDef k8s fill:#eef9f0,stroke:#2d8a34,stroke-width:1px,color:#1e5a22
  classDef argocd fill:#f3eaff,stroke:#6f42c1,stroke-width:1px,color:#3c2a77

  A[Repo Commit]:::action --> B[Bootstrap apply\nbootstrap/00..06]:::k8s
  B --> C[Argo CD Installed]:::argocd
  C --> D[Root App\n`environments/<env>/app-of-apps.yaml`]:::argocd
  D --> E[Discover apps\n`environments/<env>/apps/*.yaml`]:::argocd
  E --> F[Deploy Helm charts\n`applications/**/helm/*`]:::file

  subgraph Observability
    G[Prometheus/Grafana]:::k8s
  end

  F --> G
```

See `docs/architecture.md` for detailed structure and `README.md` for quick start.



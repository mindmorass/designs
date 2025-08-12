```mermaid

flowchart TD

%% ====================
%% Developer Commit & PR Stage
%% ====================
subgraph Dev_Commit
  DC1[Developer Commits Terragrunt Code]
  DC2[PR Created or Updated]
  DC1 --> DC2
end

%% ====================
%% Pipeline (Terragrunt)
%% ====================
DC2 --> Pipeline
subgraph Pipeline

  %% ====================
  %% Infra Lane (Terragrunt)
  %% ====================
  subgraph Infra_Lane
    direction LR

    %% Build & Lint
    subgraph TG_Build
      direction TB
      LBJ@{ shape: f-circ, label: "Lint Junction" }

      LBJ --> HCLFMT[terragrunt hclfmt -check]
      LBJ --> VINP[terragrunt validate-inputs]
      LBJ --> GDEP[terragrunt run-all init<br/>(populate .terragrunt-cache)]

      HCLFMT --> LMJ@{ shape: f-circ, label: "Lint Merge" }
      VINP --> LMJ
      GDEP --> LMJ

      LMJ --> PL[terragrunt run-all plan -out=tfplan]
      PL --> BP{Pass}
      BP -->|Yes| SP[Store tfplan artifacts]
    end

    %% Security / Policy
    subgraph TG_Security
      direction TB
      SBJ@{ shape: f-circ, label: "Security Junction" }

      SP --> SBJ
      SBJ --> CHK[Checkov<br/>scan .terragrunt-cache or plan]
      SBJ --> TFS[tfsec<br/>scan .terragrunt-cache]
      SBJ --> TRS[Terrascan<br/>scan .terragrunt-cache]
      SBJ --> CFT[Conftest<br/>(OPA) on plan/policies]

      CHK --> SMJ@{ shape: f-circ, label: "Security Merge" }
      TFS --> SMJ
      TRS --> SMJ
      CFT --> SMJ

      SMJ --> ISP{Pass}
      ISP -->|Yes| TG3[Tag Infra/PR]
    end

  end

  %% ====================
  %% Deploy
  %% ====================
  subgraph Deploy
    TG3 --> AP[terragrunt run-all apply]
    AP --> DP_PASS{Pass}
  end

  %% ====================
  %% Notifications
  %% ====================
  subgraph Notify
    DP_PASS -->|Yes & No| Notify_Owners
    BP -->|No| Notify_Owners
    ISP -->|No| Notify_Owners
  end

end

%% ====================
%% Styles
%% ====================
style Dev_Commit fill:#ffe6cc,stroke:#cccccc,stroke-width:1px
style Pipeline fill:#f7f7f7,stroke:#cccccc,stroke-width:1px
style Infra_Lane fill:#e6f2ff,stroke:#cccccc,stroke-width:1px
style Deploy fill:#e6ffe6,stroke:#cccccc,stroke-width:1px
style Notify fill:#fff0f0,stroke:#cccccc,stroke-width:1px

classDef lint fill:#f0f8ff,stroke:#ccc,stroke-width:1px
classDef security fill:#fff0f5,stroke:#ccc,stroke-width:1px

class HCLFMT,VINP,GDEP lint
class CHK,TFS,TRS,CFT security

%% ====================
%% Clickable Links
%% ====================
click HCLFMT "https://terragrunt.gruntwork.io/docs/reference/cli-options/#hclfmt" "terragrunt hclfmt"
click VINP   "https://terragrunt.gruntwork.io/docs/reference/cli-options/#validate-inputs" "terragrunt validate-inputs"
click GDEP   "https://terragrunt.gruntwork.io/docs/reference/cli-options/#run-all" "terragrunt run-all"
click PL     "https://terragrunt.gruntwork.io/docs/reference/cli-options/#plan" "terragrunt plan/apply"
click AP     "https://terragrunt.gruntwork.io/docs/reference/cli-options/#apply" "terragrunt apply"

click CHK "https://www.checkov.io" "Checkov"
click TFS "https://aquasecurity.github.io/tfsec/" "tfsec"
click TRS "https://github.com/tenable/terrascan" "Terrascan"
click CFT "https://www.conftest.dev/" "Conftest (OPA)"
```

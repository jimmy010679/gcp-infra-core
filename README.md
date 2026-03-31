# GCP Infrastructure Core (Terraform)

這是一個基於 Terraform 管理的 Google Cloud Platform (GCP) 基礎架構專案。主要用於部署與管理一個 AI Code Review 應用程式的基礎資源，並透過 Workload Identity Federation (WIF) 實現與 GitHub Actions 的安全整合。

## 專案架構

本專案採用分層式的 Terraform 架構，將全域資源與環境特定資源分開管理：

*   **Global (`/global`)**: 管理跨環境的共用資源，如 Workload Identity Federation (WIF) 與 Service Accounts。
*   **Environments (`/environments`)**: 管理特定環境（如 `prod`）的應用程式資源。
*   **Modules (`/modules`)**: 存放可重複使用的 Terraform 模組，例如 Cloud Run 部署與網路配置。

### 核心組件

1.  **Workload Identity Federation (WIF)**: 允許 GitHub Actions 安全地存取 GCP 資源，無需管理長期有效的 Service Account Key。
2.  **Artifact Registry**: 用於儲存 AI Code Review 應用程式的 Docker 映像檔。
3.  **Cloud Run**: 部署 AI Code Review 服務，具備自動縮放與公開存取功能。

---

## 目錄結構

```text
.
├── environments/           # 環境特定配置
│   └── ai-code-review/
│       └── prod/           # 生產環境配置 (Cloud Run, Artifact Registry)
├── global/                 # 全域共用資源 (WIF, IAM)
├── modules/                # 可重複使用的模組
│   ├── cloud-run-app/      # Cloud Run 模組
│   └── networking/         # 網路相關模組
└── README.md
```

---

## 快速上手

### 前置作業

1.  安裝 [Terraform](https://www.terraform.io/downloads.html) (建議版本 v1.0.0+)。
2.  安裝 [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)。
3.  確保您具備 GCP 專案的 `Owner` 或足夠的 IAM 權限。
4.  完成 gcloud 驗證：
    ```bash
    gcloud auth application-default login
    ```

### 部署全域資源 (WIF)

1.  進入 `global` 目錄：
    ```bash
    cd global
    ```
2.  初始化並套用變更：
    ```bash
    terraform init
    terraform apply -var="project_id_ai_reviewer=YOUR_PROJECT_ID"
    ```
    *注意：此步驟會建立 WIF Pool 與 Provider，並綁定指定的 GitHub Repository (`jimmy010679/ai-code-review`)。*

### 部署生產環境資源

1.  進入 `prod` 目錄：
    ```bash
    cd environments/ai-code-review/prod
    ```
2.  初始化並套用變更：
    ```bash
    terraform init
    terraform apply
    ```
    *初始部署時，Cloud Run 會使用預設的 `hello` 映像檔。後續將由 CI/CD 流水線更新為實際的應用程式映像檔。*

---

## CI/CD 整合 (GitHub Actions)

本專案配置了 WIF 以支援安全部署。在 GitHub Actions 的 Workflow 中，您需要提供以下資訊：

*   **Workload Identity Provider**: `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool-tf/providers/github-provider-tf`
*   **Service Account**: `tf-github-deployer@<PROJECT_ID>.iam.gserviceaccount.com`

### 部署邏輯說明

*   **Artifact Registry**: 啟用了 `prevent_destroy` 以防止意外刪除映像檔。
*   **Cloud Run**: 透過 `lifecycle { ignore_changes = [template[0].containers[0].image] }` 確保 Terraform 不會覆蓋由 GitHub Actions 更新的映像檔。

---

## 注意事項

*   **安全性**: `global/wif.tf` 中限制了只有特定的 GitHub Repository 可以交換 Token，請確保 `attribute_condition` 符合您的實際需求。
*   **成本控管**: 專案中使用的 Cloud Run 與 Artifact Registry 資源會產生費用，不使用時請記得銷毀或縮減規模。

# GCP Infrastructure Core (Terraform)

這是一個基於 Terraform 管理的 Google Cloud Platform (GCP) 基礎架構專案。主要用於部署與管理一個 AI Code Review 應用程式的基礎資源，並透過 Workload Identity Federation (WIF) 實現與 GitHub Actions 的安全整合。

## 專案架構

本專案採用分層式的 Terraform 架構，旨在支援**多專案、多環境**的靈活管理：

*   **Global (`/global`)**: 管理跨環境的共用資源，特別是針對各個應用專案（如 AI Code Review）配置獨立的 Workload Identity Federation (WIF) 與專屬 Service Accounts，確保身分驗證的最小權限原則。
*   **Environments (`/environments`)**: 根據應用專案分類（如 `ai-code-review/`），並依環境（如 `prod/`）管理特定資源。
*   **Modules (`/modules`)**: 存放可重複使用的 Terraform 模組，供不同應用程式調用。

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
    terraform apply
    ```
    *注意：此步驟會建立專屬的 WIF Pool 與 Provider，並根據提供的 GitHub Repository 建立對應的 Service Account (`tf-github-ai-reviewer`)。此架構支援多專案擴展，各專案擁有獨立的身份識別與權限。*

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
    *在此階段，環境層會透過 Data Source 動態取得 Global 層建立的 Service Account 並授予部署所需的權限。*

---

## CI/CD 整合 (GitHub Actions)

本專案配置了 WIF 以支援安全部署。在 GitHub Actions 的 Workflow 中，您需要提供以下資訊：

*   **Workload Identity Provider**: `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool-tf/providers/github-provider-tf`
*   **Service Account**: `tf-github-ai-reviewer@<PROJECT_ID>.iam.gserviceaccount.com`

### 部署邏輯說明

*   **Artifact Registry**: 啟用了 `prevent_destroy` 以防止意外刪除映像檔。
*   **Cloud Run**: 透過 `lifecycle { ignore_changes = [template[0].containers[0].image] }` 確保 Terraform 不會覆蓋由 GitHub Actions 更新的映像檔。

---

## 注意事項

*   **安全性**: `global/wif.tf` 中限制了只有特定的 GitHub Repository 可以交換 Token，請確保 `attribute_condition` 符合您的實際需求。
*   **成本控管**: 專案中使用的 Cloud Run 與 Artifact Registry 資源會產生費用，不使用時請記得銷毀或縮減規模。

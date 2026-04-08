# GCP Infrastructure Core (IaC)

![Terraform Infrastructure](https://github.com/jimmy010679/gcp-infra-core/actions/workflows/terraform.yml/badge.svg)

本專案是雲端環境的 **管理核心 (Management Hub)**，採用 **Terraform** 實作基礎設施即代碼 (IaC)。透過分層管理架構，定義並維護應用專案所需的身分驗證（WIF）、網路資源與伺服器基礎架構。

---

## 🏗 架構設計亮點

### 1. 無密鑰安全認證 (Workload Identity Federation)
捨棄具資安風險的傳統靜態 Service Account JSON Key，採用 **GCP Workload Identity Federation (WIF)**：
* [cite_start]**OIDC 信任機制**：建立 GitHub 與 Google Cloud 間的 OIDC 信任關係。
* [cite_start]**最小權限原則**：精確限制僅允許特定的 GitHub 儲存庫（如 `ai-code-review`）換取臨時憑證。

### 2. 跨專案資源管理 (Cross-Project Administration)
實踐企業級的專案隔離架構，區分「行政管理」與「應用執行」環境：
* [cite_start]**遠端狀態儲存 (Remote Backend)**：Terraform State 存放於獨立的 `jimmy-infra-admin` 專案中，確保狀態檔的安全與集中管理。
* [cite_start]**跨專案授權**：透過 `google_project_iam_member` 授予部署帳號跨專案存取儲存桶 (GCS) 的權限，解決 `403 Forbidden` 認證問題。

---

## 🛠 CI/CD 與自動化流水線

本專案透過 **GitHub Actions** 實現高度自動化的基礎設施維護流程：

### 基礎設施自動化流程 (IaC Pipeline)
1. **認證 (Authenticate)**：利用 WIF 動作換取 GCP 臨時存取權限。
2. **初始化 (Init)**：跨專案連接至遠端 GCS Backend 初始化環境。
3. **自動化審查 (Plan on PR)**：
   * 當發起 Pull Request 時，自動執行 `terraform plan`。
   * [cite_start]利用 `github-script` 將 Plan 結果自動留言於 PR 下方，方便代碼審查。
4. **自動化部署 (Apply on Push)**：
   * 僅在代碼合併至 `main` 分支後，才觸發 `terraform apply` 進行實際資源更動。

### 資源生命週期策略
針對 Cloud Run 等動態資源，配置了 **Lifecycle Policy**：
* [cite_start]**`ignore_changes`**：排除 `image` 與 `labels` 的變動追蹤。
* **價值**：確保基礎設施狀態不會與應用程式層級的 CI/CD（如頻繁的 Image 更新）產生衝突，達成權責分離 [cite: 2]。

---

## 📂 專案結構

```text
.
├── environments/           # 環境特定配置
│   └── ai-code-review/
│       └── prod/           # 生產環境配置 (Cloud Run, Artifact Registry)
│   └── test-k8s-app/
│       └── prod/           # 生產環境配置
├── global/                 # 全域共用資源 (WIF, IAM)
├── modules/                # 可重複使用的模組
│   ├── cloud-run-app/      # Cloud Run 模組
│   └── networking/         # 網路相關模組
└── README.md
```

---

## ⚙️ 必備 GitHub 變數設定

| 類型 | 變數名稱 | 說明 |
| :--- | :--- | :--- |
| **Variables** | `GCP_WIF_PROVIDER` | WIF Provider 完整路徑 |
| **Variables** | `GCP_SERVICE_ACCOUNT` | 部署用的 SA Email |

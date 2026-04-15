# GCP Infrastructure Core (IaC)

![Terraform Infrastructure](https://github.com/jimmy010679/gcp-infra-core/actions/workflows/terraform.yml/badge.svg)

本專案是雲端環境的 **管理核心 (Management Hub)**，採用 **Terraform** 實作基礎設施即代碼 (IaC)。透過「地基與應用分離」的架構，定義並維護全域身分驗證（WIF）、行政專案權限與各應用專案的基礎架構。

---

## 🏗 架構設計亮點

### 1. 無密鑰安全認證 (Workload Identity Federation)
捨棄具資安風險的傳統靜態 JSON Key，採用 **GCP WIF** 實作 Keyless 認證：
* **OIDC 信任機制**：建立 GitHub 與 Google Cloud 間的信任關係，僅限特定 Repo 換取臨時憑證。
* **身分與權限分離**：行政專案負責「核發身分」，應用專案負責「執行任務」，達成清晰的權責分界。

### 2. 中心化管理策略 (Centralized Governance)
* **內政管理 (Self-Management)**：授予管理 SA 在行政專案中的 `iam.workloadIdentityPoolAdmin` 等角色，使其具備維護自身認證體系的能力。
* **跨專案行政權**：透過 `serviceusage.serviceUsageAdmin` 與 `projectIamAdmin` 讓核心 SA 能跨專案自動開啟 API 並管理成員權限。
* **遠端狀態鎖定**：所有環境的 Terraform State 均集中存放於 `jimmy-infra-admin` 專案的 GCS Bucket，並實作跨專案存取授權。

---

## 🛠 CI/CD 雙階流水線

本專案透過 **GitHub Actions** 實作具備依賴檢查的自動化流程：

### 兩階段執行邏輯 (Dependency Pipeline)
為了確保權限與地基先行，流水線拆分為兩個連續任務：

1. **🌍 第一階段：Global Infra (地基)**
   * **路徑**：`./global`
   * **核心任務**：更新 WIF Pool、SA 帳號、行政專案 API 與跨專案 IAM 授權。
   * **重要性**：此任務必須成功，後續應用環境才能獲得正確的授權進行操作。

2. **🚀 第二階段：App Infra (應用環境)**
   * **路徑**：`./environments/*`
   * **核心任務**：透過矩陣（Matrix）同時部署 `ai-code-review` 與 `test-k8s-app` 的具體資源。
   * **特性**：採用 `fail-fast: false` 策略，確保個別環境失敗不會干擾其他專案部署。

### 自動化回饋機制
* **Plan on PR**：當發起 Pull Request 時，`global` 與各個 `matrix path` 都會自動執行 `terraform plan`，並利用 `github-script` 將結果貼回 PR 留言，實現透明化審查。
* **Apply on Push**：僅在合併至 `main` 分支後，才觸發 `terraform apply -auto-approve` 進行正式資源異動。

---

## 📂 專案結構

```text
.
├── environments/           # 環境特定配置
│   └── ai-code-review/
│       └── prod/           # 生產環境配置 (Cloud Run, Artifact Registry)
│   └── test-k8s-app/
│       └── prod/           # 生產環境配置 (GKE, Artifact Registry)
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


## 💻 應用程式專案

### 1. **[ai-code-review](https://github.com/jimmy010679/ai-code-review)**

架在 Cloud Run 上面的 Next.js

### 2. **[test-k8s-app](https://github.com/jimmy010679/test-k8s-app)**

架在 GKE 上面的 Next.js
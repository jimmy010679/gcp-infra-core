# GCP Infrastructure Core (IaC)

![Terraform Infrastructure](https://github.com/jimmy010679/gcp-infra-core/actions/workflows/terraform.yml/badge.svg)

本專案是雲端環境的 **管理核心 (Management Hub)**，採用 **Terraform** 實作基礎設施即代碼 (IaC)。透過「地基與應用分離」的架構，定義並維護全域身分驗證（WIF）、行政專案權限與各應用專案的基礎架構。

---

## 🏗 架構設計亮點

* **無密鑰安全認證 (Keyless Authentication)**：通過全局 Workload Identity Federation (WIF) 模塊，實現 GitHub Actions 與 GCP 的安全認證，徹底消除長期 Access Key 泄漏風險。
* **模塊化設計 (Modular Design)**：將網絡、資料庫、計算資源封裝為可高度複用的 Terraform 模塊，便於未來快速擴展至新項目或新環境。

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

## ⚙️ 必備 GitHub 變數設定

| 類型 | 變數名稱 | 說明 |
| :--- | :--- | :--- |
| **Variables** | `GCP_WIF_PROVIDER` | WIF Provider 完整路徑 |
| **Variables** | `GCP_SERVICE_ACCOUNT` | 部署用的 SA Email |

---

## 💻 旗下應用程式專案

### 1. **[test-k8s-app](https://github.com/jimmy010679/test-k8s-app)**
* **定位**：高可靠、多層隔離的 Kubernetes 應用範例。
* **部署**：運行於 **Google Kubernetes Engine (GKE)** 叢集的 Next.js 應用。

#### 🌐 深度網路架構 (Networking)
採用雙 VPC 物理隔離設計，確保「應用服務」與「數據存儲」徹底拆分：
* **App VPC**：部署 GKE 叢集，配置 Cloud NAT/Router 處理對外通訊。
* **Data VPC**：專門託管 Cloud SQL (PostgreSQL)，不對公網開放。
* **Private Service Connect (PSC)**：透過 Google 私有端點技術，實現跨 VPC 的安全內網存取。

#### 🛡️ 安全存取控管 (Security)
* **無密鑰架構**：全站透過 **WIF (Workload Identity Federation)** 進行身分驗證，徹底消除長期 Access Key 洩漏風險。
* **IAP 安全隧道**：開發者透過 **Identity-Aware Proxy (IAP)** 跳板機存取資料庫，無需開放 5432 埠口至公網。
    > **本地端連接指令：**
    > ```bash
    > gcloud compute ssh test-k8s-app-prod-bastion \
    >     --tunnel-through-iap \
    >     --project test-k8s-app-492717 \
    >     --zone asia-east1-a \
    >     -- -L 5432:10.10.0.2:5432 -N
    > ```

#### 📊 可觀測性
實作 **Prometheus** 與 **OpenTelemetry**，自動採集指標 (Metrics) 並整合追蹤 (Tracing)，實現從 Gateway 到資料庫的端到端效能視覺化。

#### 🗺️ 專案架構圖
![專案架構圖](docs/images/test-k8s-app-architecture.png)

### 2. **[test-vm-app](https://github.com/jimmy010679/test-vm-app)**
* **定位**：使用 VM + Instance Templates + Managed Instance Group 應用範例。
* **部署**：運行於 **Google Compute Engine** 的 Node.js 應用。

### 3. **[ai-code-review(test-cloudrun-app)](https://github.com/jimmy010679/ai-code-review)**
* **部署**：運行於 **Google Cloud Run** 的 Serverless Next.js 應用。

---

## 🗺️ 全域網段規劃 (Global IP Allocation Strategy)

本專案採用 **以專案為核心的區段保留法 (Project-Based Block Allocation)** 進行 IP CIDR 規劃。此架構不僅確保各專案、各環境的網路 (VPC) 之間絕對不會發生 IP 衝突 (Zero Overlap)，更能無痛支援未來跨部門的微服務互連 (VPC Peering) 與技術堆疊轉換。

### 📐 核心命名公式

將網路劃分為「實體機網段」與「容器虛擬網段」兩個維度：

1. **實體網路 (VM, Node, Database)**
   👉 `10.[環境(10,20,30)].[專案 Base ID (0~99)].0/24`
2. **K8s 容器網路 (Pod, Service)**
   👉 `10.[100+環境(110,120,130)].[專案 Base ID (0~99)].0/16` 

* **第 2 碼 (環境)**：`10` = Prod, `20` = UAT, `30` = Dev
* **第 3 碼 (專案 Base ID)**：
    * 每個專案固定分配一個包含 4 個子網的區塊（例如：Project A 拿 0~3，Project B 拿 4~7）。
    * `0~3`：分配給 **test-k8s-app** 專案
    * `20~23`：分配給 **test-vm-app** 專案

---

### 📊 網段配置對照表

#### 1. test-k8s-app (Kubernetes 架構)
Base ID 分配為 `0`。GKE 採用 `VPC_NATIVE` 模式，將實體節點與虛擬容器的網段嚴格拆分，便於流量追蹤與防火牆管控。

| 部署環境 | 資源類型 (用途) | 網段配置 (CIDR) | 說明 / 識別特徵 |
| :--- | :--- | :--- | :--- |
| **Prod (10)** | GKE Node (App VPC) | `10.10.0.0/24` | 節點實體 IP (Base+0) |
| **Prod (10)** | Data VPC (Cloud SQL) | `10.10.1.0/24` | 資料庫專用網段 (Base+1) |
| **Prod (10)** | **GKE Pod** (Secondary) | `10.110.0.0/18` | 容器動態 IP (可容納 ~1.6 萬個 Pod) |
| **Prod (10)** | **GKE Service** (Secondary) | `10.111.0.0/20` | 服務發現虛擬 IP (可容納 ~4 千個 Service) |
| **UAT (20)** | GKE Node (App VPC) | `10.20.0.0/24` | 測試環境節點 |
| **UAT (20)** | Data VPC (Cloud SQL) | `10.20.1.0/24` | 測試環境資料庫 |
| **UAT (20)** | **GKE Pod** (Secondary) | `10.120.0.0/18` | 測試環境 Pod |
| **UAT (20)** | **GKE Service** (Secondary) | `10.121.0.0/20` | 測試環境 Service |
| **Dev (30)** | GKE Node (App VPC) | `10.30.0.0/24` | 開發環境節點 |
| **Dev (30)** | Data VPC (Cloud SQL) | `10.30.1.0/24` | 開發環境資料庫 |
| **Dev (30)** | **GKE Pod** (Secondary) | `10.130.0.0/18` | 開發環境 Pod |
| **Dev (30)** | **GKE Service** (Secondary) | `10.131.0.0/20` | 開發環境 Service |


#### 2. test-vm-app (傳統 VM 架構)
Base ID 分配為 `20`。架構較為單純，採用直接映射。

| 部署環境 | 資源類型 (用途) | 網段配置 (CIDR) | 說明 / 識別特徵 |
| :--- | :--- | :--- | :--- |
| **Prod (10)** | VM Subnet (MIG) | `10.10.20.0/24` | 應用程式負載平衡群組 (Base+0) |
| **Prod (10)** | Data VPC (保留) | `10.10.21.0/24` | 保留給未來擴充專屬資料庫 (Base+1) |
| **UAT (20)** | VM Subnet (MIG) | `10.20.20.0/24` | 測試環境虛擬機 |
| **Dev (30)** | VM Subnet (MIG) | `10.30.20.0/24` | 開發環境虛擬機 |

---

## 📂 專案結構

```text
.
├── environments/           # 環境特定配置 (具體項目的實例化)
│   ├── ai-code-review/     # (test-cloudrun-app) 項目，代改名
│   │   └── prod/           # 包含 Cloud Run, Artifact Registry 等無服務器部署配置
│   └── test-k8s-app/       # 測試用 Kubernetes 項目
│   │   └── prod/           # 包含 GKE, Cloud SQL (PSC 連接), Artifact Registry
│   └── test-vm-app/        # 測試用 VM 項目
│       └── prod/           # 包含 VM, Instance Templates
├── global/                 # 全局公共資源
│   └──                     # 包含 Workload Identity Federation (WIF), 跨項目 IAM 權限分配等
├── modules/                # 可複用的核心模塊庫
│   ├── bastion/            # 跳板機，連到 Database，是用 VM + IAP
│   ├── gke-networking/     # App VPC 網絡模塊 (涵蓋 NAT, Subnet, Ingress 配置)
│   ├── data-vpc/           # Data VPC 模塊 (極簡私有網絡，專供數據組件隔離使用)
│   ├── cloud-sql-postgres/ # Cloud SQL PostgreSQL 模塊 (內置 PSC 配置與安全策略)
│   └── cloud-run-app/      # Cloud Run 服務模塊 (封裝容器部署標準化參數)
└── README.md               # 項目說明文檔
```
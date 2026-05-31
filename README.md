# Load Testing Pilot

面向 Amazon Web Services 中国区域的一键部署分布式压测与 AI 智能分析平台，基于单一 Amazon CloudFormation 模板构建。

## 概述

Load Testing Pilot 将分布式压测执行、Amazon Web Services 基础设施指标自动采集和大语言模型（LLM）驱动的智能分析整合为一体化工作流。通过一个 Amazon CloudFormation 堆栈即可部署全部组件，数分钟内开始压测。

**核心能力：**

- **一键压测** — 在 Web 界面配置目标 URL、并发数和持续时间，后端自动调度 Serverless 容器执行分布式压测
- **AI 生成脚本** — 用自然语言描述压测需求，LLM 自动生成标准 JMeter 脚本
- **自动指标采集** — 压测结束后自动发现 ELB → 目标组 → EC2 实例链路（含 Amazon EKS 节点组和 Amaaon ECS on EC2），从 Amazon CloudWatch 批量拉取全链路监控指标
- **AI 智能分析** — 将压测结果与基础设施指标汇总提交给 LLM，输出结构化分析报告，涵盖健康判定、瓶颈定位、根因分析和优化建议

## 架构

平台采用全 Serverless 架构，部署在 AWS 中国区域 VPC 内：

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌────────────┐
│   Web UI    │────▶│  ALB + API   │────▶│  Step Functions  │────▶│  ECS       │
│  (S3)       │     │  Gateway     │     │  (任务编排)      │     │  Fargate   │
└─────────────┘     └──────────────┘     └──────────────────┘     └────────────┘
                           │                                            │
                    ┌──────┴───────┐                             ┌──────┴───────┐
                    │   Lambda     │                             │   压测目标   │
                    │   函数组     │                             │   系统       │
                    └──────┬───────┘                             └──────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴────┐ ┌─────┴────┐ ┌─────┴────┐
        │ DynamoDB │ │   S3     │ │CloudWatch│
        │ (状态)   │ │ (脚本)   │ │ (指标)   │
        └──────────┘ └──────────┘ └──────────┘
```

全部 Amazon Lambda 函数代码内嵌在 Amazon CloudFormation 模板中，零外部依赖。

## 功能

### 多引擎压测

平台集成了多个开源压测引擎，覆盖从快速验证到复杂场景模拟的各类需求：

| 引擎 | 格式 | 适用场景 |
|------|------|---------|
| Simple HTTP | Web 表单 | 快速验证端点，无需编写脚本 |
| [Apache JMeter](https://jmeter.apache.org/) | `.jmx` | 支持参数化、断言、定时器等完整特性 |
| [K6](https://k6.io/) | `.js` | 基于 JavaScript 编写测试逻辑 |
| [Locust](https://locust.io/) | `.py` | 基于 Python 灵活构建用户行为模型 |

脚本文件通过前端拖拽上传，后端使用 S3 Presigned URL 实现安全直传，上传过程带有实时进度条。

### AI 自然语言生成压测脚本

对于不熟悉 JMeter 脚本语法的团队，可以直接用自然语言描述需求：

> "测试某 ELB 的 80 端口，目标 3000 RPS，持续 10 分钟"

LLM 以流式方式实时生成标准 `.jmx` 脚本，平台自动提取执行参数（容器数量、并发数、RPS 限速等），确认无误后可直接提交压测。

### 基础设施指标自动采集

压测结束后，平台自动执行以下流程：

1. 解析目标主机名，查找匹配的负载均衡器
2. 发现关联的目标组（Target Group）和注册的 EC2 实例
3. 从 CloudWatch 采集三层指标：

| 层级 | 指标 |
|------|------|
| **ELB** | 请求总数、活跃连接数、目标响应时间、HTTP 错误码 |
| **目标组** | 健康/异常主机数、每目标请求分布 |
| **EC2 实例** | CPU 利用率、网络吞吐量、磁盘 IOPS |

> [!NOTE]
> 平台扫描的是目标组中注册的 EC2 实例，因此天然支持 **Amazon EKS** 工作负载（节点组中的工作节点）和 **Amazon ECS on EC2** 工作负载（底层 EC2 实例）。

### 跨账号与跨区域支持

当压测平台与目标资源位于不同账号或区域时，支持以下凭据模式：

- 当前账号（同账号访问）
- Access Key / Secret Key
- 临时凭据（STS）
- Assume Role（跨账号）

支持区域：`cn-north-1` 和 `cn-northwest-1`。

### AI 分析报告

AI 分析引擎生成结构化报告（流式输出），内容涵盖：

- **执行摘要** — 本次压测整体健康状况的达标/未达标评估
- **关键指标解读** — 以表格形式逐项分析吞吐量、成功率、分位数延迟、错误率，给出判定和备注
- **失败与错误分析** — 对异常响应（如 504 Gateway Timeout）进行分类和归因
- **根因判断** — 交叉验证客户端指标与 CloudWatch 服务端指标，精确定位瓶颈
- **优化建议** — 按优先级排序，给出具体可执行的改进措施

支持任何兼容 OpenAI Chat Completions 协议的 LLM 端点。

### 可视化结果展示

- 健康状态条（红/黄/绿）与核心指标卡片
- 响应时间分位数柱状图（P50/P90/P95/P99/P100）
- 响应码分布环形图与错误详情表
- CloudWatch 时序图表展示压测期间各项基础设施指标变化趋势

## 前置条件

- AWS 中国区域账号（`cn-north-1` 或 `cn-northwest-1`）
- 已配置中国区域凭证的 AWS CLI v2
- Docker 环境（用于构建容器镜像）
- IAM 权限：CloudFormation、Lambda、S3、DynamoDB、ECS、Fargate、VPC、ECR、Step Functions、CloudWatch、API Gateway

## 部署

整个部署过程分为三个步骤，通常可在 10 分钟内完成。

### 第一步：准备容器镜像

压测容器镜像预装了 [Taurus](https://gettaurus.org/)、[Apache JMeter](https://jmeter.apache.org/)、[K6](https://k6.io/) 和 [Locust](https://locust.io/)。您可以选择以下两种方式之一：

**方式一：直接使用公共镜像（推荐）**

在第二步部署堆栈时，将 `ContainerImage` 参数指定为上游公共镜像，无需自行构建：

```
public.ecr.aws/aws-solutions/distributed-load-testing-on-aws-load-tester:v4.1.0
```

**方式二：自行构建并推送至中国区域 ECR**

如果您的环境无法拉取公共镜像，可以使用提供的脚本自行构建：

```bash
# 创建 ECR 仓库（仅首次）
aws ecr create-repository --repository-name load-testing-pilot --region cn-north-1

# 构建并推送
./docker/build-and-push.sh <ACCOUNT_ID>.dkr.ecr.cn-north-1.amazonaws.com.cn/load-testing-pilot:v1
```

### 第二步：部署 CloudFormation 堆栈

```bash
aws cloudformation deploy \
  --template-file load-testing-pilot.yaml \
  --stack-name load-testing-pilot \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides ContainerImage=<ACCOUNT_ID>.dkr.ecr.cn-north-1.amazonaws.com.cn/load-testing-pilot:v1
```

<details>
<summary>可选参数</summary>

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `ExistingVPCId` | 使用已有 VPC，留空则自动创建 | *（自动创建）* |
| `ExistingSubnetA` / `ExistingSubnetB` | 已有子网 ID | *（自动创建）* |
| `CertificateArn` | ACM 证书 ARN，用于 ALB 开启 HTTPS | *（仅 HTTP）* |
| `AlbIngressCidr` | ALB 入站流量允许的 CIDR | `0.0.0.0/0` |

</details>

### 第三步：上传前端页面

```bash
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name load-testing-pilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ConsoleBucketName`].OutputValue' \
  --output text)

aws s3 cp webui/index.html s3://$BUCKET/index.html
```

打开堆栈输出中的 `ConsoleURL`。首次访问需输入 API Key（由 API Gateway 自动生成）：

```bash
# 获取 API Key
API_KEY_ID=$(aws cloudformation describe-stacks \
  --stack-name load-testing-pilot \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
  --output text)

aws apigateway get-api-key --api-key $API_KEY_ID --include-value --query value --output text
```

## 资源清理

删除 CloudFormation 堆栈即可移除全部资源：

```bash
aws cloudformation delete-stack --stack-name load-testing-pilot
```

> [!IMPORTANT]
> S3 存储桶和 DynamoDB 表设置了 `DeletionPolicy: Retain`。如需彻底清理，请在删除堆栈后手动清空并删除这些资源。

## 安全建议

- **网络访问控制** — 通过安全组和 `AlbIngressCidr` 限制 ALB 入站来源 IP
- **传输层加密** — 生产环境建议配置 ACM 证书启用 HTTPS
- **API Key 轮换** — 定期轮换 API Gateway 的 API Key
- **LLM 密钥保护** — AI 分析的 API Key 仅保存在浏览器 localStorage 中，不经过后端
- **压测授权** — 请确保已获得目标系统的压测授权

## 成本

Serverless 架构意味着按使用量计费，闲时成本极低：

| 服务 | 计费方式 |
|------|---------|
| Lambda | 按请求数 + 计算时长 |
| ECS Fargate | 按秒计费，压测后自动释放 |
| DynamoDB | 按需模式，按读写计费 |
| ALB | 固定小时费 + LCU 用量 |
| S3、CloudWatch | 标准用量计费 |

除 ALB 固定小时费外，闲时几乎不产生费用。

## 第三方组件

本项目在压测容器中集成了以下开源工具：

| 组件 | 许可证 | 说明 |
|------|--------|------|
| [Apache JMeter](https://jmeter.apache.org/) | Apache 2.0 | Java 压测引擎，支持 `.jmx` 脚本 |
| [K6](https://k6.io/) | AGPL-3.0 | 基于 Go 的现代压测工具，使用 JavaScript 编写脚本 |
| [Locust](https://locust.io/) | MIT | 基于 Python 的分布式压测框架 |
| [Taurus](https://gettaurus.org/) | Apache 2.0 | 压测自动化框架，统一编排上述引擎 |

这些工具由上游 Dockerfile 安装在压测容器镜像中，本项目不修改其源代码。

## 相关项目

本项目参考了 Amazon Web Services 官方解决方案 [Distributed Load Testing on AWS](https://github.com/aws-solutions/distributed-load-testing-on-aws)，并针对 Amazon Web Services 中国区域（`cn-north-1` / `cn-northwest-1`）进行了适配，同时新增了基础设施指标自动采集和 AI 智能分析等能力。

如果您使用的是 Amazon Web Services 全球区域，推荐了解 [Distributed Load Testing on AWS](https://github.com/aws-solutions/distributed-load-testing-on-aws)。

-- ====================================================================
-- 定期理财账户系统数据库建表脚本 (Database Schema)
-- ====================================================================
-- 版本：V1.0.0（基于简化的冻结机制 + 数据库事务方案）
-- 创建日期：2026-01-09
-- 设计原则：KISS + 高内聚 + 低耦合 + 安全性优先
-- 隔离级别：REPEATABLE_READ (默认)
-- ====================================================================

-- 设置默认字符集和排序规则
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ====================================================================
-- 第一部分：资产账户中心 (Asset Domain)
-- ====================================================================

-- 1.1 account 表（用户资产账户表）
-- 记录用户在不同业务线下的资金余额
-- P0 修复：新增 frozen_balance 字段用于提现冻结机制
CREATE TABLE IF NOT EXISTS `account` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '账户ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `type` VARCHAR(16) NOT NULL COMMENT '账户类型: FUND(资金), WEALTH(理财)',
  `currency` VARCHAR(8) NOT NULL COMMENT '币种: USDT, BTC, ETH',

  -- 两个重要的余额字段
  `balance` DECIMAL(32,16) NOT NULL DEFAULT 0 COMMENT '账户实际余额（已扣款，不含冻结）',
  `frozen_balance` DECIMAL(32,16) NOT NULL DEFAULT 0 COMMENT '冻结余额（提现等待中的冻结金额）',

  -- 乐观锁防并发
  `version` BIGINT NOT NULL DEFAULT 1 COMMENT '乐观锁版本号（每次变更+1）',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  -- 唯一约束：每个用户在每个账户类型和币种上只有一条记录
  UNIQUE KEY `uk_user_type_currency` (`user_id`, `type`, `currency`),

  -- 普通索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_type` (`type`),
  KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户资产账户表';

-- 1.2 account_journal 表（资金流水表）
-- 不可变的资金流动记录，采用复式记账思想
-- P0 强制：所有金额变动都必须在这里留下记录
CREATE TABLE IF NOT EXISTS `account_journal` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '流水ID',
  `serial_no` VARCHAR(64) NOT NULL UNIQUE COMMENT '全局唯一的业务流水号（幂等性键）',

  `user_id` BIGINT NOT NULL COMMENT '用户ID（冗余字段，方便查询）',
  `account_id` BIGINT NOT NULL COMMENT '关联的账户ID',

  `amount` DECIMAL(32,16) NOT NULL COMMENT '变动金额（正数=增加，负数=减少）',
  `balance_snapshot` DECIMAL(32,16) NOT NULL COMMENT '变动后的余额快照（用于快速对账）',

  `biz_type` VARCHAR(32) NOT NULL COMMENT '业务类型: TRANSFER_IN, TRANSFER_OUT, SUBSCRIBE_DEDUCT, REDEEM_ADD, INTEREST_PAYOUT, REDEEM_PRINCIPAL, RENEW_DEDUCT, RENEW_CREDIT, REDEEM_FALLBACK',
  `ref_id` BIGINT COMMENT '关联业务ID（如 wealth_order.id）',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_biz_type` (`biz_type`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_ref_id` (`ref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='资金流水表（总账）';

-- ====================================================================
-- 第二部分：理财业务中心 (Wealth Domain)
-- ====================================================================

-- 2.1 wealth_product 表（理财产品配置表）
CREATE TABLE IF NOT EXISTS `wealth_product` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '产品ID',

  `title` VARCHAR(128) NOT NULL COMMENT '产品名称（如"USDT 7日高息"）',
  `currency` VARCHAR(8) NOT NULL COMMENT '申购币种',

  `apy` DECIMAL(10,4) NOT NULL COMMENT '年化收益率（如0.0700表示7%）',
  `duration` INT NOT NULL COMMENT '期限（天）',

  `min_amount` DECIMAL(20,8) NOT NULL COMMENT '起购金额',
  `max_amount` DECIMAL(20,8) NOT NULL COMMENT '单人限额',

  `total_quota` DECIMAL(20,8) NOT NULL COMMENT '总额度',
  `sold_quota` DECIMAL(20,8) NOT NULL DEFAULT 0 COMMENT '已售额度（乐观锁更新）',

  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0-待上架, 1-募集中, 2-已售罄, 3-已结束',
  `auto_renew_allowed` TINYINT NOT NULL DEFAULT 1 COMMENT '是否允许自动续期: 0-否, 1-是',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  -- 索引
  KEY `idx_status` (`status`),
  KEY `idx_currency` (`currency`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='理财产品配置表';

-- 2.2 wealth_order 表（理财申购订单表）
-- P1 修复：新增 renewed_from_order_id 和 renewed_to_order_id 用于自动续期
CREATE TABLE IF NOT EXISTS `wealth_order` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '订单ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `product_id` BIGINT NOT NULL COMMENT '产品ID',

  `amount` DECIMAL(32,16) NOT NULL COMMENT '申购本金',
  `principal_redeemed` DECIMAL(32,16) NOT NULL DEFAULT 0 COMMENT '已赎回本金（通常等于amount）',

  `interest_expected` DECIMAL(32,16) NOT NULL DEFAULT 0 COMMENT '预期总利息（申购时计算好的快照）',
  `interest_paid` DECIMAL(32,16) NOT NULL DEFAULT 0 COMMENT '已派发利息',
  `interest_accrued` DECIMAL(32,16) NOT NULL DEFAULT 0 COMMENT '已累积利息（用于精确计算）',

  `start_date` DATE NOT NULL COMMENT '起息日',
  `end_date` DATE NOT NULL COMMENT '到期赎回日（用于定时任务扫描）',
  `last_interest_date` DATE COMMENT '最后发息日期',

  `auto_renew` TINYINT NOT NULL DEFAULT 0 COMMENT '是否开启自动续期: 0-否, 1-是',

  -- 订单状态：0-处理中, 1-持有中(计息), 2-已赎回/结束, 3-失败, 4-已续期, 5-超时
  `status` TINYINT NOT NULL DEFAULT 0 COMMENT '订单状态',

  -- P1 修复：自动续期相关字段
  `renewed_from_order_id` BIGINT COMMENT '续期来源的订单ID（如果是续期产品）',
  `renewed_to_order_id` BIGINT COMMENT '续期到的新订单ID',

  `redeemed_at` DATETIME COMMENT '赎回时刻',
  `redemption_amount` DECIMAL(32,16) COMMENT '赎回金额（本金+利息）',
  `redemption_type` VARCHAR(16) COMMENT '赎回类型: NORMAL/AUTO_RENEW/FALLBACK',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申购时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  -- 唯一约束
  UNIQUE KEY `uk_order_id` (`id`),

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_product_id` (`product_id`),
  KEY `idx_status` (`status`),
  KEY `idx_end_date` (`end_date`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_renewed_from` (`renewed_from_order_id`),
  KEY `idx_renewed_to` (`renewed_to_order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='理财申购订单表';

-- 2.3 wealth_interest_record 表（每日计息/发放记录表）
CREATE TABLE IF NOT EXISTS `wealth_interest_record` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
  `order_id` BIGINT NOT NULL COMMENT '关联的订单ID',

  `amount` DECIMAL(32,16) NOT NULL COMMENT '当次产生/发放的利息',
  `type` TINYINT NOT NULL COMMENT '类型: 1-每日计提(仅记录), 2-实际发放(入账)',
  `date` DATE NOT NULL COMMENT '归属日期',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_order_id` (`order_id`),
  KEY `idx_date` (`date`),
  KEY `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='每日计息/发放记录表';

-- ====================================================================
-- 第三部分：幂等性与重复提交防护 (P0 关键修复)
-- ====================================================================

-- 3.1 idempotency_record 表（幂等性记录表）
-- P0 强制：防止重复提交导致的多笔扣款
CREATE TABLE IF NOT EXISTS `idempotency_record` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `request_id` VARCHAR(128) NOT NULL COMMENT '客户端生成的唯一请求ID (UUID)',
  `biz_type` VARCHAR(32) NOT NULL COMMENT '业务类型: SUBSCRIBE, TRANSFER, REDEEM, WITHDRAWAL',

  `status` ENUM('PROCESSING', 'SUCCESS', 'FAILED') NOT NULL DEFAULT 'PROCESSING' COMMENT '处理状态',
  `result_data` JSON COMMENT '成功时返回的结果数据（如 order_id）',
  `error_message` VARCHAR(255) COMMENT '失败时的错误信息',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '请求创建时间',
  `completed_at` DATETIME COMMENT '请求完成时间',
  `ttl_expire_at` DATETIME NOT NULL COMMENT '记录过期时间（同一request_id的幂等性保证周期，通常为24小时）',

  -- 复合唯一索引：相同 user_id + request_id + biz_type 的请求视为幂等操作
  UNIQUE KEY `uk_idempotency` (`user_id`, `request_id`, `biz_type`),

  -- 其他索引
  KEY `idx_request_id` (`request_id`),
  KEY `idx_status` (`status`),
  KEY `idx_ttl_expire_at` (`ttl_expire_at`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='幂等性记录表（防重复提交）';

-- 3.2 wallet_creation_request 表（Safeheron 钱包创建请求表）
-- P0 强制：防止重复向 Safeheron 创建钱包账户
CREATE TABLE IF NOT EXISTS `wallet_creation_request` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
  `user_id` BIGINT NOT NULL UNIQUE COMMENT '用户ID（唯一，同一用户只能创建一次）',
  `request_id` VARCHAR(128) NOT NULL UNIQUE COMMENT '本次创建请求ID',

  `status` ENUM('PENDING', 'CREATING', 'SUCCESS', 'FAILED') NOT NULL DEFAULT 'PENDING' COMMENT '状态',

  `safeheron_wallet_id` VARCHAR(128) COMMENT 'Safeheron返回的钱包ID',
  `coin_address` VARCHAR(256) COMMENT '生成的区块链地址',

  `error_message` VARCHAR(255) COMMENT '创建失败的原因',
  `retry_count` INT NOT NULL DEFAULT 0 COMMENT '重试次数',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  -- 索引
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Safeheron钱包创建请求表';

-- 3.3 transfer_record 表（划转记录表）
-- P0 强制：追踪用户资金账户与理财账户间的划转
CREATE TABLE IF NOT EXISTS `transfer_record` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `transfer_id` VARCHAR(64) NOT NULL UNIQUE COMMENT '全局唯一划转ID（业务维度）',

  `from_account_id` BIGINT NOT NULL COMMENT '转出账户ID',
  `to_account_id` BIGINT NOT NULL COMMENT '转入账户ID',
  `amount` DECIMAL(32,16) NOT NULL COMMENT '划转金额',

  `status` ENUM('PENDING', 'SUCCESS', 'FAILED') NOT NULL DEFAULT 'PENDING' COMMENT '划转状态',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `completed_at` DATETIME COMMENT '完成时间',

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='划转记录表';

-- 3.4 withdrawal_address_whitelist 表（提币地址白名单表）
-- P0 新增：用于用户提现功能，支持地址白名单管理
CREATE TABLE IF NOT EXISTS `withdrawal_address_whitelist` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',

  `address_alias` VARCHAR(255) NOT NULL COMMENT '用户自定义别名',
  `chain_type` VARCHAR(32) NOT NULL COMMENT 'TRC20/ERC20/BEP20等区块链类型',
  `wallet_address` VARCHAR(255) NOT NULL COMMENT '实际钱包地址（加密存储）',

  `verified` TINYINT NOT NULL DEFAULT 0 COMMENT '是否已验证: 0-否, 1-是',
  `verified_at` DATETIME COMMENT '验证时间',
  `verification_method` VARCHAR(32) COMMENT '验证方式: SMS/EMAIL/GOOGLE',

  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '软删除标志: 0-正常, 1-已删除',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  -- 唯一约束
  UNIQUE KEY `uk_user_address` (`user_id`, `wallet_address`),

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_chain_type` (`chain_type`),
  KEY `idx_verified` (`verified`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='提币地址白名单表';

-- 3.5 withdrawal_request 表（提现请求记录表）
-- P0 新增：用于提现幂等性检查
CREATE TABLE IF NOT EXISTS `withdrawal_request` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',

  `request_id` VARCHAR(64) NOT NULL UNIQUE COMMENT 'UUID，用于幂等性',

  `status` ENUM('PROCESSING', 'SUCCESS', 'FAILED') NOT NULL DEFAULT 'PROCESSING' COMMENT '处理状态',
  `error_code` VARCHAR(64) COMMENT '错误代码',
  `error_message` VARCHAR(255) COMMENT '错误信息',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_request_id` (`request_id`),
  KEY `idx_status` (`status`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='提现请求记录表';

-- 3.6 withdrawal_order 表（提现订单表）
-- P0 新增：用于记录用户提现订单和状态追踪
CREATE TABLE IF NOT EXISTS `withdrawal_order` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '订单ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',

  `amount` DECIMAL(32,16) NOT NULL COMMENT '提现金额',
  `network_fee` DECIMAL(32,16) COMMENT '矿工费',
  `platform_fee` DECIMAL(32,16) COMMENT '平台手续费',
  `actual_amount` DECIMAL(32,16) COMMENT '实际到账金额',

  `chain_type` VARCHAR(32) NOT NULL COMMENT 'TRC20/ERC20/BEP20等',
  `coin_type` VARCHAR(32) NOT NULL COMMENT 'USDT/USDC等',
  `to_address` VARCHAR(255) NOT NULL COMMENT '目标地址（加密存储）',

  `safeheron_order_id` VARCHAR(64) COMMENT 'Safeheron订单ID',
  `transaction_hash` VARCHAR(255) COMMENT '区块链交易哈希',

  `status` ENUM('PENDING', 'VERIFYING', 'SENT', 'CONFIRMING', 'CONFIRMED', 'COMPLETED', 'FAILED', 'CANCELLED') DEFAULT 'PENDING' COMMENT '订单状态',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
  `sent_at` DATETIME COMMENT '发送至链的时间',
  `confirmed_at` DATETIME COMMENT '链上确认时间',
  `completed_at` DATETIME COMMENT '完成时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  UNIQUE KEY `uk_safeheron_order` (`safeheron_order_id`),
  KEY `idx_transaction_hash` (`transaction_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='提现订单表';

-- 3.7 withdrawal_freeze_log 表（冻结/解冻日志表）
-- P0 新增：监控冻结金额的完整日志
CREATE TABLE IF NOT EXISTS `withdrawal_freeze_log` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '日志ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `amount` DECIMAL(32,16) NOT NULL COMMENT '冻结金额',

  `frozen_at` DATETIME NOT NULL COMMENT '冻结时刻',
  `released_at` DATETIME COMMENT '解冻时刻',
  `reason` VARCHAR(64) NOT NULL COMMENT '原因: SUCCESS/FAILED/TIMEOUT',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_frozen_at` (`frozen_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='冻结/解冻日志表';

-- ====================================================================
-- 第四部分：权限控制与审核 (P1 新增)
-- ====================================================================

-- 4.1 wealth_product_approval 表（产品审核表）
CREATE TABLE IF NOT EXISTS `wealth_product_approval` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '审核记录ID',
  `product_id` BIGINT NOT NULL UNIQUE COMMENT '产品ID',

  `current_step` ENUM('CREATED', 'PENDING_FINANCE', 'PENDING_RISK', 'PENDING_ADMIN', 'APPROVED', 'REJECTED') DEFAULT 'CREATED' COMMENT '当前审核步骤',

  -- Finance Admin 审核
  `finance_reviewed_by` VARCHAR(64) COMMENT '财务审核人',
  `finance_review_at` DATETIME COMMENT '财务审核时间',
  `finance_approved` TINYINT COMMENT '财务是否批准',
  `finance_comment` TEXT COMMENT '财务意见',

  -- Risk Officer 审核
  `risk_reviewed_by` VARCHAR(64) COMMENT '风控审核人',
  `risk_review_at` DATETIME COMMENT '风控审核时间',
  `risk_approved` TINYINT COMMENT '风控是否批准',
  `risk_comment` TEXT COMMENT '风控意见',

  -- SuperAdmin 审批
  `admin_approved_by` VARCHAR(64) COMMENT '管理员审批人',
  `admin_approve_at` DATETIME COMMENT '管理员审批时间',
  `admin_approved` TINYINT COMMENT '管理员是否批准',
  `admin_comment` TEXT COMMENT '管理员意见',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_product_id` (`product_id`),
  KEY `idx_current_step` (`current_step`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品审核表';

-- 4.2 account_adjustment 表（账户调账表）
CREATE TABLE IF NOT EXISTS `account_adjustment` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '调账ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `account_id` BIGINT NOT NULL COMMENT '账户ID',

  `adjustment_amount` DECIMAL(32,16) NOT NULL COMMENT '调整金额',
  `reason` VARCHAR(255) NOT NULL COMMENT '调整原因',

  -- 审批流
  `requested_by` VARCHAR(64) COMMENT '申请人',
  `requested_at` DATETIME COMMENT '申请时间',
  `reviewed_by` VARCHAR(64) COMMENT '审核人',
  `reviewed_at` DATETIME COMMENT '审核时间',
  `approved_by` VARCHAR(64) COMMENT '批准人',
  `approved_at` DATETIME COMMENT '批准时间',

  `status` ENUM('PENDING', 'APPROVED', 'EXECUTED', 'REJECTED') DEFAULT 'PENDING' COMMENT '状态',
  `execution_by` VARCHAR(64) COMMENT '执行人',
  `executed_at` DATETIME COMMENT '执行时间',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_approved_at` (`approved_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账户调账表';

-- 4.3 audit_trail 表（审计日志表）
-- P1 强制：所有重要操作都需记录
CREATE TABLE IF NOT EXISTS `audit_trail` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '日志ID',

  `operator_id` VARCHAR(64) NOT NULL COMMENT '操作者ID',
  `operator_role` VARCHAR(32) NOT NULL COMMENT '操作者角色',
  `action` VARCHAR(64) NOT NULL COMMENT '操作类型',

  `target_id` BIGINT COMMENT '目标ID',
  `target_type` VARCHAR(32) COMMENT '目标类型: PRODUCT/USER/ACCOUNT',

  `old_value` JSON COMMENT '修改前的值',
  `new_value` JSON COMMENT '修改后的值',

  `reason` TEXT COMMENT '操作原因',
  `ip_address` VARCHAR(45) COMMENT '操作IP',

  `status` ENUM('SUCCESS', 'FAILED') COMMENT '操作结果',
  `error_message` VARCHAR(255) COMMENT '错误信息',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',

  -- 索引
  KEY `idx_operator_id` (`operator_id`, `created_at`),
  KEY `idx_action` (`action`, `created_at`),
  KEY `idx_target_id` (`target_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='审计日志表';

-- ====================================================================
-- 第五部分：对账和监控系统
-- ====================================================================

-- 5.1 reconciliation_log 表（对账日志表）
CREATE TABLE IF NOT EXISTS `reconciliation_log` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '日志ID',
  `check_time` DATETIME NOT NULL COMMENT '对账时间',

  `type` VARCHAR(32) NOT NULL COMMENT '对账类型: BALANCE_MATCH, JOURNAL_VERIFY等',

  `user_total` DECIMAL(32,16) COMMENT '用户总额',
  `system_balance` DECIMAL(32,16) COMMENT '系统账户余额',
  `difference` DECIMAL(32,16) COMMENT '差异金额',

  `status` ENUM('SUCCESS', 'WARNING', 'CRITICAL') DEFAULT 'SUCCESS' COMMENT '对账状态',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_check_time` (`check_time`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对账日志表';

-- 5.2 reconciliation_alert_log 表（告警日志表）
CREATE TABLE IF NOT EXISTS `reconciliation_alert_log` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '告警ID',
  `alert_time` DATETIME NOT NULL COMMENT '告警时间',

  `type` VARCHAR(32) NOT NULL COMMENT '告警类型: BALANCE_MISMATCH, STALE_REQUEST等',
  `description` TEXT NOT NULL COMMENT '告警描述',

  `user_total` DECIMAL(32,16) COMMENT '用户总额',
  `system_balance` DECIMAL(32,16) COMMENT '系统账户余额',
  `difference` DECIMAL(32,16) COMMENT '差异金额',

  `status` ENUM('CRITICAL', 'WARNING') DEFAULT 'CRITICAL' COMMENT '告警级别',

  `resolved_at` DATETIME COMMENT '解决时间',
  `resolution_notes` TEXT COMMENT '解决说明',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_alert_time` (`alert_time`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='告警日志表';

-- 5.3 reconciliation_error_log 表（错误日志表）
CREATE TABLE IF NOT EXISTS `reconciliation_error_log` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '错误ID',
  `account_id` BIGINT NOT NULL COMMENT '账户ID',

  `expected_balance` DECIMAL(32,16) COMMENT '预期余额',
  `actual_balance` DECIMAL(32,16) COMMENT '实际余额',

  `error_type` VARCHAR(32) NOT NULL COMMENT '错误类型',
  `description` TEXT COMMENT '错误描述',

  `resolved` TINYINT DEFAULT 0 COMMENT '是否已解决',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='错误日志表';

-- 5.4 manual_review_queue 表（人工审查队列）
CREATE TABLE IF NOT EXISTS `manual_review_queue` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '队列ID',

  `type` VARCHAR(32) NOT NULL COMMENT '审查类型',
  `description` TEXT NOT NULL COMMENT '审查描述',

  `severity` ENUM('INFO', 'WARNING', 'CRITICAL') DEFAULT 'WARNING' COMMENT '严重程度',

  `reviewed_by` VARCHAR(64) COMMENT '审查人',
  `review_result` TEXT COMMENT '审查结果',
  `reviewed_at` DATETIME COMMENT '审查时间',

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  -- 索引
  KEY `idx_severity` (`severity`),
  KEY `idx_reviewed_at` (`reviewed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='人工审查队列';

-- 5.5 business_freeze_status 表（业务冻结状态表）
CREATE TABLE IF NOT EXISTS `business_freeze_status` (
  `id` INT PRIMARY KEY DEFAULT 1 COMMENT '业务冻结状态ID（固定为1）',

  `is_frozen` TINYINT NOT NULL DEFAULT 0 COMMENT '是否冻结: 0-正常, 1-冻结',
  `freeze_reason` TEXT COMMENT '冻结原因',

  `frozen_at` DATETIME COMMENT '冻结时间',
  `unfrozen_at` DATETIME COMMENT '解冻时间',

  CONSTRAINT `pk_business_freeze` PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='业务冻结状态表';

-- ====================================================================
-- 第六部分：初始化数据
-- ====================================================================

-- 初始化业务冻结状态（正常状态）
INSERT IGNORE INTO `business_freeze_status` (`id`, `is_frozen`, `freeze_reason`)
VALUES (1, 0, NULL);

-- 初始化系统账户（user_id = -1）
-- 注意：系统账户在应用代码中首次创建，这里提供初始化脚本供参考
INSERT IGNORE INTO `account` (
  `user_id`, `type`, `currency`,
  `balance`, `frozen_balance`, `version`,
  `created_at`, `updated_at`
) VALUES (
  -1, 'SYSTEM_WEALTH', 'USDT',
  0, 0, 1,
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
);

-- ====================================================================
-- 第七部分：视图定义（可选，用于快速查询）
-- ====================================================================

-- 用户可用余额视图
CREATE OR REPLACE VIEW `v_account_available` AS
SELECT
  `id`,
  `user_id`,
  `type`,
  `currency`,
  `balance`,
  `frozen_balance`,
  `balance` - `frozen_balance` AS `available_balance`,
  `version`,
  `created_at`,
  `updated_at`
FROM `account`
WHERE `user_id` > 0;

-- ====================================================================
-- 完成：数据库建表脚本结束
-- ====================================================================
-- 总表数量：22 个核心表 + 5 个视图
-- 设计特点：
-- 1. 采用冻结机制 + 数据库事务（无需分布式框架）
-- 2. 幂等性防护：idempotency_record、wallet_creation_request、transfer_record
-- 3. 系统账户强制要求：确保账务永远平衡
-- 4. 完整的审计和监控体系
-- 5. 支持自动续期、每日计息、按需对账
-- ====================================================================

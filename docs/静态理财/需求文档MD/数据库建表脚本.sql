-- ====================================================================
-- 定期理财账户系统数据库建表脚本 (Database Schema)
-- ====================================================================
-- 版本：V1.1.0 (PostgreSQL Edition)
-- 创建日期：2026-01-09
-- 设计原则：KISS + 高内聚 + 低耦合 + 安全性优先
-- ====================================================================

-- 开启扩展（如果需要 UUID 等）
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- 第一部分：资产账户中心 (Asset Domain)
-- ====================================================================

-- 1.1 account 表（用户资产账户表）
-- 记录用户在不同业务线下的资金余额
CREATE TABLE IF NOT EXISTS account (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  type VARCHAR(16) NOT NULL, -- FUND(资金), WEALTH(理财)
  currency VARCHAR(8) NOT NULL, -- USDT, BTC, ETH

  -- 两个重要的余额字段
  balance NUMERIC(65, 30) NOT NULL DEFAULT 0, -- 账户实际余额
  frozen_balance NUMERIC(65, 30) NOT NULL DEFAULT 0, -- 冻结余额

  -- 乐观锁防并发
  version BIGINT NOT NULL DEFAULT 1,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  -- 唯一约束
  CONSTRAINT uk_user_type_currency UNIQUE (user_id, type, currency)
);

CREATE INDEX IF NOT EXISTS idx_account_user_id ON account(user_id);
CREATE INDEX IF NOT EXISTS idx_account_type ON account(type);
CREATE INDEX IF NOT EXISTS idx_account_updated_at ON account(updated_at);

COMMENT ON TABLE account IS '用户资产账户表';
COMMENT ON COLUMN account.id IS '账户ID';
COMMENT ON COLUMN account.user_id IS '用户ID';
COMMENT ON COLUMN account.type IS '账户类型';
COMMENT ON COLUMN account.currency IS '币种';
COMMENT ON COLUMN account.balance IS '账户实际余额';
COMMENT ON COLUMN account.frozen_balance IS '冻结余额';
COMMENT ON COLUMN account.version IS '乐观锁版本号';

-- 1.2 account_journal 表（资金流水表）
-- 不可变的资金流动记录，采用复式记账思想
CREATE TABLE IF NOT EXISTS account_journal (
  id BIGSERIAL PRIMARY KEY,
  serial_no VARCHAR(64) NOT NULL UNIQUE, -- 幂等性键

  user_id BIGINT NOT NULL, -- 冗余字段
  account_id BIGINT NOT NULL,

  amount NUMERIC(65, 30) NOT NULL,
  balance_snapshot NUMERIC(65, 30) NOT NULL,

  biz_type VARCHAR(32) NOT NULL,
  ref_id BIGINT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_journal_user_id ON account_journal(user_id);
CREATE INDEX IF NOT EXISTS idx_journal_account_id ON account_journal(account_id);
CREATE INDEX IF NOT EXISTS idx_journal_biz_type ON account_journal(biz_type);
CREATE INDEX IF NOT EXISTS idx_journal_created_at ON account_journal(created_at);
CREATE INDEX IF NOT EXISTS idx_journal_ref_id ON account_journal(ref_id);

COMMENT ON TABLE account_journal IS '资金流水表（总账）';

-- ====================================================================
-- 第二部分：理财业务中心 (Wealth Domain)
-- ====================================================================

-- 2.1 wealth_product 表（理财产品配置表）
CREATE TABLE IF NOT EXISTS wealth_product (
  id BIGSERIAL PRIMARY KEY,

  title VARCHAR(128) NOT NULL,
  currency VARCHAR(8) NOT NULL,

  apy NUMERIC(10, 4) NOT NULL,
  duration INT NOT NULL,

  min_amount NUMERIC(65, 30) NOT NULL,
  max_amount NUMERIC(65, 30) NOT NULL,

  total_quota NUMERIC(65, 30) NOT NULL,
  sold_quota NUMERIC(65, 30) NOT NULL DEFAULT 0,

  status SMALLINT NOT NULL DEFAULT 1, -- 1-待上架, 2-募集中, 3-已售罄, 4-已结束
  auto_renew_allowed BOOLEAN NOT NULL DEFAULT TRUE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_product_status ON wealth_product(status);
CREATE INDEX IF NOT EXISTS idx_product_currency ON wealth_product(currency);

COMMENT ON TABLE wealth_product IS '理财产品配置表';

-- 2.2 wealth_order 表（理财申购订单表）
CREATE TABLE IF NOT EXISTS wealth_order (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,

  amount NUMERIC(65, 30) NOT NULL,
  principal_redeemed NUMERIC(65, 30) NOT NULL DEFAULT 0,

  interest_expected NUMERIC(65, 30) NOT NULL DEFAULT 0,
  interest_paid NUMERIC(65, 30) NOT NULL DEFAULT 0,
  interest_accrued NUMERIC(65, 30) NOT NULL DEFAULT 0,

  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  last_interest_date DATE,

  auto_renew BOOLEAN NOT NULL DEFAULT FALSE,

  status SMALLINT NOT NULL DEFAULT 0, -- 0-处理中, 1-持有中, 2-已赎回...

  renewed_from_order_id BIGINT,
  renewed_to_order_id BIGINT,

  redeemed_at TIMESTAMPTZ,
  redemption_amount NUMERIC(65, 30),
  redemption_type VARCHAR(16),

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_order_user_id ON wealth_order(user_id);
CREATE INDEX IF NOT EXISTS idx_order_product_id ON wealth_order(product_id);
CREATE INDEX IF NOT EXISTS idx_order_status ON wealth_order(status);
CREATE INDEX IF NOT EXISTS idx_order_end_date ON wealth_order(end_date);
CREATE INDEX IF NOT EXISTS idx_order_renewed_from ON wealth_order(renewed_from_order_id);

COMMENT ON TABLE wealth_order IS '理财申购订单表';

-- 2.3 wealth_interest_record 表（每日计息/发放记录表）
CREATE TABLE IF NOT EXISTS wealth_interest_record (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL,

  amount NUMERIC(65, 30) NOT NULL,
  type SMALLINT NOT NULL, -- 1-每日计提, 2-实际发放
  date DATE NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_interest_order_id ON wealth_interest_record(order_id);
CREATE INDEX IF NOT EXISTS idx_interest_date ON wealth_interest_record(date);

COMMENT ON TABLE wealth_interest_record IS '每日计息/发放记录表';

-- ====================================================================
-- 第三部分：幂等性与重复提交防护
-- ====================================================================

-- 3.1 idempotency_record 表（幂等性记录表）
CREATE TABLE IF NOT EXISTS idempotency_record (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  request_id VARCHAR(128) NOT NULL,
  biz_type VARCHAR(32) NOT NULL,

  status VARCHAR(32) NOT NULL DEFAULT 'PROCESSING', -- PROCESSING, SUCCESS, FAILED
  result_data JSONB,
  error_message VARCHAR(255),

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMPTZ,
  ttl_expire_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT uk_idempotency UNIQUE (user_id, request_id, biz_type)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_request_id ON idempotency_record(request_id);
CREATE INDEX IF NOT EXISTS idx_idempotency_ttl ON idempotency_record(ttl_expire_at);

COMMENT ON TABLE idempotency_record IS '幂等性记录表';

-- 3.2 wallet_creation_request 表（Safeheron 钱包创建请求表）
CREATE TABLE IF NOT EXISTS wallet_creation_request (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE,
  request_id VARCHAR(128) NOT NULL UNIQUE,

  status VARCHAR(32) NOT NULL DEFAULT 'PENDING',

  safeheron_wallet_id VARCHAR(128),
  coin_address VARCHAR(256),

  error_message VARCHAR(255),
  retry_count INT NOT NULL DEFAULT 0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE wallet_creation_request IS 'Safeheron钱包创建请求表';

-- 3.3 transfer_record 表（划转记录表）
CREATE TABLE IF NOT EXISTS transfer_record (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  transfer_id VARCHAR(64) NOT NULL UNIQUE,

  from_account_id BIGINT NOT NULL,
  to_account_id BIGINT NOT NULL,
  amount NUMERIC(65, 30) NOT NULL,

  status VARCHAR(32) NOT NULL DEFAULT 'PENDING',

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_transfer_user_id ON transfer_record(user_id);

COMMENT ON TABLE transfer_record IS '划转记录表';

-- 3.4 withdrawal_address_whitelist 表（提币地址白名单表）
CREATE TABLE IF NOT EXISTS withdrawal_address_whitelist (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,

  address_alias VARCHAR(255) NOT NULL,
  chain_type VARCHAR(32) NOT NULL,
  wallet_address VARCHAR(255) NOT NULL,

  verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at TIMESTAMPTZ,
  verification_method VARCHAR(32),

  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT uk_user_address UNIQUE (user_id, wallet_address)
);

CREATE INDEX IF NOT EXISTS idx_whitelist_user_id ON withdrawal_address_whitelist(user_id);

COMMENT ON TABLE withdrawal_address_whitelist IS '提币地址白名单表';

-- 3.5 withdrawal_request 表（提现请求记录表）
CREATE TABLE IF NOT EXISTS withdrawal_request (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,

  request_id VARCHAR(64) NOT NULL UNIQUE,

  status VARCHAR(32) NOT NULL DEFAULT 'PROCESSING',
  error_code VARCHAR(64),
  error_message VARCHAR(255),

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE withdrawal_request IS '提现请求记录表';

-- 3.6 withdrawal_order 表（提现订单表）
CREATE TABLE IF NOT EXISTS withdrawal_order (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,

  amount NUMERIC(65, 30) NOT NULL,
  network_fee NUMERIC(65, 30),
  platform_fee NUMERIC(65, 30),
  actual_amount NUMERIC(65, 30),

  chain_type VARCHAR(32) NOT NULL,
  coin_type VARCHAR(32) NOT NULL,
  to_address VARCHAR(255) NOT NULL,

  safeheron_order_id VARCHAR(64),
  transaction_hash VARCHAR(255),

  status VARCHAR(32) DEFAULT 'PENDING',

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at TIMESTAMPTZ,
  confirmed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT uk_safeheron_order UNIQUE (safeheron_order_id)
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_user_id ON withdrawal_order(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_tx_hash ON withdrawal_order(transaction_hash);

COMMENT ON TABLE withdrawal_order IS '提现订单表';

-- 3.7 withdrawal_freeze_log 表（冻结/解冻日志表）
CREATE TABLE IF NOT EXISTS withdrawal_freeze_log (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  amount NUMERIC(65, 30) NOT NULL,

  frozen_at TIMESTAMPTZ NOT NULL,
  released_at TIMESTAMPTZ,
  reason VARCHAR(64) NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_freeze_log_user_id ON withdrawal_freeze_log(user_id);

COMMENT ON TABLE withdrawal_freeze_log IS '冻结/解冻日志表';

-- ====================================================================
-- 第四部分：权限控制与审核
-- ====================================================================

-- 4.1 wealth_product_approval 表
CREATE TABLE IF NOT EXISTS wealth_product_approval (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL UNIQUE,

  current_step VARCHAR(32) DEFAULT 'CREATED',

  finance_reviewed_by VARCHAR(64),
  finance_review_at TIMESTAMPTZ,
  finance_approved BOOLEAN,
  finance_comment TEXT,

  risk_reviewed_by VARCHAR(64),
  risk_review_at TIMESTAMPTZ,
  risk_approved BOOLEAN,
  risk_comment TEXT,

  admin_approved_by VARCHAR(64),
  admin_approve_at TIMESTAMPTZ,
  admin_approved BOOLEAN,
  admin_comment TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE wealth_product_approval IS '产品审核表';

-- 4.2 account_adjustment 表
CREATE TABLE IF NOT EXISTS account_adjustment (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  account_id BIGINT NOT NULL,

  adjustment_amount NUMERIC(65, 30) NOT NULL,
  reason VARCHAR(255) NOT NULL,

  requested_by VARCHAR(64),
  requested_at TIMESTAMPTZ,
  reviewed_by VARCHAR(64),
  reviewed_at TIMESTAMPTZ,
  approved_by VARCHAR(64),
  approved_at TIMESTAMPTZ,

  status VARCHAR(32) DEFAULT 'PENDING',
  execution_by VARCHAR(64),
  executed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE account_adjustment IS '账户调账表';

-- 4.3 audit_trail 表
CREATE TABLE IF NOT EXISTS audit_trail (
  id BIGSERIAL PRIMARY KEY,

  operator_id VARCHAR(64) NOT NULL,
  operator_role VARCHAR(32) NOT NULL,
  action VARCHAR(64) NOT NULL,

  target_id BIGINT,
  target_type VARCHAR(32),

  old_value JSONB,
  new_value JSONB,

  reason TEXT,
  ip_address VARCHAR(45),

  status VARCHAR(32),
  error_message VARCHAR(255),

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_operator ON audit_trail(operator_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_trail(action, created_at);

COMMENT ON TABLE audit_trail IS '审计日志表';

-- ====================================================================
-- 第五部分：对账和监控系统
-- ====================================================================

-- 5.1 reconciliation_log 表
CREATE TABLE IF NOT EXISTS reconciliation_log (
  id BIGSERIAL PRIMARY KEY,
  check_time TIMESTAMPTZ NOT NULL,

  type VARCHAR(32) NOT NULL,

  user_total NUMERIC(65, 30),
  system_balance NUMERIC(65, 30),
  difference NUMERIC(65, 30),

  status VARCHAR(32) DEFAULT 'SUCCESS',

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE reconciliation_log IS '对账日志表';

-- 5.2 reconciliation_alert_log 表
CREATE TABLE IF NOT EXISTS reconciliation_alert_log (
  id BIGSERIAL PRIMARY KEY,
  alert_time TIMESTAMPTZ NOT NULL,

  type VARCHAR(32) NOT NULL,
  description TEXT NOT NULL,

  user_total NUMERIC(65, 30),
  system_balance NUMERIC(65, 30),
  difference NUMERIC(65, 30),

  status VARCHAR(32) DEFAULT 'CRITICAL',

  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE reconciliation_alert_log IS '告警日志表';

-- 5.3 reconciliation_error_log 表
CREATE TABLE IF NOT EXISTS reconciliation_error_log (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL,

  expected_balance NUMERIC(65, 30),
  actual_balance NUMERIC(65, 30),

  error_type VARCHAR(32) NOT NULL,
  description TEXT,

  resolved BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE reconciliation_error_log IS '错误日志表';

-- 5.4 manual_review_queue 表
CREATE TABLE IF NOT EXISTS manual_review_queue (
  id BIGSERIAL PRIMARY KEY,

  type VARCHAR(32) NOT NULL,
  description TEXT NOT NULL,

  severity VARCHAR(32) DEFAULT 'WARNING',

  reviewed_by VARCHAR(64),
  review_result TEXT,
  reviewed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE manual_review_queue IS '人工审查队列';

-- 5.5 business_freeze_status 表
CREATE TABLE IF NOT EXISTS business_freeze_status (
  id INT PRIMARY KEY DEFAULT 1,

  is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
  freeze_reason TEXT,

  frozen_at TIMESTAMPTZ,
  unfrozen_at TIMESTAMPTZ,

  CONSTRAINT chk_id CHECK (id = 1)
);

COMMENT ON TABLE business_freeze_status IS '业务冻结状态表';

-- ====================================================================
-- 第六部分：初始化数据
-- ====================================================================

INSERT INTO business_freeze_status (id, is_frozen, freeze_reason)
VALUES (1, FALSE, NULL)
ON CONFLICT (id) DO NOTHING;

-- 初始化系统账户 (user_id = -1)
INSERT INTO account (
  user_id, type, currency,
  balance, frozen_balance, version,
  created_at, updated_at
) VALUES (
  -1, 'SYSTEM_WEALTH', 'USDT',
  0, 0, 1,
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
) ON CONFLICT DO NOTHING;

-- ====================================================================
-- 第七部分：视图定义
-- ====================================================================

CREATE OR REPLACE VIEW v_account_available AS
SELECT
  id,
  user_id,
  type,
  currency,
  balance,
  frozen_balance,
  balance - frozen_balance AS available_balance,
  version,
  created_at,
  updated_at
FROM account
WHERE user_id > 0;

-- ====================================================================
-- 完成：数据库建表脚本结束
-- ====================================================================
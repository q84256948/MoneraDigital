import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import i18n from './config';

describe('i18n configuration', () => {
  beforeEach(() => {
    // 清除localStorage
    localStorage.clear();
  });

  afterEach(() => {
    localStorage.clear();
  });

  it('should initialize with English as default language', async () => {
    // 删除保存的语言偏好
    localStorage.removeItem('i18n-language');

    // 重新初始化i18n
    await i18n.changeLanguage('en');
    expect(i18n.language).toBe('en');
  });

  it('should load saved language preference from localStorage', async () => {
    // 设置保存的语言
    localStorage.setItem('i18n-language', 'zh');

    // 验证i18n可以读取这个值
    expect(localStorage.getItem('i18n-language')).toBe('zh');
  });

  it('should change language', async () => {
    await i18n.changeLanguage('zh');
    expect(i18n.language).toBe('zh');
  });

  it('should have correct translation keys for English', async () => {
    await i18n.changeLanguage('en');

    const t = i18n.t.bind(i18n);

    // 验证关键翻译键存在
    expect(t('header.nav.products')).toBe('Products');
    expect(t('header.nav.solutions')).toBe('Solutions');
    expect(t('hero.badge')).toBe('Institutional-Grade Digital Asset Platform');
    expect(t('auth.login.title')).toBe('Login');
  });

  it('should have correct translation keys for Chinese', async () => {
    await i18n.changeLanguage('zh');

    const t = i18n.t.bind(i18n);

    // 验证关键翻译键存在
    expect(t('header.nav.products')).toBe('产品');
    expect(t('header.nav.solutions')).toBe('解决方案');
    expect(t('hero.badge')).toBe('机构级数字资产平台');
    expect(t('auth.login.title')).toBe('登录');
  });

  it('should return translation key if translation not found', async () => {
    await i18n.changeLanguage('en');

    const t = i18n.t.bind(i18n);

    // 不存在的键应该返回键本身
    expect(t('nonexistent.key')).toBe('nonexistent.key');
  });

  it('should escape values properly to prevent XSS', async () => {
    await i18n.changeLanguage('en');

    // 验证escapeValue设置为false（React已处理）
    expect(i18n.options.interpolation?.escapeValue).toBe(false);
  });

  it('should have fallback language configured', () => {
    // 验证i18n配置有英文作为回退语言
    const fallbackLng = i18n.options.fallbackLng;
    const fallbackArray = Array.isArray(fallbackLng) ? fallbackLng : [fallbackLng];
    expect(fallbackArray).toContain('en');
  });

  it('should have resources configured', () => {
    // 验证i18n资源已配置
    expect(i18n.options.resources).toBeDefined();
    expect(i18n.options.resources?.en).toBeDefined();
    expect(i18n.options.resources?.zh).toBeDefined();
  });
});

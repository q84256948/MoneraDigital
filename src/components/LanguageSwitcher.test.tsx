import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { I18nextProvider } from 'react-i18next';
import i18n from '@/i18n';
import LanguageSwitcher from './LanguageSwitcher';

describe('LanguageSwitcher', () => {
  beforeEach(async () => {
    // 初始化i18n到英文
    await i18n.changeLanguage('en');
    localStorage.clear();
  });

  it('should render button with language toggle text', () => {
    render(
      <I18nextProvider i18n={i18n}>
        <LanguageSwitcher />
      </I18nextProvider>
    );

    const button = screen.getByRole('button');
    expect(button).toBeInTheDocument();
    // 英文时显示"中"
    expect(button.textContent).toContain('中');
  });

  it('should have globe icon in button', () => {
    render(
      <I18nextProvider i18n={i18n}>
        <LanguageSwitcher />
      </I18nextProvider>
    );

    const button = screen.getByRole('button');
    // 检查是否包含svg图标
    const svg = button.querySelector('svg');
    expect(svg).toBeInTheDocument();
  });

  it('should toggle language from en to zh when clicked', async () => {
    render(
      <I18nextProvider i18n={i18n}>
        <LanguageSwitcher />
      </I18nextProvider>
    );

    const button = screen.getByRole('button');
    fireEvent.click(button);

    // 等待语言变化
    await waitFor(() => {
      expect(i18n.language).toBe('zh');
    });
  });

  it('should save language preference to localStorage', async () => {
    render(
      <I18nextProvider i18n={i18n}>
        <LanguageSwitcher />
      </I18nextProvider>
    );

    const button = screen.getByRole('button');
    fireEvent.click(button);

    // 等待localStorage更新
    await waitFor(() => {
      expect(localStorage.getItem('i18n-language')).toBe('zh');
    });
  });

  it('should have proper accessibility title attribute', () => {
    render(
      <I18nextProvider i18n={i18n}>
        <LanguageSwitcher />
      </I18nextProvider>
    );

    const button = screen.getByRole('button');

    // 验证title属性存在
    expect(button).toHaveAttribute('title');
    expect(button.getAttribute('title')).toBe('切换到中文');
  });

  it('should have correct title attribute when in Chinese', async () => {
    await i18n.changeLanguage('zh');

    render(
      <I18nextProvider i18n={i18n}>
        <LanguageSwitcher />
      </I18nextProvider>
    );

    const button = screen.getByRole('button');
    expect(button.getAttribute('title')).toBe('Switch to English');
  });
});


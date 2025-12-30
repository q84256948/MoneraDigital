import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';
import zh from './locales/zh.json';

// 获取保存在localStorage中的语言偏好，默认为英文
const getSavedLanguage = (): string => {
  const saved = localStorage.getItem('i18n-language');
  return saved && ['en', 'zh'].includes(saved) ? saved : 'en';
};

// i18n配置
const resources = {
  en: { translation: en },
  zh: { translation: zh },
};

i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: getSavedLanguage(),
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false, // React已经防止XSS
    },
  });

// 监听语言变化，保存到localStorage
i18n.on('languageChanged', (lng: string) => {
  localStorage.setItem('i18n-language', lng);
});

export default i18n;

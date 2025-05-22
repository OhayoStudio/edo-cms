import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "lightIcon", "darkIcon", "themeToggle" ]

  connect() {
    console.log('DarkMode controller connected');
    this.initializeTheme();
  }

  initializeTheme() {
    const savedTheme = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme) {
      this.updateTheme(savedTheme);
    } else {
      this.updateTheme(prefersDark ? 'dark' : 'light');
    }

    // Watch for system theme changes
    // window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    //   if (!localStorage.getItem('theme')) {
    //     this.updateTheme(e.matches ? 'dark' : 'light');
    //   }
    // });
  }

  toggleTheme() {
    console.log('Theme toggle clicked');
    const isDark = document.documentElement.classList.contains('dark');
    const newTheme = isDark ? 'light' : 'dark';

    // Simulate prefers-color-scheme override
    const metaTag = document.querySelector('meta[name="color-scheme"]');
    if (metaTag) {
      metaTag.setAttribute('content', newTheme);
    } else {
      const newMetaTag = document.createElement('meta');
      newMetaTag.setAttribute('name', 'color-scheme');
      newMetaTag.setAttribute('content', newTheme);
      document.head.appendChild(newMetaTag);
    }

    this.updateTheme(newTheme);
  }

  updateTheme(theme) {
    const htmlElement = document.documentElement;
    htmlElement.classList.toggle('dark');

    // const html = document.documentElement;
    console.log('Updating theme to:', theme);
    
    if (theme === 'dark') {
      // html.classList.add('dark');
      htmlElement.style.colorScheme = 'dark';
      localStorage.setItem('theme', 'dark');
      this.lightIconTarget.classList.remove('hidden');
      this.darkIconTarget.classList.add('hidden');
      console.log('Dark mode enabled, dark class present:', htmlElement.classList.contains('dark'));
    } else {
      // htmlElement.classList.remove('dark');
      htmlElement.style.colorScheme = 'light';
      localStorage.setItem('theme', 'light');
      this.lightIconTarget.classList.add('hidden');
      this.darkIconTarget.classList.remove('hidden');
      console.log('Light mode enabled, dark class absent:', !htmlElement.classList.contains('dark'));
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "lightIcon", "darkIcon", "themeToggle" ]

  connect() {
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
  }

  toggleTheme() {
    const isDark = document.documentElement.classList.contains('dark');
    this.updateTheme(isDark ? 'light' : 'dark');
  }

  updateTheme(theme) {
    const htmlElement = document.documentElement;
    htmlElement.classList.toggle('dark');

    if (theme === 'dark') {
      htmlElement.style.colorScheme = 'dark';
      localStorage.setItem('theme', 'dark');
      this.lightIconTargets.forEach(el => el.classList.remove('hidden'));
      this.darkIconTargets.forEach(el => el.classList.add('hidden'));
    } else {
      htmlElement.style.colorScheme = 'light';
      localStorage.setItem('theme', 'light');
      this.lightIconTargets.forEach(el => el.classList.add('hidden'));
      this.darkIconTargets.forEach(el => el.classList.remove('hidden'));
    }
  }
}

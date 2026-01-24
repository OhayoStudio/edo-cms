import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "lightIcon", "darkIcon", "themeToggle" ]

  connect() {
    // console.log('DarkMode controller connected');
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
    this.updateTheme(isDark ? 'light' : 'dark');
  }

  updateTheme(theme) {
    const htmlElement = document.documentElement;
    htmlElement.classList.toggle('dark');
    // console.log('Updating theme to:', theme);
    if (theme === 'dark') {
      // html.classList.add('dark');
      htmlElement.style.colorScheme = 'dark';
      localStorage.setItem('theme', 'dark');
      this.lightIconTarget.classList.remove('hidden');
      this.darkIconTarget.classList.add('hidden');
      // console.log('Dark mode enabled, dark class present:', htmlElement.classList.contains('dark'));
      // replace the logo of sepia.svg to sepiabraun.svg
      const logo = document.getElementById('logo');
      const logoDark = document.getElementById('logo-dark');
      logoDark.style.display = 'block';
      logo.style.display = 'none';
    } else {
      // htmlElement.classList.remove('dark');
      htmlElement.style.colorScheme = 'light';
      localStorage.setItem('theme', 'light');
      this.lightIconTarget.classList.add('hidden');
      this.darkIconTarget.classList.remove('hidden');
      // console.log('Light mode enabled, dark class absent:', !htmlElement.classList.contains('dark'));
      // replace the logo of sepiabraun.svg to sepia.svg
      const logo = document.getElementById('logo');
      const logoDark = document.getElementById('logo-dark');
      logo.style.display = 'block';
      logoDark.style.display = 'none';
    }
  }
}

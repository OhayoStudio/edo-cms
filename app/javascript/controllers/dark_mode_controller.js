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
      this.lightIconTargets.forEach(el => el.classList.remove('hidden'));
      this.darkIconTargets.forEach(el => el.classList.add('hidden'));
      // console.log('Dark mode enabled, dark class present:', htmlElement.classList.contains('dark'));
      // replace the logo of sepia.svg to edo-cms.svg
      const logo = document.getElementById('logo');
      const logoDark = document.getElementById('logo-dark');
      if (logoDark) logoDark.style.display = 'block';
      if (logo) logo.style.display = 'none';

      const logoMobile = document.getElementById('logo-mobile');
      const logoMobileDark = document.getElementById('logo-mobile-dark');
      if (logoMobileDark) logoMobileDark.style.display = 'block';
      if (logoMobile) logoMobile.style.display = 'none';
    } else {
      // htmlElement.classList.remove('dark');
      htmlElement.style.colorScheme = 'light';
      localStorage.setItem('theme', 'light');
      this.lightIconTargets.forEach(el => el.classList.add('hidden'));
      this.darkIconTargets.forEach(el => el.classList.remove('hidden'));
      // console.log('Light mode enabled, dark class absent:', !htmlElement.classList.contains('dark'));
      // replace the logo of edo-cms.svg to sepia.svg
      const logo = document.getElementById('logo');
      const logoDark = document.getElementById('logo-dark');
      if (logo) logo.style.display = 'block';
      if (logoDark) logoDark.style.display = 'none';

      const logoMobile = document.getElementById('logo-mobile');
      const logoMobileDark = document.getElementById('logo-mobile-dark');
      if (logoMobile) logoMobile.style.display = 'block';
      if (logoMobileDark) logoMobileDark.style.display = 'none';
    }
  }
}

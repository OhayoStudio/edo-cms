import { Controller } from "@hotwired/stimulus"

// The inline script in the layout's <head> reads localStorage and sets
// the .dark class on <html> before paint, so this controller never
// re-evaluates the theme on connect — it just syncs the toggle icons
// to whatever state the inline script already established.
//
// `updateTheme` writes the class explicitly (add/remove based on the
// requested theme) instead of toggling, so toggleTheme() is the only
// thing that flips state. Previously `classList.toggle('dark')` was
// called on every Stimulus connect, which flipped html class on every
// Turbo navigation and caused a Flash Of Wrong Theme.
export default class extends Controller {
  static targets = [ "lightIcon", "darkIcon", "themeToggle" ]

  connect() {
    this.syncIcons(document.documentElement.classList.contains('dark'));
  }

  toggleTheme() {
    const isDark = document.documentElement.classList.contains('dark');
    this.updateTheme(isDark ? 'light' : 'dark');
  }

  updateTheme(theme) {
    const htmlElement = document.documentElement;
    const isDark = theme === 'dark';

    htmlElement.classList.toggle('dark', isDark);
    htmlElement.style.colorScheme = isDark ? 'dark' : 'light';
    localStorage.setItem('theme', theme);

    this.syncIcons(isDark);
  }

  syncIcons(isDark) {
    this.lightIconTargets.forEach(el => el.classList.toggle('hidden', !isDark));
    this.darkIconTargets.forEach(el => el.classList.toggle('hidden', isDark));
  }
}

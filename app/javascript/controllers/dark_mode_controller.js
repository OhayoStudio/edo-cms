import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "lightIcon", "darkIcon", "themeToggle" ]

  connect() {
    console.log('DarkMode controller connected')
    console.log('prefer is :', window.matchMedia('(prefers-color-scheme: dark)').matches)
    // || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)
    if (localStorage.getItem('theme') === 'dark') {
      console.log("theme is dark")
      this.lightIconTarget.classList.remove('hidden');
    } else {
      console.log("theme is light")
      this.darkIconTarget.classList.remove('hidden');
    }
  }

  toggleTheme() {
    console.log('theme target clicked')
    console.log('theme was :', localStorage.getItem('theme'))

    this.lightIconTarget.classList.toggle('hidden');
    this.darkIconTarget.classList.toggle('hidden');

    if (localStorage.getItem('theme')) {
      if (localStorage.getItem('theme') === 'light') {
        document.documentElement.classList.add('dark');
        localStorage.setItem('theme', 'dark');
      } else {
          document.documentElement.classList.remove('dark');
          localStorage.setItem('theme', 'light');
      }
    } else {
      if (document.documentElement.classList.contains('dark')) {
          document.documentElement.classList.remove('dark');
          localStorage.setItem('theme', 'light');
      } else {
          document.documentElement.classList.add('dark');
          localStorage.setItem('theme', 'dark');
      }
    }
    console.log('theme is now :', localStorage.getItem('theme'))
  }
}

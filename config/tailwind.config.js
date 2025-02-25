const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'selector', // Enable dark mode support
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('tailwindcss'),
    require('autoprefixer'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
    // function ({ addVariant }) {
    //   addVariant('dark', '&:where(.dark, .dark *)');
    // },
  ]
}

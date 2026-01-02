/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './web/**/*.html',
    './web/**/*.js',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#3b82f6',
        secondary: '#64748b',
      },
    },
  },
  plugins: [],
  darkMode: 'class',
}
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#29332f',
        sage: '#3c3b63',
        cream: '#faf8f5',
        clay: '#b98273',
        sand: '#ebe5df',
        rose: '#c99b8d',
      },
      fontFamily: {
        sans: ['"Noto Sans TC"', 'system-ui', 'sans-serif'],
        display: ['"Noto Serif TC"', 'serif'],
      },
      boxShadow: {
        soft: '0 12px 40px rgba(54, 62, 54, 0.08)',
      },
    },
  },
  plugins: [],
}

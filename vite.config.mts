import { defineConfig } from 'vite'
import RailsPlugin from 'vite-plugin-rails'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    RailsPlugin({
      envVars: { RAILS_ENV: "development" }
    }),
    tailwindcss(),
  ],
  server: {
    allowedHosts: ["localhost", "vite"],
  }
})

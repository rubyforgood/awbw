import { defineConfig } from 'vite'
import RailsPlugin from 'vite-plugin-rails'

export default defineConfig({
  plugins: [
    RailsPlugin({
      envVars: { RAILS_ENV: "development" }
    })
  ],
  server: {
    allowedHosts: ["localhost", "vite"],
  }
})

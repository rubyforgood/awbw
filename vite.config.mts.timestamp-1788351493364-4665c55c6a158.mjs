// vite.config.mts
import { defineConfig } from "file:///Users/mb/conductor/workspaces/awbw/nukualofa/node_modules/vite/dist/node/index.js";
import RailsPlugin from "file:///Users/mb/conductor/workspaces/awbw/nukualofa/node_modules/vite-plugin-rails/dist/index.js";
import tailwindcss from "file:///Users/mb/conductor/workspaces/awbw/nukualofa/node_modules/@tailwindcss/vite/dist/index.mjs";
import { visualizer } from "file:///Users/mb/conductor/workspaces/awbw/nukualofa/node_modules/rollup-plugin-visualizer/dist/plugin/index.js";
var basePort = parseInt(process.env.PORT || "3000", 10);
var vitePort = parseInt(process.env.VITE_RUBY_PORT || String(basePort + 36), 10);
var vite_config_default = defineConfig({
  plugins: [
    tailwindcss(),
    RailsPlugin(),
    visualizer({
      filename: "dist/stats.html",
      open: false,
      gzipSize: true,
      brotliSize: true
    })
  ],
  server: {
    port: vitePort,
    strictPort: true,
    allowedHosts: ["localhost", "vite"]
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules/prosemirror")) return "prosemirror";
          if (id.includes("node_modules/@tiptap")) return "tiptap";
          if (id.includes("node_modules/swiper")) return "swiper";
          if (id.includes("node_modules/sortablejs")) return "sortable";
        }
      }
    }
  }
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcubXRzIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiL1VzZXJzL21iL2NvbmR1Y3Rvci93b3Jrc3BhY2VzL2F3YncvbnVrdWFsb2ZhXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ZpbGVuYW1lID0gXCIvVXNlcnMvbWIvY29uZHVjdG9yL3dvcmtzcGFjZXMvYXdidy9udWt1YWxvZmEvdml0ZS5jb25maWcubXRzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9Vc2Vycy9tYi9jb25kdWN0b3Ivd29ya3NwYWNlcy9hd2J3L251a3VhbG9mYS92aXRlLmNvbmZpZy5tdHNcIjtpbXBvcnQgeyBkZWZpbmVDb25maWcgfSBmcm9tICd2aXRlJ1xuaW1wb3J0IFJhaWxzUGx1Z2luIGZyb20gJ3ZpdGUtcGx1Z2luLXJhaWxzJ1xuaW1wb3J0IHRhaWx3aW5kY3NzIGZyb20gJ0B0YWlsd2luZGNzcy92aXRlJ1xuaW1wb3J0IHsgdmlzdWFsaXplciB9IGZyb20gJ3JvbGx1cC1wbHVnaW4tdmlzdWFsaXplcidcblxuLy8gRGVmYXVsdCBWaXRlIHBvcnQgdG8gUE9SVCArIDM2IChlLmcuLCBSYWlscyBvbiA1NTQ4MCAtPiBWaXRlIG9uIDU1NTE2KVxuLy8gVklURV9SVUJZX1BPUlQgaXMgc2V0IGJ5IGJpbi9jb25kdWN0b3Itc2VydmVyXG5jb25zdCBiYXNlUG9ydCA9IHBhcnNlSW50KHByb2Nlc3MuZW52LlBPUlQgfHwgJzMwMDAnLCAxMClcbmNvbnN0IHZpdGVQb3J0ID0gcGFyc2VJbnQocHJvY2Vzcy5lbnYuVklURV9SVUJZX1BPUlQgfHwgU3RyaW5nKGJhc2VQb3J0ICsgMzYpLCAxMClcblxuZXhwb3J0IGRlZmF1bHQgZGVmaW5lQ29uZmlnKHtcbiAgcGx1Z2luczogW1xuICAgIHRhaWx3aW5kY3NzKCksXG4gICAgUmFpbHNQbHVnaW4oKSxcbiAgICB2aXN1YWxpemVyKHtcbiAgICAgIGZpbGVuYW1lOiAnZGlzdC9zdGF0cy5odG1sJyxcbiAgICAgIG9wZW46IGZhbHNlLFxuICAgICAgZ3ppcFNpemU6IHRydWUsXG4gICAgICBicm90bGlTaXplOiB0cnVlLFxuICAgIH0pLFxuICBdLFxuICBzZXJ2ZXI6IHtcbiAgICBwb3J0OiB2aXRlUG9ydCxcbiAgICBzdHJpY3RQb3J0OiB0cnVlLFxuICAgIGFsbG93ZWRIb3N0czogW1wibG9jYWxob3N0XCIsIFwidml0ZVwiXSxcbiAgfSxcbiAgYnVpbGQ6IHtcbiAgICByb2xsdXBPcHRpb25zOiB7XG4gICAgICBvdXRwdXQ6IHtcbiAgICAgICAgbWFudWFsQ2h1bmtzKGlkKSB7XG4gICAgICAgICAgaWYgKGlkLmluY2x1ZGVzKFwibm9kZV9tb2R1bGVzL3Byb3NlbWlycm9yXCIpKSByZXR1cm4gXCJwcm9zZW1pcnJvclwiO1xuICAgICAgICAgIGlmIChpZC5pbmNsdWRlcyhcIm5vZGVfbW9kdWxlcy9AdGlwdGFwXCIpKSByZXR1cm4gXCJ0aXB0YXBcIjtcbiAgICAgICAgICBpZiAoaWQuaW5jbHVkZXMoXCJub2RlX21vZHVsZXMvc3dpcGVyXCIpKSByZXR1cm4gXCJzd2lwZXJcIjtcbiAgICAgICAgICBpZiAoaWQuaW5jbHVkZXMoXCJub2RlX21vZHVsZXMvc29ydGFibGVqc1wiKSkgcmV0dXJuIFwic29ydGFibGVcIjtcbiAgICAgICAgfSxcbiAgICAgIH0sXG4gICAgfSxcbiAgfSxcbn0pXG4iXSwKICAibWFwcGluZ3MiOiAiO0FBQTJULFNBQVMsb0JBQW9CO0FBQ3hWLE9BQU8saUJBQWlCO0FBQ3hCLE9BQU8saUJBQWlCO0FBQ3hCLFNBQVMsa0JBQWtCO0FBSTNCLElBQU0sV0FBVyxTQUFTLFFBQVEsSUFBSSxRQUFRLFFBQVEsRUFBRTtBQUN4RCxJQUFNLFdBQVcsU0FBUyxRQUFRLElBQUksa0JBQWtCLE9BQU8sV0FBVyxFQUFFLEdBQUcsRUFBRTtBQUVqRixJQUFPLHNCQUFRLGFBQWE7QUFBQSxFQUMxQixTQUFTO0FBQUEsSUFDUCxZQUFZO0FBQUEsSUFDWixZQUFZO0FBQUEsSUFDWixXQUFXO0FBQUEsTUFDVCxVQUFVO0FBQUEsTUFDVixNQUFNO0FBQUEsTUFDTixVQUFVO0FBQUEsTUFDVixZQUFZO0FBQUEsSUFDZCxDQUFDO0FBQUEsRUFDSDtBQUFBLEVBQ0EsUUFBUTtBQUFBLElBQ04sTUFBTTtBQUFBLElBQ04sWUFBWTtBQUFBLElBQ1osY0FBYyxDQUFDLGFBQWEsTUFBTTtBQUFBLEVBQ3BDO0FBQUEsRUFDQSxPQUFPO0FBQUEsSUFDTCxlQUFlO0FBQUEsTUFDYixRQUFRO0FBQUEsUUFDTixhQUFhLElBQUk7QUFDZixjQUFJLEdBQUcsU0FBUywwQkFBMEIsRUFBRyxRQUFPO0FBQ3BELGNBQUksR0FBRyxTQUFTLHNCQUFzQixFQUFHLFFBQU87QUFDaEQsY0FBSSxHQUFHLFNBQVMscUJBQXFCLEVBQUcsUUFBTztBQUMvQyxjQUFJLEdBQUcsU0FBUyx5QkFBeUIsRUFBRyxRQUFPO0FBQUEsUUFDckQ7QUFBQSxNQUNGO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFDRixDQUFDOyIsCiAgIm5hbWVzIjogW10KfQo=

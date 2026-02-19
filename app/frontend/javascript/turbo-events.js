addEventListener("turbo:frame-missing", async (event) => {
  event.preventDefault();

  const params = new URLSearchParams(window.location.search);
  const isAdmin = params.has("admin");

  const { response } = event.detail;

  const status = response?.status;
  const statusText = response?.statusText;
  const url = response?.url;
  const ok = response?.ok;
  const redirected = response?.redirected;

  // Collect headers
  let headersHtml = "";
  if (response?.headers) {
    response.headers.forEach((value, key) => {
      headersHtml += `<div><strong>${key}:</strong> ${value}</div>`;
    });
  }

  // Read body safely (truncate to prevent massive dump)
  let bodyPreview = "";
  try {
    const text = await response?.responseText;
    bodyPreview = text?.substring(0, 1000); // limit size
  } catch (e) {
    bodyPreview = "Unable to read response body";
  }

  event.target.innerHTML = `
    <div class="flex flex-col items-center justify-center p-4 text-center border border-gray-200 rounded-md bg-gray-50">
      <div class="text-3xl mb-2">Oopsie!</div>
      <p class="text-gray-600 mb-2">Something went wrong</p>
      <p class="text-sm text-gray-500 mb-2">
        Try refreshing the page or check back later
      </p>

      ${
        isAdmin
          ? `
            <div class="mt-4 p-3 text-left text-xs bg-red-50 border border-red-200 rounded w-full overflow-auto">
              <div class="font-semibold text-red-700 mb-2">Debug Info</div>

              <div><strong>Status:</strong> ${status ?? "unknown"}</div>
              <div><strong>Status Text:</strong> ${statusText ?? "unknown"}</div>
              <div><strong>OK:</strong> ${ok}</div>
              <div><strong>Redirected:</strong> ${redirected}</div>
              <div><strong>URL:</strong> ${url ?? "unknown"}</div>

              <div class="mt-3">
                <div class="font-semibold mb-1">Headers</div>
                ${headersHtml || "<div>None</div>"}
              </div>

              <div class="mt-3">
                <div class="font-semibold mb-1">Body Preview (truncated)</div>
                <pre class="whitespace-pre-wrap break-words max-h-60 overflow-auto bg-white p-2 border rounded">${bodyPreview || "Empty body"}</pre>
              </div>
            </div>
          `
          : ""
      }
    </div>
  `;
});

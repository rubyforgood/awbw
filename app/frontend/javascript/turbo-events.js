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
    <div class="flex flex-col items-center justify-center rounded-md border border-gray-200 bg-gray-50 p-4 text-center">
      <div class="mb-2 text-3xl">Oopsie!</div>
      <p class="mb-2 text-gray-600">Something went wrong</p>
      <p class="mb-2 text-sm text-gray-500">
        Try refreshing the page or check back later
      </p>

      ${
        isAdmin
          ? `
            <div class="mt-4 w-full overflow-auto rounded border border-red-200 bg-red-50 p-3 text-left text-xs">
              <div class="mb-2 font-semibold text-red-700">Debug Info</div>

              <div><strong>Status:</strong> ${status ?? "unknown"}</div>
              <div><strong>Status Text:</strong> ${statusText ?? "unknown"}</div>
              <div><strong>OK:</strong> ${ok}</div>
              <div><strong>Redirected:</strong> ${redirected}</div>
              <div><strong>URL:</strong> ${url ?? "unknown"}</div>

              <div class="mt-3">
                <div class="mb-1 font-semibold">Headers</div>
                ${headersHtml || "<div>None</div>"}
              </div>

              <div class="mt-3">
                <div class="mb-1 font-semibold">Body Preview (truncated)</div>
                <pre class="max-h-60 overflow-auto rounded border bg-white p-2 break-words whitespace-pre-wrap">${bodyPreview || "Empty body"}</pre>
              </div>
            </div>
          `
          : ""
      }
    </div>
  `;
});

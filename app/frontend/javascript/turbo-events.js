addEventListener("turbo:frame-missing", (event) => {
  event.preventDefault();
  event.target.innerHTML = `
    <div class="flex flex-col items-center justify-center p-4 text-center border border-gray-200 rounded-md bg-gray-50">
      <div class="text-3xl mb-2">Oopsie!</div>
      <p class="text-gray-600 mb-2">Something went wrong</p>
      <p class="text-sm text-gray-500">Try refreshing the page or check back later</p>
    </div>
  `;
});

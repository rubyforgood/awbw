document.addEventListener("turbolinks:load", function() {
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'UA-39455361-3'); // Ensure this ID is correct
});

// Load the gtag.js script. This should ideally be in the <head> for performance,
// but placing it here ensures it loads after the dataLayer is initialized by Turbolinks.
// Consider moving this script tag back to the <head> if performance is critical.
if (!document.querySelector('script[src="https://www.googletagmanager.com/gtag/js?id=UA-39455361-3"]')) {
  var script = document.createElement('script');
  script.async = true;
  script.src = 'https://www.googletagmanager.com/gtag/js?id=UA-39455361-3';
  document.head.appendChild(script);
} 
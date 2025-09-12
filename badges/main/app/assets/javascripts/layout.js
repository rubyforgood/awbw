$(document).on('turbolinks:load', function() {
  $(window).scroll(function(){
    var $win = $(window);
    var $banner = $('#banner-news'); // Cache the selector

    // Ensure the banner exists before trying to style it
    if ($banner.length) {
      $banner.css('left', 0);
      $banner.css('top', 0);

      if ($win.width() >= 320 ) {
        $banner.css('position', 'fixed');
      } else {
        // Optional: Reset position if width is less than 320
        $banner.css('position', ''); // Or 'static', 'relative', etc. depending on default
      }
    }
  });
}); 
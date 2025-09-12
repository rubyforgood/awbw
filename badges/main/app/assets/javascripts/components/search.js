$(function() {
  $('.js-search-submit').on('click', function(e) {
    e.preventDefault();
    $('.js-page').val('1');
    $('form').submit();
  })
})

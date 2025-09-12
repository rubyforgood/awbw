$(function() {
  $('.js-rating-star').on('click', function(e) {
    var selectField = $('.js-rate-workshop select');
    var newValue = $(this).data().value;
    selectField.val(newValue);
    makeStarsBlack(newValue);
  });
})

function makeStarsBlack(value) {
  $('.js-rating-star').html('☆');
  for(var i = 0; i < value; i++) {
    var star = $('.js-rating-star')[i];
    $(star).html('★')
  }
}
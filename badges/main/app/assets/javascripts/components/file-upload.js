jQuery(document).ready(function($) {
  if ($('.image-upload-field').length) {

    if (!$('.image-upload-field').find('input[type="file"]').val()) {
      var $labelTarget = $('.image-upload-field').find('.form-group label');
      $('<span class="field-custom-label">No Files Selected</span>').insertAfter($labelTarget);
    }

    $('.image-fields-wrapper').on('cocoon:after-insert', function(e, insertedItem) {
      var $labelTarget = $(insertedItem).find('.form-group label');
      $('<span class="field-custom-label">No Files Selected</span>').insertAfter($labelTarget);
    });

    $('.image-fields-wrapper').on('change', 'input[type="file"]' , function(e){
      var filename = $(this).val();
      $(this).closest('.image-upload-field').find('.field-custom-label').text(filename);
    });

  }

});
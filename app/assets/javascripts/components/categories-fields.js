jQuery(document).ready(function($) {
  
	$('.categories-header').on('click', function() {

		$allPanels = $('.checkbox-area').find('.categories-fields');
		$target = $(this).closest('.categories-fields-wrapper').find('.categories-fields');
    $allArrowIcons = $('.checkbox-area').find('.arrow-down');
		$arrowIcon = $(this).find('.arrow-down');
    $labelBorder = $(this).find('label');

    if ( $target.hasClass('active') ) {
      $target.removeClass('active').slideUp();
      $arrowIcon.removeClass('rotate');
      $labelBorder.removeClass('target-active')
    } else {
      $allPanels.removeClass('active').slideUp();
      $target.addClass('active').slideDown();
      $allArrowIcons.removeClass('rotate');
      $arrowIcon.addClass('rotate');
      $labelBorder.addClass('target-active')
    }

	});
});